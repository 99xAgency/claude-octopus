#!/usr/bin/env bash
# pr-review-state.sh — per-PR review iteration state for /octo:review
#
# Why this exists:
#   Today, running /octo:review twice on the same PR is stateless — each pass
#   sees only the current diff, not what was flagged last round, what was
#   addressed, or what regressed. This module gives the dispatch prompt
#   "what we said before + what changed since" so round N+1 is a structured
#   re-review, not a fresh read.
#
# Public API (all functions echo to stdout, never modify env vars):
#
#   pr_review_state_load <pr_number>
#       Echoes a markdown-formatted "prior context" block ready for prompt
#       injection. Empty if no prior round exists or no PR.
#
#   pr_review_state_save <pr_number> <findings_file>
#       Persists a round entry (HEAD sha + finding summary) to the per-PR
#       state file. Idempotent — append-only, atomic via tmp+mv.
#
#   pr_review_diff_since_last <pr_number>
#       Echoes git diff from last round's HEAD sha to current HEAD,
#       truncated at OCTOPUS_PR_REVIEW_DIFF_MAX_LINES (default 500).
#
# State location:
#   .claude-octopus/pr-review-state/<pr_number>.json
#   (per-project, scoped to the current repo; one file per PR)
#
# Schema (per-file):
#   {
#     "version": "1.0",
#     "pr_number": 322,
#     "rounds": [
#       {
#         "round": 1,
#         "timestamp": "2026-04-25T07:00:00Z",
#         "head_sha": "abc123def456",
#         "findings_count": 3,
#         "findings_summary": [
#           {"file": "src/foo.ts", "line": 42, "title": "...", "severity": "normal"}
#         ]
#       }
#     ]
#   }

# ── Internal helpers ─────────────────────────────────────────────────────────

_pr_state_dir() {
    printf '%s' ".claude-octopus/pr-review-state"
}

_pr_state_file() {
    local pr_number="$1"
    printf '%s/%s.json' "$(_pr_state_dir)" "$pr_number"
}

_pr_state_in_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

_pr_state_current_sha() {
    git rev-parse HEAD 2>/dev/null || true
}

# Atomic JSON write — same pattern as state-manager.sh's atomic_write
_pr_state_atomic_write() {
    local file="$1" content="$2"
    local tmp
    tmp=$(mktemp "${file}.XXXXXX")
    printf '%s\n' "$content" > "$tmp" && mv "$tmp" "$file"
}

# ── Public API ───────────────────────────────────────────────────────────────

# pr_review_state_load <pr_number>
# Returns: markdown-formatted prior context block (empty if no prior data)
pr_review_state_load() {
    local pr_number="${1:-}"
    [[ -z "$pr_number" ]] && return 0

    local state_file
    state_file=$(_pr_state_file "$pr_number")
    [[ ! -f "$state_file" ]] && return 0

    # Round count guard — if state file exists but has no rounds, skip
    local round_count
    round_count=$(jq -r '.rounds | length' "$state_file" 2>/dev/null || echo "0")
    [[ "$round_count" -lt 1 ]] && return 0

    local last_round_n last_sha last_ts
    last_round_n=$(jq -r '.rounds[-1].round' "$state_file" 2>/dev/null)
    last_sha=$(jq -r '.rounds[-1].head_sha' "$state_file" 2>/dev/null)
    last_ts=$(jq -r '.rounds[-1].timestamp' "$state_file" 2>/dev/null)

    # Build the prior context block
    {
        printf '## Prior reviews on this PR\n\n'
        printf 'This is review **round %d** for PR #%d.\n\n' \
            "$((round_count + 1))" "$pr_number"
        printf '### Findings from round %d (HEAD `%s`, %s)\n\n' \
            "$last_round_n" "${last_sha:0:8}" "$last_ts"

        # Echo the prior round's finding summary
        local findings_count
        findings_count=$(jq -r '.rounds[-1].findings_count' "$state_file" 2>/dev/null)
        if [[ "$findings_count" -eq 0 ]]; then
            printf '_(No findings flagged in the prior round.)_\n\n'
        else
            jq -r '.rounds[-1].findings_summary[] | "- `\(.file):\(.line)` [\(.severity)] \(.title)"' \
                "$state_file" 2>/dev/null
            printf '\n'
        fi

        # Diff since last round
        printf '### Changes since round %d\n\n' "$last_round_n"
        local diff_block
        diff_block=$(pr_review_diff_since_last "$pr_number" 2>/dev/null)
        if [[ -z "$diff_block" ]]; then
            if ! _pr_state_in_git_repo; then
                printf '_(Not a git repo or git unavailable — diff omitted.)_\n\n'
            else
                printf '_(No changes between round %d and current HEAD.)_\n\n' "$last_round_n"
            fi
        else
            printf '```diff\n%s\n```\n\n' "$diff_block"
        fi

        # Reviewer instructions
        printf '### Your job this round\n\n'
        printf -- '- For each prior finding above, classify against the current diff: **addressed** / **persistent** / **regressed**.\n'
        printf -- '- Add **new** findings only if introduced by the diff since round %d.\n' "$last_round_n"
        printf -- '- Do not re-raise findings that were addressed unless the fix introduced a new bug.\n\n'
    }
}

# pr_review_state_save <pr_number> <findings_file>
# Appends a round entry to the per-PR state file.
# findings_file is the JSON file produced by review_run() with shape:
#   {"findings": [{"file": "...", "line": 42, "title": "...", "severity": "..."}, ...]}
pr_review_state_save() {
    local pr_number="${1:-}"
    local findings_file="${2:-}"
    [[ -z "$pr_number" || -z "$findings_file" ]] && return 0
    [[ ! -f "$findings_file" ]] && return 0

    local state_dir
    state_dir=$(_pr_state_dir)
    mkdir -p "$state_dir"

    local state_file
    state_file=$(_pr_state_file "$pr_number")

    # Compose the new round entry
    local current_sha timestamp findings_count
    current_sha=$(_pr_state_current_sha)
    timestamp=$(date -u +%FT%TZ)
    findings_count=$(jq -r '.findings | length' "$findings_file" 2>/dev/null || echo "0")

    # Trimmed finding summary — strip detail to keep the state file small
    local findings_summary
    findings_summary=$(jq -c '[.findings[] | {file, line, title, severity}]' "$findings_file" 2>/dev/null || echo "[]")

    # Determine the next round number
    local next_round=1
    if [[ -f "$state_file" ]]; then
        local existing_rounds
        existing_rounds=$(jq -r '.rounds | length' "$state_file" 2>/dev/null || echo "0")
        next_round=$((existing_rounds + 1))
    fi

    # Build the new round JSON
    local new_round_json
    new_round_json=$(jq -n \
        --argjson round "$next_round" \
        --arg ts "$timestamp" \
        --arg sha "$current_sha" \
        --argjson count "$findings_count" \
        --argjson summary "$findings_summary" \
        '{round: $round, timestamp: $ts, head_sha: $sha, findings_count: $count, findings_summary: $summary}')

    # Append (or initialize)
    local new_state
    if [[ -f "$state_file" ]]; then
        new_state=$(jq --argjson r "$new_round_json" '.rounds += [$r]' "$state_file" 2>/dev/null)
    else
        new_state=$(jq -n \
            --argjson pr "$pr_number" \
            --argjson r "$new_round_json" \
            '{version: "1.0", pr_number: $pr, rounds: [$r]}')
    fi

    if [[ -n "$new_state" ]]; then
        _pr_state_atomic_write "$state_file" "$new_state"
    fi
}

# pr_review_diff_since_last <pr_number>
# Echoes git diff <last-round-sha>..HEAD, capped at OCTOPUS_PR_REVIEW_DIFF_MAX_LINES.
# Empty if no prior round, no sha recorded, or not in a git repo.
pr_review_diff_since_last() {
    local pr_number="${1:-}"
    [[ -z "$pr_number" ]] && return 0
    _pr_state_in_git_repo || return 0

    local state_file
    state_file=$(_pr_state_file "$pr_number")
    [[ ! -f "$state_file" ]] && return 0

    local last_sha
    last_sha=$(jq -r '.rounds[-1].head_sha // empty' "$state_file" 2>/dev/null)
    [[ -z "$last_sha" || "$last_sha" == "null" ]] && return 0

    local max_lines="${OCTOPUS_PR_REVIEW_DIFF_MAX_LINES:-500}"
    local diff
    diff=$(git diff "${last_sha}"..HEAD 2>/dev/null || true)
    [[ -z "$diff" ]] && return 0

    local total_lines
    total_lines=$(printf '%s\n' "$diff" | wc -l | tr -d ' ')
    if [[ "$total_lines" -gt "$max_lines" ]]; then
        printf '%s\n' "$diff" | head -n "$max_lines"
        printf '\n[... %d more lines truncated — full diff: git diff %s..HEAD]\n' \
            "$((total_lines - max_lines))" "$last_sha"
    else
        printf '%s\n' "$diff"
    fi
}
