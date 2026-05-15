---
name: fix-test
description: Diagnose and fix failing tests. Project-agnostic — detects test infrastructure dynamically. Uses domain agents for root cause analysis. Adds regression tests for bugs found.
version: 2.0.0
tags:
  - testing
  - debugging
  - fix
user_invocable: true
---

# Fix Test

Diagnose and fix failing tests. **Project-agnostic** — detects test runners, frameworks, and conventions dynamically from the project context.

> Typically follows `/create-test` or `/create-code` when tests fail.

**Related**: `/create-test` (write tests), `/create-code` (implement), `/review-code` (review)

## Usage

```
/fix-test                                 # Fix all failing tests (auto-detect runner)
/fix-test <test-file>                     # Fix specific test file
/fix-test <test-file> --test <name>       # Fix specific test by name
/fix-test --flaky                         # Focus on flaky/intermittent failures
/fix-test --ci                            # Fix CI-specific failures
/fix-test --swarm                         # Agent teams for parallel diagnosis
/fix-test --swarm --sequential            # Swarm tasks run serially
```

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Convergence |
|------|------------------|------------------|-------------|
| Default (no flags) | Parallel Task() calls (backend/frontend/E2E diagnosis are independent) | SKIPPED | Single-pass |
| `--swarm` | Background agents with shared findings dir (diagnosticians + multi-LLM) | Fresh agents cross-validate (shared root causes) | Full convergence loop |
| `--sequential` | Serial Task() calls | SKIPPED | Single-pass |

## Project Context Loading

See `~/.claude/docs/project-context-loading.md` for:
- **Three-level agent discovery** — load agents tagged `[CODE]` or `[BOTH]`
- **Test infrastructure detection** — discover project's test runners, frameworks, and conventions

## Test Infrastructure Detection

> **Shared algorithm**: See `~/.claude/docs/project-context-loading.md` § "Project Test Infrastructure Detection"

## Workflow

### Step 1: Identify Failures

Run the detected test command. Capture:
- Failing test names and files
- Error messages and stack traces
- Which tests pass vs fail

### Step 2: Classify Failures

| Category | Signs | Approach |
|----------|-------|----------|
| **Code bug** | Assertion failure, wrong value | Fix the code under test |
| **Test bug** | Wrong assertion, stale mock | Fix the test |
| **Setup issue** | Missing fixture, DB state | Fix test setup |
| **Flaky** | Passes sometimes, timing-dependent | Fix the race (see Flakiness Root Cause below) |
| **Environment** | CI-only, missing dependency | Fix CI config |

### Step 3: Domain Agent Diagnosis (MANDATORY)

Use three-level agent discovery. Spawn diagnostic agents:

| Agent | Role | When |
|-------|------|------|
| `debugger` | Root cause analysis, trace execution | Always (default) |
| `ci-failure-reviewer` | CI-specific failures, flaky patterns | `--ci` or `--flaky` |
| `ts-test-writer` | Unit test patterns, mocking issues | Unit test failures |
| `e2e-test-writer` | E2E test patterns, selector issues | E2E test failures |
| `e2e-debugger` | DB state, API traces for E2E | E2E with data issues |

**Before spawning: read `~/.claude/agents/AGENT_REGISTRY.md`. The table above lists defaults; the registry may have project-specific additions. Never select from memory.**

**Emit Selection Rationale (MANDATORY — before spawning)**: Print the `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. List every diagnostic candidate agent under SELECTED (with trigger reason — failure type matches row, `--flaky`/`--ci` flag active, etc.) or SKIPPED (with specific reason — failure type does not match, no E2E files in failing set, project-only agent, etc.). The block is user-visible output, printed before any agent spawns.

Spawn agents from the table above (see AGENT_REGISTRY) with the failing test names, error output, source files under test, and failing test files as context.

### Step 4: Apply Fixes

Fix one failure at a time. After each fix:
1. Re-run the specific test to verify the fix
2. Re-run the full suite to check for regressions
3. If regression, revert and try a different approach

### Step 5: Verify All Green

Run the complete test suite. All tests must pass before completion.

### Step 6: Regression Test Verification

For every **code bug** fix (not test bug fixes):

1. **Verify the test captures the specific bug** — the test should fail if the fix is reverted
2. **If no test exists for the specific failure mode**, write one:
   ```
   Regression test for: {bug description}
   - The test must fail WITHOUT the fix
   - The test must pass WITH the fix
   - The test should assert on the specific symptom, not just "it works"
   ```
3. **Document the regression link**: Add a brief comment in the test referencing the failure it guards against

## Flakiness Root Cause Analysis

When `--flaky` is used or a test is classified as flaky:

| Root Cause | Fix | Band-Aid (avoid) |
|------------|-----|-------------------|
| Race condition in test setup | Wait for specific condition before acting | `sleep(2000)` |
| Shared mutable state between tests | Isolate test data, add proper teardown | `test.describe.serial` |
| Non-deterministic ordering | Remove ordering dependency | Fixed seed / sort |
| WebSocket timing | Wait for WS event confirmation | Arbitrary timeout |
| Animation/transition timing | Wait for animation end event or stable DOM | `waitForTimeout` |
| Database eventual consistency | Wait for read-after-write confirmation | Retry loop with sleep |

**NEVER add retries or arbitrary waits as the primary fix.** Find and fix the actual race. If the structural fix is too complex for this session, document the root cause and file it — don't paper over it.

## Output Format

```markdown
## Test Fix Summary

### Status: ALL GREEN / PARTIAL / BLOCKED

### Test Infrastructure Detected
- **Framework**: [Jest / Go testing / Playwright / etc.]
- **Runner**: [exact command]

### Failures Diagnosed
| Test | Root Cause | Fix Type | Status |
|------|-----------|----------|--------|
| [test name] | [cause] | code fix / test fix | fixed / blocked |

### Shared Root Causes
- [If multiple failures share a cause, describe it]

### Regression Tests
| Bug Fixed | Regression Test | File:Line |
|-----------|----------------|-----------|
| [bug description] | [test name] | [location] |

### Agent Findings
- **debugger**: [diagnosis summary]
- **ci-failure-reviewer**: [if applicable]

### Test Results
- **Before**: N failing
- **After**: 0 failing (all green) / M still failing
```

## Flags

| Flag | Effect |
|------|--------|
| `--flaky` | Focus on intermittent/timing failures |
| `--ci` | Fix CI-specific failures (env differences) |
| `--test <name>` | Fix specific test by name |
| `--max-attempts <n>` | Max fix attempts per test (default: 3) |
| `--swarm` | Agent teams for parallel diagnosis (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: tasks run serially |

## When to Use

| Scenario | Use `/fix-test` | Just fix manually |
|----------|-----------------|-------------------|
| Multiple tests failing after `/create-code` | yes | |
| Flaky tests need structural diagnosis | yes (with `--flaky`) | |
| CI failures different from local | yes (with `--ci`) | |
| New tests from `/create-test` failing | yes | |
| Single obvious test assertion wrong | | yes |
| Test needs import updated | | yes |

## Swarm Mode (`--swarm`)

> **Swarm protocol**: See `~/.claude/docs/swarm-harness.md`

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1: Backend diagnosis | debugger | Diagnose Go test failures | Independent Work | -- |
| T2: Frontend diagnosis | debugger | Diagnose TS/React test failures | Independent Work | -- |
| T3: E2E diagnosis | e2e-debugger | Diagnose E2E failures | Independent Work | -- |
| T4: Multi-LLM patterns | general-purpose | Analyze failure patterns | Independent Work | -- |
| T5: Cross-validation | 3-5 Phase 1 types covering major domains (see swarm-harness.md) | Share root causes + contradiction check | Cross-Validation | T1-T4 |
| T6: Apply fixes | coder | Fix code/tests | -- | T5 |
| T7: Verify all green | coder | Run full test suite | -- | T6 |

T6→T7 loop respects MAX_ROUNDS from swarm-harness.md Convergence Pattern (3 solo, 10 swarm cap).

## Fix Prompts — Pattern Completeness Rule

When spawning fix agents, **always include** the Pattern Completeness instruction from `~/.claude/docs/pattern-completeness-rule.md` in the agent prompt.

## Tips

- **Read the error carefully** — most failures have clear error messages
- **Check if it's the code or the test** — fix the right thing
- **Never add mock data to make tests pass** — fix the actual issue
- **Shared root causes save time** — if 5 tests fail, they might share 1 cause
- **Flaky tests need structural fixes** — retries are a band-aid, fix the race
- **Never hardcode test infrastructure** — detect it dynamically
- **Always add regression tests for code bugs** — prevent the same bug from recurring
- **Pattern completeness** — when you fix one test, check siblings for the same issue


## Self-rewrite hook
After every 10 uses OR when the same class of failure appears 3+ times:
1. Re-read recent fix-test outcomes.
2. If a new root-cause pattern appeared (flaky async, mock drift, env difference), add it to Tips.
3. If the swarm table is out of date, update agent roles.
4. Commit: `skill-update: fix-test, <one-line reason>`.
