---
name: create-plan
description: Parse requirements first, research codebase for gaps, consult domain agents, draft structured implementation plan, save to file. Review goes through /review-plan.
version: 3.0.0
tags:
  - planning
  - architecture
  - design
---

# Create Plan

**Requirements -> Research -> Consult -> Draft -> Save.** Generates a structured implementation plan driven by requirements, validated against codebase reality. Does NOT review -- run `/review-plan` after drafting.

**Related**: `/review-plan` (validate plan), `/multi-review` (ad-hoc architecture decisions)

## Usage

```
/create-plan <request>                    # Research + consult + draft + save
/create-plan <request> --output <file>    # Save to specific file
/create-plan <request> --minimal          # Lightweight plan for small features
/create-plan <request> --draft            # Skip domain consultation + review
/create-plan <request> --mm               # Force Mattermost layer template
/create-plan <request> --generic          # Force generic template (skip MM auto-detect)
/create-plan <request> --swarm            # Use agent teams for parallel research
/create-plan <request> --swarm --sequential  # Swarm tasks run serially
```

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Convergence |
|------|------------------|------------------|-------------|
| Default (no flags) | Parallel subagents, no shared state (research + agents + multi-LLM) | SKIPPED | Single-pass |
| `--swarm` | Background agents with shared findings dir (research + agents + multi-LLM) | Fresh agents cross-pollinate | Canonical convergence (swarm-harness.md) |
| `--sequential` | Serial Task() calls | SKIPPED | Single-pass |
| `--draft` | Leader only, no agents or multi-LLM | SKIPPED | Single-pass |
| `--minimal` | Reduced agent set, abbreviated template | SKIPPED | Single-pass |

## Project Context Loading

See `~/.claude/docs/project-context-loading.md` -- three-level agent discovery + reference docs before researching.

## Project Auto-Detection

The skill auto-detects Mattermost projects and uses the appropriate template.

**MM Detection**: Checks for `server/channels/` + `webapp/channels/` structure, or `CLAUDE.md` mentioning "Mattermost"

| Detected Project | Template Used | Override |
|------------------|---------------|----------|
| Mattermost repo | MM Layer Template | `--generic` |
| Other repos | Generic Template | `--mm` |

**Output location**: `plans/<feature-name>.md` (kebab-case).

## Templates

See `~/.claude/docs/plan-templates.md` for:
- Generic plan template
- MM Layer template (Model->Store->App->API->Webapp)
- Phase strategy (for large features)
- Frontend pattern references (auto-include for UI plans)
- Template section guidelines

## Workflow

### Step 0: Parse Requirements Source (MANDATORY)

**This step runs BEFORE any codebase exploration.** The requirements define the plan's scope — the codebase informs feasibility and existing state, but does NOT drive what gets planned.

1. **Identify the requirements source**: The user's prompt may reference a PDF, markdown doc, Jira ticket, CSV, or inline description. READ the full source document(s).
2. **Extract a structured requirements list**. For each requirement, capture:
   - **What the user sees/does** (UI surface, if any)
   - **What the system does** (backend behavior)
   - **Priority** (required vs nice-to-have) if stated in the source
   - **Layers touched**: Does the requirement imply UI changes? API changes? Store changes? Migrations? List every layer.
3. **Write the structured list down** (in working notes or plan preamble) before proceeding. This list is the DRIVING SCOPE — every item must appear in the final plan as either: implemented in the plan, explicitly deferred with a named follow-up plan reference, or marked as already complete with a code location.

**Rule**: A requirement from the source document may NOT be silently dropped. If the plan doesn't cover it, there must be a visible entry explaining why (deferred, out of scope with rationale, or already done).

### Step 1: Research Codebase (against requirements)

For EACH requirement from Step 0, use Explore agent to search the codebase:
- **Already implemented?** → Mark as done, note file:line location
- **Partially implemented?** → Note what exists vs what's missing
- **Not started?** → Note related patterns to follow (2-3 similar features with file:line references)

The output is a **gap analysis** keyed to requirements, not a code-driven scope definition. Document MM patterns observed for each layer touched.

### Step 1.5: Domain Consultation (MANDATORY)

Use three-level agent discovery from `~/.claude/docs/project-context-loading.md`. Load agents tagged `[PLAN]` or `[BOTH]`.

**Route by plan content** — spawn agents relevant to the feature being planned:

| Feature touches | Agents to consult |
|----------------|-------------------|
| Database / migrations | `database-architecture-auditor` |
| Permissions / auth | `permission-design-auditor` |
| API design | `api-contract-reviewer` |
| Frontend / React | `react-frontend-expert`, `redux-expert` |
| System design | `system-design-reviewer` |
| Caching | `caching-expert` |

**Before spawning — Emit Selection Rationale (MANDATORY)**: Print the `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. List every `[PLAN]` or `[BOTH]` candidate agent under SELECTED (with trigger reason — matched domain in the feature description) or SKIPPED (with specific reason — `[CODE]`-only tag, domain not touched by plan, `--minimal`/`--draft` active, etc.). The block is user-visible output, printed before any agent spawns.

Spawn agents from the table above (see AGENT_REGISTRY) in advisory mode (not review) with the feature description, Step 0 requirements list, and Step 1 gap analysis as context.

**Minimum**: 1 domain agent if plan touches that domain. **Skip with**: `--minimal` or `--draft`.

### Step 2: Draft Plan Using Template

Use the appropriate template from `~/.claude/docs/plan-templates.md`. Incorporate domain agent advice into the plan — patterns, constraints, and recommended approaches inform the design.

#### Self-Containment Rule

**A plan MUST be self-contained.** It must cover every layer a requirement touches — frontend AND backend — in one document. Never defer a layer to "see other plan" or "covered by plan X." If another plan exists for related work, absorb the relevant architecture into this plan. The plan is the single source of truth that `/create-code` reads to generate implementation.

#### External Claims Grounding Rule (MANDATORY)

> **Full rules**: `.claude/agents/_shared/plan-grounding-rules.md` §§ 4-7 (regulatory, API/SDK, competitor, market claims)

**Plan authoring is subject to the same grounding rules as plan review.** The plan-grounding-rules exist in `_shared/` because they apply to BOTH authoring and reviewing — not just reviewing. Every external claim (regulatory, competitor, framework, market data) MUST be verified via WebSearch/WebFetch BEFORE writing it into the plan. Use the verification templates and fallback markers from plan-grounding-rules.md.

**Why this matters during authoring**: Plan documents become authoritative sources for `/create-code`, `/review-plan`, and future sessions. A fabricated claim in a plan propagates into code, tests, agent prompts, and marketing copy. The cost of one WebSearch now is far less than the cost of detecting and fixing a hallucination downstream.

**This rule applies to ALL modes** including `--draft` and `--minimal`. There is no flag to skip external claim verification.

#### Architecture vs Code Rule

**Plans describe architecture, not code.** `/create-code` reads the plan + codebase to produce code — it can discover patterns, line numbers, and syntax on its own. The plan's job is to communicate decisions that CANNOT be derived from the codebase alone:

| Plan SHOULD contain | Plan should NOT contain |
|--------------------|-----------------------|
| Data flow: what calls what, what data moves where | Go struct definitions or TypeScript interfaces |
| Error policies: soft vs hard failure, fallback behavior | Code snippets or function signatures |
| Design decisions with rationale | Line numbers or file offsets |
| Component relationships: which existing component to reuse and why | Exact import paths |
| New concepts: structs/types that don't exist yet (described, not coded) | SQL query examples |
| State management: where state lives, what triggers updates | Redux action/reducer boilerplate |
| Migration strategy: what changes, what order, what's backward-compatible | Migration SQL |
| Cascade effects: if X changes, what else must change | Copy-pasted existing code |

**Test**: If removing a section would leave `/create-code` unable to make a design decision, keep it. If `/create-code` could derive the same information by reading the codebase, remove it.

**Files to Modify tables**: List file paths and a short description of the change (what, not how). This gives `/create-code` a roadmap. Do NOT include line numbers — they drift as code changes.

#### Requirements Coverage Rule

The plan MUST address every requirement from Step 0 that is not already fully implemented. If a requirement spans multiple layers (e.g., backend resolver + frontend autocomplete UI), ALL layers must appear in the plan. If a requirement is intentionally deferred, it MUST appear in a "Deferred / Out of Scope" section with: (a) the original requirement text, (b) why it's deferred, and (c) a named follow-up plan reference if applicable. A plan that silently drops requirements because "they're in a different layer" is incomplete.

### Step 2.25: Completeness Check (MANDATORY)

**MANDATORY** after drafting (skip with `--draft` or `--minimal` flags). Spawn a **haiku** agent to verify the plan contains all required sections from the template checklist.

**Why this exists**: Under context pressure (especially in swarm mode), the drafting agent skips sections it considers "obvious" — acceptance criteria, audit events, error response tables, empty states. This check catches structural gaps before the heavier assertion checker and review steps.

Spawn the `plan-completeness-checker` agent (see AGENT_REGISTRY) on the saved plan file.

**Failure behavior**: If MISSING or EMPTY sections are found, the leader (or synthesis agent) MUST fill them before proceeding to Step 2.5. INCOMPLETE items should be addressed if straightforward.

### Step 2.4: Migration SQL Column Verification (MANDATORY if plan contains migrations)

**MANDATORY** when the plan contains any SQL migration code (ALTER TABLE, UPDATE, CREATE TABLE, INSERT). Spawn the `db-migration-expert` agent (see AGENT_REGISTRY) in advisory mode on the saved plan file. The agent must:

1. Extract every `(table, column)` pair referenced in migration SQL (UPDATE SET, ALTER TABLE, CREATE INDEX ON)
2. Verify each column exists on that table — in `migrations.go` prior migrations, being added in the same migration block, or present in store query SELECT lists (not merely aliased from a JOIN)
3. Flag any column that is a JOIN alias projected onto the result but not an actual column on the target table

**Failure behavior**: Any MISSING_COLUMN finding blocks saving. The leader must fix the migration SQL in the plan before Step 2.5.

### Step 2.5: Auto-Run Plan Assertion Checker

**MANDATORY** after drafting (skip with `--draft` flag). Spawn `plan-assertion-reviewer` agent (see AGENT_REGISTRY) on the saved file. This agent verifies factual claims against the codebase and checks whether reasoning built on those facts is valid.

**Failure behavior**: If MUST_FIX findings are returned, the plan is **blocked** — fix all MUST_FIX items in the plan before proceeding to Step 2.6. SHOULD_FIX items are warnings; address if straightforward, otherwise note them for the reviewer.

### Step 2.6: External Claims Verification (MANDATORY if plan contains external claims)

**MANDATORY** when the plan references regulatory articles, competitor data, framework APIs, penalty amounts, market figures, or any claim whose truth depends on something outside the codebase. Skip with `--draft` flag only.

> **Why this exists**: The plan-assertion-reviewer (Step 2.5) verifies claims against the **codebase**. It cannot verify claims about the outside world — FATF recommendation numbers, competitor pricing, framework method signatures, regulatory deadlines. Those hallucinations pass Step 2.5 undetected and become "authoritative" text. This step closes that gap.

**Process**:
1. Scan the draft plan for external claims — look for: article/section numbers, dates, penalty amounts, competitor names + any factual assertion, framework/SDK method names or capabilities, market size or conversion rate figures.
2. For each external claim found, verify using WebSearch or WebFetch per the verification templates in `.claude/agents/_shared/plan-grounding-rules.md` §§ 4-7.
3. For claims that verify correctly, add `(verified [date])` or `(as of [date])` inline.
4. For claims that fail verification, either correct them with the verified value and source, or mark with `<!-- TODO: verify [claim] against [source] -->`.
5. For claims that cannot be verified (no authoritative source found), mark with `(unverified)` so downstream reviewers know the provenance.

**Failure behavior**: Any regulatory claim that fails verification (wrong article number, wrong deadline, wrong penalty) is a **blocker** — fix before Step 3. Stale competitor data is a warning — mark with `(unverified)` and proceed.

**Agents**: If the project has a `regulatory-accuracy-auditor` or `competitive-intelligence-validator` agent (check AGENT_REGISTRY), spawn it on the draft for automated verification. Otherwise, the leader performs verification manually using WebSearch.

### Step 3: Review (via `/review-plan`)

MAX_REVIEW_ITERATIONS = 2

Run `/review-plan` on the draft. If MUST FIX items found, update and re-run. Stop after MAX_REVIEW_ITERATIONS rounds.

### Step 4: Save to File (MANDATORY)

Save to `plans/<feature-name>.md` (kebab-case). Tell user the saved location.

### Step 5: Exit Plan Mode

Call ExitPlanMode tool. User approves or requests changes.

### Step 6: Implementation (after approve)

**ALWAYS read from the saved plan file -- NEVER use conversation context.** The plan file is source of truth: version-controlled, user may have edited it, multiple sessions can reference it.

## Flags

| Flag | Effect |
|------|--------|
| `--draft` | Skip domain consultation + review, just generate plan |
| `--minimal` | Abbreviated template, skip domain consultation |
| `--output <path>` | Save to specific file |
| `--mm` | Force Mattermost layer template |
| `--generic` | Force generic template, skip MM auto-detection |
| `--swarm` | Agent teams for parallel research (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: tasks run serially |

## Examples

```bash
/create-plan "Add OAuth2 support with Google and GitHub providers"
/create-plan "Add loading spinner" --draft
/create-plan "Fix pagination bug" --minimal
```

## When to Use

| Scenario | Use `/create-plan` | Just ask CC |
|----------|--------------------|-----------------------|
| New feature | yes | |
| Multi-file change | yes | |
| API/database changes | yes | |
| Simple bug fix | | yes |
| Single-file tweak | | yes |

## Swarm Mode (`--swarm`)

> **Swarm protocol**: See `~/.claude/docs/swarm-harness.md`

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T0: Parse requirements | general-purpose | `requirements-parser` | Pre-Research | -- |
| T1: Research codebase | Explore | `plan-researcher` | Independent Work | T0 |
| T2: Research patterns | Explore | `plan-patterns` | Independent Work | T0 |
| T2.5: Domain consultation | (from three-level discovery) | `plan-advisors` | Independent Work | T0 |
| T2.5-llm: Multi-LLM opinions | general-purpose | `multi-llm-advisor` | Independent Work | T0 |
| T3: Cross-validation | 3-5 Phase 1 types covering major domains (see swarm-harness.md) | Advisors see all findings + contradiction check | Cross-Validation | T1, T2, T2.5, T2.5-llm |
| T4: Draft plan | general-purpose (fresh) | `plan-drafter` | Synthesis | T3 |
| T4.5: Completeness check | general-purpose (haiku) | `completeness-checker` | Synthesis | T4 |
| T4.6: Migration SQL column check | db-migration-expert | `migration-column-checker` | Synthesis | T4.5 |
| T5: Assertion check | plan-assertion-reviewer | `plan-checker` | Synthesis | T4.6 |
| T5.5: External claims | general-purpose | `external-claims-verifier` | Synthesis | T5 |

T0 (requirements parser) runs FIRST — all research tasks receive the structured requirements list as input. T1/T2 search the codebase keyed to each requirement (gap analysis). T4 (plan drafter) MUST be a fresh agent — leader context is too heavy from coordination. T5 auto-verifies facts+reasoning against codebase. T5.5 verifies external claims (regulatory, competitor, framework) via WebSearch — uses project agents (`regulatory-accuracy-auditor`, `competitive-intelligence-validator`) if available, otherwise manual WebSearch.


## Anti-patterns
- Swarm mode for a feature that fits in one file — overhead exceeds benefit.
- Skipping `--minimal` for genuinely small changes — a 300-line plan for a 10-line fix.
- Treating the plan as final before `/review-plan` — assertion errors surface late.
- Over-specifying implementation details in the plan — destination language, not driving directions.
- Writing the plan without running it through `/review-plan` first — plans that look complete but miss a schema dependency or wrong function signature.

## Self-rewrite hook
After every 10 plans created, or after any plan that failed assertion review or had major corrections during `/create-code`:
1. Re-read the last 3 review outcomes (what `/review-plan` or `/plan-assertion-reviewer` flagged).
2. If a recurring missed dependency type appeared, add it to the research checklist.
3. If swarm mode consistently over-fires for small tasks, tighten the swarm trigger criteria.
4. Commit: `skill-update: create-plan, <one-line reason>`.
