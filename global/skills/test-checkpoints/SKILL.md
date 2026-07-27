---
name: test-checkpoints
description: Layered test-quality checkpoint pipeline for MM changes — compile/lint → focused unit tests → coverage on changed code → mutation audit → reviewer swarm → focused E2E. Runs cheap layers first, fail-fast, using existing MM test harness and agents only. Never modifies product code to satisfy a checkpoint.
version: 1.0.0
tags:
  - testing
  - quality
user_invocable: true
---

# Test Checkpoints

Run a change through layered quality checkpoints, cheapest first. Each layer must pass before the next runs; on failure, fix and re-enter at the failing layer. The pipeline composes EXISTING agents and the EXISTING MM test harness — it introduces no CI changes and never edits master/product code merely to make a checkpoint pass (if a checkpoint exposes a product bug, report it; fixing it is a separate, user-approved change).

## Scope first

Establish the diff before any layer: `git diff master --name-only` (or staged changes). Every layer operates on changed packages/files only — never the whole repo.

## Layers

| # | Checkpoint | How (MM harness) | Delegate to |
|---|-----------|------------------|-------------|
| 1 | Compile + lint | Go: build the changed packages; golangci config lives at `server/.golangci.yml`. Webapp: type-check and lint via the webapp's own npm scripts | inline |
| 2 | Unit tests, changed packages | Go: `go test` per changed package from `server/` (docker-dependent store/api4 tests need the test DB up). Jest: run only the suites related to changed files, never the full webapp suite | `go-test-writer` / `ts-test-writer` to fix failures |
| 3 | Coverage on changed code | Generate a coverage profile with the harness's own coverage wiring (see `server/Makefile`); inspect only changed files' functions. Missing tests for new logic = fail | `test-coverage-reviewer` |
| 4 | Mutation audit | Static mutant audit of changed lines; TOOL mode (gremlins) only for non-DB Go packages when installed | `mutation-test-reviewer` |
| 5 | Reviewer swarm | `/review-code` on the diff | per its routing |
| 6 | Focused E2E | Only when the change alters user-visible behavior; run ONE targeted spec (`--grep`), never the full suite | `playwright-test-writer` / `playwright-debugger` |

Layers 1–2 are hard gates: red means stop. Layers 3–4 gate on MUST_FIX findings only — SHOULD_FIX accumulates into the final report. Layer 6 runs only when warranted; skipping it is a recorded decision, not an omission.

## Success criteria

The pipeline is done when: layers 1–2 green, layers 3–5 report zero MUST_FIX, layer 6 run-or-waived with reason, and the final report lists every SHOULD_FIX with file:line. That report is the deliverable.

## Anti-patterns

- Running expensive layers while cheap ones are red — burning an E2E run to discover a compile error.
- Weakening a test, adding `t.Skip`, or editing product code so a checkpoint passes — the checkpoint found something; report it.
- Running mutation TOOL mode against docker-dependent packages (store/sqlstore, api4) — each mutant re-runs DB tests; hours wasted. Static mode covers those.
- Treating layer 3's "coverage exists" as sufficient — a covered line with no killing assertion still fails layer 4.
- Full-repo scope on any layer: full test suite, full E2E sweep, repo-wide mutation. Diff scope only.

## Self-rewrite hook

After every 5 uses OR on any failure:
1. Re-read recent feedback or episodic notes about this skill.
2. If a new failure mode has appeared, add it to Anti-patterns.
3. If a constraint was violated, tighten the constraint language.
4. Commit: `skill-update: test-checkpoints, <one-line reason>`.
