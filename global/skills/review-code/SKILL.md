---
name: review-code
description: Comprehensive code review via specialized agents + multi-LLM review with cross-validation. Works on local changes or GitHub PRs.
version: 2.0.0
tags:
  - code-review
  - quality
  - analysis
---

# Review Code

Comprehensive code review using **specialized agents** AND **multi-LLM review** with Independent Work → Cross-Validation → Synthesis. Catches bugs, security issues, and pattern violations.

Works on: **Local changes** (uncommitted+staged vs HEAD, default) or **GitHub PRs** (`--pr` flag). Pass `--scope=branch` to review the entire branch vs base instead.

> `/create-plan` -> `/create-code` (includes auto-review) -> `/create-test` -> `/fix-test`

**Note**: `/create-code` now auto-runs `/review-code` as its final step. Use this skill standalone for: reviewing code not written via `/create-code`, re-reviewing after manual edits, reviewing PRs, or when you want swarm/full mode.

**Run `/lint` after** -- this skill finds semantic issues; lint cleans formatting.

**Related**: `/review-plan` (plans), `/create-code` (implement + auto-review), `/lint` (formatting)

## Three-Phase Review

| Phase | Participants | Purpose |
|-------|-------------|---------|
| **Independent Work** | Agents + multi-LLM (independent, parallel) | Diverse perspectives without anchoring bias |
| **Cross-Validation** | Agents see all Independent Work findings | Validate, dispute, go deeper with full context |
| **Synthesis** | Leader merges all findings | Final report with 80/20 filter |

## Usage

```
/review-code                              # Uncommitted+staged vs HEAD (default)
/review-code --scope=branch               # Whole branch vs base (auto-detect, fallback master)
/review-code <file-or-directory>          # Review specific path
/review-code backend                      # Go files only
/review-code frontend                     # TypeScript/React files only
/review-code --pr 123                     # Review GitHub PR #123
/review-code --quick                      # Tier 1 agents only (no multi-LLM)
/review-code --full                       # All tiers + multi-LLM (most thorough)
/review-code --agents-only                # Skip multi-LLM review
/review-code --llm-only                   # Skip agents, multi-LLM only
/review-code --swarm                      # Parallel agents via teams + convergence loop
/review-code --swarm --sequential         # Groups run serially, agents parallel within group
/review-code --base feature-branch        # Implies --scope=branch with this base
/review-code --plan path/to/plan.md       # Review against implementation plan
```

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Leader Dedup | Convergence |
|------|------------------|------------------|--------------|-------------|
| Default (no flags) | Parallel subagents, no shared state (agents + multi-LLM) | SKIPPED | **MANDATORY** | Single-pass |
| `--swarm` | Background agents with shared findings dir (agents + multi-LLM) | Fresh agents cross-validate | **MANDATORY** | Canonical convergence (swarm-harness.md) |
| `--sequential` | Serial Task() calls | SKIPPED | **MANDATORY** | Single-pass |
| `--quick` | Tier 1 agents only, no multi-LLM | SKIPPED | **MANDATORY** | Single-pass |
| `--security` | Tier 1 + Tier 2 (Security) agents + security-focused multi-LLM | SKIPPED | **MANDATORY** | Single-pass |
| `--agents-only` | Parallel subagents, no shared state (agents only) | SKIPPED | **MANDATORY** | Single-pass |
| `--llm-only` | Parallel subagents, no shared state (multi-LLM only) | SKIPPED | **MANDATORY** | Single-pass |

## Project Context Loading

See `~/.claude/docs/project-context-loading.md` -- three-level agent discovery + reference docs before review.

## Workflow

### Step 0: Read Agent Registry (MANDATORY — before any other step)

Read `~/.claude/agents/AGENT_REGISTRY.md` **in full, no line limit**. The Parallel Groups table is near the top of the file. Apply the trigger table to determine which groups run:

| Changed files | Groups to add |
|--------------|---------------|
| Always | Cross-cutting |
| `*.go` | Backend |
| `*.ts` / `*.tsx` | Frontend |
| New files or dirs added | Compatibility |
| Test files | Testing |
| CI/CD files or `--ci` flag | Infrastructure |
| `--thorough` / `--full` | Security |

**Do not select any agents until this read is complete. Never select agents from memory.**

1. **Identify changes** -- determine the comparison base from scope:
   - Default (no `--scope`, no `--base`, no `--pr`): `git diff HEAD` (uncommitted+staged work).
   - `--scope=branch` or `--base <branch>`: `git diff <base>` (whole branch vs base; base auto-detects, fallback `master`).
   - `--pr <n>`: `gh pr diff <n>`.

   **Print the active scope as the first line of output**, e.g. `Reviewing 5 uncommitted file(s) (vs HEAD). Use --scope=branch for full branch review.` This prevents users from shipping a PR thinking they got a full review when they only got the unstaged slice. Detect languages and domains from the resulting file set.
2. **Load implementation plan** (if `--plan` provided) -- Read the plan file. Extract: phased delivery scope, intentional design decisions, accepted trade-offs, and deferred items. This context is included in every agent prompt.
3. **Gather full context** -- BEFORE spawning any review agents:
   - **Identify changed-file paths**: Run `git diff --name-only` against the active scope's base to get the path list.
   - **Identify sibling/parent components**: Scan the diff for `import`, `styled(...)`, `extends`, prop types, and interface references. Add their paths to the codebase-paths list.
   - **Identify pattern exemplars**: For each changed construct (styled component, API handler, store method, etc.), identify 2-3 existing sibling paths that establish the convention (e.g., for a new `MemberButton`, identify the `DotMenuButton` and `TitleButton` paths from the same file/package).
   - **Pass paths, not bundled content (default for local scopes)**: Include the codebase-paths list inline in each agent prompt. Agents Read on demand from the working tree. Bundling full file contents inline duplicated ~50 KB × N across the swarm; passing paths lets each agent fetch only what it needs and keeps prompts lean.
   - **Exception — `--pr` mode**: When reviewing a PR with no local checkout, fetch each path's content via `gh` and bundle inline — agents have no working tree to Read from.
   - **Why include codebase context at all**: Diff-only review produces false positives — agents flag "issues" that are actually established codebase conventions (e.g., color opacity values, touch target sizes, missing focus styles that no sibling component has either). The diff alone doesn't show convention.
   - **CRITICAL — Annotate diff scope in agent prompts**: ALWAYS include the raw `git diff` output (with `+`/`-` line markers) as a separate clearly-labeled section. Label it: `## Diff (YOUR REVIEW SCOPE — only flag issues in these changed lines)`. Pass codebase paths in a `## Codebase Paths (Read these for context — do NOT flag issues in unchanged code)` section. Under `--pr` mode where contents are bundled, label them `## Full File Context (for understanding only — do NOT flag issues in unchanged code)` instead. The visual separation prevents agents from treating codebase context as review scope.
4. **Load agents** -- three-level discovery from `~/.claude/docs/project-context-loading.md`, tagged `[CODE]` or `[BOTH]`
5. **Emit Selection Rationale (MANDATORY — before spawning anything)** -- Print a `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. List every candidate agent under either SELECTED (with trigger reason) or SKIPPED (with specific reason). The block is user-visible output, printed after the scope line from Step 1 and before any agent spawns. In `--swarm` mode, also write `selection-rationale.md` to the synthesis dir so it survives `/clear`.

6. **Independent Work** -- agents + multi-LLM run in parallel, write COMPLETE findings to files, neither sees the other's output
7. **Cross-Validation** -- agents READ each other's findings files directly (leader provides file paths + brief themes, not a condensed summary)
8. **Synthesis** -- fresh synthesis agent reads ALL findings files, merges with 80/20 filter, 2+ source agreement = MUST FIX. Leader reads only the summary.
9. **Leader Dedup Gate (MANDATORY — all modes)** -- Before the diff-scope gate, the leader (you) MUST deduplicate and merge findings from all agents. This step runs in ALL modes, not just `--swarm`. Agents work independently and frequently report the same root-cause pattern as separate findings with different severities.
   - **Group by root pattern**: For each finding, ask "what is the anti-pattern?" (e.g., "uses `HandleError` instead of `HandleAppError`", "missing `classifyAppError` wrapper"). Two findings with the same anti-pattern are ONE finding.
   - **Merge across agents**: If error-handling-reviewer and api-reviewer both flag the same function call, merge into one finding citing both sources.
   - **Merge across severities**: If the same pattern appears as MUST_FIX in one agent and SHOULD_FIX in another, use the HIGHER severity and list ALL instances.
   - **Count ALL in-scope instances**: For merged pattern findings, grep for the pattern across ALL changed files to find every instance — not just the ones agents reported. Report the total count.
   - **One finding, one fix**: The merged finding gets a single fix description that addresses all instances (e.g., "Replace `HandleError` with `HandleAppError` at 4 call sites in changed code").
   - **Why this exists**: Without this gate, the same bug reported by N agents appears as N separate findings, creating noise and hiding the systemic nature of the issue. The user sees "4 separate problems" when there is actually "1 pattern, 4 instances."
9.5. **Runtime-claim verification gate (MANDATORY before any behavioral MUST_FIX)** -- For every finding whose claim is *behavioral* ("breaks / 404s / never found / returns wrong value / spams / silently fails / data loss"), the leader MUST verify the **terminal end** of the execution path before assigning MUST_FIX — not the changed line alone.
   - **Read the callee, not just the caller.** The diff usually shows the *caller*; the failure claim lives at the *callee*. "Calls endpoint E / store method M / consumer C" → read E's handler / M's body / C before labeling. Reading the caller only confirms the call *happens*, never that it *fails*. (This is source-reading-discipline rule 3 — symmetric reading — applied to severity assignment.)
   - **Reconcile against the test suite.** Grep for a test covering that exact path. A green test on the path is disconfirming evidence — demote and re-read. Treat "tests pass but I claim it's broken" as a contradiction to resolve, never a footnote.
   - **Severity is capped by what you read.** Full-path read (caller→callee) OR a red test/repro → MUST_FIX permitted. Same-layer-as-diff read only → SHOULD_FIX (unverified runtime claim) maximum.
   - **Scope:** applies to runtime/behavioral findings only. Pattern/style/structural findings (dead code, naming, layer violations) do NOT need a full-path trace. This is a leader gate, not an agent constraint — agents should keep surfacing cross-layer hypotheses cheaply; the leader does not promote them without reading the far end.
   - **Why this exists:** caught a false "page version restore is broken" MUST_FIX — the frontend called the posts restore endpoint, but the server handler (`RestorePostVersion`) had a `Pages`-table fallback the caller-side read never saw. The leader had "verified" only the frontend wiring (the premise), not the server handler (the conclusion).
10. **Diff-scope gate (MANDATORY)** -- Before presenting ANY finding to the user, verify it is on a changed line. The gate **MUST use the same comparison base as Step 1** — never widen the gate beyond the chosen scope:
   - Default scope: `git diff HEAD --name-only` and `git diff HEAD -- <file>`.
   - `--scope=branch` / `--base`: `git diff <base> --name-only` and `git diff <base> -- <file>`.
   - `--pr <n>`: use the PR diff.

   For each MUST_FIX or SHOULD_FIX finding, check: is the cited file in the changed-files set?
   - If YES: verify the cited line/function appears in a `+` hunk (added/modified code).
   - If NO (file not changed, or cited line is in unchanged code): **DROP the finding**. Pre-existing issues in unchanged code — including code committed earlier in the branch when scope is `uncommitted` — are out of scope.

   This step is a HARD GATE. No finding passes to the user without diff verification. Catches agents that read full files for context and then flagged pre-existing issues.
11. **Present results** -- the user-visible output is structured as: (1) Selection Rationale block from Step 5 already printed at the top, (2) MUST_FIX and SHOULD_FIX findings that passed both gates (dedup + diff-scope), (3) verdict. If not READY, ask user: "N MUST_FIX found. Fix and run another round?"

## Prompts & Output Format

See `~/.claude/docs/review-prompts.md` for: code review prompt template, output format, and agent prompt rules (neutral framing to avoid confirmation bias).

## Pattern Completeness — Single Source of Truth

The Pattern Completeness rule lives in `~/.claude/agents/_shared/grounding-rules.md` § "Pattern Completeness (Mandatory)". Every review agent reads `grounding-rules.md` as its FIRST ACTION, so the rule is automatically enforced without prompt injection. Do NOT duplicate it here or in agent prompts.

## Agent Tiers & Selection

Read `~/.claude/agents/AGENT_REGISTRY.md` **in full, no line limit** for agent lists per tier.

**Selection logic** -- pick agents based on changed file types (tier numbers match `~/.claude/agents/AGENT_REGISTRY.md`):
- **Tier 1 (Cross-cutting)**: Always run all agents
- **Tier 3 (Backend)**: If `*.go` files changed
- **Tier 4 (Frontend)**: If `*.ts`/`*.tsx` changed, OR API/schema changes (bridge trigger)
- **Tier 5 (Testing)**: If test files changed; E2E agents if `e2e-tests/playwright/` changed
- **Tier 6 (Compatibility)**: If `model/` files changed, fields removed/renamed, API surface changes, or new files/dirs added — `backwards-compatibility-reviewer`, `batch-operations-reviewer`, `null-safety-reviewer`, `deprecation-reviewer`, `license-reviewer`, `file-structure-reviewer`
- **Tier 7 (Infrastructure)**: If CI/CD files changed (`.github/`, `Makefile`, `Dockerfile`, `.gitlab-ci.yml`) or `--ci` flag — `ci-failure-reviewer`
- **Tier 2 (Security)**: With `--security`, `--thorough`, or `--full` flag
- **Project group**: If changed files match project-specific patterns — agents from **project** registry (`<project>/.claude/agents/AGENT_REGISTRY.md`, "Parallel Groups" table). Discovered automatically via three-level agent discovery; no hardcoded agent names here.

**Routing rule**: Only spawn `[CODE]` or `[BOTH]` agents. NEVER spawn `[PLAN]`-only agents.

## Convergence Tracking

Uses canonical pattern from `~/.claude/docs/swarm-harness.md#convergence-pattern`. Track MUST FIX count trend across rounds.

## Flags

| Flag | Effect |
|------|--------|
| `--pr <number>` | Review GitHub PR instead of local changes |
| `--quick` | Tier 1 agents only, no multi-LLM (fastest) |
| `--security` | Tier 1 + Tier 2 (Security) agents + security-focused multi-LLM. Narrower than `--full` |
| `--full` / `--thorough` | All tiers + multi-LLM (most thorough) |
| `--agents-only` | Skip multi-LLM review |
| `--llm-only` | Skip agents, multi-LLM only |
| `--swarm` | Parallel agents via teams + auto-fix convergence (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: groups run serially |
| `--ci` | Include Tier 7 (Infrastructure) agents for CI/CD review |
| `--scope=uncommitted` | (default) Review only uncommitted+staged changes (`git diff HEAD`) |
| `--scope=branch` | Review the entire branch vs base (`git diff <base>`); base defaults to auto-detect, fallback `master` |
| `--base <branch>` | Implies `--scope=branch` and overrides the base branch |
| `--plan <path>` | Load implementation plan as context — agents distinguish intentional-per-plan from genuine issues |

## Examples

```bash
/review-code                           # Full review of local changes
/review-code backend                   # Go files only
/review-code --pr 123                  # Review a PR
/review-code --quick                   # Fast check (Tier 1 only)
/review-code --full                    # Thorough (all tiers + LLM)
/review-code --swarm                   # Parallel swarm review
/review-code --swarm --sequential      # Sequential swarm
/review-code --plan impl-plan.md       # Review with plan context (reduces false positives)
/review-code --plan impl-plan.md --full # Thorough + plan-aware
```

## Swarm Mode (`--swarm`)

> **Swarm protocol**: See `~/.claude/docs/swarm-harness.md`
>
> **Persistence**: Set `PERSIST_DIR = "{repo}/plans/.review-history/code-{branch-name}"`
> before invoking the harness. Each round's synthesis files are mirrored there
> so they survive `/clear` and reboots. See harness "Persistent Archive" section.

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1a-n: Code agents (by tier) | (from AGENT_REGISTRY.md) | Domain reviewers | Independent Work | -- |
| T2: Multi-LLM review | general-purpose | LLM reviewers | Independent Work | -- |
| T3: Cross-validation | 3-5 Phase 1 types covering major domains (see swarm-harness.md) | Validate/dispute/go deeper + contradiction check | Cross-Validation | T1*, T2 |
| T4: Synthesize | general-purpose (fresh) | Merge all findings | Synthesis | T3 |

### Parallel Groups (Independent Work)

Groups and agent assignments are defined in `~/.claude/agents/AGENT_REGISTRY.md` SS "Parallel Groups for Code Review". The table below mirrors those groups exactly — see the registry for agent lists.

| Group | When |
|-------|------|
| Cross-cutting | Always |
| Backend | Go changes |
| Frontend | TS/React changes |
| Compatibility | `model/` changes, API surface changes, new files/dirs |
| Infrastructure | CI/CD file changes or `--ci` |
| Security | `--thorough` or `--full` |
| Project | Project-specific file patterns (from project registry) |
| Testing | E2E changes |

## Plan-Aware Review (`--plan`)

When `--plan <path>` is provided, include the full plan content in every agent prompt with these instructions:

> **Implementation Plan Context**: The code under review implements this plan. Before flagging any finding:
> 1. Check if the behavior is **explicitly prescribed by the plan** (e.g., phased delivery, accepted trade-offs, intentional scaffolding). If so, classify as INFO with note "intentional per plan."
> 2. Check if the finding **contradicts the plan** (code does X but plan says Y). Flag as MUST_FIX with note "deviates from plan."
> 3. If the plan **doesn't mention** the concern, evaluate it on its own merits as normal.
> 4. Check if code is **scaffolded for a later phase** (field exists but has no migration/handler yet). If the plan says it ships in a later phase, classify as INFO.

This eliminates false positives from phased delivery, intentional design trade-offs (e.g., "gaps on failure are acceptable"), and deferred features.

## Fix Prompts — Pattern Completeness Rule

When spawning coder agents to fix findings, **always include** the Pattern Completeness instruction from `~/.claude/docs/pattern-completeness-rule.md` in the agent prompt.

## Tips

- **Run before every commit** -- catch issues early
- **Use `--quick` for WIP** -- full review before PR
- **Fix MUST FIX immediately** -- they're blockers for a reason
- **Trust multi-source consensus** -- 2+ sources (agent + LLM, agent + agent) agreeing = real issue
- **Use `--agents-only` for speed** -- when external LLMs are slow
- **Cross-Validation catches false positives** -- validates/disputes Independent Work findings

## Anti-patterns
- Running full swarm review on a 5-line change — `--quick` exists for a reason.
- Treating every finding as a blocker — severity tiers (MUST_FIX / SHOULD_FIX / CONSIDER) exist to separate signal from noise.
- Spawning review agents without telling them the diff scope — agents flag pre-existing issues as new findings.
- Acting on a single-source finding without cross-validation — one agent's opinion is a hypothesis, not a verdict.
- Skipping `--quick` pre-commit and doing full review only at PR time — late reviews cost more to fix.
- **Skipping the Selection Rationale block (Step 5)** — silently selecting agents hides drift. See `~/.claude/docs/selection-rationale.md` for the full anti-pattern list.

## Self-rewrite hook
After every 15 review runs, or after any run where the review produced more noise than signal (most findings were false positives or pre-existing issues):
1. Re-read the last 5 sets of findings — which finding types consistently turned out to be false positives?
2. If a recurring false-positive category appears, add a note to the relevant agent's prompt or the shared false-positive-prevention rule.
3. If cross-validation consistently reverses a specific agent's findings, flag that agent for tuning.
4. Commit: `skill-update: review-code, <one-line reason>`.
