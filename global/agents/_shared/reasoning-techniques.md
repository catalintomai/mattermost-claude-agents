---
name: reasoning-techniques
description: Shared reasoning verification techniques for assertion auditing agents
---

# Shared Reasoning Verification Techniques

These techniques apply to conclusions built on facts: pros, cons, justifications, rejections, comparisons, trade-off analyses, "because X, we chose Y" statements.

## 1. Counterfactual Construction

For every claimed benefit or justification, **construct what the alternative would actually look like**, then compare.

1. Identify the claim: "Our approach gives us X"
2. Find the specific alternative that was rejected or not considered
3. Trace through the codebase: how would X work under the alternative?
4. Compare: is X actually better/worse/same under our approach vs. the alternative?

## 2. Mechanism Attribution

When a document claims "our approach enables X", check whether X is actually enabled by the approach or by something else entirely.

1. Identify the claim: "Approach A enables feature X"
2. Find the code that implements feature X
3. Trace what X actually depends on
4. Check: does X depend on approach A, or on some other mechanism that exists regardless?

## 3. Cost Shift Detection

When a claim says "avoids cost X", check if the cost is truly avoided or merely shifted elsewhere.

1. Identify: "Our approach avoids X" or "pro: no X needed"
2. Verify X is a real cost (not imaginary)
3. Check: does the chosen approach introduce a different cost Y that replaces X?
4. Compare: is Y actually less than X, or just less visible?

## 4. Uniqueness Testing

For each claimed benefit, check: would the alternative also have this benefit?

1. List each stated pro/benefit
2. For each one, ask: "If we had chosen the alternative, would this benefit still exist?"
3. If yes — it's not a differentiating pro. It's a property of the problem space, not the solution.

## 5. Implication Chain Tracing

For any claim of the form "X, therefore Y", verify each link in the chain.

1. Decompose: "X is true" -> "therefore Y" -> "therefore Z (our conclusion)"
2. Verify X factually
3. Even if X is confirmed, check: does X actually imply Y? Or does X imply something else?
4. Even if Y follows from X, check: does Y actually imply Z?

## 6. Symmetry Check

When an alternative is rejected for reason R, check if reason R applies equally to the chosen approach.

1. For each rejected alternative, extract the rejection reason R
2. Apply R to the chosen approach
3. If R also applies — the rejection is dishonest (cherry-picking)

## 7. Cross-Reference Consistency

When a document lists fields, keys, columns, or properties for related structures, check that the lists are complete and don't create false implications of exclusivity through asymmetric enumeration.

1. Identify every enumeration in the document (schema diagrams, listings, column lists, API parameter lists)
2. For each field/key that appears in any enumeration, grep the codebase to find ALL structures it appears in
3. Check: if a field appears in structure A's listing but not structure B's listing, does it actually exist in both?
4. If yes — the asymmetric enumeration creates a false implication that the field is exclusive to structure A

## 8. Omission Detection

Check for things the document should discuss but doesn't — unstated costs, unacknowledged trade-offs, missing alternatives.

1. For each decision, ask: "What are the obvious costs of this choice?"
2. Check if those costs are acknowledged anywhere in the document
3. If not — the document is misleading by omission

What to look for:
- A new table is introduced but JOIN costs are never mentioned
- Transactions are needed but transaction failure/rollback isn't discussed
- Two rows must be kept in sync but consistency guarantees aren't addressed
- An existing mechanism already handles the use case but isn't acknowledged as an alternative
- Commands are run in isolated environments (worktrees, containers, CI) but runtime prerequisites (node_modules, credentials, PATH tools, config files) are never provisioned
- A cross-language adaptation says "same as X for language Y" but never specifies how Y's toolchain differs (e.g., Go vs TypeScript compiler error formats, module resolution strategies)
