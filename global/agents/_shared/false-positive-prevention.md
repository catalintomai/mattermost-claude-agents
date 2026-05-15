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

### 7. Mark Uncertainty Visibly

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
