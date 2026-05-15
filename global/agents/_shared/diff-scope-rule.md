---
name: diff-scope-rule
description: Constrains review agents to only flag issues in changed lines (diff scope), preventing false positives from pre-existing code
---

# Diff Scope Rule

**MANDATORY** for all code review agents reviewing branch changes.

## Core Rule

You are reviewing a **branch diff**, not the entire codebase. Your findings MUST be scoped to lines that were actually changed.

## Rules

1. **ONLY flag issues on changed lines**: Lines marked with `+` in the diff are your review scope. Lines without `+` are context only.

2. **Full file context is for UNDERSTANDING, not for flagging**: When you receive full file contents alongside a diff, the full file helps you understand surrounding code. Do NOT flag issues in unchanged lines.

3. **Pre-flight check for every finding**: Before including ANY finding in your report, verify:
   - "Is the problematic code on a line marked with `+` in the diff?"
   - If **NO** → the issue is pre-existing and NOT in scope. Skip it or demote to `[PRE-EXISTING]`.

4. **Pre-existing issues**: If you discover a genuine issue in unchanged code while reading context, you MAY note it as:
   ```
   [PRE-EXISTING][INFO] file:line — description
   ```
   Pre-existing issues MUST NOT appear as MUST_FIX or SHOULD_FIX. They are informational only.

5. **Modified lines vs new lines**: Both are in scope. If a line was changed (appears as `-` then `+`), the new version is reviewable. If a line is entirely new (`+` only), it is reviewable.

6. **Moved code**: If code was moved without modification (identical `-` and `+` blocks), use judgment — flag only if the move itself introduces a problem (e.g., wrong scope, lost context). Do not flag pre-existing issues in moved code.

7. **Partially-modified functions — the most common false-positive trap**: When a function appears in the diff because *some* of its lines changed, only the `+` lines inside it are in scope. The unchanged context lines (no `+` prefix) inside that same function are **pre-existing** and out of scope, even though they're inside a modified function.

   **Before flagging any line inside a modified function, run:**
   ```bash
   git diff <base> -- <file> | grep '^+' | grep -F 'the-problematic-call'
   ```
   If the call does not appear in the `+` output, it was already there before this branch — it is pre-existing and must not be flagged as MUST_FIX or SHOULD_FIX.

   **Concrete example of the failure mode**: A function `changeOwner` is modified in this branch to add input validation. The `HandleError` call at the end of the function was already present on `master`. The diff shows `+func` lines (new validation code) but the `HandleError` line has no `+` prefix. An agent that reads the full file and sees `HandleError` inside a "modified function" may flag it — incorrectly. The `git diff | grep '^+'` check would have caught this.

   **Pattern Escalation Override interaction**: When using the Pattern Escalation Override (finding the same anti-pattern across the codebase), each instance you classify as "in-scope" must independently pass the `+` line check. An instance that appears in a modified function but is itself not a `+` line is a **pre-existing instance**, not an in-scope instance — list it under "Pre-existing instances", not "In-scope instances".

## Pattern Escalation Override

**CRITICAL**: When you find a pattern violation on a changed line, the diff-scope rule does NOT limit you to reporting just that one instance. A pattern violation is a **systemic issue** — reporting one instance while ignoring 50 identical ones means the next review finds another, and the cycle repeats forever.

**When this override triggers**: You found a MUST_FIX or SHOULD_FIX on a changed line, AND the root cause is a **repeatable pattern** (wrong function call, missing wrapper, inconsistent error handling, missing guard, etc.) rather than a one-off logic bug specific to that line.

**Required workflow**:

1. **Identify the anti-pattern**: What makes this code wrong? (e.g., "calls `HandleError` instead of `HandleAppError` for service-layer errors")
2. **Grep the entire codebase** for all instances of the same anti-pattern
3. **Report as ONE finding** with two sections:

```markdown
1. **[agent:TAG]** [VERIFIED] `file.go:42` — [pattern description]

   **In-scope instances** (on changed lines — MUST_FIX/SHOULD_FIX):
   - `file.go:42` — [evidence]
   - `file.go:159` — [evidence]

   **Pre-existing instances** (unchanged lines — same anti-pattern, listed for completeness):
   - `file.go:234` — same pattern
   - `other.go:55` — same pattern
   - ... (N total)

   **Fix**: [single fix that addresses ALL instances, e.g., "Replace all `HandleError` with `HandleAppError` where the error originates from a service/store call — 107 call sites across 7 files"]
```

**Key rules**:
- The finding severity (MUST_FIX/SHOULD_FIX) is determined by the in-scope instances
- Pre-existing instances are listed under the same finding (not as separate `[PRE-EXISTING][INFO]` entries) because they share a root cause
- The fix MUST address all instances, not just the in-scope ones
- If the grep reveals the anti-pattern exists in 50+ locations, state the count and representative examples — don't list all 50

**This override does NOT apply to**: one-off bugs (null dereference on a specific variable), logic errors unique to one function, or issues where each instance has a different root cause.

## Verification Checklist

Before submitting your review:
- [ ] Every MUST_FIX finding includes a `Diff evidence:` field with the verbatim `+` line from `git diff`. A MUST_FIX without this field is **invalid** — drop it.
- [ ] Every SHOULD_FIX finding references at least one line from the diff (marked `+`)
- [ ] No findings flag issues in unchanged context lines UNLESS they are (a) pre-existing instances of a pattern found on a changed line (Pattern Escalation Override) or (b) blast-radius sites that must change as a direct consequence of a diff change
- [ ] Pre-existing issues that are NOT part of a pattern and NOT blast-radius are tagged `[PRE-EXISTING][INFO]` and excluded from MUST_FIX/SHOULD_FIX counts
- [ ] Every pattern-violation finding includes a grep for all codebase instances
- [ ] Blast-radius sites are listed under the triggering finding, NOT as standalone MUST_FIX entries
- [ ] For every finding inside a **partially-modified function**: confirmed via `git diff <base> -- <file> | grep '^+' | grep -F '<flagged-call>'` that the specific flagged call is a `+` line, not just context inside a modified function
