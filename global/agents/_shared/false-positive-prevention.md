---
name: false-positive-prevention
description: Universal false positive prevention principles for all agents across all projects
---

# Universal False Positive Prevention

This file establishes principles that apply to ANY agent in ANY project. Project-specific guardrails (e.g., `viglex-internal-guardrails.md`) extend these universal rules with domain-specific details.

## Universal Principles

### 1. Verify Before Asserting

- Require evidence from specified documents, sources, or tool results
- Do NOT rely on training knowledge or inference alone
- If you cannot find evidence, mark [UNVERIFIED] instead of guessing

### 2. When Uncertain, Escalate

- Incomplete evidence is NOT the same as incorrect evidence
- When confidence < threshold, escalate to human rather than making a borderline decision
- Escalation is the default; silence is the exception

### 3. Don't Hallucinate External Claims

- Do NOT invent facts about external products, regulations, or organizations
- Do NOT cite sources that don't exist
- If a claim cannot be verified, mark [UNVERIFIED — source check: DATE] and flag for manual follow-up

### 4. Schema Constraints Prevent False Positives

- Strict JSON schemas (with required/optional fields, enums, ranges) prevent hallucination better than open prompting
- If a tool returns data that violates the schema, escalate instead of coercing
- Tight schemas > loose schemas > pure natural language

### 5. Confidence Semantics

- Confidence = **strength of evidence**, NOT probability of correctness
- 0.9 confidence means "5 independent sources confirmed," not "90% likely true"
- Do NOT report confidence > actual evidence strength

### 6. Explicit Prohibitions Outperform Pure Prompting

Research shows: Models ignore "do not hallucinate" but comply with "if uncertain, return {status: insufficient_data}".

Pattern that works:
```
If [signal], return {action: "escalate", reason: "insufficient_data"}
```

Pattern that doesn't work:
```
Do not hallucinate or make guesses about this domain
```

### 7. Convention Claims Require a Convention Check

Before asserting that changed code violates a convention, verify the convention actually holds locally: read the surrounding file, the sibling handlers in the same package, and the generated artifact the change targets. "This differs from how I would write it" is not a violation; "this differs from every sibling in the same file" is.

Two retractions on one PR make the cost concrete. A reviewer flagged a handler for rewriting `GetSinglePost` failures as permission errors — a maintainer showed the identical pattern in `updatePost`, `postPatchChecks`, and the patch and restore handlers, and the reviewer withdrew it ("My original comment was wrong. Apologies for the noise!"). The same reviewer asked for `make i18n-extract` on an `en.json` key that was already in canonical order, so the regeneration would have been a no-op.

If the convention check cannot be performed with the material available, downgrade the finding to `[UNVERIFIED]` rather than asserting the violation.

### 8. Generated Files Are Not Churn

Before reporting *any* finding whose claim is "these lines changed and nothing explains why" — untraced churn, drive-by cleanup, unrelated removal — first establish whether the file is **generated**. One command answers it:

```bash
grep -rn "<path/to/file>" Makefile package.json */package.json 2>/dev/null
```

If the path appears as a build target or an `--out-file`, the finding is void. Diffs in a build output are the expected result of running the generator, not unexplained churn. The only legitimate question left is whether the *source* change justified the regeneration — so review the source, not the artifact.

Common generated-but-committed artifacts: i18n/message catalogues (`formatjs extract --out-file`, mmgotool), lockfiles (`go.sum`, `package-lock.json`), mocks (`make plugin-mocks`, mockery), API clients, and snapshots. Hand-editing any of them creates drift that the next generator run silently reverts — so a "fix" that edits the artifact is worse than no fix, because it looks correct until someone runs the build.

A second, independent check that kills the same false positive: **find a sibling in the same state.** If another symbol of the same kind (another deferred feature, another commented-out block) was treated the same way and nobody objected, the change is the local norm rather than an anomaly.

Concrete case: a reviewer flagged three removed "Favorites" i18n keys as untraced churn in a permissions PR. `webapp/i18n/en.json` is the `--out-file` of `formatjs extract`; the keys' only references sat inside a deferred-feature JSX comment, so they were not in the AST and extraction correctly dropped them. The sibling check was equally decisive — `docs.sidebar.space.mute`, another deferred feature, was already absent for the identical reason. The finding was relayed and acted on, producing two wrong edits before either check was run.

### 9. Mark Uncertainty Visibly

- [VERIFIED] — Found in authoritative source, traceable, reproducible
- [UNVERIFIED — reason] — Could not verify; flagged for manual review
- Never silent failures; always surface uncertainty

---

## How to Use This File

### For Internal Agents

Reference this file alongside project-specific guardrails:

```markdown
**Guardrails**: 
Read `~/.claude/agents/_shared/false-positive-prevention.md` (universal principles)
AND `./.claude/agents/_shared/[project]-guardrails.md` (domain-specific patterns)
```

### For Creating New Projects

When starting a new project, create a project-local guardrails file that:
1. References this file (do NOT repeat universal principles)
2. Adds domain-specific guidance (terminology, thresholds, escalation rules)
3. Applies to agents you create in that project

---

## Examples by Domain

### Compliance AI (Viglex)

**Universal principle**: "When uncertain, escalate"  
**Viglex addition**: "Escalate if confidence < 0.60 for sanctions matches; < 0.75 for SAR recommendations"

### General Code Review

**Universal principle**: "Verify before asserting"  
**Project addition**: "Verify code changes with git blame and PR context; don't rely on filenames"

### Market Research

**Universal principle**: "Don't hallucinate external claims"  
**Project addition**: "Verify competitor features against official announcements, not analyst estimates; cite URLs"

---

## Scientific Basis

These principles are grounded in:
- Anthropic's "Minimizing Hallucinations" research
- OpenAI's Function Calling Best Practices
- Snap Agent Format (explicit constraints)
- GSA-TTS devCrew_s1 (enterprise guardrails)
- Academic research on prompt engineering effectiveness

Key finding: **Fail-safe design** (explicit "what to do when uncertain") outperforms constraint-based design ("don't do X").
