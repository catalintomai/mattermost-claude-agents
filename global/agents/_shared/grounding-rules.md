---
name: grounding-rules
description: Evidence-based grounding rules for agent findings
---

# Evidence-Based Grounding Rules

**MANDATORY** - All agent findings MUST be grounded in actual code/files.

## Core Rules

1. **READ BEFORE REPORTING**: You MUST read a file using the Read tool BEFORE reporting any issue in that file. Never report issues in files you have not read in this session.

2. **VERIFY FILE EXISTS**: Before referencing any file path, use Glob to verify it exists. If Glob returns no results, the file does not exist - do not report issues for non-existent files.

3. **QUOTE ACTUAL CODE**: Every finding MUST include a direct quote of the problematic code copied from your Read tool output. No paraphrasing or reconstructing from memory.

4. **VERIFY LINE NUMBERS**: When reporting `file:line`, the line number must match your Read output. Count the lines if necessary.

5. **NO HALLUCINATED PATHS**: Never invent or guess file paths. Only use paths you have confirmed exist via Glob or Read.

6. **NO ASSUMPTIONS**: If you cannot verify something exists, do not report it. Say "I could not verify..." instead.

## Verification Templates

### For Code Issues
```
**Issue**: [type] in `verified/path/file.go:NN`
**Evidence** (from Read output):
```go
// Actual code copied from Read tool
```
**Problem**: [description based on evidence]
```

### For "Missing" Claims
Before claiming validation, auth, or any pattern is "missing":
- Search for it with Grep across the codebase
- Check if it's handled in middleware, app layer, or elsewhere
- Only report as "missing" after verifying it's not done anywhere in the call chain

```
**Claim**: [X] is missing
**Verification**:
grep -r "pattern" path/
**Results**: [paste actual grep output]
**Conclusion**: [CONFIRMED missing / Actually handled at Y]
```

### For "Function/Type Does Not Exist" Claims
Before claiming a function, type, or variable doesn't exist:
- Search for its definition with Grep (not just its usage)
- Check the same package (other files), imports, and dependencies
- Only report as "doesn't exist" after confirming no definition found

```
**Claim**: [Function X] does not exist
**Verification**:
grep -r "func X\|func.*X\|type X" --include="*.go" .
**Results**: [paste actual grep output]
**Conclusion**: [CONFIRMED missing / Actually defined at path/file.go:NN]
```

### For "Incorrect Pattern/API Usage" Claims
Before claiming a code pattern, API call, or library usage is wrong:
- Search the codebase for the **same pattern** using Grep
- If 2+ existing production files use the same construct, it is an **established pattern** — do NOT flag it as a bug unless you can prove the existing usages are also broken
- Check library source/docs if unsure how a function behaves (e.g., `sq.Expr` placeholder translation)
- Only report as "incorrect" after confirming the pattern is genuinely wrong, not just unfamiliar

```
**Claim**: Pattern X is incorrect / will crash at runtime
**Verification**:
grep -r "pattern" --include="*.go" server/
**Results**: [paste actual grep output]
**Conclusion**: [CONFIRMED incorrect — no existing usage / Actually established pattern used in N files]
```

### For "Unused Code" Claims
```
**Claim**: [X] appears unused
**Verification**:
grep -r "X" --include="*.go" server/
grep -r "X" --include="*.ts" webapp/
**Results**: [paste actual grep output]
**Conclusion**: [CONFIRMED unused / Actually used in N locations]
```

### For Causal/Scope Claims
Before claiming "X requires Y" or "X is because of Y":
- Verify the **scope** of the relationship — does Y guard X specifically, or does Y guard the entire enclosing context (endpoint, function, module)?
- Check if Y would exist even without X (e.g., a permission check that guards the whole endpoint, not a specific parameter)
- Only report a causal relationship after confirming the permission/check is specifically tied to the feature, not just co-located

```
**Claim**: Endpoint A requires PermissionX because of ParameterY
**Verification**:
1. Read the endpoint — does PermissionX gate the whole function or just ParameterY?
2. Would PermissionX still be required if ParameterY were removed?
**Conclusion**: [CONFIRMED causal / Actually endpoint-level, unrelated to ParameterY]
```

### For Provenance/History Claims
Before claiming "X was written because of Y", "X predates Y", or "this code/rule
was derived from Z":
- Run `git log --follow -p <file>` or `git log --grep="<keyword>"` to find the
  commit that introduced the thing
- If no git evidence supports the causal chain, **do not make the claim**
- A pattern match (two things look similar) is NOT evidence of causation
- Say "these share the same example — possibly related" rather than
  "this PR is what that rule was written from"

**Rule**: No provenance claim without a commit hash or explicit documentation
to back it up. If you can't show the evidence, say "I don't know."

### For Flag/Permission Scope Claims
Before claiming "operation X should be gated by flag/permission Y":
- A flag's scope is defined by **where it's actually enforced in code**, not by what its name suggests it *could* cover
- Grep for every call site of the flag's check function — these are Y's actual scope
- If operation X is not in that set, it is **outside Y's scope by design** — do NOT flag it as a bypass
- Only flag a missing check if an **existing sibling operation at the same semantic level** already checks Y (e.g., UpdateFoo checks Y but CreateFoo doesn't, and both are content mutations)

```
**Claim**: Operation X should check flag Y
**Verification**:
1. Grep for all call sites of Y's enforcement function
2. Categorize each call site by semantic level (content edit, lifecycle, operational config, etc.)
3. Categorize operation X — is it at the same semantic level as the existing call sites?
**Conclusion**: [CONFIRMED — X is same level as existing gated ops / X is a different operation type, outside Y's intended scope]
```

**Why this matters**: Flag names are suggestive but not authoritative. `AdminOnlyEdit` gates content editing — not every mutation on the entity. `OwnerGroupOnlyActions` gates specific lifecycle actions — not all run operations. The code decides scope, not the name.

## Pattern Completeness (Mandatory)

**Every finding is a potential pattern.** Before writing ANY finding, you MUST search the codebase for ALL instances of the same anti-pattern and report them as ONE finding — not N separate findings for the same root cause.

**Workflow for every finding:**
1. **Identify the root pattern** — what makes this code wrong? (e.g., "calls `HandleError` instead of `HandleAppError` for service-layer errors")
2. **Grep for the pattern** across the codebase — search for all call sites, all similar functions, all parallel code paths. This is NOT optional. You MUST run the grep BEFORE writing the finding.
3. **Report the pattern once** with ALL affected locations listed (in-scope and pre-existing), not N separate findings for the same root cause.
4. **The fix must address ALL instances** — not just the one you found first.

**This applies in TWO directions:**
- **Same bug, multiple locations**: Found bad pattern X at line 42? Grep for X everywhere. Report once with all locations.
- **Missing guard on parallel paths**: Found a guard (validation, permission, error wrapping, sanitization) on one entry point? Grep for ALL parallel entry points (create/update/duplicate/import, REST/GraphQL) and verify each has the equivalent guard. Report every unguarded path in the same finding.

**Output format for pattern findings:**
```markdown
1. **[agent:TAG]** [VERIFIED] `file.go:42`, `file.go:87`, `other.go:15` — [pattern description]

   **In-scope instances** (changed lines):
   - `file.go:42` — [evidence]

   **Pre-existing instances** (same pattern, unchanged lines):
   - `file.go:87`, `other.go:15` — same pattern (N total)

   **Fix**: [single fix covering ALL instances]
```

## Re-Read Before Submit (Mandatory for MUST_FIX)

**The #1 cause of false positives is reconstructed evidence.** Agents read a file, form an opinion, then write "evidence" from memory — inadvertently dropping lines, nil guards, feature flag checks, or other details that invalidate the finding.

For every MUST_FIX finding, you MUST:
1. **Re-read the exact lines** you are about to cite using the Read tool — AFTER forming your finding, not before
2. **Copy-paste directly** from the fresh Read output into your evidence block
3. **Verify your claim still holds** against the freshly-read code
4. If re-reading disproves your finding, **drop it** — do not adjust the evidence to fit your conclusion

This applies even if you already read the file earlier in the session. Memory of code is unreliable — the Read tool is the source of truth.

For SHOULD_FIX findings, re-reading is strongly recommended but not mandatory.

## Neutral Framing in Agent Prompts

**NEVER include conclusions in agent prompts.** Present neutral observations and let agents draw their own conclusions.

```
# WRONG — leading prompt (biases the agent):
"Endpoint B is missing PermissionX for include_deleted,
 while Endpoint A requires PermissionX for include_deleted."

# RIGHT — neutral prompt (independent reasoning):
"Endpoint A checks PermissionX at the top and also passes include_deleted.
 Endpoint B does not check PermissionX but also passes include_deleted.
 Analyze whether this is a security concern."
```

**Why**: Agents are confirmation-biased. If you state a conclusion as fact, they'll find evidence supporting it rather than independently verifying the causal relationship.

**Rule of thumb**: If you've already formed an opinion, actively phrase the prompt to NOT reveal it. Describe what you SEE, not what you THINK it means.

## Before Submitting Review

- [ ] Every MUST_FIX evidence block was copy-pasted from a Read call made AFTER forming the finding
- [ ] Every file path mentioned has been verified with Glob or Read
- [ ] Every code snippet is copied from Read output, not reconstructed
- [ ] Every "missing" claim has grep verification showing no results
- [ ] Every "doesn't exist" claim has grep verification for definitions
- [ ] Every "incorrect pattern" claim has grep verification confirming no established usage in the codebase
- [ ] Every UX behavior finding (disabled button, return null, missing hint, etc.) has grep verification of sibling components — if 2+ siblings use the same approach it is an established pattern and must be demoted to INFO
- [ ] Every MUST_FIX finding has been grep-verified for pattern completeness (all codebase instances found, not just one — see "Pattern Completeness" section above)
- [ ] Line numbers match actual Read output
