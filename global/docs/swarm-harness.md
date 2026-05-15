# Swarm Harness — Shared Collaboration Protocol

Reference for `--swarm` mode across all skills. Defines how agents **collaborate**, not just how they're spawned.

**Skills using this**: `/create-plan`, `/create-code`, `/review-code`, `/review-plan`, `/fix-test`, `/create-test`

## Prerequisites

Swarm mode requires the experimental agent teams env var:

```
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

**Runtime guard (MUST implement in every skill's swarm section):**

```
1. Check: is CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 set?
   - Use Bash: echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
2. If NOT set:
   a. Print: "⚠ Swarm mode requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
   b. If skill has --sequential mode: auto-fallback and print:
      "Falling back to --sequential mode (no team infra needed)"
   c. If skill has NO --sequential mode: fall back to plain parallel subagents and print:
      "Falling back to parallel subagents (no team coordination)"
   d. NEVER fail silently — always inform the user what happened
3. If set: proceed with TeamCreate as normal
```

Skills with `--sequential` fallback: `/review-code`, `/review-plan`, `/create-plan`, `/create-code`, `/create-test`, `/fix-test`

## Why Swarm vs Plain Subagents

Plain subagents run independently and report back to the leader. A swarm adds value ONLY when agents build on each other's work. If agents don't interact, don't use swarm mode — just launch parallel subagents.

**Swarm is worth it when:**
- Findings from one agent inform another agent's scope
- Cross-validation reduces false positives
- A convergence loop iterates until quality threshold is met
- Synthesis requires weighing conflicting agent opinions

**Swarm is NOT worth it when:**
- All agents are independent reviewers with no interaction
- The task is simple enough for one agent
- The overhead of shared artifacts + phases exceeds the benefit

### Mechanism Comparison

Skills reference these modes in their Mode Behavior tables:

| | Default (no flags) | `--swarm` | `--sequential` |
|---|---|---|---|
| **Orchestration** | Fire-and-forget subagents | `TeamCreate` + shared findings dir | Serial subagents |
| **Communication** | None between agents | Files (findings dir) only — no SendMessage. Leader polls output files. | None between agents |
| **Shared state** | None — each agent returns result to leader | `/tmp/swarm-{team}/` findings dir | None |
| **Cross-Validation** | Skipped | Full (agents see each other's work) | Skipped |
| **Convergence** | Single pass | Loop until green or max rounds | Single pass |
| **Env var required** | No | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | No |

## Role Clarity

| Role | Responsibilities | Constraints |
|------|-----------------|-------------|
| **Leader** | Creates team/tasks/findings dir; assigns tasks; spawns synthesis agent; makes final decisions on conflicts; handles user communication; sends shutdown; cleans up (TeamDelete, rm dir) | Owns ALL git ops (stash, commit, branch) — teammates NEVER touch git |
| **Teammates** | Work on assigned tasks; write findings to designated file in shared dir | `run_in_background: true`, no SendMessage; never self-assign beyond scope; never read/write outside assigned scope |
| **Validators** | Read ALL Independent Work findings (cross-cutting); verify against actual code; write validation results | Do not fix issues — only confirm, dispute, or flag missed; never trust findings at face value |

## Git Ops Ownership

**Only the leader touches git.** This is non-negotiable.

| Operation | Who | When |
|-----------|-----|------|
| `git stash push` | Leader only | Before applying fixes each convergence round |
| `git stash pop` | Leader only | On regression (revert to previous round) |
| `git diff` / `git status` | Leader only | Pre-flight checks, post-fix verification |
| File edits (Write/Edit) | Fixer agent | Only when assigned by leader, one fixer at a time |
| `git add` / `git commit` | Nobody | User commits manually (per project CLAUDE.md) |

**Why:** Multiple agents touching git creates race conditions, conflicting stash stacks, and unrecoverable state. One agent owns the state machine.

## Conflict Resolution

### Edit conflicts (two agents want to edit the same file)
- **Sequential fixer rule** (already in Swarm Limits): only one fixer agent at a time
- Leader queues fix tasks and assigns them serially, never in parallel
- If two findings affect the same function, leader merges them into one fix task

### Finding conflicts (agents disagree)
Priority order:
1. Domain specialist > generalist (store-reviewer on DB issue beats general-purpose)
2. Finding with code evidence > finding without
3. Higher severity wins when evidence is equal
4. If still tied: escalate to user in synthesis report

### Scope conflicts (agent works outside its area)
- Findings outside an agent's assigned focus are **discarded** in synthesis
- Leader logs the out-of-scope finding for awareness but does not promote it

## Finding Fidelity Principle

**The #1 cause of quality loss in swarm mode is detail compression.** When findings get summarized (whether via SendMessage, Task return values, or leader context overflow), specific details (file:line references, code snippets, edge cases, exact values) get dropped. The solution: all findings live in files, and only a dedicated synthesis agent reads them.

**Rule: Findings live in files. The leader reads only the summary.**

- Agents MUST write complete, uncompressed findings to their designated file in the shared directory
- All agents run with `run_in_background: true` — no SendMessage, no Task return values in leader context
- Cross-validation agents read other agents' phase1 files directly
- The synthesis agent reads ALL phase1 + phase2 files and produces a summary
- The leader reads ONLY the synthesis summary file (~20 lines) — never the raw findings

**Why this matters**: With 10+ agents, raw findings can exceed 20K+ tokens. If the leader reads them all, it runs out of context before synthesis. By delegating synthesis to a fresh agent and reading only the summary, the leader stays lean regardless of swarm size.

## Handoff Protocol

With `run_in_background: true`, agents don't use SendMessage. Each agent writes COMPLETE findings (no compression — every file:line, code snippet, edge case) to its designated file, then exits. The leader polls for output files via `Glob(f"{WORKDIR}/phase1/*.md")` and proceeds when count matches expected agents. Use `TaskOutput(block=false)` to check individual agent status. Critical findings are flagged under MUST_FIX with CRITICAL severity — the synthesis agent surfaces them.

## Shared Findings Protocol

The core collaboration mechanism: agents write structured findings to a shared directory that other agents can read.

### Directory Structure
```
/tmp/swarm-{team-name}/
├── phase1/                    # Independent Work (agents + multi-LLM)
│   ├── {agent-name}.md        # Each agent's findings
│   ├── multi-llm.md           # Multi-LLM review output
│   └── ...
├── phase2/                    # Cross-Validation
│   ├── {agent-name}.md        # Cross-Validation results (reuse or fresh)
│   └── ...
├── synthesis.md               # Final merged report
└── round-{N}/                 # Convergence loop rounds
    ├── synthesis-summary.md
    ├── synthesis.md
    └── convergence-audit.md   # (round > 0 only)
```

### Persistent Archive (`PERSIST_DIR`)
`/tmp/swarm-{team}/` is volatile — wiped on reboot, lost after `/clear`,
deleted by `TeamDelete()` at end of run. To survive that, the leader
sets `PERSIST_DIR` to a project-local path before invoking the harness,
and the harness mirrors each round's synthesis files into it.

Convention:
- `/review-plan <plan>` → `PERSIST_DIR = "{repo}/plans/.review-history/{plan-basename-no-ext}"`
- `/review-code` → `PERSIST_DIR = "{repo}/plans/.review-history/code-{branch-name}"`

Only `synthesis.md`, `synthesis-summary.md`, and `convergence-audit.md`
are mirrored — not phase1/phase2 (those would bloat the repo). After
`/clear`, recover by reading `{PERSIST_DIR}/round-{N}/synthesis-summary.md`.

### Finding Format (phase1/*.md)
Each agent MUST write findings in this format so other agents can parse them:
```markdown
# Findings: {agent-name}

## MUST_FIX
- **{id}**: {description} | `{file}:{line}` | {evidence}

## SHOULD_FIX
- **{id}**: {description} | `{file}:{line}` | {evidence}

## PASS
- {check description}
```

## Execution Phases

### Independent Work (parallel)

**Multi-LLM is a parallel work stream (Task calls), NOT a team subagent.** The leader spawns it as a `Task(subagent_type="general-purpose")` — same as domain agents. It has no special status: it writes to `phase1/multi-llm.md` just like agents write to `phase1/{name}.md`. Both streams are first-class Independent Work participants.

**Two streams run in parallel, independently:**

1. **Domain agents** — specialized agents run in parallel, each writes to `/tmp/swarm-{team}/phase1/{name}.md`
2. **Multi-LLM** — a `Task(subagent_type="general-purpose")` that runs `/multi-review` (or equivalent multi-LLM calls), writes output to `/tmp/swarm-{team}/phase1/multi-llm.md`

**Leader instructions to agents:**
```
Write your findings to /tmp/swarm-{team}/phase1/{your-name}.md
using the standard finding format (MUST_FIX / SHOULD_FIX / PASS sections).
```

**Key rule:** Agents in Independent Work do NOT read other agents' findings or multi-LLM output. They work independently to avoid anchoring bias. Multi-LLM reviewers similarly work without seeing agent findings.

### Cross-Validation (parallel, after Independent Work)

After ALL Independent Work completes (both agents AND multi-LLM), the leader decides whether cross-validation is warranted.

#### Fast Path (skip Cross-Validation)

**Before spawning cross-validators, the leader scans Phase 1 findings files for severity signals.** This is a lightweight check — scan for `## MUST_FIX` headers and count `SHOULD_FIX` entries, do NOT read full evidence.

```python
# Leader scans phase1 files (Grep, not Read — stays lean)
must_fix_count = count_matches(f"{WORKDIR}/phase1/*.md", pattern="^- \\*\\*.*MUST_FIX")
should_fix_count = count_matches(f"{WORKDIR}/phase1/*.md", pattern="^- \\*\\*.*SHOULD_FIX")

if must_fix_count == 0 and should_fix_count <= 2:
    # Fast path: skip Cross-Validation, lightweight synthesis only
    skip_cross_validation = True
```

**When fast path triggers:**
- Skip Phase 2 entirely (no cross-validators spawned)
- Spawn a single **haiku** synthesis agent that reads Phase 1 files and produces the summary
- Haiku synthesizer confirms SHOULD_FIX items (if any) but does NOT deep-verify — no MUST_FIX to verify
- Verdict is READY unless a SHOULD_FIX is suspicious enough to escalate

**When fast path does NOT trigger:**
- Any MUST_FIX found → full Cross-Validation (always verify blockers)
- 3+ SHOULD_FIX → full Cross-Validation (volume suggests deeper issues)

**Override:** `--thorough` or `--full` flags bypass fast path and always run Cross-Validation.

#### Full Cross-Validation

**Select 3-5 Phase 1 agent types** that cover the major domains present in the changes. Do NOT spawn one cross-validator per Phase 1 agent — that's wasteful. Instead, pick agent types that together cover the key concern areas (e.g., backend, frontend, security, testing). Each cross-validator reads ALL phase1 files, not just their domain's.

Do NOT reuse Independent Work agents via SendMessage — SendMessage adds coordination overhead to the leader's context. Fresh agents with `run_in_background: true` keep the leader lean.

**Agent selection algorithm:**
1. Group Phase 1 agents by domain (backend, frontend, security, testing, compatibility, etc.)
2. Pick one agent type per domain that had the most findings, up to 5 total
3. If fewer than 3 domains, add the most general-purpose types to reach 3

**Leader spawns cross-validation agents:**
```python
# Select 3-5 agent types covering major domains (NOT all Phase 1 agents)
xval_agents = select_domain_covering_agents(agents, min=3, max=5)

for agent in xval_agents:
    Task(
        subagent_type=agent.type,
        name=f"{agent.name}-xval",
        team_name=TEAM,
        prompt=f"""CROSS-VALIDATION for {agent.focus_area}.

Read ALL files in {WORKDIR}/phase1/ to see what every reviewer found.
Then re-examine your domain area against the actual codebase.

CRITICAL — VERIFY EVIDENCE AGAINST SOURCE CODE:
For every MUST_FIX finding in your domain, you MUST:
1. Read the ACTUAL source file at the cited line range using the Read tool
2. Compare the quoted evidence against the real code
3. If the evidence is wrong (missing guards, wrong line numbers, omitted context),
   DISPUTE the finding with counter-evidence from your Read output
Do NOT confirm a finding based solely on the quoted evidence — the quote may be
reconstructed from memory and missing critical details (nil guards, feature flags, etc.).

- Confirm or dispute findings that touch your area (with verified evidence)
- Go deeper on issues others flagged in your domain
- Flag anything everyone missed
- Check if findings from different agents CONTRADICT each other in your domain

Write results to {WORKDIR}/phase2/{agent.name}.md
using Confirmed / Disputed / Deeper / Missed format.
For Deeper and Missed sections, use canonical finding format (agent:TAG, file:line, Evidence, Severity, Fix).
""",
        run_in_background=True
    )
```

### Cross-Validation Output Format (phase2/*.md)

Uses the same canonical severity/tag/evidence structure as Phase 1, grouped by cross-validation action.

```markdown
# Cross-Validation: {agent-name}

## Confirmed
- **{finding-id}** from {source}: {why it's valid}

## Disputed
- **{finding-id}** from {source}: {why it's wrong}
  **Counter-evidence**:
  ```
  [actual code or data contradicting the finding]
  ```

## Deeper (went deeper based on cross-validated context)

New findings use canonical format (same as Phase 1):

1. **[agent:TAG]** `file.go:42` — [one-line description] | triggered by {source}'s finding
   **Evidence**:
   ```go
   [actual code from Read output]
   ```
   **Severity**: MUST_FIX | SHOULD_FIX
   **Fix**: [concrete fix]

## Missed (new findings from cross-checking)

New findings use canonical format (same as Phase 1):

1. **[agent:TAG]** `file.go:78` — [one-line description]
   **Evidence**:
   ```go
   [actual code from Read output]
   ```
   **Severity**: MUST_FIX | SHOULD_FIX
   **Fix**: [concrete fix]
```

Note: `{source}` can be an agent name OR "multi-llm" — both are first-class Independent Work participants. `Deeper` and `Missed` findings use canonical format so the synthesizer can parse them identically to Phase 1 findings.

### Synthesis (single agent, after Cross-Validation)

One synthesis agent reads phase1 + phase2 and produces the final report.

**IMPORTANT — File-Based Synthesis**: The synthesizer (whether leader or a fresh agent) MUST read findings from `phase1/*.md` and `phase2/*.md` files using the Read tool. It MUST NOT rely on SendMessage content or conversation context for findings. This is where the Finding Fidelity Principle pays off — uncompressed files preserve the detail that makes synthesis thorough.

**Fresh-agent synthesis** (MANDATORY): Always spawn a fresh `general-purpose` agent for synthesis. The leader's context is consumed by coordination overhead — a fresh agent with clean context produces more thorough output. The synthesizer also writes a short summary file (~20 lines) so the leader only needs to read that, not the full report.

**Synthesis agent produces TWO files:**
1. `{WORKDIR}/synthesis.md` — full report with all findings, evidence, and citations
2. `{WORKDIR}/synthesis-summary.md` — verdict + MUST_FIX and SHOULD_FIX counts + 1-line per item (max 30 lines)

**Leader reads ONLY the summary.** The full report is for the user to review directly.

**Consensus rule:** MUST_FIX requires either:
- 2+ independent Independent Work sources finding the same issue (agent + agent, agent + multi-LLM, etc.), OR
- 1 source finding + 1 Cross-Validation agent confirming

Single-source findings with no Cross-Validation confirmation = SHOULD_FIX at most.

### Convergence Loop (if skill supports it)

After fixes, re-run Independent Work → Cross-Validation → Synthesis. See convergence pattern below.

## Cross-Validation by Skill Type

Each skill uses the Independent Work → Cross-Validation → Synthesis pattern differently. This table shows the universal mapping:

| Skill Type | Independent Work | Cross-Validation |
|------------|------------------|------------------|
| **Review** (`/review-plan`, `/review-code`) | Agents + multi-LLM review independently | Fresh agents validate/dispute/go deeper in own domain |
| **Create** (`/create-plan`) | Research + domain agent consultation + multi-LLM | Fresh advisors see each other's findings + LLM opinions → refine, flag conflicts |
| **Implement** (`/create-code`) | Sequential dependency chain (T1→T2→...→T5) with interface files after each layer | Cross-layer validation (pattern-reviewer, client-server-alignment-reviewer, multi-LLM) after all layers complete |
| **Test** (`/create-test`) | Write tests by layer + multi-LLM reviews coverage | Fresh test writers see each other's coverage + LLM gaps → avoid duplication, add integration |
| **Fix** (`/fix-test`) | Diagnose failures by layer + multi-LLM analyzes patterns | Fresh diagnosticians see other root causes + LLM analysis → identify shared causes |

**Key insight:** Multi-LLM output is always an Independent Work participant alongside domain agents. Cross-Validation agents see BOTH streams — this is what makes it valuable.

## Execution Template

```python
TEAM = f"swarm-{skill}-{short_id}"
WORKDIR = f"/tmp/{TEAM}"

# PERSIST_DIR: project-local archive that survives reboots, /clear, and TeamDelete.
# Skills set this to the target's stable slug (plan basename for /review-plan,
# branch name for /review-code) so a session loss can recover the synthesis.
# When set, each round's synthesis.md / synthesis-summary.md / convergence-audit.md
# are mirrored into {PERSIST_DIR}/round-{N}/ after archival.
# Leave None to disable (preserves prior /tmp-only behavior).
PERSIST_DIR = None  # e.g. f"{repo_root}/plans/.review-history/{target_slug}"

# Setup
TeamCreate(team_name=TEAM)
Bash(f"mkdir -p {WORKDIR}/phase1 {WORKDIR}/phase2")
if PERSIST_DIR:
    Bash(f"mkdir -p {PERSIST_DIR}")

# Inter-round memory: build context from previous round (empty string for round 0)
round_context = ""
if round > 0:
    prev_summary = Read(f"{WORKDIR}/round-{round-1}/synthesis-summary.md")
    round_context = f"""
ROUND {round} CONTEXT — Previous round found these issues (now fixed):
{prev_summary}

Focus on:
1. Whether the fixes introduced NEW issues (regressions)
2. Issues in areas NOT covered by previous findings
3. Do NOT re-report issues that match the above list — they are fixed
4. If a previous fix looks incomplete or introduced a side effect, report that as NEW
"""

# Independent Work (agents + multi-LLM in parallel)
agents = select_agents(changed_files)  # from three-level discovery

# 1a: Domain agents
for agent in agents:
    Task(
        subagent_type=agent.type,
        name=agent.name,
        team_name=TEAM,
        prompt=f"""
{round_context}
{agent.task_prompt}

Write findings to {WORKDIR}/phase1/{agent.name}.md
using MUST_FIX / SHOULD_FIX / PASS format.
""",
        run_in_background=True
    )

# 1b: Multi-LLM review — parallel Independent Work stream (see Independent Work section)
Task(
    subagent_type="general-purpose",
    name="multi-llm-reviewer",
    team_name=TEAM,
    prompt=f"""
{round_context}
Run multi-LLM review (codex, gemini, seq-server) on the changed files.
Write consolidated output to {WORKDIR}/phase1/multi-llm.md
using MUST_FIX / SHOULD_FIX / PASS format.
""",
    run_in_background=True
)

# Wait for ALL Independent Work (agents + multi-LLM) to complete
# Leader checks output files exist (Glob) but does NOT Read them
phase1_files = Glob(f"{WORKDIR}/phase1/*.md")

# Fast-path gate: scan Phase 1 for severity signals before spawning cross-validators
must_fix_count = grep_count(f"{WORKDIR}/phase1/", pattern=r"^\*\*.*\|.*MUST_FIX")
should_fix_count = grep_count(f"{WORKDIR}/phase1/", pattern=r"^\*\*.*\|.*SHOULD_FIX")
skip_cross_validation = (must_fix_count == 0 and should_fix_count <= 2)

if not skip_cross_validation:
    # Full Cross-Validation — see "Full Cross-Validation" section for
    # agent selection algorithm and full prompt template with VERIFY EVIDENCE rules
    xval_agents = select_domain_covering_agents(agents, min=3, max=5)
    for agent in xval_agents:
        Task(
            subagent_type=agent.type,
            name=f"{agent.name}-xval",
            team_name=TEAM,
            prompt=build_xval_prompt(agent, round_context, WORKDIR),  # see Full Cross-Validation section
            run_in_background=True
        )

    # Wait for Cross-Validation to complete
    # Leader checks phase2 files exist but does NOT Read them

# Synthesis: spawn a FRESH agent with clean context
# This is the only agent that reads all findings — leader never does
# Fast path uses haiku for lightweight synthesis; full path uses default model
# Build synthesis round history (all prior summaries for trend tracking)
synthesis_history = ""
if round > 0:
    prior_summaries = []
    for r in range(round):
        s = Read(f"{WORKDIR}/round-{r}/synthesis-summary.md")
        prior_summaries.append(f"### Round {r}\n{s}")
    synthesis_history = f"""
## Prior Round Summaries (for trend tracking)
{chr(10).join(prior_summaries)}

Use these to track MUST_FIX trend across rounds and detect oscillation
(same issue appearing, disappearing, reappearing).
"""

synthesizer_model = "haiku" if skip_cross_validation else None  # haiku for fast path

Task(
    subagent_type="general-purpose",
    name="synthesizer",
    model=synthesizer_model,  # haiku on fast path, default otherwise
    prompt=f"""You are the synthesis agent. Your ONLY job is to read all review
findings, VERIFY the critical ones against actual source code, and produce a final report.
{synthesis_history}
Read ALL files in:
- {WORKDIR}/phase1/*.md (Independent Work findings)
{"- " + WORKDIR + "/phase2/*.md (Cross-Validation results)" if not skip_cross_validation else "# Phase 2 skipped (fast path — no MUST_FIX found)"}

## MANDATORY: Re-Verify Every MUST_FIX Candidate

Before including ANY finding as MUST_FIX, you MUST:
1. Use the Read tool with offset/limit to read ONLY the cited line range (e.g., offset=620 limit=15), NOT the entire file
2. Verify the quoted evidence matches the real code
3. Verify the claimed issue actually exists (e.g., a "missing nil guard" is actually missing)
4. If the evidence doesn't match or the issue doesn't exist, DISMISS the finding

This step catches the #1 source of false positives: agents quoting reconstructed code
that omits guards, checks, or context that invalidates their claim.

For UNVERIFIED findings (from multi-LLM sources without Read access), re-verification
is MANDATORY before promotion to any severity — these findings are hypotheses, not facts.

## Filtering Rules

Apply this filter AFTER re-verification:
- MUST_FIX: 2+ independent sources agree OR 1 source + 1 cross-validator confirms.
  Must meet blocker criteria (blocks implementation, data loss, security, will fail).
  Must survive re-verification against actual source code.
- SHOULD_FIX: Single-source findings not disputed by cross-validation.
  Re-verification recommended but not mandatory.
- DISMISSED: Findings disputed by cross-validation with evidence,
  OR findings that fail re-verification (evidence doesn't match actual code).

For each finding, cite which sources found it and which confirmed it.

Write the final report to {WORKDIR}/synthesis.md

At the END of synthesis.md, include a ## Metadata section:
- Mode: swarm
- Round: N
- Independent Work agents: (count)
- Cross-validation agents: (count)
- MUST_FIX total: N (N from cross-val only, N from 2+ independent sources)
- SHOULD_FIX total: N (N from cross-val only)
- DISMISSED: N (false positives caught by cross-val)

"From cross-val only" means findings that appeared ONLY in phase2 (Deeper/Missed)
and were NOT present in any phase1 file. This measures cross-validation's added value.

Also write a SHORT summary (max 30 lines) to {WORKDIR}/synthesis-summary.md
with the verdict (READY/NEEDS WORK/MAJOR REVISION), MUST_FIX count,
SHOULD_FIX count, a 1-line description of each MUST_FIX and SHOULD_FIX item,
and the cross-val-only counts (e.g. "Cross-validation caught 2 additional MUST_FIX").
""",
    run_in_background=True
)

# Leader reads ONLY the summary file (small) — not the full synthesis
Read(f"{WORKDIR}/synthesis-summary.md")  # ~30 lines max
# Full report available at {WORKDIR}/synthesis.md for user to read

# Convergence Audit (round > 0 only, synchronous — must complete before archival)
# Detects semantic thrashing: findings reversed without new evidence across rounds.
if round > 0:
    prior_paths = " ".join(
        f"{WORKDIR}/round-{r}/synthesis.md" for r in range(round)
    )
    Task(
        subagent_type="convergence-auditor",
        name="convergence-auditor",
        prompt=f"""Audit convergence across {round+1} rounds.
        Prior round synthesis files: {prior_paths}
        Current synthesis: {WORKDIR}/synthesis.md
        Current phase1/phase2 (for evidence on flagged items): {WORKDIR}/phase1/, {WORKDIR}/phase2/
        Prior convergence audits (for self-consistency): {WORKDIR}/round-*/convergence-audit.md
        Write audit to {WORKDIR}/convergence-audit.md""",
        run_in_background=False  # synchronous — must complete before archival
    )
    # Read verdict and act on it before archival
    verdict = Read(f"{WORKDIR}/convergence-audit.md")  # parse ## Verdict section

# Archival: archive current round findings before next iteration.
# Preserves synthesis.md per round (needed by convergence-auditor in future rounds).
Bash(f"mkdir -p {WORKDIR}/round-{round}")
Bash(f"mv {WORKDIR}/synthesis-summary.md {WORKDIR}/round-{round}/")
Bash(f"mv {WORKDIR}/synthesis.md {WORKDIR}/round-{round}/")
if round > 0:
    Bash(f"mv {WORKDIR}/convergence-audit.md {WORKDIR}/round-{round}/")
# Mirror small final artifacts to persistent project-local archive (if enabled).
# Only synthesis files — phase1/phase2 stay in /tmp to avoid bloating the repo.
if PERSIST_DIR:
    Bash(f"mkdir -p {PERSIST_DIR}/round-{round}")
    Bash(f"cp {WORKDIR}/round-{round}/*.md {PERSIST_DIR}/round-{round}/")
# Clean up working directories for next round
Bash(f"rm -rf {WORKDIR}/phase1 {WORKDIR}/phase2")
Bash(f"mkdir -p {WORKDIR}/phase1 {WORKDIR}/phase2")
# Loop back to Independent Work with round_context built from round-{N}/synthesis-summary.md

# Cleanup
shutdown_all_agents()
TeamDelete()
Bash(f"rm -rf {WORKDIR}")
```

## Convergence Pattern

**Canonical convergence logic for all skills.** Skills MUST reference this section instead of defining their own.

### Review vs Fix Skills

**Review skills** (`/review-plan`, `/review-code`): The leader cannot auto-fix — the user must update their plan/code. After presenting findings:
1. Show MUST_FIX and SHOULD_FIX from the synthesis summary
2. If verdict is not READY, ask the user: "N MUST_FIX and M SHOULD_FIX found. Would you like to fix and run another round?"
3. Track round numbers across invocations for convergence comparison

**Fix/create skills** (`/create-code`, `/fix-test`, `/create-test`): Auto-fix loop applies — the skill fixes issues and re-runs automatically until converged or escalated.

### Defaults

| Setting | Solo | Swarm |
|---------|------|-------|
| MAX_ROUNDS | 3 | 10 (safety cap) |

### Revert Strategy

Before applying fixes each round, stash the current state:

```bash
git stash push -m "round-{N}"
```

On regression (issue count > previous round), restore previous state:

```bash
git stash pop
```

### Exit Conditions

| Condition | Trigger | Action |
|-----------|---------|--------|
| **Success** | 0 issues | Stop — converged |
| **Oscillation** | Same issues as 2 rounds ago | Escalate to user |
| **No progress** | Issue count not decreasing for 2 consecutive rounds | Escalate to user |
| **Regression** | Issue count > previous round | `git stash pop`, escalate to user |
| **Thrashing** | convergence-auditor returns THRASHING (2+ unjustified reversals) | Escalate to user (archival runs first) |
| **Safety cap** | MAX_ROUNDS reached | Escalate to user |

All exits except success → escalate to user with round history.

### Inter-Round Memory

In rounds > 0, agents receive the previous round's synthesis summary as context. This prevents re-discovering fixed issues and focuses agents on regression detection. See the Execution Template for the exact `round_context` prompt and `synthesis_history` construction.

**Rules:**
- Round 0: no context (first pass — independent discovery)
- Round 1+: include previous round's synthesis summary
- Only the summary (~30 lines), never the full synthesis — keeps agent context lean
- Cross-validation agents also receive round context (same format)
- The synthesis agent receives ALL prior round summaries (not just N-1) for trend tracking

### Cross-Agent Deduplication

When multiple agents work in parallel (swarm mode), they share findings through the task list to avoid duplicate work:

1. Call TaskList to see all tasks
2. Read completed tasks' descriptions for prior findings (e.g., ROOT CAUSE, TEST COVERAGE entries)
3. If your work matches an existing finding:
   → Update your task: "DUPLICATE OF Task #{X} — same {finding_type}: {description}"
   → Skip work, mark completed

Skills override only the **finding field name** (e.g., "ROOT CAUSE" for `/fix-test`, "TEST COVERAGE" for `/create-test`).

## Sequential Mode

When `--sequential` is used (or env var not set and skill auto-fallbacks), tasks run **serially** in dependency order via `Task()` — no `TeamCreate`/`SendMessage`/`TaskCreate` needed, no env var required. Slower but works without experimental infrastructure. See Mechanism Comparison table for full diff.

```
Parallel (default --swarm):
  t=0   [Pre-work / context build                                      ]
  t=1   [Group A (agents parallel)] [Group B (agents parallel)] [...]
  t=N   [Synthesis + dedup                                             ]

Sequential (--sequential):
  t=0   [Pre-work / context build                 ]
  t=1   [Group A (agents parallel within group)   ]
  t=2   [Group B (agents parallel within group)   ]
  ...
  t=N   [Synthesis + dedup                        ]
```

## Error Handling

| Scenario | Action |
|----------|--------|
| Agent missing (pre-flight) | Skip; log "Missing: {name}"; note in report |
| Agent spawn fails (runtime) | Log "Agent {name} unavailable"; mark incomplete; continue |
| Agent times out / crashes | Skip findings; mark incomplete; continue |
| Agent fails to write findings file | Leader retries once |
| Validator can't parse a finding | Skip that finding (not a blocker) |
| Entire group has no valid agents | Skip group; note in report |
| Conflicting findings | Domain specialist wins over generalist; else higher severity |
| CRITICAL finding mid-swarm | Do NOT stop other agents; flag in synthesis |
| Persistent failure | Leader takes over directly or escalates to user |

Never leave swarm silently stuck — all failure paths surface to user.

## Review Agent Prompt Template

Generic template for review agents (skills customize `{focus}` and `{files}`):

```
You are reviewing code/plan changes.

SHARED CONTEXT (pre-scanned):
{contents of shared context file}

YOUR FOCUS: {agent-specific focus area}

CHANGED FILES IN YOUR SCOPE:
{list of files relevant to this agent}

FINDING FORMAT:
- File: path/to/file.go:line
- Severity: CRITICAL|HIGH|MEDIUM|LOW
- Issue: one-line description
- Evidence: code snippet or explanation
- Fix: suggested resolution

Report "NO ISSUES" if everything looks correct for your focus area.
Do NOT report issues outside your focus area.
```

## Swarm Limits

- **Max concurrent agents**: 5 (prevents resource exhaustion)
- **Max team lifetime**: per convergence pattern safety cap above
- **Sequential fixer rule**: only one fixer agent at a time to avoid edit conflicts
- **Large failure sets (>15 items)**: group aggressively (by file, by error pattern) before spawning agents

## Lifecycle Summary

All agents are fire-and-forget background tasks (`run_in_background: true`). No SendMessage, no idle management. The leader's context holds only: spawn calls + summary file + round context (~30 lines per prior round). See the Execution Template for the full lifecycle code.

## Cost Awareness

Swarm mode is expensive. Rough multipliers:
- Independent Work: N agents + 1 multi-LLM reviewer (3 external API calls)
- Cross-Validation: 3-5 fresh agents (subset of Phase 1 types, covering major domains)
- Synthesis: +1 synthesis agent
- Convergence: multiply above by rounds

**Full path total: ~(2N+2) × rounds + 1 convergence-auditor per round > 0 (haiku).** For review-code with 11 agents and 2 rounds = ~47 agent invocations.

**Fast path total: ~(N+2) × rounds.** When Phase 1 finds no MUST_FIX and ≤2 SHOULD_FIX, Cross-Validation is skipped and synthesis uses haiku. For clean code with 11 agents = ~13 invocations (saves ~70% vs full path).

**Context savings:** All agents run with `run_in_background: true`. The leader's context stays lean — it only reads the synthesis summary (~20 lines), not the full findings from all agents. This prevents the leader from running out of context with large swarms.

Only use swarm when the quality improvement justifies the cost. For quick reviews, plain subagents are fine.
