---
command: optimize
description: Analyze token usage patterns and optimize with RTK integration
allowed-tools: Bash, Read, Glob, Grep
---

# Token Optimization (/octo:optimize)

**Your first output line MUST be:** `🐙 Octopus Token Optimizer`

Analyze the current session's token usage patterns, detect optimization opportunities, and guide RTK setup for 60-90% bash output savings.

## EXECUTION CONTRACT (Mandatory)

When the user invokes `/octo:optimize`, you MUST follow these steps in order.

### STEP 1: Check RTK Status

Use the Bash tool:

```bash
echo "=== RTK Status ==="
if command -v rtk &>/dev/null; then
    echo "INSTALLED: $(rtk --version 2>&1 | head -1)"
    echo ""
    echo "=== RTK Gain Stats ==="
    rtk gain --json 2>/dev/null || rtk gain 2>/dev/null || echo "No gain data yet"
    echo ""
    echo "=== RTK Hook Status ==="
    SETTINGS="${HOME}/.claude/settings.json"
    if [[ -f "$SETTINGS" ]] && grep -q 'rtk' "$SETTINGS" 2>/dev/null; then
        echo "Claude Code hook: ACTIVE"
    else
        echo "Claude Code hook: NOT CONFIGURED"
    fi
else
    echo "NOT INSTALLED"
fi
```

### STEP 2: Analyze Context Usage

Use the Bash tool:

```bash
echo "=== Context Bridge ==="
SESSION="${CLAUDE_SESSION_ID:-unknown}"
BRIDGE="/tmp/octopus-ctx-${SESSION}.json"
if [[ -f "$BRIDGE" ]]; then
    cat "$BRIDGE"
else
    echo "No context bridge found"
fi
```

### STEP 3: Display Optimization Report

Format the results as:

```
🐙 Octopus Token Optimizer
============================================================

RTK Status
------------------------------------------------------------
Installed:        [Yes v0.33.1 / No]
Hook Active:      [Yes / No — run: rtk init -g]
Commands Filtered: [N]
Tokens Saved:     [N] (~XX% avg compression)

Context Window
------------------------------------------------------------
Current Usage:    [XX%]
Remaining:        [XX%]

Recommendations
------------------------------------------------------------
[1-3 specific, actionable recommendations based on findings]
```

### STEP 4: Offer Guided Setup (if RTK not installed)

If RTK is NOT installed:

```
RTK Installation Guide
============================================================
RTK saves 60-90% of tokens on bash output by filtering
and compressing CLI command results.

Savings per command type:
  ls/tree:         ~80%    |  git status/diff: ~75-80%
  cat/read:        ~70%    |  test runners:    ~90%
  grep/rg:         ~80%    |  build output:    ~90%

Install:  brew install rtk
Setup:    rtk init -g
Verify:   rtk gain
```

### STEP 5: Show General Token Tips

Always display at the end:

```
Token Tips
============================================================
• Use Read/Grep/Glob tools instead of bash cat/grep/find
• Prefer --oneline, --short, --quiet flags on git commands
• For test output, use | tail -50 or --reporter=dot
• Avoid reading entire large files — use offset/limit params
• Above 70% context, start fresh for new tasks
```

## Validation Gates

- RTK detection attempted (version + gain stats)
- Context window usage displayed
- Actionable recommendations provided
- Install guide shown when RTK is missing
- General tips always displayed
