# Feature Gap Analysis — Claude Code ↔ Claude Octopus

> **Living document.** Updated each release to track Claude Code (CC) feature adoption status.
> Last updated: v8.41.0 (2026-03-08) — CC baseline: v2.1.71

## How to Use This Document

- **Green** = Adopted and wired into orchestrate.sh
- **Yellow** = Detected (flag exists) but not yet wired into any workflow
- **Red** = Not detected / not adopted
- Review after each CC changelog update to identify new opportunities

---

## Feature Flag Inventory (72 flags across 24 thresholds)

### Fully Adopted (Green)

| Flag | CC Version | Octopus Usage |
|------|-----------|---------------|
| `SUPPORTS_HOOK_EVENTS` | v2.1.16 | All 13 hook event types |
| `SUPPORTS_AGENT_TYPE_ROUTING` | v2.1.20 | Curated agent selection in spawn_agent() |
| `SUPPORTS_AGENT_FIELD` | v2.1.20 | Agent type metadata in spawned agents |
| `SUPPORTS_AGENT_MEMORY` | v2.1.20 | Memory scope per agent (project/user/local) |
| `SUPPORTS_AGENT_MODEL_FIELD` | v2.1.20 | Model selection per agent type |
| `SUPPORTS_PERSISTENT_MEMORY` | v2.1.33 | Cross-memory warm start injection |
| `SUPPORTS_AGENT_TEAMS` | v2.1.34 | Claude→Claude native Agent Teams dispatch |
| `SUPPORTS_FAST_OPUS` | v2.1.36 | Auto-routing to Fast Opus for interactive tasks |
| `SUPPORTS_WORKTREE_ISOLATION` | v2.1.38 | Worktree-based isolation for parallel agents |
| `SUPPORTS_PROMPT_CACHE_OPT` | v2.1.40 | Stable prefix ordering for cache hits |
| `SUPPORTS_ANCHOR_MENTIONS` | v2.1.42 | @file#anchor references for context efficiency |
| `SUPPORTS_CONTINUATION` | v2.1.46 | Agent continuation/resume across sessions |
| `SUPPORTS_NATIVE_AUTO_MEMORY` | v2.1.59 | Delegates project/user memory to CC native |
| `SUPPORTS_INSTRUCTIONS_LOADED_HOOK` | v2.1.61 | Dynamic context injection via InstructionsLoaded |
| `SUPPORTS_HTTP_HOOKS` | v2.1.63 | Native HTTP telemetry hooks |
| `SUPPORTS_STATUSLINE_API` | v2.1.44 | Phase/workflow display in statusline |
| `SUPPORTS_STATUSLINE_WORKTREE` | v2.1.55 | Worktree branch in statusline |
| `SUPPORTS_EFFORT_CALLOUT` | v2.1.55 | Effort level passed into spawn_agent() |
| `SUPPORTS_TASK_MANAGEMENT` | v2.1.50 | Background task tracking |
| `SUPPORTS_STRUCTURED_OUTPUTS` | v2.1.52 | Structured JSON output from agents |
| `SUPPORTS_STABLE_BG_AGENTS` | v2.1.53 | Reliable background agent execution |
| `SUPPORTS_WORKTREE_HOOKS` | v2.1.55 | Hooks fire in worktree context |
| `SUPPORTS_ULTRATHINK` | v2.1.58 | Extended thinking for complex planning |

### Detected but Partially Wired (Yellow)

| Flag | CC Version | Status | Opportunity |
|------|-----------|--------|-------------|
| `SUPPORTS_FORK_CONTEXT` | v2.1.48 | Flag detected | Could branch conversation for parallel exploration paths |
| `SUPPORTS_SDK_MODEL_CAPS` | v2.1.52 | Flag detected | Could query model capabilities dynamically |
| `SUPPORTS_BATCH_COMMAND` | v2.1.54 | Flag detected | Could batch multiple agent commands in single call |
| `SUPPORTS_REMOTE_CONTROL` | v2.1.56 | Flag detected | Could enable external dashboards to control workflows |
| `SUPPORTS_AGENTS_CLI` | v2.1.60 | Flag detected | Could leverage `claude agents` CLI for team management |
| `SUPPORTS_RELOAD_PLUGINS` | v2.1.62 | Flag detected | Could hot-reload after skill updates mid-session |
| `SUPPORTS_NATIVE_LOOP` | v2.1.70 | Flag detected | Could use native loop for recurring monitoring tasks |
| `SUPPORTS_RUNTIME_DEBUG` | v2.1.70 | Flag detected | Could expose internal state for troubleshooting |
| `SUPPORTS_FAST_BRIDGE_RECONNECT` | v2.1.70 | Flag detected | Could improve agent team reconnection speed |
| `SUPPORTS_VSCODE_PLAN_VIEW` | v2.1.70 | Flag detected | Could surface plan progress in VS Code sidebar |
| `SUPPORTS_IMAGE_CACHE_COMPACTION` | v2.1.71 | Flag detected | Could optimize image-heavy workflows |
| `SUPPORTS_RENAME_WHILE_PROCESSING` | v2.1.71 | Flag detected | Could allow session renaming mid-workflow |

### Not Yet Tracked (Red — Potential CC Features)

These are CC capabilities that Octopus doesn't detect yet:

| Feature | Description | Priority |
|---------|-------------|----------|
| Native tool approval policies | CC's per-tool auto-approve rules | Low — Octopus manages its own permission modes |
| Conversation branching API | Branch and merge conversation threads | Medium — useful for debate workflows |
| Native skill caching | CC caches skill content across sessions | Low — Octopus already manages skill lifecycle |
| Cost tracking API | CC's built-in cost attribution per agent | High — could replace manual cost estimation |
| Session transcript export | Structured export of conversation history | Medium — useful for audit trails |

---

## Gap Closure History

| Version | Flags Added | Flags Wired | Notes |
|---------|------------|-------------|-------|
| v8.40.0 | 6 new flags | 3 dead wired | CC v2.1.70-71 sync, total 72 flags |
| v8.41.0 | 0 | 0 | Anti-injection nonces, learnings layer, Multi-LLM debate gates |
| v8.35.0 | 0 | 3 activated | effort_callout, worktree branch, InstructionsLoaded |
| v8.34.0 | 0 | 0 | Recurrence detection, JSONL logging |

---

## Process: How to Update This Document

1. Read the CC changelog (`https://code.claude.com/docs/changelog`)
2. For each new CC version:
   - Check if new hook events, agent fields, or capabilities are introduced
   - Add a `SUPPORTS_*` flag to `detect_claude_code_version()` if needed
   - Classify as Green (wired), Yellow (detected), or Red (not tracked)
3. Update the tables above
4. File a commit: `docs: update FEATURE-GAP.md for CC vX.Y.Z`

---

## Metrics

- **Total flags tracked:** 72
- **Fully adopted (Green):** ~23 (core workflow flags)
- **Detected/partial (Yellow):** ~12 (opportunity backlog)
- **Coverage ratio:** ~49% of flags are fully wired into workflows
- **Target:** 65% wired by v9.0.0
