---
name: security-fix
description: >-
  Orchestrates TDD-driven fixes for security tickets — failing secure-behavior
  tests first, then implementation, then post-fix lateral sweep, then a PR with
  no exploit details in the public description. Use when given a Jira security
  ticket URL or an MM-* security issue.
version: 1.0.0
tags:
  - security
  - tdd
  - orchestration
user_invocable: true
---

# Security Fix

Orchestrated TDD workflow for security tickets. The invoking agent is **orchestrator only** — it must not write application code, tests, or fixes itself. Every substantive step is delegated to a subagent.

> `/security-fix <jira-url>`

## Orchestrator rule

**Do not implement or edit code directly.** Delegate every write operation to a subagent. Track phases, pass artifacts (ticket summary, file paths, test names, failure messages), and decide when to loop.

## Phase 1 — Fetch ticket context

Parse the Jira URL to extract the issue key (e.g. `MM-68140`). Fetch title, description, acceptance criteria, suggested remediation, and severity via Atlassian MCP (`mcp__mcp-atlassian__jira_get_issue`).

Summarize for downstream subagents: affected endpoint/component, root cause description, suggested fix, severity.

## Phase 2 — Failing secure-behavior tests (delegate to subagent)

Spawn a subagent with the ticket summary and instruct it to run:

```
/create-test --tdd --security
```

Pass the ticket summary as the "plan" input — the subagent uses it to write tests asserting secure behavior (what must be denied/omitted). **Do not pass a plan file if one doesn't exist** — the ticket summary is sufficient context.

**Gate**: Tests must fail for the right reason (current vulnerable behavior), not compilation errors. If the subagent reports green tests, instruct it to revise until red.

Collect: list of new test files, how to run them, exact failure messages.

## Phase 3 — Implement fix (delegate to subagent)

Spawn a subagent with the ticket summary and Phase 2 test files. Instruct it to implement the minimal fix that makes all Phase 2 tests pass.

The subagent may use `/create-code` with the ticket summary as context, or implement directly if the fix is surgical (single file, clear remediation from ticket).

**Gate**: All Phase 2 tests must pass. Collect: files changed, rationale if diverging from ticket remediation.

## Phase 4 — Post-fix lateral sweep (delegate to subagent)

Spawn a subagent using `security/security-auditor` in post-fix sweep mode:

```
Review the fix applied in [files from Phase 3] for post-fix lateral sweep.
Check adjacent handler patterns, all user roles, and resource state edge cases.
```

If the sweep finds gaps with failing tests: return to **Phase 3** with the new failing tests added. Re-run Phase 4 after the fix. Stop after 2 loop iterations or when the sweep reports no material gaps.

Collect: gap count, any additional test files written.

## Phase 5 — Open PR

Delegate PR creation to a subagent. Pass:
- Files changed (from Phase 3)
- Jira ticket key and URL (for the PR body)
- Instruction to follow `~/.claude/agents/_shared/security-pr-policy.md`

**PR policy (mandatory)**: Read `~/.claude/agents/_shared/security-pr-policy.md`. The PR title and body must not contain exploit details, severity labels, or step-by-step abuse scenarios. Keep those in Jira.

Check for `.github/PULL_REQUEST_TEMPLATE.md` in the repo root. If present, use it as the PR body structure.

Open as non-draft (review-ready) unless the user explicitly requests draft.

## Orchestrator checklist

1. Fetch Jira ticket → summarize for subagents
2. Phase 2: failing secure-behavior tests → gate on red for right reason
3. Phase 3: implement fix → gate on Phase 2 tests green
4. Phase 4: post-fix lateral sweep → loop to Phase 3 if gaps found (max 2 iterations)
5. Phase 5: open PR with security-pr-policy applied
6. Report to user: ticket, test files, production changes, any residual risks

## Anti-patterns

- Writing application code or tests directly (orchestrator must delegate)
- Combining Phase 2 and Phase 3 in one subagent (breaks TDD discipline)
- Skipping Phase 4 for "small" fixes
- Including exploit details, severity labels, or CVE scores in the public PR body
- Opening the PR as draft when the work is review-ready
