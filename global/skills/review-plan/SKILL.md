---
name: review-plan
description: Multi-LLM + domain agent validation for implementation plans. Supports --spec mode for requirements validation and default mode for technical feasibility. Focuses on 80/20 high-impact issues. Tracks convergence across rounds.
version: 2.0.0
tags:
  - plan-review
  - validation
  - quality
---

# Plan Review

Validate implementation plans using **domain agents** AND **multiple LLMs** before writing code. **Focuses on 80/20 analysis** -- the critical few issues that matter. **Tracks convergence** across review rounds.

**Two modes:**
- **Default**: Technical feasibility (can this be built?)
- **`--spec`**: Requirements validation (are we building the right thing?)

**Related**: `/create-plan` (generate plans), `/multi-review` (code/architecture decisions)

## Usage

```
/review-plan <plan-file>                           # Technical review (default)
/review-plan <plan-file> --spec                    # Requirements validation
/review-plan <plan-file> --req <requirements>      # Compare against original request
/review-plan <plan-file> --context <relevant-files> # Include codebase context
/review-plan <plan-file> --quick                   # Fast single-model check (Gemini only)
/review-plan <plan-file> --reset                   # Clear review history, start fresh
/review-plan <plan-file> --swarm                   # Agent teams for parallel review
/review-plan <plan-file> --swarm --sequential      # Swarm tasks run serially
```

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Convergence |
|------|------------------|------------------|-------------|
| Default (no flags) | Parallel subagents, no shared state (agents + multi-LLM) | SKIPPED | Single-pass |
| `--swarm` | Background agents with shared findings dir (agents + multi-LLM) | Fresh agents cross-validate | Canonical convergence (swarm-harness.md) |
| `--sequential` | Serial Task() calls | SKIPPED | Single-pass |
| `--quick` | Gemini only, no agents | SKIPPED | Single-pass |

## Project Context Loading

See `~/.claude/docs/project-context-loading.md` -- three-level agent discovery + reference docs before review.

## 80/20 Prioritization

See `~/.claude/docs/review-prompts.md` for the canonical 80/20 filter (MUST_FIX / SHOULD_FIX / DEFER / SKIP criteria and blocker definitions per mode).

**Be ruthless.** Most LLM "warnings" are nice-to-haves.

## Workflow

### Step 0: Read ALL THREE Agent Registries (MANDATORY — before any other step)

Read every registry level before selecting any agent. Missing a level silently drops a whole class of domain-specific agents (e.g., skipping Level 2 drops all Mattermost-suite [PLAN]/[BOTH] agents).

Read these files **in order**, collecting every agent tagged `[PLAN]` or `[BOTH]` from each:

1. `~/.claude/agents/AGENT_REGISTRY.md` — Level 1 (global, language-agnostic)
2. `~/mattermost/.claude/agents/AGENT_REGISTRY.md` — Level 2 (Mattermost-suite) — read when working in any Mattermost project clone
3. `.claude/agents/AGENT_REGISTRY.md` — Level 3 (project-specific) — read when the file exists

The merged candidate list from all three levels feeds Step 2 domain routing. **Do not select any agents until all applicable levels are read. Never select agents from memory.**

### Step 1: Gather Context

Read plan file. If `--req` provided, read requirements. If `--context`, read codebase files. Detect mode. `--reset` clears previous rounds.

### Step 2: Load Domain Agents (MANDATORY)

Use three-level agent discovery from `~/.claude/docs/project-context-loading.md`. Load agents tagged `[PLAN]` or `[BOTH]`.

**Minimum agents** (always run):
- `design-flaw-reviewer` — logical flaws, missing states, contradictions
- `simplicity-reviewer` — unnecessary complexity, over-engineering, YAGNI violations
- `plan-assertion-reviewer` — verifies factual claims against codebase AND checks reasoning built on those facts (with `--full`: pass `--thorough` to apply all 8 reasoning techniques)

**Always-run design agents** (in addition to minimum set — these are the design wave for Step 3a):

| Agent | Trigger |
|-------|---------|
| `system-design-reviewer` | Any plan with state machines, multi-step flows, or entity lifecycles |
| `separation-of-concerns-reviewer` | Any plan touching more than one layer (API, App, Store, UI) |

**Domain routing** (run if plan touches that domain):

| Plan touches | Additional agents |
|-------------|-------------------|
| Database / migrations | `database-architecture-auditor` |
| Permissions / auth | `permission-design-auditor`, `backwards-compatibility-reviewer` |
| Restricts existing access / tightens enforcement | `backwards-compatibility-reviewer` |
| Changes defaults or validation rules | `backwards-compatibility-reviewer` |
| Removes or renames props / fields / callbacks on existing types | `backwards-compatibility-reviewer`, `type-design-reviewer` |
| Adds new props or fields to existing public types | `type-design-reviewer` |
| API design | `api-contract-reviewer` |
| Frontend / React | `ux-design-auditor` |
| Architecture | `architecture-assertion-auditor` |
| External products | `external-claims-auditor` |
| CI/CD / workflows / cross-repo builds | `ci-design-reviewer` |
| Build tools / compiler invocation / multi-language (Go+TS, Go+Python, etc.) | `architecture-assertion-auditor` — verify build tool semantics (error formats, compilation scope, environment prerequisites) via WebSearch |

### Step 2.5: Emit Selection Rationale (MANDATORY — before spawning anything)

Print the `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. The block **must** include:

1. **Registries read** — list each level checked (L1 / L2 / L3) and whether it was found. This makes registry omissions visible before any agent runs.
2. **SELECTED** — every `[PLAN]` or `[BOTH]` candidate agent with trigger reason (minimum-set, always-run design, domain-routing match, `--full` flag, etc.)
3. **SKIPPED** — every `[PLAN]` or `[BOTH]` candidate with specific skip reason (`[CODE]`-only tag, no matching domain, wrong project scope, etc.)

The block is user-visible output, printed before any agent spawns. If the registries-read row is absent, the rationale is incomplete.

### Step 3: Run Reviews — Design First, Then Technical

**Review in two waves.** Design flaws in the architecture waste all effort spent fixing API names. Technical accuracy reviews are only valuable after the design is sound.

#### Step 3a: Design Validation (run first)

Launch design-focused agents in parallel:
- `design-flaw-reviewer` — logical flaws, missing states, contradictions, state machine completeness
- `system-design-reviewer` — entity lifecycles, permission model, data model fitness, interaction completeness
- `separation-of-concerns-reviewer` — conflated concerns, over-coupled abstractions, orthogonal decisions bundled
- `simplicity-reviewer` — over-engineering, YAGNI, unnecessary abstractions

Focus prompt: "Is the DESIGN correct? Right abstractions? Complete state machines? All entry points covered? Simplest solution?" Do NOT ask about API names, file paths, or code syntax.

#### Step 3b: Technical Feasibility (run after 3a, or in parallel if design is stable)

Launch technical agents AND multi-LLM reviewers:
- `plan-assertion-reviewer` — verify factual claims against codebase
- Domain-specific agents (from Step 2 routing table)
- Project-specific agents (from three-level discovery)
- All models from `~/.claude/docs/multi-llm-review.md`

Focus prompt: "Can this be BUILT? Correct API calls? Right file paths? Migration versions? Code-level accuracy?"

**When to run 3a and 3b in parallel**: If the plan sections being reviewed are mature/stable (e.g., Round 2+ after design was already validated). For NEW sections or major redesigns, run 3a first, fix design issues, then run 3b.

**Quick mode**: Gemini only, no agents — skip the two-wave split.

### Step 4: Synthesize with 80/20 Filter

**Design findings take priority over technical findings.** A wrong abstraction is more expensive than a wrong API name.

1. **MUST FIX** -- 2+ sources agree (agent + LLM, agent + agent, LLM + LLM) AND meets blocker criteria. Design flaws that 2+ design agents agree on are automatic MUST FIX.
2. **SHOULD FIX** -- single-source valid findings, not blocking
3. **DEFER** -- valid concerns for future
4. **SKIP** -- reject over-engineering

### Step 5: Present Results and Offer Next Round

After reading the synthesis summary, present findings to the user. If verdict is not READY:
1. Show the MUST_FIX and SHOULD_FIX items from the summary
2. Ask the user: "N MUST_FIX and M SHOULD_FIX found. Would you like to fix the plan and run another round?"
3. If user fixes and says yes → run again (track round number for convergence)
4. If READY → congratulate and suggest proceeding to `/create-code`

Round history is tracked automatically — repeated invocations compare against previous rounds.

## Prompts & Output Format

See `~/.claude/docs/review-prompts.md` for: technical review prompt, spec review prompt, and output format.

## Convergence Tracking

Uses canonical pattern from `~/.claude/docs/swarm-harness.md#convergence-pattern`. `--reset` starts fresh.

## Verdict Criteria

| Verdict | Criteria |
|---------|----------|
| **READY** | 0 MUST FIX items. Proceed. |
| **NEEDS WORK** | 1-2 MUST FIX items. Quick fixes needed. |
| **MAJOR REVISION** | 3+ MUST FIX or fundamental flaw. Rethink. |

## Flags

| Flag | Effect |
|------|--------|
| `--spec` | Requirements validation mode |
| `--req <requirements>` | Compare against original request |
| `--context <files>` | Include codebase context |
| `--quick` | Single-model check (Gemini only, no agents) |
| `--full` | Thorough review: `plan-assertion-reviewer` applies all 8 reasoning techniques (vs default 3) |
| `--reset` | Clear review history, start fresh |
| `--swarm` | Agent teams for parallel review (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: tasks run serially |

## Examples

```bash
/review-plan plans/feature.md --spec    # Requirements first
/review-plan plans/feature.md           # Then technical
/review-plan plans/feature.md           # Round 2 (compares to R1)
/review-plan plans/feature.md --reset   # Start fresh
/review-plan plans/small-fix.md --quick # Quick check
```

## Integration with Workflow

```
/create-plan -> /review-plan --spec -> /review-plan -> fix MUST FIX -> /review-plan (R2) -> approve -> /create-code -> /review-code
```

## Swarm Mode (`--swarm`)

> **Swarm protocol**: See `~/.claude/docs/swarm-harness.md`
>
> **Persistence**: Set `PERSIST_DIR = "{repo}/plans/.review-history/{plan-basename-no-ext}"`
> before invoking the harness. Each round's synthesis files are mirrored there
> so they survive `/clear` and reboots. See harness "Persistent Archive" section.

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1a-c: Plan agents | (from three-level discovery) | Domain reviewers | Independent Work | -- |
| T2: Multi-LLM review | general-purpose | LLM reviewers | Independent Work | -- |
| T3: Cross-validation | 3-5 Phase 1 types covering major domains (see swarm-harness.md) | Validate/dispute/go deeper + contradiction check | Cross-Validation | T1*, T2 |
| T4: Synthesize | general-purpose (fresh) | Merge all findings | Synthesis | T3 |

## Tips

- **Design before execution**: Validate the design (right abstractions, complete state machines) BEFORE checking API names and file paths. Fixing typos on a flawed design wastes effort.
- **Three-layer review sequence**: `--spec` (requirements) → design validation (Step 3a) → technical feasibility (Step 3b). Skip layers only when the plan is mature.
- **Run `--spec` before default** -- no point validating technical if requirements are wrong
- **Be skeptical of LLM "blockers"** -- most are actually SHOULD FIX or DEFER
- **Round 1 always has the most MUST FIX** -- if round 2 has 0, you're likely done
- **Use `--reset`** when plan has changed significantly
- **Domain agents catch what LLMs miss** -- pattern violations, MM-specific constraints
