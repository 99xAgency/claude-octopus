---
name: skill-claude-code-plugin
version: 1.0.0
description: Build, migrate, validate, and publish Anthropic Claude Code plugins. Use when working on `.claude-plugin/plugin.json`, plugin-root `skills/`, `agents/`, `hooks/`, `.mcp.json`, `.lsp.json`, `settings.json`, or local `claude --plugin-dir` plugin testing.
---

# Claude Code Plugin Development

## Overview

Build Claude Code plugins against the current Anthropic plugin layout first, then apply any repo-specific compatibility steps that keep downstream packaging working.

**Core principle:** Keep the plugin root clean, keep generated artifacts in sync, and verify the plugin by loading it in Claude Code instead of trusting static docs alone.

---

## Current Anthropic Plugin Layout

Use the current Claude Code plugin structure:

- Keep only `plugin.json` inside `.claude-plugin/`
- Keep `skills/`, `agents/`, `hooks/`, `.mcp.json`, `.lsp.json`, and `settings.json` at the plugin root
- Treat the plugin `name` in `.claude-plugin/plugin.json` as the namespace prefix for invocable plugin features
- Use `claude --plugin-dir /absolute/path/to/plugin` for local development
- Use `/reload-plugins` after editing loaded plugin files during a session

Do **not** put `skills/`, `agents/`, `hooks/`, `commands/`, `.mcp.json`, or `.lsp.json` inside `.claude-plugin/`.

---

## Component Workflow

### 1. Identify the plugin surface you need to change

Route the request to the smallest relevant surface:

- **Manifest**: `.claude-plugin/plugin.json`
- **Skill**: `skills/<skill-name>/SKILL.md`
- **Agent**: `agents/<agent-name>.md`
- **Hooks**: `hooks/` plus `hooks.json`
- **MCP**: `.mcp.json`
- **LSP**: `.lsp.json`
- **Default behavior**: `settings.json`

If the user is still experimenting and does not need a shareable plugin, prefer standalone `.claude/` config and only package it as a plugin when reuse or distribution matters.

### 2. Inspect the existing plugin shape before editing

Run quick structure checks first:

```bash
pwd
find . -maxdepth 2 \( -path './.claude-plugin/*' -o -path './skills/*' -o -path './agents/*' -o -path './hooks/*' \)
jq empty .claude-plugin/plugin.json
```

If the repo already uses compatibility shims or generated artifacts, detect the editable source of truth before changing anything.

### 3. Edit the right component

#### Manifest

- Keep `name` stable unless the user explicitly wants a namespace-breaking change
- Update `description`, `version`, `author`, `homepage`, `repository`, or `license` only when needed
- Keep manifest paths or metadata aligned with the plugin’s actual layout

#### Skills

Create or update `skills/<skill-name>/SKILL.md` with concise frontmatter and actionable instructions.

Minimum modern pattern:

```md
---
name: my-skill
description: Explain what the skill does and when to use it.
---

Use this skill to ...
```

Use `$ARGUMENTS` when the skill should consume user input after the skill name. Use `disable-model-invocation: true` only when the skill should run explicitly instead of being invoked automatically.

#### Agents

- Keep agent instructions narrow and role-specific
- Match the model and tool restrictions to the agent’s job
- Prefer agent creation only when the task genuinely benefits from a specialized default thread or reusable subagent persona

#### Hooks

- Keep hooks idempotent and fast
- Guard destructive side effects
- Validate JSON syntax and executable paths
- Document any required environment variables or third-party binaries

#### MCP and LSP

- Keep `.mcp.json` and `.lsp.json` at the plugin root
- Validate command names, args, and expected local dependencies
- Prefer official, documented integration paths over ad hoc wrappers

#### Settings

- Use `settings.json` only for supported defaults
- Avoid hiding surprising behavior behind plugin defaults without explaining it

---

## Claude Octopus Repo Rules

When working inside this repository, keep both the modern plugin layout and Octopus’s compatibility pipeline aligned.

### Source of truth in this repo

- Edit or add source skills in `plugin/.claude/skills/*.md`
- Keep `plugin/.claude-plugin/plugin.json` in sync if the skill should ship with the plugin
- Treat `plugin/skills/*/SKILL.md` as generated output
- Treat `plugin/openclaw/src/tools/index.ts` as generated output

### Required regeneration after adding or renaming a skill

Run:

```bash
cd plugin
bash scripts/build-factory-skills.sh
bash scripts/build-openclaw.sh
```

If OpenClaw runtime artifacts need to stay current, rebuild them too:

```bash
npm --prefix openclaw run build
```

Do **not** hand-edit generated files in `plugin/skills/` or `plugin/openclaw/src/tools/index.ts`.

### Manifest compatibility note

Anthropic’s current docs favor plugin-root discovery, but this repo still keeps an explicit skill list in `plugin/.claude-plugin/plugin.json`. Until the repo is migrated, update that manifest list when you add or remove a shipping skill.

### Namespace lock

For Claude Octopus specifically, preserve the plugin manifest name `"octo"` unless the user explicitly asks for a breaking namespace change.

---

## Validation Loop

Run the smallest useful validation set for the change:

```bash
# Manifest syntax
jq empty plugin/.claude-plugin/plugin.json

# Regenerate plugin-root skills and commands
bash plugin/scripts/build-factory-skills.sh

# Validate the generated skill folder
python3 /Users/chris/.codex/skills/.system/skill-creator/scripts/quick_validate.py plugin/skills/<skill-name>

# Verify OpenClaw registry drift is resolved
bash plugin/scripts/build-openclaw.sh --check

# Rebuild shipped OpenClaw JS when src changed
npm --prefix plugin/openclaw run build
```

Then smoke-test the plugin in Claude Code:

```bash
claude --plugin-dir /absolute/path/to/plugin
```

Inside Claude Code:

- Run `/help` to confirm the plugin loaded
- Invoke the relevant plugin capability
- Run `/reload-plugins` after edits in an active session

---

## Common Failure Modes

- Putting plugin components inside `.claude-plugin/` instead of the plugin root
- Changing the manifest `name` and accidentally breaking the plugin namespace
- Editing generated output instead of the actual source file
- Forgetting to update `plugin/.claude-plugin/plugin.json` in this repo’s legacy packaging flow
- Forgetting `build-openclaw.sh`, leaving the OpenClaw registry stale
- Claiming support for hooks, providers, MCP tools, or CLI integrations that are not actually wired into runtime scripts and tests

---

## Delivery Expectations

When finishing Claude Code plugin work:

- Summarize what changed in the manifest, plugin components, and generated artifacts
- Call out any namespace, migration, or compatibility risks
- Report exactly how you validated the plugin
- Say clearly if runtime testing in Claude Code or a marketplace install was not performed
