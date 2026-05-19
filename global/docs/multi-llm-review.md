# Multi-LLM Code Reviews

For deep code review, security audit, or architecture review, use multiple LLMs:

## Quick Method
Use `/multi-review` - Unified multi-LLM review (includes all below)

## Manual Method (parallel)
- `codex exec -m gpt-5.3-codex` (CLI) - Code review / `gpt-5.5-pro` for architecture
- `gemini -p "..." -m gemini-2.5-flash --output-format text` (CLI) - Best available free tier
- `mcp__seq-server__sequentialthinking` (MCP) - Systematic reasoning

## CLI vs MCP Preference (for multi-LLM review tools only)

**For codex and gemini, ALWAYS use CLI commands via Bash, NOT their MCP tools:**
- `codex exec` via Bash (NOT `mcp__codex-native__codex`)
- `gemini` via Bash (NOT `mcp__gemini-cli__ask-gemini`)

CLIs are faster, have consistent output formatting, and match skill documentation.
MCP tools have different parameter names and behavior.

**Note**: This exception applies ONLY to multi-LLM review tools (codex, gemini). For everything else (filesystem, GitHub, Jira), prefer MCP tools — see `~/mattermost/CLAUDE.md`.

## Model Selection Guidelines

### Gemini (CLI v0.42.0 — verified working as of 2026-05-18)
- **gemini-2.5-flash**: Best all-round free tier model — try this first
- **gemini-2.5-flash-lite**: Fastest/cheapest, good for quick queries
- **gemini-3.1-flash-lite**: Latest generation lite model — also works
- **gemini-2.5-pro**: Deep architectural analysis — use sparingly (low daily quota)
- ❌ `gemini-3-flash-preview` — 404 not available via this API key
- ❌ `gemini-3.1-pro-preview` — 404 not available via this API key
- ❌ `gemini-2.0-flash` / `gemini-2.0-flash-lite` — shutting down June 1 2026

**Quota fallback**: If a model returns "quota exceeded", drop down the chain:
`gemini-2.5-flash` → `gemini-2.5-flash-lite` → `gemini-3.1-flash-lite`

### Codex (Enterprise Key — verified 2026-05-18)
- **gpt-5.3-codex**: Best codex model for code review — use this
- **gpt-5.5-pro**: Best reasoning model for architecture decisions — use when the question is design/arch rather than code
- **gpt-5.2-codex**: Fallback if gpt-5.3-codex unavailable
- Note: Requires enterprise key (`cs enterprise`). Personal key project may lack model access.

### Claude Code (Handle Directly)
- File operations (Read, Write, Edit, Glob, Grep)
- Git operations, Bash commands
- TodoWrite planning, tool orchestration
- Quick analysis of 1-3 files

## CLI Commands

### Codex (with fallback)
```bash
# Code review (best codex model)
codex exec --skip-git-repo-check -m gpt-5.3-codex "prompt"

# Architecture/design review (best reasoning model)
codex exec --skip-git-repo-check -m gpt-5.5-pro "prompt"

# Fallback if gpt-5.3-codex unavailable
codex exec --skip-git-repo-check -m gpt-5.2-codex "prompt"
```

### Gemini (with fallback)
```bash
# Try first (best quality)
gemini -p "prompt" -m gemini-2.5-flash --output-format text

# Fallback if quota exceeded
gemini -p "prompt" -m gemini-2.5-flash-lite --output-format text

# Second fallback
gemini -p "prompt" -m gemini-3.1-flash-lite --output-format text
```

## Notes
- Gemini CLI v0.42.0: use `-p` flag for non-interactive mode (positional arg also still works)
- Gemini quota fallback chain: gemini-2.5-flash → gemini-2.5-flash-lite → gemini-3.1-flash-lite
- **On quota error**: If command fails with "quota exceeded", retry with next model in fallback chain
- **On 404 error**: Model not accessible via your API key — skip it entirely
