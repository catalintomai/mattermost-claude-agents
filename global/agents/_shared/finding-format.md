---
name: finding-format
description: Canonical output format for all review agents
---

# Canonical Finding Format

**MANDATORY** for all review/audit agents. Ensures orchestrators can parse, merge, and deduplicate findings across agents in swarm mode, and humans get consistent reports in standalone mode.

> **Relationship to review-prompts.md**: This file defines the **agent-level** output format (what each agent emits). The orchestrator-level synthesis format (tables, convergence tracking, verdicts) is defined in `~/.claude/docs/review-prompts.md`. Multi-LLM reviewers (Codex/Gemini) use a simplified numbered-list format embedded in the prompt templates there.

## Agent Prefix Requirement

Every agent reading this file **MUST** prefix all findings with its own agent name:
```
[agent:YOUR-AGENT-NAME]
```
Replace `YOUR-AGENT-NAME` with the literal value of the `name:` field in your own frontmatter (e.g., `[agent:api-reviewer]`, `[agent:xss-reviewer]`). This prefix enables orchestrators to attribute findings when multiple agents run in swarm mode.

## Output Structure

```markdown
## [Review Type]: [scope]

### Status: PASS | FAIL

### MUST_FIX

1. **[agent:TAG]** `file.go:42` — [one-line description]
   **Diff evidence**: `+    <verbatim line from git diff that triggered this finding>`
   **Blast radius** *(only when the diff change requires updating pre-existing callers/sites as a consequence)*:
   - `other.go:89` — [why this site must change as a result of the diff change]
   **Evidence**:
   ```go
   [actual code from Read output]
   ```
   **Fix**: [concrete fix covering diff evidence line AND any blast-radius sites]

### SHOULD_FIX

1. **[agent:TAG]** `file.go:78` — [one-line description]
   **Evidence**: [quote or reference]
   **Fix**: [suggested fix]

### PASS

- [check performed and passed]

### Summary

- MUST_FIX: [N]
- SHOULD_FIX: [N]
- Checks passed: [N]
```

## Field Definitions

| Field | Required | Description |
|-------|----------|-------------|
| **Review Type** | Yes | Agent's review name (e.g., "Race Condition Review", "API Layer Review") |
| **scope** | Yes | What was reviewed (filename, feature, endpoint) |
| **Status** | Yes | `PASS` (0 MUST_FIX) or `FAIL` (1+ MUST_FIX) |
| **TAG** | Yes | Agent-prefixed uppercase label: `{agent}:{issue}` (e.g., `race:TOCTOU`, `api:STORE_BYPASS`, `validation:MISSING_BOUNDS`). Prefix prevents collisions when multiple agents emit same issue name for different subsystems. |
| **file:line** | Yes | Verified location — must match Read output |
| **Diff evidence** | **Yes — MUST_FIX only** | Verbatim `+` line from `git diff` proving the finding is on a changed line. A MUST_FIX without this field is **invalid and must be dropped**. |
| **Blast radius** | No | Pre-existing callers/sites that must change *as a direct consequence* of the diff change (e.g., callers of a new function that replaces an old one). Only include when the diff itself creates the obligation. |
| **Evidence** | Yes | Actual code quote per grounding-rules.md |
| **Fix** | Yes | Concrete remediation, not vague advice |

## Pattern Completeness (Mandatory)

When you find a bug, **do not report just the one instance you found**. Treat every finding as a potential **pattern** and search the codebase for all occurrences before writing your report.

> **Interaction with diff-scope-rule**: See the **Pattern Escalation Override** in `~/.claude/agents/_shared/diff-scope-rule.md`. When a pattern violation is found on a changed line, you MUST grep the entire codebase for all instances — both in-scope and pre-existing. The diff-scope rule explicitly permits this for pattern violations. Report one finding with all locations grouped.

**Workflow for every finding:**
1. Identify the **root pattern** — what makes this code wrong? (e.g., "calls `HandleError` instead of `HandleAppError` for service-layer errors", "wraps error before classifying it")
2. **Grep for the pattern** across the codebase — search for all call sites, all similar functions, all parallel code paths. This is NOT optional. You MUST run the grep BEFORE writing the finding.
3. **Report the pattern once** with ALL affected locations listed (in-scope and pre-existing), not N separate findings for the same root cause
4. **The fix must address ALL instances** — not just the ones on changed lines. A fix that patches 1 of 107 identical call sites is not a fix.

**This applies in TWO directions:**
- **Same bug, multiple locations**: Found bad pattern X? Grep for X everywhere.
- **Missing guard on parallel paths**: Found any guard (validation, permission, error wrapping, sanitization, etc.) on one entry point? Grep for ALL parallel entry points that perform the same operation (e.g., create, update, duplicate, import, REST, GraphQL) and verify EACH has the equivalent guard. Report every unguarded path.

**Examples:**
- Found `HandleError` (always 500) used instead of `HandleAppError` (sentinel-aware) on a changed line? → `grep 'HandleError\(w,' server/api/` to find ALL 107 call sites. Report once with the full count and a codebase-wide fix.
- Found `isPbAdmin` computed from request-body `Members` in `createPlaybook`? → Grep for ALL calls to `IsPlaybookAdminMember` and check whether each passes request-body or DB-loaded data. Report every vulnerable call site.
- Found `errors.Wrap(err, ...)` before `classifyAppError()` in one resolver? → Grep for ALL `classifyAppError` calls and check if any others wrap first. Report the full list.
- Found missing nil check on `field.Type` in `makeRunNameFormatFunc`? → Grep for ALL accesses to `field.Type` in the same file/package. Report every unguarded access.
- Found missing size validation in `setRunPropertyValue`? → Grep for ALL property value entry points and check each for the same validation gap.
- Found a guard (permission check, validation, error classification) on one entry point but not a sibling? → Grep for ALL paths that write/read the same fields and report every path missing the guard.

**Output format** (see diff-scope-rule.md Pattern Escalation Override for full template):
```markdown
1. **[agent:TAG]** [VERIFIED] `file.go:42`, `file.go:87`, `other.go:15` — [pattern description]

   **In-scope instances** (changed lines):
   - `file.go:42` — [evidence]

   **Pre-existing instances** (same pattern, unchanged lines):
   - `file.go:87`, `other.go:15` — same pattern (N total)

   **Fix**: [single fix covering ALL instances]
```

## Verification Status

Every finding MUST include a verification status:

| Status | Meaning | When to Use |
|--------|---------|-------------|
| `VERIFIED` | Evidence was re-read from source immediately before writing | Agent used Read tool on the cited file:line AFTER forming the finding |
| `UNVERIFIED` | Evidence was not independently verified against source | Multi-LLM findings (Codex/Gemini have no Read access), or agent did not re-read |

**Format**: Add `[VERIFIED]` or `[UNVERIFIED]` after the tag:
```markdown
1. **[api:MISSING_PERM]** [VERIFIED] `file.go:42` — description
1. **[ml:RACE_CONDITION]** [UNVERIFIED] `file.go:42` — description
```

**Synthesis rule**: UNVERIFIED findings MUST NOT be promoted to MUST_FIX without re-verification by the synthesizer or a cross-validator.

## Severity Mapping

Agents may use domain-specific terminology internally. When emitting findings, map to canonical severities:

| Canonical | Maps From | Meaning |
|-----------|-----------|---------|
| `MUST_FIX` | Critical, Block PR, Block Implementation, Data Race, Breaking Change | Blocks merge. Correctness, security, or data-loss risk. |
| `SHOULD_FIX` | High Priority, Recommendations, Medium Priority, Improvement | Should fix but doesn't block. Performance, maintainability, best practice. |
| `PASS` | (no issues in category) | Check was performed and no issues found. |

Findings that don't fit either severity (informational notes, minor style nits) go under `SHOULD_FIX` with a `NOTE` tag.

## Tags

Tags use `{agent}:{issue}` format — the agent prefix is the short domain name, the issue is an uppercase label. This namespacing lets orchestrators distinguish e.g. `api:MISSING_VALIDATION` (missing API input check) from `null:MISSING_VALIDATION` (missing nil guard).

Each agent defines its own domain tags. Examples:

| Agent (prefix) | Example Tags |
|----------------|-------------|
| Race conditions (`race`) | `race:TOCTOU`, `race:SHARED_MAP`, `race:GOROUTINE_LEAK`, `race:MISSING_LOCK` |
| API layer (`api`) | `api:STORE_BYPASS`, `api:MISSING_PERM`, `api:MISSING_AUDIT` |
| Error handling (`err`) | `err:IGNORED_ERR`, `err:MISSING_WRAP`, `err:WRONG_ERR_TYPE` |
| Validation (`val`) | `val:MISSING_VALIDATION`, `val:MISSING_CROSS_REF`, `val:MISSING_BOUNDS` |
| XSS (`xss`) | `xss:UNSAFE_RENDER`, `xss:MISSING_SANITIZE` |
| Null safety (`null`) | `null:NIL_DEREF`, `null:MISSING_NIL_CHECK` |

## Standalone vs Swarm Mode

This format works in both modes:
- **Standalone**: Agent returns the report directly. Human reads it.
- **Swarm**: Agent writes to `/tmp/swarm-{team}/phase1/{name}.md`. Orchestrator parses `MUST_FIX` / `SHOULD_FIX` sections for merge/dedup.

No format changes needed between modes — the structure is the same.

## Domain-Specific Extensions

Agents MAY add extra sections after the canonical ones for domain-specific detail:

```markdown
### MUST_FIX
[canonical findings...]

### SHOULD_FIX
[canonical findings...]

### PASS
[canonical checks...]

### [Domain-Specific Section]
[e.g., "Race Detection Results", "Pattern Checklist", "Complexity Score"]
```

The rule: canonical sections first, extras after.

## Numeric Scores

Some agents produce scores (e.g., Complexity Score 1-10). Include these as a domain-specific extension section. The score does NOT replace the MUST_FIX/SHOULD_FIX/PASS structure — it supplements it.
