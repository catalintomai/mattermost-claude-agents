---
name: eighty-twenty-rule
description: 80/20 prioritization rule for all agents — propose the minimum change that solves the actual problem; sequence work so the system runs first
---

# The 80/20 Rule

**MANDATORY** for all agents proposing changes, findings, plans, or recommendations.

The principle: **20% of the changes deliver 80% of the value. Find those 20% and lead with them.** Everything else is either deferred or skipped.

---

## Rule 1: What Enables the System to Run Comes First

When proposing work, sequence it:

1. **Now** — without this, nothing works (correctness, the system won't start, tests fail, the user can't do the main thing)
2. **Soon** — without this, the system works poorly (reliability, performance, important edge cases)
3. **Later** — without this, the system is harder to extend (refactoring, observability, developer experience)
4. **Never (for now)** — YAGNI, hypothetical future requirements, "nice to have"

Put later items in a clearly-labeled deferred section. Do not present them at the same level as Now items.

---

## Rule 2: Blocker Criteria for Review Agents

A MUST_FIX is a finding where **the system produces wrong results or cannot operate** without the fix. Apply this strictly.

| MUST_FIX (blocks) | NOT MUST_FIX (defer or skip) |
|-------------------|------------------------------|
| Logical contradiction — two rules cannot both be true | Suggestion to improve naming |
| Missing state — valid input produces undefined behavior | YAGNI — feature not yet needed |
| Wrong output — calculation or decision is incorrect | Scope expansion — adding requirements not in the plan |
| Security hole — data exposed or bypass possible | Over-engineering — abstraction for one use case |
| CI will fail — build broken, test will always fail | Style preference — valid but different from author's choice |
| Phase ordering wrong — later phase feature in Phase 0b | Minor ambiguity with an obvious implementation path |

**If a finding does not clearly fit the left column, it is SHOULD_FIX at most, or DEFER/SKIP.**

---

## Rule 3: Do Not Raise Scope or YAGNI Concerns

Do not flag:
- "This could be more extensible"
- "You might want to add X later"
- "Consider refactoring Y for future maintainability"
- "This design doesn't support use case Z" (when Z is not in scope)
- Complexity concerns when the code is not actually broken
- Missing features that are explicitly deferred to a later phase

These are not findings. They are product decisions. If the plan says "Phase 3", do not flag the absence of Phase 3 features in Phase 1.

**Exception**: raise a scope concern if and only if the missing item makes the current phase's output *incorrect* — i.e., what is built cannot work without it.

---

## Rule 4: One Change at a Time

When proposing fixes or implementations:

- Solve the stated problem. Do not simultaneously refactor surrounding code.
- A bug fix is not an invitation to clean up the function. Fix the bug.
- A new feature is not an invitation to add configurability. Add the feature.
- Three similar lines of code is not automatically a refactoring opportunity.

If you notice something else worth fixing, note it briefly under SHOULD_FIX or DEFER — do not bundle it into the primary fix.

---

## Rule 5: Plans Must Be Ordered by Phase

When writing or reviewing implementation plans:

- The earliest phase must contain only what is needed to get the system running
- Advanced features, edge case handling, and operational concerns belong in later phases
- Phase sections should be ordered from "needed first" to "added later"
- Defer-only content (e.g., Phase 3 contamination checks in a Phase 1 plan) goes at the **end**, clearly labeled, with a stop note: *"Do not implement until Phase X."*

A plan that puts Phase 3 content in the middle of Phase 1 content violates this rule.

---

## Application by Agent Type

| Agent type | How the rule applies |
|------------|---------------------|
| Review agents (plan, code, design) | MUST_FIX only for blockers; skip YAGNI/scope/style; label phase-misplaced content as SHOULD_FIX not MUST_FIX |
| Coder / implementer agents | Implement exactly what was asked; do not add unrequested validation, abstractions, or comments |
| Planning agents | Order sections by phase; Phase 0/1 first; advanced content last with explicit defer labels |
| All agents proposing changes | Lead with the minimum change; put optional improvements in a separate "also consider" section |

---

## Quick Test

Before writing a finding or proposal, ask:

> "If this is not addressed, does the system produce wrong results or fail to operate?"

- **Yes** → MUST_FIX
- **No, but it's a real improvement** → SHOULD_FIX
- **No, and it's for a later phase** → DEFER
- **No, and it's speculative** → SKIP
