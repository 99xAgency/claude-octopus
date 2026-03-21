---
name: skill-copilot-provider
version: 1.0.0
aliases: [copilot-provider, github-copilot, copilot]
description: GitHub Copilot as limited-role provider via gh copilot CLI for research, explanation, and suggestion tasks
trigger: |
  AUTOMATICALLY ACTIVATE when user says:
  "copilot provider" or "add copilot" or "github copilot" or "use copilot"
  DO NOT activate for general copilot IDE usage or copilot chat in editor.
---

# GitHub Copilot Provider Skill

## Overview

Adds GitHub Copilot as a limited-role provider in the Claude Octopus multi-LLM ecosystem. Copilot is accessed via the `gh copilot` CLI extension, supporting research, explanation, and suggestion roles only.

**Core principle:** Copilot supplements existing providers for quick explanations and shell suggestions at zero additional cost (uses existing GitHub subscription).

---

## Detection

Before using Copilot as a provider, verify the `gh copilot` extension is installed:

```bash
# Check gh CLI is available
if ! command -v gh &>/dev/null; then
  # gh CLI not installed — silently skip Copilot provider
  return 0
fi

# Check copilot extension is present
if ! gh extension list 2>/dev/null | grep -q 'copilot'; then
  # Copilot extension not installed — silently skip
  return 0
fi
```

**Graceful degradation:** When `gh copilot` is unavailable, silently skip the Copilot provider. Do NOT emit errors or warnings. Other providers continue to operate normally.

---

## Available Roles

Copilot is a **limited provider** — it supports only the following roles:

| Role | Command | Use Case |
|------|---------|----------|
| **Research** | `gh copilot explain` | Quick concept lookups, code explanations |
| **Explanation** | `gh copilot explain` | Summarize code behavior, error messages |
| **Suggestion** | `gh copilot suggest` | Shell command suggestions, CLI help |

### Commands Used

**Explanation / Research:**
```bash
gh copilot explain "<query>"
```
Use for research and explanation roles. Returns a natural language explanation of the query topic.

**Shell Suggestions:**
```bash
gh copilot suggest "<query>"
```
Use for suggestion roles. Returns shell command suggestions for the given task.

---

## Prohibited Roles

Copilot CLI is NOT a full provider. The following roles MUST NOT be assigned to Copilot:

| Prohibited Role | Reason |
|-----------------|--------|
| **Implementation** | Copilot CLI cannot write or modify files |
| **Review** | Copilot CLI cannot perform structured code review |
| **Orchestration** | Copilot CLI has no orchestration capabilities |

Never assign Copilot to roles requiring structured output, file modifications, or multi-step workflows.

---

## Integration with Provider Router

Register Copilot as a limited provider with role restrictions in the provider router:

```
Provider: copilot
Type: limited
Roles: [research, explanation, suggestion]
Prohibited: [implementation, review, orchestration]
Detection: gh extension list | grep copilot
Cost: Zero additional (GitHub subscription)
```

### Provider Indicators

When Copilot is active in a multi-provider workflow, use the green indicator:

```
Providers:
🔴 Codex CLI - Implementation
🟡 Gemini CLI - Security review
🟢 Copilot CLI - Quick explanation
🔵 Claude - Synthesis
```

The 🟢 indicator is distinct from other providers:
- 🔴 = Codex CLI
- 🟡 = Gemini CLI
- 🟢 = Copilot CLI
- 🟣 = Perplexity
- 🔵 = Claude

---

## Doctor Integration

The `/octo:doctor` providers check reports Copilot availability:

```
Providers:
  ✓ Claude Code v2.x.x
  ✓ Codex CLI installed
  ✓ Gemini CLI installed
  ✓ Copilot CLI installed (gh copilot)    # or ✗ if unavailable
```

When Copilot is unavailable, doctor reports it as informational (not an error), since Copilot is an optional supplementary provider.

---

## Integration Notes

1. **Zero additional cost** — Uses existing GitHub subscription, no API keys required
2. **Works alongside existing providers** — Copilot supplements Codex, Gemini, and Claude
3. **Never assigned structured output roles** — Copilot CLI returns plain text only
4. **Graceful degradation** — When unavailable, silently skip with no errors or warnings
5. **No provider cascade** — Copilot does not fall back to other providers; if unavailable, the role is reassigned

---

## Example Workflows

### Research with Copilot

```
🐙 **CLAUDE OCTOPUS ACTIVATED** - Multi-provider research mode
🔍 Discover Phase: Researching WebSocket authentication patterns

Providers:
🔴 Codex CLI - Technical implementation analysis
🟡 Gemini CLI - Ecosystem research
🟢 Copilot CLI - Quick explanation of auth tokens
🔵 Claude - Strategic synthesis
```

### Copilot Unavailable (Graceful Degradation)

```
🐙 **CLAUDE OCTOPUS ACTIVATED** - Multi-provider research mode
🔍 Discover Phase: Researching WebSocket authentication patterns

Providers:
🔴 Codex CLI - Technical implementation analysis
🟡 Gemini CLI - Ecosystem research
🔵 Claude - Strategic synthesis
```

When Copilot is not detected, it is silently omitted from the provider list. No error messages, no warnings, no degraded-mode banners.
