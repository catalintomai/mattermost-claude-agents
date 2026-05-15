# Selection Rationale (Agent Audit Block)

**Source of truth for all skills that select and spawn agents from a registry.** Linked by `/review-code`, `/review-plan`, `/create-plan`, `/create-code`, `/create-test`, `/triage-issue`, `/fix-test`, and any other agent-orchestrating skill.

## What it is

A mandatory pre-spawn block printed as user-visible output. It lists every candidate agent under either `SELECTED` (with trigger reason) or `SKIPPED` (with specific skip reason), making agent selection auditable.

## Why it exists

Without it, agent selection is opaque. Users see the same agents run every PR with no way to tell whether that's "all six matched the diff" or "the group-level rule fired six times regardless of content." Visibility is the prerequisite for tightening selection logic.

## When to emit

Immediately after the orchestrating skill (a) identifies its scope (changed files, plan path, ticket, etc.) and (b) loads the candidate agent registry — but **before spawning any agent**.

If the skill spawns agents in waves (e.g., `/create-test` runs draft-time agents then post-implementation agents), emit one block per wave with the wave name in the header.

If the skill genuinely has no selection to make (only one hardcoded agent), this rule does not apply. The rule applies whenever there is filtering from a candidate set of two or more.

## Format

```
## Selection Rationale[ — <wave name if applicable>]
Scope: <one-line scope summary>. Languages/Domains: <Go, TS, Playbooks, ...>. Flags: <--full, --plan, ...>.

SELECTED (N agents):
- <agent-name> — <one-line trigger reason>
- ...

SKIPPED (M agents):
- <agent-name> — <one-line specific skip reason>
- ...
```

## Rules

1. **List EVERY agent the candidate registry knows about** under either SELECTED or SKIPPED. No agent silently disappears. The registry includes global (~/.claude/agents/), project (`<project>/.claude/agents/`), and any Level 2 registry loaded via three-level discovery.

2. **SKIPPED reasons MUST be specific.** Cite the missing pattern, missing flag, or wrong phase tag. Never write "not needed", "not relevant", "not applicable", or "out of scope."

3. **Distinguish flag-unlocked from match-based selections.** When the user invokes a broadening flag (`--full`, `--thorough`, `--depth=deep`), agents pulled in by the flag should say so (`"--full unlocks Security tier"`), not borrow a content-match reason they don't actually have.

4. **The block is part of the user-visible output**, not internal thinking. It comes immediately after the scope line and before any agent output.

5. **In swarm or persistent modes, also write `selection-rationale.md` to the synthesis dir** so it survives `/clear` and post-mortems can reconstruct what ran.

6. **Phase-tag gating is a skip reason, not a hidden filter.** A code-review skill SKIPS `[PLAN]`-only agents with reason `"[PLAN]-only tag, code-review skill"`. A plan-review skill SKIPS `[CODE]`-only agents with reason `"[CODE]-only tag, plan-review skill"`. Do not silently omit them — surface them.

7. **Project-only agents that don't match the current project are SKIPPED**, not omitted. Reason: `"Playbooks-only agent — current project is mattermost-server"`.

## Trigger phrasing examples

**SELECTED reasons** (be concrete, cite the trigger):
- `Cross-cutting (always)`
- `match: *.go in diff`
- `match: server/sqlstore/migrations.go`
- `match: webapp/**/*.tsx in diff`
- `[PLAN]-tagged, plan-review skill`
- `--full unlocks Security tier`
- `--full unlocks Deep Experts`
- `--plan provided — load plan-context`
- `--ci flag active`
- `Project group: Playbooks files in diff`

**SKIPPED reasons** (be specific, cite what's missing):
- `no *.go in diff`
- `no e2e-tests/*.spec.ts changed`
- `[PLAN]-only tag, code-review skill`
- `[CODE]-only tag, plan-review skill`
- `--full not active`
- `--ci not active and no .github/ files changed`
- `Python-only — no .py in diff`
- `no Playbooks plugin files`
- `no migration files in diff`
- `no model/ field changes`

## Anti-patterns

- **Skipping the block entirely** — silent selection hides drift and defeats the audit purpose.
- **Vague reasons** like "not needed", "not relevant", "not applicable" — these violate Rule 2 and provide no signal for fixing selection logic later.
- **Listing only SELECTED without SKIPPED** — the SKIPPED list is the audit trail. The asymmetry is precisely what tightens selection over time.
- **Burying the block inside agent output** — it must print before agents spawn, not after they finish.
- **Reusing a content-match reason for a flag-unlocked agent** — if `xss-reviewer` runs because `--full` unlocked it (not because the diff has template rendering), say so. Otherwise you're lying about why it fired.
- **Emitting the block at the end of the run as a summary** — by then it's too late to course-correct, and it merges visually with findings.

## How skills reference this doc

Each orchestrating skill should have a short workflow step like:

> **N. Emit Selection Rationale (MANDATORY — before spawning anything)** — Print the `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. List every candidate agent under either SELECTED (with trigger reason) or SKIPPED (with specific reason). The block is user-visible output, printed before any agent spawns.

The skill does NOT inline the format, rules, or examples. Those live here.

## Self-rewrite hook

After every 20 runs across all skills, or whenever a user reports "the same agents keep firing":
1. Re-read recent rationale blocks.
2. Look for SKIPPED reasons that turned out to be wrong (agent should have fired) or SELECTED reasons that fired on noise (agent had nothing to flag).
3. If a recurring miscategorization appears, sharpen the agent's `description` trigger clause and/or propose a per-agent path+content matcher.
4. Commit: `docs-update: selection-rationale, <one-line reason>`.
