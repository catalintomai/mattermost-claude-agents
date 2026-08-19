---
name: doubt-driven
description: Subjects a non-trivial decision to fresh-context adversarial review BEFORE it stands, while course-correction is still cheap. Use when correctness matters more than speed, when working in unfamiliar code, on irreversible operations, or when about to claim a non-obvious fact ("this is safe", "nothing uses this", "this matches the spec"). In-flight counterpart to /review-code.
version: 1.0.0
tags:
  - verification
  - review
  - discipline
user_invocable: true
---

# Doubt-Driven

**Doubt the claim before it stands, not the artifact after it ships.**

A confident answer is not a correct one. Long sessions accumulate context that quietly
turns assumptions into "facts". This skill materializes a fresh-context reviewer — biased
to **disprove**, not approve — before a non-trivial decision is acted on.

This is not `/review-code`. That is a verdict on a finished artifact, with a leader,
cross-validation, and convergence. This is an in-flight posture: one claim, one adversary,
while the cost of being wrong is still a rewrite rather than a revert.

## When to Use

A decision is **non-trivial** when at least one is true:

- It introduces or modifies branching logic, a guard, or a gate.
- It crosses a layer or module boundary (api4 → app → store).
- It asserts a property the compiler cannot verify — thread safety, idempotence, ordering, an invariant.
- It is a **negative claim**: "nothing calls this", "no consumer exists", "this event is missing".
- Its blast radius is irreversible: production deploy, data migration, public API change, file deletion.
- You are about to state a non-obvious fact the user will act on.

**When NOT to use.** Doubt everything and you ship nothing.

- Mechanical edits: renames, formatting, file moves.
- Following a clear, unambiguous instruction.
- Reading or summarizing existing code.
- One-line changes with obvious correctness.
- The user asked for speed over verification.

## The Cycle

```
- [ ] 1 CLAIM     — wrote the claim + why it matters, in 3 lines
- [ ] 2 EXTRACT   — isolated artifact + contract, stripped my reasoning
- [ ] 3 DOUBT     — dispatched the adversary that owns this claim type
- [ ] 4 RECONCILE — classified every finding against the artifact
- [ ] 5 STOP      — met a stop condition
```

### 1 CLAIM — surface what stands

```
CLAIM: <the decision, one or two lines>
WHY IT MATTERS: <what breaks if this is wrong>
```

If you cannot write it that compactly, you have a vibe, not a decision. Surface it first.

### 2 EXTRACT — smallest reviewable unit

A fresh-context reviewer needs the **artifact** and the **contract**, never the journey.

- Code: the diff or the single function — not the file.
- Decision: the proposal in 3–5 sentences plus the constraints it must satisfy.
- Strip your reasoning. If the artifact only survives with your narration attached, that
  is the finding.

### 3 DOUBT — dispatch the adversary that owns the claim type

Do not spawn a generic reviewer. Route by what kind of claim it is:

| Claim shape | Adversary | Why this one |
|---|---|---|
| "This guard/gate/validator holds" | `counterexample-reviewer` | Attacks the code's own stated guarantees |
| "Signature / schema / constant is X" | `symbol-sweep-reviewer` then `plan-assertion-reviewer` | Mechanical existence check, then reasoning |
| "We already have this mechanism" | `reuse-detector` | Verifies the mechanism exists on master, not just the branch |
| "Vendor / competitor behaves like X" | `external-claims-auditor` | Primary-source verification |
| "The architecture follows because…" | `architecture-assertion-auditor` | Catches valid facts → invalid conclusion |
| "Nothing uses this / zero references" | see **Negative claims** below | Absence needs more rigor than presence |

Prompt the adversary to **refute**, and tell it to default to refuted when uncertain.
State the claim and the contract; do not include your justification.

**Negative claims** (`docs/search-first-workflow.md` is canonical). Before "does not
exist", confirm both:

1. The search space was **whole** — no `head`/`tail` truncation on a listing you then
   quantify over, right directory, right branch.
2. The query was **name-complete** — you grepped the concern, not one spelling; wrappers,
   aliases, and SDK layers use different names than the thing they wrap.

If you cannot confirm both, the honest claim is "did not find", not "does not exist".

### 4 RECONCILE — classify, do not negotiate

Every finding gets exactly one verdict, decided against the artifact text:

- **ACCEPTED** — the artifact is wrong. Change it.
- **REFUTED** — cite the evidence that voids the finding, in the artifact or the code.
  A refutation is a `file:line`, not a paragraph of confidence.
- **DEFERRED** — real, out of scope for this claim. Name it as a follow-up.

Hold refutations to the same standard as acceptances. Asymmetric skepticism — scrutinizing
alarming findings while waving through reassuring ones — is the documented failure mode in
`skills/review-code/SKILL.md`.

### 5 STOP

Stop at the first of: findings are trivial, 3 cycles completed, or the user overrides.
Three cycles without convergence means the claim is wrong or underspecified — escalate,
do not iterate.

## Loading Constraints

**Do not add this skill to an agent's `skills:` frontmatter.** Step 3 spawns a reviewer;
an agent that runs it would spawn from inside a subagent, breaking the 3-level depth limit
in `agents/_shared/delegation-contract.md`. This skill is for the main-session orchestrator.

If you reach Step 3 already inside a subagent, surface that to the user and let the main
session run the cycle. A self-questioning fallback carries your own context with you, so it
is not fresh-context review — flag any such result as degraded.

## Why This Exists

In this collection's own audit session, an agent reported two confident findings: that
`AGENT_REGISTRY.md` omitted 57 agents, and that four agents held dead cross-references.
Both were wrong. The first came from a grep that only matched names at the start of a table
row, silently skipping every name in a comma-separated cell. The second resolved names
against one directory when agents live in five, and counted `redis-expert` as dead when it
was the registry's own worked example of a dead reference.

Both were negative claims. Both would have died in Step 3 against the two questions above —
before they reached the user as fact, and before either turned into an edit.

---

*Cycle structure adapted from the `doubt-driven-development` skill in
[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT); adversary
routing and the negative-claim rule are specific to this collection.*
