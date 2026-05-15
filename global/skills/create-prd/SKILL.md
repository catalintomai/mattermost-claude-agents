---
name: create-prd
description: Create a Product Requirements Document (PRD) through systematic Socratic interviewing and codebase exploration. Surfaces hidden assumptions before writing requirements. Output feeds directly into /create-plan.
version: 1.0.0
tags:
  - planning
  - requirements
  - product
user_invocable: true
---

# Create PRD

**Interview → Explore → Draft → Save.** Produces a structured PRD by systematically questioning you about the *problem* (not the solution) before touching the codebase. Designed to catch hidden assumptions before they become bugs.

> Precedes `/create-plan` in the planning chain:
> **`/create-prd`** → `/create-plan` → `/create-code` → `/create-test`

**Related**: `/create-plan` (implementation plan from PRD), `/review-plan` (validate plan)

## Usage

```
/create-prd <rough description>           # Full interview + exploration + draft
/create-prd <rough description> --quick   # Abbreviated interview, skip deep exploration
/create-prd --jira <key>                  # Start from a Jira issue (e.g. MM-12345)
/create-prd --from <file>                 # Seed from existing notes, transcript, or doc
```

## Output

Saves to `plans/<feature-name>.prd.md`. Pass the path directly to `/create-plan`:
```
/create-plan plans/<feature-name>.prd.md
```

## Workflow

### Phase 1: Interrogation (Grill Phase)

**Goal**: Understand the PROBLEM, not the solution. Ask Socratic questions and follow answers into sub-questions before moving on. Do NOT propose solutions during this phase.

If `--jira <key>` is provided, fetch the issue via `mcp__mcp-atlassian__jira_get_issue` and use it as pre-filled context — then fill any gaps with targeted questions rather than running the full interview.

If `--from <file>` is provided, read the file and extract pre-filled answers — interview only for missing dimensions.

Ask no more than 3 dimensions at once. After each answer, follow up with "why?" or "what happens if..." before advancing. If the user says "I don't know", offer 2-3 options based on codebase patterns, make it clear they're suggestions, then let the user choose.

#### Dimension 1: Problem Definition
- What problem are we solving? (drive toward a 1-sentence statement)
- Who experiences it? (end user / admin / system / developer — be specific)
- How do they experience it today? (current behavior, workaround they use)
- How often? (daily, per-run, per-channel — real usage frequency)
- What's the measurable impact? (time lost, errors made, data wrong, support tickets)

#### Dimension 2: Solution Boundaries
- What is the MINIMUM change that solves the stated problem?
- What explicitly does NOT need to change? (protect scope)
- What does "solved" look like? (acceptance criteria in plain language — not implementation terms)
- What existing features should this be consistent with? (design coherence)

#### Dimension 3: Constraints
- Backward compatibility requirements? (what must keep working)
- Performance constraints? (list size, query latency, load at scale)
- Permissions / auth constraints? (who can do what — roles, licenses, tiers)
- Any licensing or feature-tier gating?

#### Dimension 4: Deferral Boundaries
- What is explicitly out of scope for this PRD? (write it down — prevents scope creep later)
- Are there known follow-on PRDs? (name them now so they don't get absorbed)

**Stop interviewing** when every dimension has an answer. Do not advance to Phase 2 until the problem is unambiguous.

### Phase 2: Codebase Exploration

After Phase 1 has complete answers, spawn an `Explore` agent to map what exists vs what's needed.

For each problem area from Phase 1:
- **Already solved?** → Note file:line, mark as "DONE — already implemented"
- **Partially solved?** → Note what exists, what's missing
- **Not started?** → Find 2-3 analogous features showing the established pattern (file:line)

Skip with `--quick`.

### Phase 3: Draft PRD

Use interview answers + exploration findings to produce the PRD document:

```markdown
# PRD: <Feature Name>

## Problem Statement
<1-3 sentences. Who has what problem, with what measurable impact.>

## Goals
- <Outcome 1 — user-observable behavior change>
- <Outcome 2>

## Non-Goals (Explicitly Out of Scope)
- <Thing we are deliberately NOT doing, with brief rationale>

## User Stories
| As a...   | I want to...  | So that...  |
|-----------|---------------|-------------|
| <role>    | <action>      | <benefit>   |

## Acceptance Criteria
<Numbered, testable. Each maps to a user story.>
1. Given <state>, when <action>, then <outcome>

## Implementation Notes (High-Level)
<!-- Architecture hints for /create-plan. NOT code, NOT file paths. -->
- Layers affected: [API / App / Store / Frontend / Migration]
- New data: <what needs to be stored / schema impact>
- Permissions: <who can do what>
- Backward compat: <what must keep working unchanged>
- Performance: <any known constraints>

## Open Questions
<Unresolved questions that /create-plan must answer before implementation begins>

## Out of Scope — Named Follow-Ons
<Deferred features listed by name, so they can become their own PRDs>

## Exploration Findings
<Summary from Phase 2: already implemented (file:line), partial, and new gaps>
```

### Phase 4: Save

Save to `plans/<feature-name>.prd.md` (kebab-case). Tell the user the path.

Suggest the next step:
```
/create-plan plans/<feature-name>.prd.md
```

## Flags

| Flag | Effect |
|------|--------|
| `--quick` | Abbreviated Phase 1 (key dimensions only), skip deep codebase exploration |
| `--from <file>` | Seed the interview with content from a file (notes, transcript, doc) |
| `--jira <key>` | Fetch a Jira issue as starting context for Phase 1 |

## When to Use

| Scenario | `/create-prd` first | Go straight to `/create-plan` |
|----------|---------------------|-------------------------------|
| Vague idea or user feedback | yes | |
| Jira epic or initiative | yes | |
| Complex feature with unclear scope | yes | |
| Unknown constraints or edge cases | yes | |
| Well-defined requirements already exist | | yes |
| Bug fix or small targeted enhancement | | yes |
| Spike or proof-of-concept | | yes |
