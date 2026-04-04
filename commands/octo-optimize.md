---
description: "Analyze token usage patterns and optimize with RTK integration"
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
    # Check Claude Code hook
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
    echo "No context bridge found (statusline may not have run yet)"
fi

echo ""
echo "=== Session File ==="
SESSION_FILE="${HOME}/.claude-octopus/session.json"
if [[ -f "$SESSION_FILE" ]]; then
    cat "$SESSION_FILE" 2>/dev/null | python3 -m json.tool 2>/dev/null || cat "$SESSION_FILE"
else
    echo "No session file"
fi
```

### STEP 3: Display Optimization Report

Format the results as a clear report:

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

If RTK is NOT installed, display:

```
RTK Installation Guide
============================================================
RTK (Rust Token Killer) saves 60-90% of tokens on bash output
by filtering and compressing CLI command results.

Token savings per command type:
  ls/tree:         ~80% savings
  cat/read:        ~70% savings
  grep/rg:         ~80% savings
  git status/diff: ~75-80% savings
  test runners:    ~90% savings

Install:
  brew install rtk          # macOS (recommended)
  cargo install --git https://github.com/rtk-ai/rtk  # any platform

Configure for Claude Code:
  rtk init -g               # auto-installs Claude Code bash hook

Verify:
  rtk --version             # check install
  rtk gain                  # check savings after use
```

### STEP 5: Offer Guided Setup (if RTK installed but hook not configured)

If RTK is installed but the Claude Code hook is not active:

```
RTK is installed but the Claude Code hook is not active.
Run this to enable automatic bash output compression:

  rtk init -g

This installs a Claude Code bash hook that transparently
rewrites commands (e.g., git status → rtk git status)
for compressed output. No workflow changes needed.
```

### STEP 6: Show General Token Tips

Always show these tips at the end:

```
General Token Optimization Tips
============================================================
• Use Read/Grep/Glob tools instead of cat/grep/find in bash
  (built-in tools are not affected by RTK but are already concise)
• Prefer --oneline, --short, --quiet flags on git commands
• For test output, pipe through | tail -50 or use --reporter=dot
• Avoid reading entire large files — use offset/limit parameters
• When context is above 70%, start a fresh session for new tasks
```

## Validation Gates

- RTK detection attempted (version check and gain stats)
- Context window usage displayed
- Actionable recommendations provided
- Install guide shown when RTK is missing
- Hook configuration guide shown when hook is inactive
- General tips always displayed

## Prohibited Actions

- Automatically installing RTK without user consent
- Modifying the user's shell profile or Claude Code settings
- Fabricating RTK gain statistics
- Claiming specific token savings without RTK gain data to back it up
