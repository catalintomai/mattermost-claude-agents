---
name: triage-issue
description: Systematically diagnose a bug or issue, identify root cause, design a TDD fix plan, and create a Jira ticket. Bridges "found a bug" to "have a plan to fix it" without guessing. Use before /fix-test when the cause is unknown.
version: 1.0.0
tags:
  - debugging
  - triage
  - planning
user_invocable: true
---

# Triage Issue

**Capture → Diagnose → Root Cause → TDD Plan → Jira Ticket.** Turns a bug report into an actionable fix plan before writing any code.

> Use BEFORE `/fix-test` when the root cause is not obvious.
> `/triage-issue` → `/create-plan --minimal` → `/create-code` → `/fix-test`

**Related**: `/fix-test` (fix once cause is known), `debugger` agent (root cause), `e2e-debugger` agent (E2E with DB state)

## Usage

```
/triage-issue <description>               # Triage from free-text description
/triage-issue --jira <key>                # Triage from Jira issue (e.g. MM-12345)
/triage-issue --test <failing-test>       # Triage from a specific failing test
/triage-issue --log <paste>               # Triage from error log / stack trace
/triage-issue --no-ticket                 # Diagnosis only, skip Jira ticket creation
```

## Workflow

### Step 1: Capture Problem

Collect all available evidence before starting diagnosis.

| Source | What to capture |
|--------|----------------|
| User description | Error message, steps to reproduce, expected vs actual |
| Jira issue (`--jira`) | Fetch via `mcp__mcp-atlassian__jira_get_issue`: summary, description, comments, linked issues |
| Failing test (`--test`) | Test name, assertion failure, full stack trace |
| Error log (`--log`) | Full trace, file:line of first non-library frame |
| Git history | `git log --oneline -20 -- <affected-file>` — recent changes to the area |

**Hypothesis list**: Before diagnosing, write down 2-3 candidate root causes based on the evidence. This forces hypothesis-driven investigation instead of random exploration.

### Step 2: Diagnose

Spawn diagnostic agents in parallel based on the symptom. Give each agent the evidence from Step 1 and the hypothesis list with instructions to **confirm or refute each hypothesis** — not explore freely.

| Symptom | Agent | Context to provide |
|---------|-------|--------------------|
| Go test / server error | `debugger` | Error + stack trace + affected files + hypotheses |
| E2E / Playwright failure | `e2e-debugger` | Test output + DB query to verify state + hypotheses |
| CI-only failure | `ci-failure-reviewer` | CI log + local vs CI diff + hypotheses |
| React/TS component bug | `debugger` | Component + props + error output + hypotheses |
| Intermittent / flaky | `ci-failure-reviewer` | Pattern across runs + timing context |

**Emit Selection Rationale (MANDATORY — before spawning)**: Print the `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. List every diagnostic candidate agent under SELECTED (with trigger reason — symptom row matched in table) or SKIPPED (with specific reason — symptom does not match, framework not detected, project-only agent, etc.). The block is user-visible output, printed before any agent spawns.

### Step 3: Root Cause Analysis

Synthesize agent findings:

1. **Which hypothesis was confirmed?** (or was it something unexpected?)
2. **Exact location**: file:line where the bug manifests
3. **Why it happens**: the logic error, race condition, missing check, or wrong assumption
4. **Why it wasn't caught**: missing test, wrong assertion, or no test at all

If agents disagree, run a targeted second pass: spawn a single `debugger` with both conflicting hypotheses and the specific files, asking for a definitive verdict.

### Step 4: TDD Fix Design

Design the fix as a red-green-refactor cycle BEFORE writing any code.

```
RED:   Write a test that fails because of the bug
       - Name: "should <expected behavior> when <condition>"
       - Must fail WITHOUT the fix
       - Assert on the symptom (observable behavior), not the implementation

GREEN: Minimal code change that makes the test pass
       - One logical change
       - No cleanup or refactoring yet

REFACTOR: (if needed) Clean up after green, keeping tests green
```

For each fix cycle: name the test, state the assertion, state the minimal change, think through whether the change breaks any existing tests.

### Step 5: Create Jira Ticket

Unless `--no-ticket` is passed, create a Jira issue via `mcp__mcp-atlassian__jira_create_issue`.

Use issue type `Bug`. Summary: `[Component] Short description`.

Description body:
```
## Problem
<1-2 sentences: what's wrong, where, under what conditions>

## Root Cause
<file:line + why the logic is wrong>

## Why It Wasn't Caught
<missing test / wrong assertion / no test>

## Fix Plan (TDD)

### Red: Test to Write
- File: <test file>
- Test name: "<name>"
- Assertion: <what it checks>
- Fails because: <why it currently fails>

### Green: Minimal Fix
- File: <source file>
- Change: <1-sentence description>

### Verify: No Regression
- Run: <test suite / specific tests>

## Affected Areas
<other files/components to review or re-test>
```

Return the Jira issue URL.

## Output

```markdown
## Triage Summary

### Root Cause
**File**: `<file>:<line>`
**Bug**: <1-sentence description>
**Trigger**: <condition that causes it>

### Why It Wasn't Caught
<missing test / wrong assertion / no test>

### Fix Plan
| Cycle | Action | File | Description |
|-------|--------|------|-------------|
| RED | Write failing test | `<test-file>` | `<test name>` |
| GREEN | Minimal fix | `<source-file>` | <change> |

### Jira Ticket
<URL — or "skipped (--no-ticket)">

### Recommended Next Step
- Simple fix: implement directly via `/fix-test` or `/create-code`
- Complex fix: `/create-plan --minimal "<fix description>"`
```

## Flags

| Flag | Effect |
|------|--------|
| `--jira <key>` | Fetch Jira issue as starting context (e.g. `MM-12345`) |
| `--test <name>` | Start from a specific failing test name |
| `--log <text>` | Start from a pasted error log or stack trace |
| `--no-ticket` | Skip Jira ticket creation, output diagnosis only |

## When to Use

| Scenario | `/triage-issue` | `/fix-test` directly |
|----------|-----------------|----------------------|
| Bug reported in Jira, cause unknown | yes | |
| Failing test, root cause unclear | yes | |
| Intermittent / flaky failure | yes | |
| E2E failing — not sure if test or code bug | yes | |
| Test fails, cause is obvious from the diff | | yes |
| Regression with a clear recent change | | yes |
| Simple assertion mismatch | | yes |


## Self-rewrite hook
After every 10 uses OR on any failure where the root cause was misdiagnosed:
1. Re-read recent triage outcomes and check if the diagnosis matched the actual fix.
2. If a recurring misdiagnosis pattern appears, add it to a new "Known false trails" section.
3. If the Jira integration broke, update the flags/tooling section.
4. Commit: `skill-update: triage-issue, <one-line reason>`.
