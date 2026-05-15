---
name: git-guardrails
description: Install a PreToolUse hook that actively blocks dangerous git commands — git reset --hard, git restore, git checkout --, git rebase, git clean -f, and force flags. Run once per scope (global or project) to enforce git safety rules at the system level.
version: 1.0.0
tags:
  - git
  - safety
  - setup
user_invocable: true
---

# Git Guardrails

**Install once. Enforce forever.** Adds a PreToolUse hook that intercepts every Bash tool call and blocks dangerous git commands before they execute — at the system level, not just as a documented rule.

**Scope**: Global (`~/.claude/`) protects all projects on this machine. Project (`.claude/`) protects only the current repo.

## Usage

```
/git-guardrails                          # Install globally (recommended)
/git-guardrails --project                # Install for current project only
/git-guardrails --uninstall              # Remove the hook
/git-guardrails --test                   # Verify the hook is working (no changes)
/git-guardrails --show                   # Print block list and installed settings path
```

## What It Blocks

| Command Pattern | Why It's Dangerous |
|-----------------|-------------------|
| `git reset --hard` | Destroys all uncommitted work — unrecoverable |
| `git checkout -- <path>` | Permanently discards file changes |
| `git checkout HEAD -- <path>` | Permanently discards file changes |
| `git restore <path>` | Permanently discards file changes |
| `git rebase` | Rewrites history |
| `git clean -f` | Deletes untracked files permanently |
| `git push --force` / `git push -f` | Overwrites remote history |
| `git branch -D` | Force-deletes branch without merge check |

## Workflow

### Step 1: Determine Scope

If `--project` flag is set → scope is `.claude/` (current working directory).
Otherwise → scope is `~/.claude/` (global).

Resolve `<scope-dir>` to an absolute path.

### Step 2: Write the Hook Script

Write the following script to `<scope-dir>/scripts/block-dangerous-git.sh`:

```bash
#!/usr/bin/env bash
# Git Guardrails — blocks dangerous git commands in Claude Code sessions
# Installed by /git-guardrails skill. Edit block list here.

set -euo pipefail

INPUT=$(cat)

# Extract bash command from tool invocation JSON
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || true)

[ -z "$COMMAND" ] && exit 0

block() {
  local pattern="$1"
  local reason="$2"
  local alt="$3"
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "" >&2
    echo "🚫 BLOCKED by git-guardrails: $reason" >&2
    echo "   Command: $COMMAND" >&2
    echo "   Safe alternative: $alt" >&2
    echo "" >&2
    exit 2
  fi
}

block 'git[[:space:]]+reset[[:space:]]+--hard' \
  "git reset --hard destroys all uncommitted work" \
  "git stash (then git stash pop to restore)"

block 'git[[:space:]]+checkout[[:space:]]+(--|HEAD[[:space:]]+--)[[:space:]]' \
  "git checkout -- <path> permanently discards changes" \
  "git stash (then git stash pop to restore)"

block 'git[[:space:]]+restore[[:space:]]' \
  "git restore permanently discards changes" \
  "git stash (then git stash pop to restore)"

block 'git[[:space:]]+rebase' \
  "git rebase rewrites history" \
  "git merge (preserves history)"

block 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f' \
  "git clean -f permanently deletes untracked files" \
  "git stash -u (includes untracked, recoverable)"

block 'git[[:space:]]+push[[:space:]].*(--force|-f)([[:space:]]|$)' \
  "git push --force overwrites remote history" \
  "coordinate with the team; use --force-with-lease if truly needed"

block 'git[[:space:]]+branch[[:space:]]+-D[[:space:]]' \
  "git branch -D force-deletes without merge check" \
  "git branch -d (safe delete — fails if unmerged)"

exit 0
```

Make it executable:
```bash
chmod +x <scope-dir>/scripts/block-dangerous-git.sh
```

### Step 3: Update settings.json

Read `<scope-dir>/settings.json` (or create it if absent). Merge in the hook — do NOT replace existing content.

Add under `hooks.PreToolUse` (append to the array if it already exists):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash <scope-dir>/scripts/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

If `PreToolUse` already has a `Bash` matcher, append to its `hooks` array rather than creating a duplicate matcher.

### Step 4: Verify

Run two quick tests against the script directly:

```bash
# Should be BLOCKED (exit 2):
echo '{"tool_input":{"command":"git reset --hard HEAD"}}' \
  | bash <scope-dir>/scripts/block-dangerous-git.sh
echo "Exit code: $? (expected: 2)"

# Should PASS (exit 0):
echo '{"tool_input":{"command":"git status"}}' \
  | bash <scope-dir>/scripts/block-dangerous-git.sh
echo "Exit code: $? (expected: 0)"
```

Report pass/fail. If both match expected, installation is complete.

### Step 5: Confirm

Report to the user:
- Script installed at: `<scope-dir>/scripts/block-dangerous-git.sh`
- Settings updated at: `<scope-dir>/settings.json`
- Scope: global / project
- Commands now blocked: list the 8 patterns
- To uninstall: `/git-guardrails --uninstall`

## Uninstall

When `--uninstall` is passed:
1. Read `<scope-dir>/settings.json`
2. Remove the hook entry added by this skill from `hooks.PreToolUse`
3. Write the file back
4. Optionally delete `<scope-dir>/scripts/block-dangerous-git.sh` (ask first)

Do NOT modify settings.json unless `--uninstall` is explicitly passed.

## Flags

| Flag | Effect |
|------|--------|
| `--project` | Install for current project only (`.claude/`) instead of globally |
| `--uninstall` | Remove hook from settings.json |
| `--test` | Run verification tests only — no changes made |
| `--show` | Print block list and path of the installed settings.json |
