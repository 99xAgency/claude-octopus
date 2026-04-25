#!/usr/bin/env bash
# Tests for scripts/lib/pr-review-state.sh — round-aware PR review state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "pr-review-state.sh — round-aware PR review state"

LIB="$PROJECT_ROOT/scripts/lib/pr-review-state.sh"
[[ -f "$LIB" ]] || { echo "missing $LIB"; exit 1; }

# Source the lib in the parent shell so functions are visible to every
# test_case below. The lib's state-file paths are relative to $PWD, so each
# test cd's into a fresh tmp dir before running.
# shellcheck disable=SC1090
source "$LIB"

# ── Fixtures ─────────────────────────────────────────────────────────────────

# Create + cd into a fresh tmp git repo. Sets the global $TMP_REPO so the
# parent shell stays in the new dir (command substitution would lose the cd).
TMP_REPO=""
setup_tmp_repo() {
    TMP_REPO=$(mktemp -d "${TMPDIR:-/tmp}/pr-review-state-test.XXXXXX")
    cd "$TMP_REPO"
    git init -q
    git config user.email t@t
    git config user.name t
    echo "v1" > thing.txt
    git add . && git commit -q -m "initial"
}

cleanup_tmp_repo() {
    cd /
    [[ -n "$TMP_REPO" ]] && rm -rf "$TMP_REPO"
    TMP_REPO=""
}

write_findings_file() {
    # write_findings_file <path> <count>
    local path="$1" count="${2:-2}"
    local findings='[]'
    if [[ "$count" -gt 0 ]]; then
        findings=$(jq -n --argjson n "$count" '[range($n) | . as $i | {file: "src/foo.ts", line: (($i + 1) * 10), title: ("issue " + (($i + 1) | tostring)), severity: "normal", category: "bug", detail: "...", confidence: 0.9}]')
    fi
    jq -n --argjson f "$findings" '{findings: $f}' > "$path"
}

# ── Tests ────────────────────────────────────────────────────────────────────

# 1. Lib sources cleanly + exposes the public API
test_case "all 3 public functions are defined after sourcing"
setup_tmp_repo
if declare -f pr_review_state_load >/dev/null \
   && declare -f pr_review_state_save >/dev/null \
   && declare -f pr_review_diff_since_last >/dev/null; then
    test_pass
else
    test_fail "missing public function(s)"
fi
cleanup_tmp_repo

# 2. Load with no prior state returns empty
test_case "load returns empty when no state file exists"
setup_tmp_repo
output=$(pr_review_state_load 42)
[[ -z "$output" ]] && test_pass || test_fail "expected empty output, got: $output"
cleanup_tmp_repo

# 3. Save creates the state file with correct schema
test_case "save creates state file with v1.0 schema"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 3
pr_review_state_save 42 "$findings"
state_file=".claude-octopus/pr-review-state/42.json"
if [[ -f "$state_file" ]] \
   && [[ "$(jq -r '.version' "$state_file")" == "1.0" ]] \
   && [[ "$(jq -r '.pr_number' "$state_file")" == "42" ]] \
   && [[ "$(jq -r '.rounds | length' "$state_file")" == "1" ]]; then
    test_pass
else
    test_fail "schema mismatch in $state_file"
fi
rm -f "$findings"
cleanup_tmp_repo

# 4. Save persists head_sha and findings_count
test_case "save records head_sha + findings_count + summary"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 2
pr_review_state_save 42 "$findings"
state_file=".claude-octopus/pr-review-state/42.json"
expected_sha=$(git rev-parse HEAD)
if [[ "$(jq -r '.rounds[0].head_sha' "$state_file")" == "$expected_sha" ]] \
   && [[ "$(jq -r '.rounds[0].findings_count' "$state_file")" == "2" ]] \
   && [[ "$(jq -r '.rounds[0].findings_summary | length' "$state_file")" == "2" ]]; then
    test_pass
else
    test_fail "save did not persist sha/count/summary correctly"
fi
rm -f "$findings"
cleanup_tmp_repo

# 5. Load returns markdown context when state exists
test_case "load returns prior-context block after save"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 2
pr_review_state_save 42 "$findings"
output=$(pr_review_state_load 42)
echo "$output" | grep -qE 'Prior reviews on this PR' \
   && echo "$output" | grep -qE 'review \*\*round 2\*\*' \
   && echo "$output" | grep -qE 'Findings from round 1' \
   && echo "$output" | grep -qE 'Your job this round' \
   && test_pass || test_fail "load did not produce expected sections"
rm -f "$findings"
cleanup_tmp_repo

# 6. Multiple saves append rounds (don't overwrite)
test_case "save appends rounds — does not overwrite"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 2
pr_review_state_save 42 "$findings"
echo "v2" > thing.txt
git add . && git commit -q -m "fix"
write_findings_file "$findings" 1
pr_review_state_save 42 "$findings"
state_file=".claude-octopus/pr-review-state/42.json"
if [[ "$(jq -r '.rounds | length' "$state_file")" == "2" ]] \
   && [[ "$(jq -r '.rounds[0].round' "$state_file")" == "1" ]] \
   && [[ "$(jq -r '.rounds[1].round' "$state_file")" == "2" ]] \
   && [[ "$(jq -r '.rounds[0].head_sha' "$state_file")" != "$(jq -r '.rounds[1].head_sha' "$state_file")" ]]; then
    test_pass
else
    test_fail "round append broken — got $(jq -r '.rounds | length' "$state_file") rounds"
fi
rm -f "$findings"
cleanup_tmp_repo

# 7. Diff function returns content when there's a real change between rounds
test_case "pr_review_diff_since_last returns the actual diff"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 1
pr_review_state_save 42 "$findings"
echo "v2 — addressed" > thing.txt
echo "added" > newfile.txt
git add . && git commit -q -m "fix"
diff_output=$(pr_review_diff_since_last 42)
if echo "$diff_output" | grep -qE '^\+v2 — addressed' \
   && echo "$diff_output" | grep -qE 'newfile\.txt'; then
    test_pass
else
    test_fail "diff did not contain expected changes — got: $(echo "$diff_output" | head -3)"
fi
rm -f "$findings"
cleanup_tmp_repo

# 8. Diff truncation kicks in past the line cap
test_case "diff truncation honours OCTOPUS_PR_REVIEW_DIFF_MAX_LINES"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 1
pr_review_state_save 42 "$findings"
# Generate a >100 line diff
seq 1 200 > big.txt
git add . && git commit -q -m "big change"
OCTOPUS_PR_REVIEW_DIFF_MAX_LINES=20 \
    diff_output=$(OCTOPUS_PR_REVIEW_DIFF_MAX_LINES=20 pr_review_diff_since_last 42)
if echo "$diff_output" | grep -qE 'lines truncated'; then
    test_pass
else
    test_fail "expected truncation marker, got tail: $(echo "$diff_output" | tail -3)"
fi
rm -f "$findings"
cleanup_tmp_repo

# 9. Empty findings file (no findings) is handled cleanly
test_case "save handles findings_count=0 correctly"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 0
pr_review_state_save 42 "$findings"
state_file=".claude-octopus/pr-review-state/42.json"
if [[ "$(jq -r '.rounds[0].findings_count' "$state_file")" == "0" ]] \
   && [[ "$(jq -r '.rounds[0].findings_summary | length' "$state_file")" == "0" ]]; then
    output=$(pr_review_state_load 42)
    echo "$output" | grep -qE 'No findings flagged in the prior round' \
        && test_pass || test_fail "load did not show 'no findings' message"
else
    test_fail "save mishandled empty findings"
fi
rm -f "$findings"
cleanup_tmp_repo

# 10. Load with empty PR number returns empty (defensive)
test_case "load returns empty for empty pr_number"
setup_tmp_repo
output=$(pr_review_state_load "")
[[ -z "$output" ]] && test_pass || test_fail "expected empty for blank PR, got: $output"
cleanup_tmp_repo

# 11. Save with missing findings file is a no-op (defensive)
test_case "save is a no-op when findings file missing"
setup_tmp_repo
pr_review_state_save 42 "/nonexistent/path.json"
state_file=".claude-octopus/pr-review-state/42.json"
[[ ! -f "$state_file" ]] && test_pass || test_fail "state file should not exist after no-op save"
cleanup_tmp_repo

# 12. Atomic write — state file is never partial after save
test_case "save uses atomic tmp+mv pattern (no partial files left over)"
setup_tmp_repo
findings=$(mktemp)
write_findings_file "$findings" 1
pr_review_state_save 42 "$findings"
state_dir=".claude-octopus/pr-review-state"
# Should be exactly one file (42.json), no .XXXXXX leftovers
file_count=$(find "$state_dir" -maxdepth 1 -type f | wc -l | tr -d ' ')
[[ "$file_count" == "1" ]] && test_pass || test_fail "expected 1 file in state dir, found $file_count"
rm -f "$findings"
cleanup_tmp_repo

test_summary
