# Review Prompts & Output Formats

Reference doc for `/review-code` and `/review-plan`. Contains prompt templates and **orchestrator-level** output formats.

> **Relationship to finding-format.md**: Individual review agents emit findings using the format in `~/.claude/agents/_shared/finding-format.md` (agent-level). This file defines: (1) prompt templates sent to multi-LLM reviewers (simplified numbered-list format), and (2) the orchestrator synthesis format (tables with convergence tracking and verdicts).

---

## Code Review Prompt (`/review-code`)

```
Review this code for bugs, security issues, and quality.

## Code Changes
<code>
[paste git diff or file contents]
</code>

## ⛔ SCOPE RULE (HIGHEST PRIORITY — READ THIS FIRST)

Your review scope is ONLY lines that were **added or modified** in this diff. Full file context is provided so you understand the surrounding code, but you MUST NOT flag issues in unchanged lines.

**How to determine scope:**
- Lines marked with `+` in the diff = IN SCOPE (our changes)
- Lines marked with `-` in the diff = IN SCOPE (our removals)
- Unmarked lines = OUT OF SCOPE (context only)
- If a function was NOT touched in the diff, issues in that function are OUT OF SCOPE

**Concrete example:** If `FinishPlaybookRun` has new code but `RestorePlaybookRun` was not changed, do NOT flag bugs in `RestorePlaybookRun` — even if it's in the same file, even if it has real bugs. Those are pre-existing.

**For every finding you report**, verify: "Is the line I'm flagging part of the diff?" If NO → do not report it. If you believe a pre-existing issue is important context for understanding a diff finding, mention it as INFO with "(pre-existing, not introduced by this diff)".

**Exception — Security/Permission agents**: Agents whose scope explicitly includes "blast radius" analysis (e.g., permission-reviewer, threat-modeler) may flag issues in unchanged code when those issues are **directly caused by or exposed by the diff**. For example, if the diff introduces a new permission function `PlaybookEdit()`, the permission-reviewer should audit ALL callers of the old function to check if they should be migrated — even if those callers weren't touched. These findings should be tagged "(blast radius of diff change)" to distinguish them from unrelated pre-existing issues.

## CRITICAL: Apply 80/20 Thinking

**A MUST FIX blocker is ONLY:**
- Bug that will cause runtime failure
- Security vulnerability (injection, auth bypass, XSS)
- Data integrity risk (corruption, loss)
- Race condition / concurrency bug
- Missing error handling that crashes

**NOT a blocker (SHOULD FIX or SKIP):**
- Style issues, naming preferences
- Minor optimizations
- Missing comments/docs
- "Best practices" that don't affect correctness

## CRITICAL: Review Against Codebase Context, Not Generic Best Practices

You will be given the diff AND full file context including sibling/parent components. Use them:

- **Pattern exemplars are the standard**: If 3 sibling components use `opacity: 0.56`, that IS the codebase convention — do NOT flag it as a contrast violation. Only flag deviations FROM established patterns.
- **Pre-existing issues are NOT findings**: If the changed code matches a pattern that ALL similar components already use (e.g., no `:focus-visible` on any DotMenu button variant), that is a pre-existing gap, not a PR regression. Note it as informational at most.
- **Check parent components for shared behavior**: A fixed `width` is not a responsive issue if the parent already sets `max-width: 100%`. A missing keyboard handler is not an issue if the wrapper component provides it.
- **Report regressions and new deviations only**: A finding is valid ONLY if the change (a) introduces a new pattern inconsistency, (b) breaks something that worked before, or (c) has no existing precedent in the codebase to compare against. "Asymmetry" with unchanged code is not a regression — it's pre-existing.

## Evaluate

1. **Correctness**: Will this code work as intended?
2. **Security**: Any vulnerabilities?
3. **Edge Cases**: Null checks, error handling, boundary conditions?
4. **Performance**: Any obvious inefficiencies?
5. **Patterns**: Does it follow established codebase patterns? (compare against provided exemplars)

## CRITICAL: Pattern Completeness

See `~/.claude/agents/_shared/finding-format.md` § "Pattern Completeness (Mandatory)" for the full rule, workflow, and output format. In short: when you find a bug, **grep for ALL instances of the same pattern** and report them as one finding with all locations — not one finding per instance. This applies in BOTH directions: (1) same bug in multiple locations, AND (2) any guard (validation, permission, error wrapping, sanitization) present on one entry point but missing from parallel entry points for the same operation (e.g., create vs update vs duplicate vs import, REST vs GraphQL).

## Output

1. **MUST FIX** (0-3 max): What breaks? File:line (ALL instances)? Fix?
2. **SHOULD FIX** (0-5): Quality improvements
3. **VERDICT**: APPROVED / NEEDS WORK
```

---

## Code Review Output Format

```markdown
## Code Review: [files reviewed]

### Convergence
- Round: N
- MUST FIX trend: [R1: 3] → [R2: 1] → [R3: 0]
- Recommendation: STOP / CONTINUE

### MUST FIX (Blockers)

> **STRUCTURAL REQUIREMENT**: Every MUST_FIX entry MUST include a `Diff evidence:` line showing the verbatim `+` line from `git diff` that proves the issue is on a changed line. A finding without `Diff evidence:` is INVALID and must be dropped before presenting to the user. This is a hard format gate — not a soft guideline.

1. **[Issue title]** — `file.go:42` — [agent]
   **Diff evidence**: `+    <verbatim line from git diff that triggered this finding>`
   **Blast radius** *(only if diff change requires updating pre-existing callers/sites)*:
   - `other.go:89` — [why it must change as a consequence of the diff change]
   **Fix**: [concrete fix covering diff evidence line AND any blast-radius sites]

### SHOULD FIX (Quality)
| Issue | File:Line | Agent | Recommendation |
|-------|-----------|-------|----------------|
| Overly complex function | `utils.go:89` | simplicity-reviewer | Extract helper |

### Passed Checks
- [check]: [status]

### Agent Summary
| Agent | Verdict | Findings |
|-------|---------|----------|
| race-condition-reviewer | ISSUES | 1 race condition |
| simplicity-reviewer | PASS | - |

---

### Verdict: NEEDS WORK / APPROVED
### Next: STOP (converged) / CONTINUE (run again after fixes)
```

---

## Plan Technical Review Prompt (`/review-plan` default)

```
Review this implementation plan for readiness to code.

## The Plan
<plan>
[paste plan content]
</plan>

## Original Requirements (if provided)
<requirements>
[paste requirements]
</requirements>

## CRITICAL: Apply 80/20 Thinking

Focus on the 20% of issues that cause 80% of problems.

**A MUST FIX blocker is ONLY:**
- Missing step that makes implementation impossible
- Data integrity risk (orphaned records, corruption, loss)
- Security vulnerability (injection, auth bypass, SSRF)
- Undefined contract that blocks integration
- Ambiguity requiring guesswork during implementation

**NOT a blocker (put in DEFER or SKIP):**
- Missing docs, imperfect error messages
- Edge cases affecting <1% of users
- "Best practices" not strictly required
- Future-proofing for hypothetical scenarios

## Evaluate (priority order)

1. **Feasibility**: Do required APIs/functions exist?
2. **Risks**: Data integrity? Security? Breaking changes?
3. **Ambiguity**: Can developer implement without guessing?
4. **Scope**: What can be cut for MVP?

## Output

1. **MUST FIX** (0-3 max): What breaks? How to fix?
2. **SHOULD FIX** (0-5): Why it matters, why not blocking
3. **DEFER**: Valid for later
4. **SKIP**: Over-engineering to reject
5. **VERDICT**: READY / NEEDS WORK / MAJOR REVISION
```

---

## Plan Spec Review Prompt (`/review-plan --spec`)

```
Review this plan's REQUIREMENTS for completeness and clarity.
DO NOT review technical implementation - only requirements.

## The Plan
<plan>
[paste plan content]
</plan>

## Original User Request (if provided)
<request>
[paste original request]
</request>

## CRITICAL: Requirements-Only Review

You are validating "are we building the right thing?" NOT "can we build it?"

**A MUST FIX blocker is ONLY:**
- User requirement from original request NOT captured in plan
- Acceptance criteria that cannot be tested/verified
- Missing "Out of Scope" section (scope creep risk)
- Contradictory or ambiguous requirements
- Unstated assumptions that could surprise stakeholders

**NOT a blocker (put in DEFER or SKIP):**
- Missing implementation details
- Technical approach concerns
- Nice-to-have features not in original request
- Imperfect wording that's still clear

## Evaluate

1. **Completeness**: Every requirement from original request captured?
2. **Testability**: Each requirement has verifiable acceptance criteria?
3. **Scope Boundaries**: "Out of Scope" section exists and is clear?
4. **Clarity**: Could a stakeholder approve without asking questions?
5. **Assumptions**: Are implicit assumptions made explicit?

## Output

1. **MUST FIX** (0-3 max): Missing/unclear requirements
2. **SHOULD FIX** (0-5): Improvements to clarity
3. **DEFER**: Nice-to-haves for future
4. **SKIP**: Scope creep suggestions to reject
5. **VERDICT**: READY / NEEDS WORK / MAJOR REVISION
```

---

## Plan Review Output Format

```markdown
## Plan Review: [plan-name]
### Mode: Technical / Spec

### Convergence
- Round: N
- MUST FIX trend: [R1: 3] → [R2: 1] → [R3: 0]
- Recommendation: STOP / CONTINUE

### MUST FIX (Blockers)
| # | Issue | Found By | Fix |
|---|-------|----------|-----|
| 1 | [description] | codex, gemini | [fix] |

*If empty: "None - plan is ready"*

### SHOULD FIX (Quality Improvements)
| # | Issue | Why not blocking |
|---|-------|-----------------|
| 2 | [description] | [reason] |

### DEFER (Future Iterations)
- [Issue] - [why it can wait]

### SKIP (Rejected Suggestions)
- [Suggestion] - [why this is over-engineering/scope-creep]

### What's Good
- [Validated aspects]

---

### Verdict: READY / NEEDS WORK / MAJOR REVISION
### Confidence: HIGH/MEDIUM/LOW
```



