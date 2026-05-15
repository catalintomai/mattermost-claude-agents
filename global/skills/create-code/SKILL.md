---
name: create-code
description: Implement code from an approved plan. Includes auto-review via /review-code. Supports TDD workflow. Runs linters and tests before completion.
version: 3.0.0
tags:
  - implementation
  - coding
  - tdd
---

# Create Code

Implement code from an approved plan. Ensures quality through structured workflow with linting, testing, and **auto-review** (dynamic agent selection matching `/review-code`).

> `/create-plan` -> `/create-code` -> `/create-test` -> `/fix-test`

**Related**: `/create-plan` (create plan), `/review-code` (standalone review for code not written via create-code)

## CRITICAL: Plan File is Source of Truth

**ALWAYS read from the saved plan file -- NEVER use conversation context.** The plan file is version-controlled, user may have edited it, and multiple sessions can reference it.

```
/create-code plans/page-reordering.md   # Reads plan from file
```

## Usage

```
/create-code <plan-file>                  # Implement from plan (includes auto-review)
/create-code <plan-file> --tdd            # Use TDD (write tests first)
/create-code <plan-file> --no-tests       # Skip test writing (not recommended)
/create-code <plan-file> --no-review      # Skip auto-review (not recommended)
/create-code <plan-file> --task <n>       # Implement specific task from plan
/create-code <plan-file> --phase <n>     # Implement specific phase from multi-phase plan
/create-code <plan-file> --swarm          # Agent teams for parallel layer implementation
/create-code <plan-file> --swarm --sequential  # Swarm tasks run serially
/create-code                              # Find most recent plan in plans/
```

### When No File Specified

List plans in `plans/`, show most recent, ask user to confirm. Never guess.

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Convergence |
|------|------------------|------------------|-------------|
| Default (no flags) | Parallel subagents, no shared state (review agents + multi-LLM) | SKIPPED | Single-pass |
| `--swarm` | Team with shared findings dir, per layer (sequential deps, `run_in_background`) | Interface files + review agents cross-validate | Canonical convergence (swarm-harness.md) |
| `--sequential` | Serial Task() calls per dependency chain | SKIPPED | Single-pass |
| `--no-review` | Implementation only, no review agents | SKIPPED | Single-pass |

## Project Context Loading

See `~/.claude/docs/project-context-loading.md` -- three-level agent discovery for review agents.

## Workflow

1. **Read plan** -- parse tasks, files to modify, acceptance criteria
2. **Verify prior wave completion (MANDATORY for multi-wave plans)** -- see Dependency Verification below
3. **Load project context** -- three-level agent discovery, see `~/.claude/docs/project-context-loading.md`
4. **Implement each task** -- standard mode (code -> tests -> verify) or TDD mode (RED -> GREEN -> REFACTOR)
5. **Quality checks** -- run linters (`make check-style`, `npm run check-types`, `npm run check`), auto-fix where possible
6. **Test verification** -- classify and run tests appropriately (see Test Classification below)
7. **Auto-review (via `/review-code`)** -- see below. Skip with `--no-review`. **Before selecting agents: read `~/.claude/agents/AGENT_REGISTRY.md` SS "Parallel Groups for Code Review" and apply the trigger table. Never select agents from memory.**

### Dependency Verification (Step 2)

**NEVER assume prior waves are complete. NEVER trust `git status` alone.** `git status` shows changes in the current session — it does NOT show whether files from prior sessions exist.

When the plan has waves/phases with dependencies:

1. **Parse ALL waves**, not just the target wave
2. **For each prior wave**, extract the "Files to modify/create" list from the plan
3. **Verify each file EXISTS on disk** using Glob — check for the actual implementation files, not just tests or mocks
4. **For API layers specifically**: grep for route registration / handler functions in the API directory (e.g., `HandleFunc`, route patterns), not just model client methods. `client4.go` methods are model-layer, NOT API-layer.
5. **Print verification matrix** to the user before proceeding:
   ```
   Wave 1 (Model):      COMPLETE (12/12 files verified)
   Wave 2 (App):        COMPLETE (4/4 files verified)
   Wave 3 (API):        INCOMPLETE — 0/3 handler files exist in api4/
   → Target: Wave 4 (Webapp) — BLOCKED by Wave 3
   ```
6. **If ANY prior wave is incomplete**: STOP and ask the user whether to implement the missing wave first or proceed anyway

**Exception — first phase or no prior dependencies**: If the target is the first phase (no prior waves to verify), or if ALL phases are unstarted and no specific phase was requested, skip the verification prompt and **start implementing from Phase 0** (or the first phase). Don't ask the user to confirm what is obvious from the plan's ordering.

**Why this matters**: Model client methods (`model/client4.go`) and API handlers (`api4/*.go`) look similar in `git status` but are different layers. A webapp that calls Client4 methods will get 404s at runtime if the API handlers don't exist.

### Large Multi-Phase Plans

When a plan has multiple phases that exceed what can be implemented in a single session:

1. **Implement one phase at a time** — complete the current phase (all layers, linting, tests, review) before moving to the next
2. **Phase = natural stopping point** — after completing a phase, report what was done and proceed to the next phase. Do NOT ask the user for permission between phases unless there's an ambiguity or blocker
3. **Reading large plans** — if the plan file exceeds read limits, read only the current phase's section in detail. Use section headers to navigate
4. **Progress across sessions** — when resuming (`--continue`), re-run dependency verification to detect which phases are complete and pick up from the first incomplete phase
5. **No phase specified** — when no `--task` or phase flag is given, implement phases in order starting from the first incomplete one. The plan's phase ordering IS the implementation order

### TDD Mode (`--tdd`)

RED: Write a failing test for expected behavior. GREEN: Write minimal code to pass. REFACTOR: Improve quality, tests still pass.

### Test Classification (Step 6)

Tests fall into two categories with different verification strategies:

| Type | How to identify | How to run | When to run |
|------|----------------|------------|-------------|
| **Unit tests** | Mock dependencies (interfaces, `plugintest.API`), no server/DB needed | `go test ./path/...` or `npm test` | Always — after each task and at end of phase |
| **Integration/E2E tests** | Require running server, deployed plugin, real DB, or browser | Server deploy + API calls, or Playwright | Report as "written, requires server to verify" |

**Rules:**
1. **Always run unit tests** — they must pass before moving on. Use `go test` for Go, `npm test` for TypeScript
2. **Never claim integration tests pass** unless you actually ran them against a live server
3. **Clearly report both categories** in the output summary — state which tests were run and which were only written
4. **If a plan includes both types**: write both, run unit tests, note integration tests as pending verification

### Auto-Review (Step 7) — MANDATORY

After linting passes and tests are green, auto-run `/review-code` on the implementation. This uses the **same dynamic agent selection** as standalone `/review-code` — agents scale with the size and scope of changes.

**MAX_REVIEW_ITERATIONS = 2**

1. Run `/review-code` on uncommitted changes (default mode, not swarm — swarm is opt-in via `--swarm`)
2. If MUST_FIX findings: fix them, re-run linters/tests, re-run review
3. Stop after MAX_REVIEW_ITERATIONS rounds
4. If MUST_FIX remain after 2 rounds: report them in output, do NOT loop further

**Agent selection** — identical to `/review-code`, scales with what changed:
- **Tier 1 (Cross-cutting)**: Always — `simplicity-reviewer`, `error-handling-reviewer`, `duplication-reviewer`
- **Tier 3 (Backend)**: If `*.go` changed — `api-reviewer`, `app-reviewer`, `store-reviewer`, `pattern-reviewer`, `concurrent-go-reviewer`
- **Tier 4 (Frontend)**: If `*.ts`/`*.tsx` changed — `react-frontend-expert`, `redux-expert`, `component-reviewer`, `ux-edge-case-reviewer`
- **Tier 5 (Testing)**: If test files changed — `test-coverage-reviewer`
- **Tier 6 (Compatibility)**: If `model/` or API surface changed — `backwards-compatibility-reviewer`, `null-safety-reviewer`
- **Project group**: If changed files match project-specific patterns — agents from project registry

Plus multi-LLM quick check for cross-layer consistency.

Full tier details and agent lists: see `~/.claude/agents/AGENT_REGISTRY.md` SS "CODE REVIEW Agents".

**Why after linting+tests**: No point reviewing code that doesn't compile or has failing tests — those issues would flood review findings with noise.

**Skip with**: `--no-review` flag. Use sparingly — equivalent to `--draft` on `/create-plan`.

## Output Format

```markdown
## Implementation Summary

### Status: COMPLETE / PARTIAL / BLOCKED

### Dependency Verification
| Wave | Status | Files |
|------|--------|-------|
| Wave 1 (Model) | COMPLETE | 12/12 |
| Wave 2 (App) | COMPLETE | 4/4 |
| Wave 3 (API) | INCOMPLETE | 0/3 — BLOCKING |

### Tasks Completed
- [x] Task 1: [description]
- [ ] Task 3: [blocked - reason]

### Files Modified
| File | Changes |
|------|---------|

### Linting
- **Go**: clean/issues
- **TypeScript**: clean/issues

### Tests
- **Unit tests**: N added, all passing (ran via `go test` / `npm test`)
- **Integration tests**: M added, pending server verification
- **Regressions**: none / [list]

### Auto-Review
- **Round 1**: N MUST_FIX, M SHOULD_FIX
- **Round 2**: N MUST_FIX remaining (if applicable)
- **Agents run**: [list of agents that were selected]
- **MUST_FIX resolved**: [list]
- **SHOULD_FIX noted**: [list — not auto-fixed]
```

## Flags

| Flag | Effect |
|------|--------|
| `--tdd` | Use TDD workflow (write tests first) |
| `--no-tests` | Skip test writing (use sparingly) |
| `--no-review` | Skip auto-review step (use sparingly) |
| `--task <n>` | Implement only task N from plan |
| `--phase <n>` | Implement only phase N from a multi-phase plan |
| `--continue` | Resume from last incomplete task |
| `--dry-run` | Show what would be done without doing it |
| `--swarm` | Agent teams for parallel layer implementation (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: tasks run serially per dependency chain |

## Examples

```bash
/create-code plans/oauth-support.md             # All tasks + auto-review
/create-code plans/oauth-support.md --tdd       # TDD + auto-review
/create-code plans/oauth-support.md --task 3    # Specific task + auto-review
/create-code plans/oauth-support.md --no-review # Skip review (fast, risky)
/create-code plans/oauth-support.md --continue  # Resume
```

## When to Use

| Scenario | Use `/create-code` | Just implement |
|----------|--------------------|-----------------------|
| Have an approved plan | yes | |
| Multi-task implementation | yes | |
| Need TDD enforcement | yes | |
| Quick one-off fix | | yes |
| Exploratory coding | | yes |

## Swarm Mode (`--swarm`)

> **Swarm protocol**: See `~/.claude/docs/swarm-harness.md`

### Task Decomposition

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1: Model + Migrations | coder | `code-models` | Independent Work | -- |
| T2: Store layer | coder | `code-store` | Independent Work | T1 |
| T3: App layer | coder | `code-app` | Independent Work | T2 |
| T4: API layer | coder | `code-api` | Independent Work | T3 |
| T5: Webapp | coder | `code-webapp` | Independent Work | T4 |
| T6a: Model + Store tests | coder | `code-tests-backend` | Synthesis | T1, T2 |
| T6b: App + API tests | coder | `code-tests-app` | Synthesis | T3, T4 |
| T6c: Webapp tests | coder | `code-tests-webapp` | Synthesis | T5 |
| T7: Build + lint + verify | coder | `code-verify` | Synthesis | T1-T5 |
| T8: Run all tests | coder | `code-test-run` | Synthesis | T6a-c, T7 |
| T9: Auto-review | (dynamic, per `/review-code`) | `code-review` | Synthesis | T8 |
| T10: Fix MUST_FIX + re-review | coder + review agents | `code-review-fix` | Synthesis | T9 (if MUST_FIX > 0) |

### Interface Summary Protocol

After each layer completes, leader extracts interface summary and **broadcasts to ALL remaining agents** (not just the next one). This ensures downstream agents have full context.

```
INTERFACE SUMMARY from {completed-layer}:
- Exported types/structs: {list with signatures}
- Public functions: {list with signatures}
- API endpoints: {routes, methods, request/response types}
- Database schema changes: {tables, columns, constraints}

All remaining agents should reference these interfaces when implementing their layer.
```

### File Ownership

See `~/.claude/docs/swarm-harness.md` SS "Git Ops Ownership" for file ownership rules. If two agents need the same file, run sequentially or leader merges.

## Fix Prompts — Pattern Completeness Rule

When spawning coder agents, **always include** the Pattern Completeness instruction from `~/.claude/docs/pattern-completeness-rule.md` in the agent prompt.

## Tips

- **Always have a plan first** -- don't use for ad-hoc coding
- **Use `--tdd` for complex logic** -- catches bugs early
- **Run linters early** -- catch style issues before they accumulate
- **Check tests before moving on** -- each task should leave tests green
- **Auto-review catches what implementation misses** -- error handling, atomicity, reducer bugs, UX edge cases
- **Use `--no-review` only for trivial changes** -- like `--draft` on create-plan, it skips the quality gate

## Anti-patterns
- Implementing without an approved plan — skips the alignment step, produces mismatched code.
- Disabling auto-review (`--no-review`) for anything more than a trivial change.
- Running swarm mode for a task that one coder agent can handle — fan-out cost without fan-out benefit.
- Mixing implementation and test tasks in the same agent — test agent has different constraints than implementation agent.
- Moving on after a failing lint/test without fixing it — deferred failures compound.

## Self-rewrite hook
After every 10 implementation runs, or after any run where auto-review found MUST FIX issues the coder missed:
1. Re-read the last 3 review findings from the auto-review step.
2. If a recurring missed class appears (error handling, atomicity, UX edge case), add a coder-prompt reminder for that class.
3. If a swarm task consistently fails at the merge step, tighten the file-ownership rules.
4. Commit: `skill-update: create-code, <one-line reason>`.
