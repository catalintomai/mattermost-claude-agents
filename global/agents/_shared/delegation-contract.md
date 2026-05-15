---
name: delegation-contract
description: Rules for when and how to hand work off to sub-agents via the Agent() tool. Every delegation must satisfy this contract.
type: shared
---

# Delegation Contract

Every `Agent()` call is a contract. Define success before delegating, not after.

## When to delegate
- Task has 3+ independent sub-tasks that can run in parallel.
- Loading the context needed would pollute the parent context window (>10k tokens of ancillary research).
- Task needs a specialist's judgment the parent lacks (e.g., security auditor reviewing auth code).

## When NOT to delegate
- Single decision or short tool call sequence — just do it.
- Sub-agent context overlaps heavily with parent's — cheaper to do inline.
- Sub-agent would need to write to memory the parent is actively editing.
- The real goal is to delegate *thinking* — synthesis belongs in the parent, not the sub-agent.

## The handoff contract

Every `Agent()` prompt must include these four elements, even briefly:

1. **Goal** — what success looks like, in one sentence.
2. **Constraints** — what the sub-agent must not do (inherits parent permissions by default).
3. **Return format** — structured output the parent can consume without re-reading.
4. **Budget** — cap on scope (e.g., "report in under 200 words", "check only these 3 files").

Missing any element forces the parent to guess — which defeats parallelism.

## Depth limit
Hard cap: **3 levels** of recursive delegation. Parent → Child → Grandchild. No deeper.
Deeper nesting hides failures and makes cost unpredictable.

## Memory isolation
- Sub-agents read shared knowledge (agents/_shared/, docs/).
- Sub-agents do not write to files the parent is actively editing.
- On return, the parent decides which sub-agent findings to act on — never auto-apply.

## Anti-patterns
- "Delegate and hope" — fan out 5 sub-agents without specifying return format, then reconcile chaos.
- Using a sub-agent to avoid thinking — if you can't write the Goal in one sentence, you haven't thought it through.
- Delegating for context economy, then re-reading everything the sub-agent found anyway.
- Recursive delegation past depth 3 — if you need it, simplify the task decomposition.
