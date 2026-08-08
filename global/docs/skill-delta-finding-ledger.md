# Skill Delta: Finding Ledger, Fix Verification, Stop Condition

**Status:** PROPOSAL (not implemented)  
**Date:** 2026-07-30  
**Trigger:** Engineer postmortem of multi-round `/review-code` → fix churn: stateless rounds, pattern-matched fixes, same-model tests, Goodhart on MUST_FIX count.

## Why not three skills

The failure is **protocol-level**, not skill-local:

| Failure | Where it lives today |
|---------|----------------------|
| Rounds start from thin/no memory | `swarm-harness.md` Inter-Round Memory (~30-line summary only); non-swarm skills have none |
| Fix applied, next pass treats code as authored | No skill requires replaying the finding's claim after fix |
| Tests encode the same wrong model | Fix + test often same agent/round; mutation only in `test-checkpoints` L4 |
| Success = MUST_FIX count → 0 | Success/exit tables in harness + every create/review skill |

Narrowing to `review-code` / `create-code` / `swarm-harness` would re-encode the same bugs in `create-plan`, `create-test`, `fix-test`, `review-plan`, `test-checkpoints`, and any future skill that loops on findings.

**Rule for this delta:** put the protocol in **shared docs + shared agents**. Skills only declare role (review-only vs auto-fix) and cite the protocol. No per-skill reinvention.

---

## Scope inventory (all user/global Claude skills)

### In scope — multi-round find → (optional fix) → re-check

| Artifact | Role | Disposition of MUST_FIX today | Required change |
|----------|------|-------------------------------|-----------------|
| `~/.claude/docs/swarm-harness.md` | Canonical swarm + convergence | Success = `0 issues` | **Primary:** ledger, fix-verify, new exit conditions, richer round memory |
| `~/.claude/agents/_shared/finding-format.md` | Agent finding schema | claim + Fix text | **Primary:** add Claim / Verify scenario / Disposition fields |
| `~/.claude/docs/review-prompts.md` | Orchestrator synthesis format | count-based READY | **Primary:** ledger table + disposition in synthesis |
| `~/.claude/docs/pattern-completeness-rule.md` | Fixer prompt fragment | horizontal completeness only | **Primary:** add "trace the read/consume site" + "no equivalent rewrite" |
| `~/.claude/agents/review/convergence-reviewer.md` | Round thrashing auditor | OPEN/FIXED/DISMISSED/RE-RAISED (absence = FIXED) | **Primary:** FIXED only after verify pass; FIXED→RE-RAISED if verify fails |
| `skills/review-code` | Review (user or create-code) | "Fix and run another round?" | Cite protocol; ledger in output; no auto-fix (unless called from fix skill) |
| `skills/review-plan` | Plan review | same | Cite protocol; plan-domain verify scenarios |
| `skills/create-code` | Auto-fix code | `MAX_REVIEW_ITERATIONS=2`, auto-apply all MUST_FIX | Ledger + verify before close; allow REJECTED/WONT_FIX; ban silent re-architecture |
| `skills/create-plan` | Auto-fix plan | same pattern via `/review-plan` | Same dispositions; plan text verify (not code paths) |
| `skills/create-test` | Auto-fix tests | same | Verify scenario = test that would fail if claim false; prefer mutation when available |
| `skills/fix-test` | Diagnose + fix loop | MAX_ROUNDS from harness | Ledger per root cause; verify = original failure gone + no new failure |
| `skills/multi-review` | Independent Work component | emits MUST_FIX | Adopt new finding fields when emitting (passthrough format) |
| `skills/test-checkpoints` | Layered gates | done when "zero MUST_FIX" | Success = no *unresolved* MUST_FIX (includes VERIFIED dispositions); keep L4 mutation |
| `skills/security-fix` | TDD fix + lateral sweep | max 2 Phase 3↔4 loops | Ledger of ticket claims + sweep gaps; verify = secure tests still red-for-right-reason then green |

### Out of scope (no multi-round finding loop)

| Artifact | Why skip |
|----------|----------|
| `create-prd` | Interview/doc; no MUST_FIX convergence |
| `triage-issue` | One-shot diagnose → Jira; no fix loop |
| `git-guardrails` | Install hook only |
| `lint` / `handoff` / `ralphoff` (commands) | No review loop |

### Sibling surface (document only; do not implement in this delta)

Grok-side skills (`~/.grok/skills/review`, `check-work`, `execute-plan`, `design`) have analogous review loops. After this Claude delta lands and stabilizes, port the **same shared concepts** (ledger, verify, stop ≠ count) — do not fork a second protocol.

---

## Design: one protocol, three roles

### Roles

| Role | Skills | Allowed actions on a finding |
|------|--------|------------------------------|
| **Reviewer** | `review-code`, `review-plan`, multi-review agents, checkpoint L5 | Emit findings with Claim + Verify; may suggest Fix; **must not** apply Fix |
| **Fixer** | `create-code`, `create-plan`, `create-test`, `fix-test`, `security-fix` Phase 3 | Apply or **REJECT** with reason; must not invent new architecture for equivalent behavior; must attach or update Verify evidence |
| **Auditor** | `convergence-reviewer`, leader gates, checkpoint L4 mutation | Replay Verify scenarios; mark VERIFIED / FAILED_VERIFY / RE-RAISED; thrash detection |

### Finding ledger (shared schema)

Extend finding-format (and synthesis tables) so every MUST_FIX / SHOULD_FIX carries:

```markdown
1. **[agent:TAG]** `file:line` — [one-line description]
   **Diff evidence**: `+ ...`
   **Claim**: [falsifiable observable — what a reader/runtime would see if bug exists]
   **Verify**: [concrete scenario that proves Claim is gone — consumer path, not unit of the fix line]
   **Fix**: [concrete fix OR "REJECTED: <reason>"]
   **Disposition**: OPEN | APPLIED | VERIFIED | FAILED_VERIFY | REJECTED | DEFERRED
   **Design note** *(optional, max 1 line)*: [non-local invariant the fix relies on — e.g. "pre-mount vs post-mount branches mean different things"]
```

**Rules:**

1. **Claim ≠ Fix.** Claim is the bug as observed; Fix is one remediation. Agents must not write Claims that only make sense if a specific API shape is chosen.
2. **Verify is mandatory for MUST_FIX before Disposition can leave OPEN.** If the author cannot state a verify scenario, demote to SHOULD_FIX or REJECT with reason.
3. **Verify must hit the consumer path.** Prefer "call handle from inside error callback", "assert from caller after commit", "delete flag set → this test fails". Forbidden: "line X exists", "useState is present".
4. **Comments are not a disposition.** Adding explanatory comments does not move OPEN → VERIFIED. Prefer zero new comments unless Design note needs a one-line non-local invariant in code (ordering, pre/post mount). Restatements of the code = reject in fix review.
5. **Equivalent rewrite is thrash.** If round N+1 changes a working solution to a different-but-equivalent shape without FAILED_VERIFY on the prior fix, mark as thrash / reject the rewrite (feeds convergence-reviewer).

### Disposition state machine

```
OPEN
  ├─(fixer applies)→ APPLIED
  │                    ├─(verify pass)→ VERIFIED
  │                    └─(verify fail)→ FAILED_VERIFY → OPEN (or RE-RAISED)
  ├─(fixer or human rejects)→ REJECTED  (counts as resolved for stop condition)
  └─(explicit defer)→ DEFERRED        (counts as unresolved; report, don't auto-loop forever)
```

**CRITICAL change vs today:** absence of a finding in the next review round is **not** proof of FIXED. Only **VERIFIED** (or explicit **REJECTED**) resolves a ledger row. This fixes the core postmortem: "next round reads the result as ordinary authored code."

`convergence-reviewer` today: "FIXED — finding was addressed (absent from current round after being OPEN)". **Replace that rule.**

### Inter-round memory (replace thin summary)

Today (`swarm-harness.md` ~367–380): previous `synthesis-summary.md` only (~30 lines), focused on "don't re-report fixed issues."

**Replace with ledger file** (always, swarm and non-swarm multi-round):

```
{WORKDIR|PERSIST_DIR}/finding-ledger.md
```

Contents: full table of all findings across rounds with Claim, Verify, Disposition, Design note, last-touch round.

Round N>0 agent `round_context` becomes:

```
ROUND N — Finding ledger (authoritative):
{finding-ledger.md}

Instructions:
1. First pass: re-run Verify for every APPLIED row. Mark VERIFIED or FAILED_VERIFY.
2. Do NOT re-derive design for VERIFIED rows. Equivalent rewrites are thrash.
3. New findings only outside ledger Claims, or FAILED_VERIFY escalations.
4. If a prior Design note exists, treat it as ground truth unless you have evidence it is wrong.
```

Persist ledger under `PERSIST_DIR` alongside synthesis so `/clear` does not wipe provenance.

### Stop condition (Goodhart fix)

**Old (harness Exit Conditions):**

| Success | 0 issues |

**New:**

| Condition | Trigger | Action |
|-----------|---------|--------|
| **Success** | No OPEN / APPLIED / FAILED_VERIFY / DEFERRED MUST_FIX; all MUST_FIX are VERIFIED or REJECTED | Stop |
| **Success (review-only)** | Ledger presented; user declined further rounds | Stop (user owns remaining OPEN) |
| **Partial** | DEFERRED remain, rest VERIFIED/REJECTED | Report DEFERRED; stop auto-loop |
| **Oscillation / thrash / regression / safety cap** | (unchanged triggers, but measured on ledger states, not raw counts) | Escalate with ledger history |
| **Metric ban** | Do not optimize for "MUST_FIX count = 0" by auto-applying every suggestion | REJECTED is a valid path; arguing beats applying a wrong fix |

Tips/anti-patterns in every skill that currently say "fix MUST_FIX immediately" / "ideally zero MUST_FIX" must be rewritten to: **resolve** (VERIFIED or REJECTED), do not merely clear the count.

### Fix-quality pass (auto-fix skills only)

After applying fixes, **before** declaring round complete:

1. Leader (or dedicated small verifier agent) walks ledger rows with Disposition=APPLIED.
2. For each: execute or reason through **Verify** at the consumer path. Prefer running a test written *from Claim* (not from the fix implementation).
3. Optional cheap mutation: for new flags/latches/guards, delete the set/clear line and confirm at least one Verify-linked test fails. If none fail → FAILED_VERIFY (tests are co-broken).
4. Same agent that wrote the production fix **must not** be the sole author of the only Verify test for that Claim when the fix introduces new control flow (state, refs, latches, pre/post branches). Either: separate test agent, or require mutation kill, or leader-authored scenario.

### Comment bloat control

In pattern-completeness / fix prompts:

> Do not add comments that restate the Claim or the Fix. Allowed comments: non-local invariants the next reader cannot recover (ordering constraints, pre-mount vs post-mount meaning, commit-time capture). Prefer Design note on the ledger over permanent code comments when the invariant is process-only.

---

## Per-artifact edit plan (implementation order)

### Phase A — Shared protocol (do first; unblocks all skills)

1. **`finding-format.md`**  
   Add Claim, Verify, Disposition, optional Design note. Define state machine. State: MUST_FIX without Claim+Verify is invalid (drop or demote).

2. **`swarm-harness.md`**  
   - Directory: `finding-ledger.md` + persist mirror  
   - Replace Inter-Round Memory with ledger injection  
   - Replace Exit Conditions Success row  
   - Add Fix-quality pass section under Fix/create skills  
   - Note: non-swarm multi-round skills MUST use the same ledger file convention under `PERSIST_DIR` or workspace `plans/.review-history/`

3. **`review-prompts.md`**  
   Synthesis template includes ledger table + disposition counts (OPEN/APPLIED/VERIFIED/REJECTED/DEFERRED), not only MUST_FIX/SHOULD_FIX integers. READY definition = no unresolved MUST_FIX (OPEN/APPLIED/FAILED_VERIFY).

4. **`pattern-completeness-rule.md`**  
   Add: trace consumer read site; no equivalent rewrite of VERIFIED design; comments not a fix.

5. **`convergence-reviewer.md`**  
   FIXED only if ledger says VERIFIED (or REJECTED). Absence alone ≠ FIXED. FAILED_VERIFY → RE-RAISED. Equivalent rewrite without FAILED_VERIFY → unjustified reversal / thrash signal.

### Phase B — Skills that only review (thin cite + output)

6. **`review-code/SKILL.md`**  
   - Step 11 present ledger, not bare counts  
   - "Fix and run another round?" → "Resolve OPEN (fix→verify or REJECT) and re-run?"  
   - Tips: delete "Fix MUST FIX immediately"; add "REJECT with reason is valid"  
   - Convergence line already cites harness — ensure it cites new exit conditions  
   - Runtime-claim gate (9.5) stays; Claim/Verify make it structural

7. **`review-plan/SKILL.md`**  
   Same presentation + READY definition. Verify scenarios are plan-text checks ("section X no longer claims Y without anchor"), not runtime.

8. **`multi-review/SKILL.md`**  
   Output format MUST_FIX entries include Claim + Verify (Disposition always OPEN at emit time).

### Phase C — Auto-fix skills (ledger + verify before close)

9. **`create-code/SKILL.md`**  
   Replace Auto-Review loop:
   ```
   1. Review → write/update finding-ledger.md
   2. For each OPEN MUST_FIX: APPLY or REJECT (reason)
   3. Fix-quality pass → VERIFIED / FAILED_VERIFY
   4. Re-review only if FAILED_VERIFY or new scope; do not re-open VERIFIED design
   5. MAX_REVIEW_ITERATIONS = 2 still, but counted as verify-fail loops, not "count still non-zero"
   ```
   Output: disposition table, not only "MUST_FIX resolved" list.

10. **`create-plan/SKILL.md`**  
    Same loop structure for plan text; no code mutation step.

11. **`create-test/SKILL.md`**  
    MUST_FIX for missing coverage: Verify = test exists and would fail if production claim false. Prefer linking to mutation when skill already has access.

12. **`fix-test/SKILL.md`**  
    Ledger keyed by root cause; Verify = original failure cleared + no regression; cite harness stop condition.

13. **`security-fix/SKILL.md`**  
    Ledger rows for ticket acceptance claims + Phase 4 sweep gaps. Phase 3 cannot close a row without Phase 2 test green *and* verify that the test still encodes the secure behavior (not a weakened assertion).

14. **`test-checkpoints/SKILL.md`**  
    Success criteria: "layers 3–5 report zero *unresolved* MUST_FIX (OPEN/APPLIED/FAILED_VERIFY)" not "zero MUST_FIX". Layer 5 uses review-code ledger. Layer 4 remains the cheap mutation backstop for co-broken tests.

### Phase D — Hygiene

15. Grep all `~/.claude/skills/**/SKILL.md` and `~/.claude/docs/**` for:
    - `0 MUST FIX` / `zero MUST_FIX` / `0 issues` as success  
    - `Fix MUST FIX immediately`  
    - `absence` ⇒ fixed  
    Rewrite to ledger language.

16. Self-rewrite hooks on affected skills: if a run closes findings without Verify, that is a skill defect — log and tighten.

---

## Explicit non-goals

- No new agent type required if leader can run verify; optional small `fix-verifier` later if leaders skip the pass.
- No change to agent registry routing / tier selection.
- No requirement that every SHOULD_FIX has Verify (SHOULD_FIX may stay advisory).
- No automatic GitHub comments from ledger (review-code `--comment` stays opt-in).
- No Grok skill edits in this delta (port later).

---

## Success criteria for the delta itself

After implementation, a multi-round run must:

1. Produce a durable `finding-ledger.md` under persist dir.
2. Refuse READY while any MUST_FIX is OPEN/APPLIED/FAILED_VERIFY.
3. Accept REJECTED with one-line reason as resolved.
4. Not rewrite a VERIFIED design to an equivalent alternative without FAILED_VERIFY.
5. Prefer Verify tests that fail under a one-line mutant of the fix (flag/latch/guard).
6. Not treat comment addition as resolution.

---

## Implementation note (when approved)

Implement Phase A fully first and land as one commit family:

`skill-update: finding-ledger protocol (shared docs + convergence-reviewer)`

Then Phase B/C skill cites in a second commit family so skills that only reference the harness pick up behavior without large prompt rewrites.

Do not implement until this proposal is approved — user asked for the delta proposal, not the patch.
