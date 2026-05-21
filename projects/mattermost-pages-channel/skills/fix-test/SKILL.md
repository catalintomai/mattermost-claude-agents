---
name: Fix Test
description: Run tests via run_pages_tests.sh, diagnose failures with domain agents + multi-LLM, apply fixes, and loop until all tests pass. Convergence-driven test fixing with Independent Work and Cross-Validation. Adds regression tests for code bugs.
tags:
  - testing
  - debugging
  - go
  - typescript
---

# Fix Test (Pages Project)

Extends `~/.claude/skills/fix-test/SKILL.md` — follow that skill's workflow, agents, classification, modes, output format, and safety rules with the project-specific overrides below.

> `/create-plan` → `/create-code` → `/create-test` → `/fix-test` → `/review-code`

**Related**: `/create-test`, `/review-code`, `.claude/docs/test-patterns.md`

## Override: Test Infrastructure (replaces global Step 1 detection)

This project uses `.claude/scripts/run_pages_tests.sh` as the **single source of truth** for which tests exist and how to run them.

```
1. Run: .claude/scripts/run_pages_tests.sh <target>
2. Capture output (pass/fail + error details)
3. Parse failures from the script's output
```

Do NOT hardcode test names — the script is maintained alongside the codebase.

### Targets

Targets are passed directly to `.claude/scripts/run_pages_tests.sh`:

| Target | What it runs |
|--------|-------------|
| *(none)* | Everything (model+store+app+api+frontend+e2e, no mmctl) |
| `all` | Same as no args |
| `backend` / `go` | All backend Go layers (model+store+app+api) |
| `model` | Model layer tests |
| `store` | Store layer tests |
| `app` | App layer tests |
| `api` | API layer tests |
| `frontend` / `jest` | All frontend Jest tests |
| `e2e` / `playwright` | All E2E Playwright tests |
| `e2e:<category>` | Specific E2E category (crud, navigation, hierarchy, editor, collaboration, ai, drafts, wiki, permissions, integration, ui, export) |
| `mmctl` | mmctl E2E tests |

### Options

| Option | Description |
|--------|-------------|
| `--max-rounds <n>` | Max convergence loop iterations (default: 3). Replaces global `--max-attempts` — this controls round count, not per-test retries. |
| `--dry-run` | Diagnose only, don't apply fixes |
| `--swarm` | Team-based coordination (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: tasks run serially |

### Examples

```
/fix-test app                          # Fix all app layer failures
/fix-test store                        # Fix store layer failures
/fix-test app api --swarm              # Fix app+api with swarm coordination
/fix-test backend                      # Fix all backend layers
/fix-test e2e:editor                   # Fix editor E2E failures
/fix-test frontend --max-rounds 5      # Fix Jest tests, up to 5 rounds
/fix-test app --dry-run                # Diagnose app failures without fixing
```

## Override: Convergence Loop (augments global Step 5)

Uses canonical pattern from `~/.claude/docs/swarm-harness.md#convergence-pattern`. Override: MAX_ROUNDS = `args.max_rounds` or 3.

Each round: run tests → parse failures → diagnose (parallel agents) → merge fixes → apply → re-run. Exit conditions, revert strategy, and round tracking per canonical pattern.

## Override: Regression Test Step (augments global Step 6)

For code bugs found during diagnosis:

1. After fixing the code, verify that a test exists that specifically catches this bug
2. If the failing test was a **pre-existing test** that caught the bug — good, the regression test already exists
3. If the bug was found via a **new test** — the new test IS the regression test, ensure it stays
4. If the code fix was prompted by a test failure but the test doesn't specifically target the root cause, **add a focused regression test**
5. **Register new regression tests** in `run_pages_tests.sh` (same as `/create-test` registration step)

## Override: Pattern Completeness Rule

When spawning agents to fix tests, **always include this instruction**:

> **Pattern Completeness**: For each fix you apply, search the same test file AND sibling test files for the same pattern. Examples:
> - Fixing `TestCreatePage` timing issue? Check `TestUpdatePage`, `TestDeletePage` for same timing.
> - Fixing stale mock in wiki actions? Check page actions, draft actions for same staleness.
> - Fixing missing cleanup in one E2E test? Check all E2E tests in the same spec file.
> - Fixing wrong assertion in store test? Check all store tests in the same `testXxxStore` function.

## Override: Output Format

### Per Round
```
## Round {n}/{max}

Ran: `.claude/scripts/run_pages_tests.sh <targets>`
Result: {pass_count} passed, {fail_count} failed

### Failures Diagnosed
| Test | Root Cause | Fix | Agent | Confidence |
|------|-----------|-----|-------|------------|

### Fixes Applied
- [file]: [change summary]

### Regression Tests Added
- [test name] → guards against [bug description]
```

### Final Summary
```
## Result: {PASS|FAIL}

Rounds: {n}/{max}
Tests fixed: {count}
Regression tests added: {count}
Remaining failures: {count or "none"}
Files modified: {list}
```

## Override: Swarm Task Decomposition

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1: Run tests | coder | `test-runner` | -- | -- |
| T2: Diagnose model failures | debugger | `diag-model` | Independent Work | T1 |
| T3: Diagnose store failures | debugger | `diag-store` | Independent Work | T1 |
| T4: Diagnose app failures | debugger | `diag-app` | Independent Work | T1 |
| T5: Diagnose API failures | debugger | `diag-api` | Independent Work | T1 |
| T6: Diagnose frontend failures | debugger | `diag-frontend` | Independent Work | T1 |
| T7: Diagnose E2E failures | playwright-debugger | `diag-e2e` | Independent Work | T1 |
| T8: Multi-LLM patterns | general-purpose | `multi-llm-diag` | Independent Work | T1 |
| T9: Cross-pollination | (same as T2-T7, Variant A) | Share root causes | Cross-Validation | T2-T8 |
| T10: Apply fixes | coder | `fixer` | -- | T9 |
| T11: Re-run tests | coder | `test-runner` | -- | T10 |

### Cross-Agent Deduplication

Uses canonical pattern from `~/.claude/docs/swarm-harness.md#cross-agent-deduplication`. Finding field: **ROOT CAUSE**.

## Integration with Other Skills

- After `/create-code` — run `/fix-test` on the implemented code
- After `/create-test` — run `/fix-test` if new tests fail
- After `/create-code --swarm` — use `--swarm` here too for consistency
- Before `/review-code` — ensure tests pass first
