---
name: agent-registry-global
description: Registry of all available global agents organized by purpose
---

# Agent Registry - Global Agents

**Location**: `~/.claude/agents/`

> **READ THIS FILE IN FULL before selecting any agents.** The Parallel Groups table — the primary input for agent selection in `/review-code` and `/review-plan` — is directly below. The catalog further down lists ONLY the agents whose files live at this (global) level.
>
> **Mattermost-suite agents** (~60 of them: layer reviewers, MM domain experts, migration agents, etc.) are catalogued in the **Level 2** registry at `~/mattermost/.claude/agents/AGENT_REGISTRY.md`. The Parallel Groups table below references them by name — three-level discovery (`~/.claude/docs/project-context-loading.md`) resolves each name to its actual file at any level.

This registry lists global agents organized by **purpose**. Use the right agent for the right job.

---

## Parallel Groups for Code Review

**Start here for `/review-code`.** Read the trigger table, select groups, then consult the full catalog below for agent details.

Agents within each group are independent and can run simultaneously. **Project registries may add agents to these groups or define new groups** — see project `.claude/agents/AGENT_REGISTRY.md` for overrides.

| Group | Agents | When |
|-------|--------|------|
| Cross-cutting | `simplicity-reviewer`, `code-slop-reviewer`, `naming-consistency-reviewer`, `db-call-reviewer`, `type-duplication-reviewer`, `structural-health-reviewer`, `separation-of-concerns-reviewer`, `code-reviewer`, `architecture-tradeoff-reviewer` | Always (all projects) |
| Backend | `api-reviewer`, `app-reviewer`, `store-reviewer`, `pattern-reviewer`, `concurrent-go-reviewer`, `go-silent-failure-reviewer`, `error-handling-reviewer`, `hardcoded-values-reviewer`, `production-reviewer`, `duplication-reviewer`, `logging-reviewer`, `websocket-event-reviewer`, `comment-reviewer`, `transaction-reviewer`, `ha-reviewer`, `api-design-reviewer` | Go changes, api4/ route changes |
| Frontend | `react-frontend-expert`, `redux-expert`, `component-reviewer`, `race-condition-reviewer`, `ux-edge-case-reviewer`, `ts-silent-failure-reviewer`, `ts-test-writer`, `responsive-reviewer`, `i18n-reviewer`, `ui-pattern-reviewer` | TS/React changes |
| Compatibility | `backwards-compatibility-reviewer`, `batch-operations-reviewer`, `null-safety-reviewer`, `deprecation-reviewer`, `license-reviewer`, `file-structure-reviewer`, `config-migration-reviewer`, `type-design-reviewer`, `client-server-alignment-reviewer`, `schema-necessity-reviewer`, `launch-readiness-reviewer` | `model/` changes, API surface changes, new files/dirs, config changes |
| Infrastructure | `ci-failure-reviewer`, `ci-gate-reviewer`, `ci-design-reviewer` | CI/CD file changes or `--ci` flag |
| Security | `xss-reviewer`, `validation-reviewer`, `permission-reviewer`, `owasp-agentic-auditor`, `accessibility-reviewer`, `security-auditor` | `--thorough` |
| Testing | `playwright-test-reviewer`, `cypress-test-reviewer`, `test-parallelization-reviewer`, `behavioral-change-reviewer`, `test-coverage-reviewer`, `test-engineer` | Test file changes, test setup refactoring, parallel mode changes |
| Python | `py-async-reviewer`, `py-datetime-reviewer`, `py-sqlite-reviewer` | Python (`.py`) changes |
| Playbooks domain | `run-lifecycle-reviewer`, `attribute-template-reviewer`, `playbooks-api-parity-reviewer`, `playbooks-expert` | Any PR in a Playbooks plugin repo (`server/app/`, `server/api/`, `server/sqlstore/`, `client/`) |
| Playbooks migrations | `playbooks-migration-reviewer` | `server/sqlstore/migrations.go` or `server/plugin.go` changes in playbooks plugin |
| Deep experts | `go-expert`, `ts-expert`, `react-expert`, `websocket-expert`, `postgres-expert`, `jira-alignment-reviewer` | `--full` or `--thorough` only |
| Project | *(see project `.claude/agents/AGENT_REGISTRY.md`)* | Project-specific changes |

---

### Phase Tags

Every agent is tagged for swarm routing:

| Tag | Meaning | Use in |
|-----|---------|--------|
| `[PLAN]` | Reviews designs, plans, architecture docs | Plan-review swarms only |
| `[CODE]` | Reviews or writes actual code | Code-review swarms only |
| `[BOTH]` | Applicable to plans AND code | Either swarm type |

**Routing rule**: Plan-review swarms (`/review-plan`, `/create-plan`) MUST NOT spawn `[CODE]`-only agents. Code-review swarms (`/review-code`, `/review-code --swarm`) MUST NOT spawn `[PLAN]`-only agents.

---

## Quick Reference: Which Agents to Use

| Task | Phase | Skill | Agents |
|------|-------|-------|--------|
| Review a plan | [PLAN] | `/review-plan` | `design-flaw-reviewer`, `simplicity-reviewer`, + domain agents |
| Create a plan | [PLAN] | `/create-plan` | Same as above (built into workflow) |
| Review architecture docs | [PLAN] | Direct use | `doc-consistency-reviewer` + `design-flaw-reviewer` + `doc-opacity-reviewer` + `mm-doc-clarity-reviewer` |
| Review code | [CODE] | `/review-code` | `pattern-reviewer`, `error-handling-reviewer`, `simplicity-reviewer`, + tier agents |
| Debug failures | [CODE] | Direct use | `debugger`, `playwright-debugger` |
| Refactor code | [CODE] | Direct use | `refactorer` |

---

## 1. PLAN REVIEW Agents

Use with `/create-plan` and `/review-plan`. Review design BEFORE implementation.

### MUST RUN (Every Plan)

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `design-flaw-reviewer` | [PLAN] | Logical flaws, missing steps | `review/` |
| `simplicity-reviewer` | [BOTH] | Over-engineering, YAGNI | `review/` |
| `plan-completeness-checker` | [PLAN] | Structural completeness — MISSING/EMPTY/INCOMPLETE sections (auto-run at Step 2.25 in `/create-plan`; MISSING/EMPTY block the plan) | `review/` |
| `plan-assertion-reviewer` | [PLAN] | Verify factual claims against codebase AND reasoning validity (auto-run at Step 2.5 in `/create-plan`; MUST_FIX findings block the plan) | `review/` |

### MUST RUN (Architecture Docs)

For long-form architecture documents, design specs, PRDs - NOT short implementation plans.

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `doc-consistency-reviewer` | [PLAN] | Internal inconsistencies, schema-text mismatch, terminology drift | `review/` |
| `doc-opacity-reviewer` | [PLAN] | First-read comprehension — undefined specialist terms, compressed one-liner conclusions, spatial metaphors standing in for a mechanism, forward references. Context-starved (reads only the page). Advisory; distinct from doc-consistency-reviewer (cross-refs/naming). | `(root)` |
| `mm-doc-clarity-reviewer` | [PLAN] | Comprehension at the SENIOR-MM-engineer bar (knows the platform, not the feature domain). Four shapes: domain-term/subtlety unglossed, nominalization stacks (coined nouns defining each other), mechanism-metaphors & misused terms ("projection" for a copy), define-once violations (cross-cutting term not in glossary). In-voice low-verbosity fixes; holds the MM-basics line. Run AFTER mm-doc-voice-reviewer. Distinct from doc-opacity-reviewer (fresh-reader, context-starved, over-flags canon). | `(root)` |

### Architecture (Complex Plans)

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `architecture-assertion-auditor` | [PLAN] | Verify factual claims AND reasoning in architecture docs | `review/` |
| `slop-detector` | [PLAN] | Flag generic/unsupported writing in architecture docs — unanchored claims, weasel tokens, empty tradeoffs, absent failure modes; produces targeted rewrite diffs | `review/` |
| `reuse-detector` | [PLAN] | Two-level novelty scan: (1) novelty verbs ("introduces a subsystem"), (2) novel mechanisms (new column/prop key/table/constant) verified against master's existing mechanism for the same concern — catches wrappers framed as new subsystems AND mechanism duplication like `Props["snapshot_kind"]` when master already discriminates via `OriginalId + DeleteAt > 0` | `review/` |
| `symbol-sweep-reviewer` | [PLAN] | Mechanical pre-pass: extracts every named symbol the plan references (constants, tables, columns, permissions, methods, flags) and greps codebase. Anchored=PASS, MISSING=FLAG with literal grep evidence, AMBIGUOUS=reports closest-match candidate. Fast (Haiku), no reasoning. Run first to catch symbol-level hallucinations before reasoning agents spend tokens. | `review/` |
| `separation-of-concerns-reviewer` | [BOTH] | Layer violations | `review/` |
| `architecture-tradeoff-reviewer` | [BOTH] | Compare design options across cost/complexity/reuse | `review/` |
| `multi-agent-architecture-reviewer` | [PLAN] | Multi-agent system designs — orchestration contracts, inter-agent data flow, memory sharing, failure handling | `review/` |
| `api-design-reviewer` | [BOTH] | API and interface design — contract-first compliance, error semantics, pagination, naming conventions, breaking changes | `review/` |
| `abac-design-reviewer` | [PLAN] | ABAC designs — policy engine / PDP-PEP architecture, attribute pipeline, per-resource policies — against the ABAC anti-pattern catalog (fail-open, BOLA object-surface gaps, engine-as-grantor, attribute provenance/staleness, combining-algorithm, inheritance, scale). Distinct from `permission-design-auditor` (operation→permission semantics) | `(root)` |
| `rbac-design-reviewer` | [PLAN] | RBAC designs — role catalog, hierarchy/inheritance, default & admin roles, assignment scope, SoD — against the RBAC anti-pattern catalog (role explosion, god roles, over-powerful defaults, privilege creep, toxic combinations, deny-in-an-additive-model, dangerous role unions). Distinct from `abac-design-reviewer` (policy/attribute designs) and `permission-design-auditor` (operation→permission semantics) | `(root)` |

> MM-specific architecture reviewers (`system-design-reviewer`, `client-server-alignment-reviewer`, `permission-design-auditor`, `type-design-reviewer`) are catalogued in the Level 2 registry at `~/mattermost/.claude/agents/AGENT_REGISTRY.md`.

### Domain-Specific (Based on Plan)

| Agent | Phase | When | Location |
|-------|-------|------|----------|
| `rest-api-expert` | [PLAN] | REST API design | `tech/` |
| `database-architecture-auditor` | [PLAN] | Schema changes (correctness) | `review/` |
| `schema-necessity-reviewer` | [BOTH] | Schema changes (necessity — prefer existing storage; challenge unnecessary migrations) | `review/` |
| `ux-design-auditor` | [PLAN] | UI/UX changes + edge cases/error states | `review/` |
| `threat-modeler` | [PLAN] | Security features | `security/` |
| `owasp-agentic-auditor` | [BOTH] | OWASP Top 10 for Agentic Applications — goal hijacking, tool misuse, least agency violations | `security/` |
| `deployment-hardening-auditor` | [BOTH] | Deployment hardening for AI agent systems — process isolation, network controls, credential storage, tool policy | `security/` |
| `aws-ec2-hardening-auditor` | [BOTH] | AWS EC2 deployment hardening — security groups, IMDSv2, IAM least-privilege, VPC, EBS encryption | `security/` |
| `external-claims-auditor` | [PLAN] | Two modes: (1) AUDIT — verify external-product claims (Confluence, Notion, etc.) in docs/plans against vendor docs; (2) BUILD — construct a verified single-product capability inventory from vendor docs (a research artifact that feeds product-strategy work). | `review/` |
| `ci-design-reviewer` | [BOTH] | CI/CD pipeline changes, GitHub Actions workflows, cross-repo build coordination, merge gates, automation trust boundaries | `review/` |

> MM-specific plan reviewers (`api-contract-reviewer`, `backwards-compatibility-reviewer`) are catalogued in the Level 2 registry.

### Playbooks Plugin (mattermost-plugin-playbooks*)

Catalogued in the Level 2 registry (`~/mattermost/.claude/agents/AGENT_REGISTRY.md` § "Mattermost Features"): `playbooks-expert`, `run-lifecycle-reviewer`, `attribute-template-reviewer`, `playbooks-api-parity-reviewer`. Run ALL FOUR when reviewing any plan or PR that touches the Playbooks plugin codebase — they catch domain-specific issues (transaction scope, template resolution, lifecycle state machine, permission paths) that generic agents miss.

### Reference Docs (not agents)

| Doc | Purpose | Location |
|-----|---------|----------|
| `review-prompts` | Code review prompt template and output format | `~/.claude/docs/review-prompts.md` |
| `swarm-harness` | Swarm lifecycle, convergence, env var guard | `~/.claude/docs/swarm-harness.md` |

> Project registries may add their own Reference Docs table — see `<project>/.claude/agents/AGENT_REGISTRY.md`.

---

## 2. CODE REVIEW Agents

Use with `/review-code`. Review implementation AFTER coding.

### Tier 0: Universal (Every Project, Every Language)

These agents catch issues that apply regardless of language, framework, or project. **Always run on every codebase.**
Detection logic is language-agnostic — no Go/TS/MM-specific rules.

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `simplicity-reviewer` | [BOTH] | Over-engineering, YAGNI violations | `review/` |
| `code-slop-reviewer` | [CODE] | AI-generation slop the simplicity/duplication reviewers leave uncovered — dead code (unused imports/vars/params/unexported symbols/struct fields, verified project-wide), god functions, redundant defensive nesting & repeated guards, cargo-cult resilience machinery, convention-drift, noise comments. Defers abstraction/YAGNI → `simplicity-reviewer`, dup code/types → `duplication-reviewer`/`type-duplication-reviewer`, orphaned indirection & god TYPES → `structural-health-reviewer` | `review/` |
| `naming-consistency-reviewer` | [BOTH] | File/variable/config naming pattern drift | `review/` |
| `type-duplication-reviewer` | [CODE] | Type duplication across Go structs and TypeScript interfaces | `review/` |
| `structural-health-reviewer` | [BOTH] | Accumulated structural fragility — shotgun surgery, god types, tangled deps, orphaned indirection, responsibility scatter | `review/` |
| `code-reviewer` | [CODE] | General code review — correctness, readability, architecture, security, performance (use MM-specific reviewers for MM projects) | `review/` |
| `deprecation-reviewer` | [BOTH] | Deprecation plans and removal PRs — replacement readiness, migration docs, zombie code (generic; use `mm-deprecation-reviewer` for MM projects) | `review/` |

### Tier 1: Core (Mattermost Projects)

Catalogued in the Level 2 registry: `pattern-reviewer`, `comment-reviewer`, `error-handling-reviewer`, `hardcoded-values-reviewer`, `production-reviewer`, `duplication-reviewer`, `db-call-reviewer`.

### Tier 2: Security

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `accessibility-reviewer` | [CODE] | WCAG compliance, screen reader, keyboard nav | `security/` |
| `security-auditor` | [CODE] | Practical exploitable vulnerabilities — OWASP Top 10, injection, auth/authz, data protection, infrastructure hardening | `security/` |

> MM-specific security reviewers (`xss-reviewer`, `validation-reviewer`, `permission-reviewer`) are catalogued in the Level 2 registry.

### Tier 3: Backend (Go)

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `go-silent-failure-reviewer` | [CODE] | Silent error patterns in Go — ignored returns, empty catch blocks, swallowed errors in deferred functions | `review/` |

> MM-specific Go backend agents (`go-backend-expert`, `api-reviewer`, `app-reviewer`, `store-reviewer`, `transaction-reviewer`, `concurrent-go-reviewer`, `logging-reviewer`, `websocket-event-reviewer`) are catalogued in the Level 2 registry.

### Tier 3b: Backend (Python)

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `py-async-reviewer` | [CODE] | asyncio patterns: blocking calls, fire-and-forget tasks, missing cleanup, concurrent state mutation | `review/` |
| `py-datetime-reviewer` | [CODE] | Naive datetime bugs, `utcnow()` deprecation, `strptime` without tz, mixed naive/aware comparisons | `review/` |
| `py-sqlite-reviewer` | [CODE] | Python `sqlite3` module: WAL mode, parameterized queries, context managers, unbatched IN clauses, busy_timeout | `review/` |

### Tier 4: Frontend (TS/React)

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `race-condition-reviewer` | [CODE] | TS/React async races, stale closures | `review/` |
| `ux-edge-case-reviewer` | [BOTH] | User-facing edge case quality: empty states, error messages, loading UX, degraded experiences — reviews plans when UI states/behaviors are described in enough detail; reviews code for implementation quality | `review/` |
| `ts-silent-failure-reviewer` | [CODE] | Silent error patterns in TypeScript/JS — empty catch blocks, unhandled promises, swallowed rejections, fire-and-forget async | `review/` |
| `ui-pattern-reviewer` | [CODE] | UI design system compliance, accessibility (WCAG 2.1 AA), component architecture, AI aesthetic anti-patterns, spacing/color tokens | `review/` |

> MM-specific frontend agents (`react-frontend-expert`, `redux-expert`, `component-reviewer`, `responsive-reviewer`, `ts-test-writer`) are catalogued in the Level 2 registry.

### Tier 5: Testing

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `test-parallelization-reviewer` | [CODE] | Test parallel-safety: shared state, env leaks, fixture isolation, race conditions under concurrent execution | `review/` |
| `behavioral-change-reviewer` | [CODE] | Semantic behavior changes disguised as refactoring — changed assertions, status codes, control flow in "cleanup" PRs | `review/` |
| `playwright-test-reviewer` | [CODE] | **Review** Playwright E2E tests (read-only: conventions, anti-patterns) — `*.spec.ts` only | `testing/` |
| `cypress-test-reviewer` | [CODE] | **Review** Cypress E2E tests (read-only: DOM detachment, wait patterns, selector stability) — `*_spec.js`, `*.cy.ts` | `testing/` |
| `test-engineer` | [CODE] | Test strategy, unit/integration test writing, coverage analysis, mock quality analysis — language-agnostic | `testing/` |

> MM-specific test reviewer (`test-coverage-reviewer`) is catalogued in the Level 2 registry.

> **`playwright-test-writer`** is an **implementation** agent (Write/Edit/Bash), not a reviewer.
> Use it to **write or fix** E2E tests. Use `playwright-test-reviewer` (Playwright) or `cypress-test-reviewer` (Cypress) to **review** them.

### Tier 6: Compatibility & Safety

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `launch-readiness-reviewer` | [CODE] | Production readiness — pre-launch checklist, feature flags, staged rollout thresholds, rollback plan validation | `review/` |

> MM-specific compatibility/safety agents (`backwards-compatibility-reviewer`, `batch-operations-reviewer`, `null-safety-reviewer`, `mm-deprecation-reviewer`, `license-reviewer`, `file-structure-reviewer`, `config-migration-reviewer`) are catalogued in the Level 2 registry.

### Tier 7: Infrastructure & Debug

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `ci-design-reviewer` | [BOTH] | CI/CD design: workflow triggers, secret scoping, cross-repo coordination, merge gates, rollout safety | `review/` |
| `ci-gate-reviewer` | [CODE] | CI merge gate enforcement: continue-on-error semantics, allow-failure settings, required status check alignment | `review/` |
| `ci-expert` | [CODE] | CI/CD implementation: GitHub Actions workflows, merge gates, branch protection, cross-repo coordination, automation bots | `tech/` |

> MM-specific CI agent (`ci-failure-reviewer`) is catalogued in the Level 2 registry.

### Tier 8: Domain & Expert

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `go-expert` | [CODE] | Go concurrency, microservices, cloud-native | `tech/` |
| `react-expert` | [CODE] | React hooks, performance, modern patterns | `tech/` |
| `ts-expert` | [CODE] | Advanced TypeScript, type systems | `tech/` |
| `websocket-expert` | [CODE] | WebSocket, real-time communication | `tech/` |
| `postgres-expert` | [CODE] | PostgreSQL | `tech/` |

> MM-specific domain experts (`ha-reviewer`, `jira-alignment-reviewer`, `i18n-reviewer`) are catalogued in the Level 2 registry.

---

## 3. IMPLEMENTATION Agents

Use directly for doing work (not reviewing).

### Core Implementation

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `coder` | [CODE] | Write code | `core/` |
| `ideation-partner` | [BOTH] | Structured ideation — refine vague ideas into actionable MVP concepts through divergent/convergent thinking phases | `core/` |
| `pr-decomposition-sequencer` | [BOTH] | Analyzes a large feature branch and produces an ordered, independently-mergeable PR sequence — clusters files by feature, builds a cross-layer dependency graph, outputs a merge-ordered plan | `core/` |
| `feature-schedule-builder` | [PLAN] | Builds an AI-driven-development delivery schedule in relative review cycles (Day/Week N) from a caller-pointed feature table + a live code scan. Paced by HUMAN REVIEW BANDWIDTH (PRs verifiable+mergeable per cycle, parallel-PR cap, dependency serialization) — NOT human coding velocity/story points, since AI writes the code. Verifies build status against code (drops done features), estimates each remaining feature in review cycles with confidence `[derived]`, sequences by dependency + release bucket. Project-agnostic (table path / columns / layer order are inputs). Distinct from `feature-prioritization-expert` (prioritizes, no schedule) and `pr-decomposition-sequencer` (splits a branch diff, human-merge cadence). | `core/` |
| `playwright-test-writer` | [CODE] | Write/fix Playwright E2E tests | `testing/` |
| `browser-testing-expert` | [CODE] | Browser testing and debugging with Chrome DevTools MCP — visual verification, network analysis, accessibility tree, performance profiling | `tech/` |

> MM-specific implementation/debug agents (`debugger`, `refactorer`, `go-test-writer`, `playwright-debugger`, `playwright-coordinator`) are catalogued in the Level 2 registry.

### PRD / Strategy

Use these BEFORE `/create-prd` when the question is "which features should we build at all" (multi-feature strategy) rather than "what are the requirements for this one feature" (single-feature PRD). They produce analytical artifacts — competitive matrices, prioritized rankings, trend reports — that feed into product-strategy docs and downstream `/create-prd` invocations.

| Agent | Phase | Purpose | Location |
|-------|-------|---------|----------|
| `competitive-product-analyst` | [PLAN] | Cross-product feature matrix from primary sources (vendor docs, pricing, changelogs). Classifies features as Table Stakes / Widespread / Differentiation Opportunity / Declining, plus a `⚑poorly-served` quality flag (present everywhere but universally criticized = highest-value build-better target); distinguishes capability from quality; surfaces user-sentiment as `[user-signal]` hypotheses. | `core/` |
| `feature-prioritization-expert` | [PLAN] | Applies ≥2 of RICE / MoSCoW / Kano / JTBD to a candidate feature list, synthesizes consensus picks vs framework outliers, surfaces stealth must-haves (Basic Kano + low RICE). Requires a defined release scope. | `core/` |
| `product-trend-researcher` | [PLAN] | Mines emerging patterns from vendor launches, conference talks, research papers, funding events. Classifies Mainstream / Emerging / Speculative / Declining / Hype with named evidence + dates (Mainstream requires adoption evidence, not just ship-count). Detects fads vs trends via follow-up-shipping signals. | `core/` |
| `feature-usage-researcher` | [PLAN] | Estimates how heavily individual features of a SINGLE product are actually used by mining multi-proxy signals (vendor marketplace install counts per category, migration-tool fidelity gap reports, community/Reddit/HN post frequency, third-party surveys). Output: per-feature usage-signal score (HIGH/MEDIUM/LOW/NO-EVIDENCE) with explicit proxy citations + honest "no first-party telemetry" disclaimer. Use to ground feature prioritization in usage frequency, not just feature presence in vendor docs or pain complaints. | `core/` |
| `voice-of-customer-researcher` | [PLAN] | Mines SINGLE-product customer sentiment on BOTH poles — ranked pain themes (most-complained-about) AND per-feature LOVED/NEUTRAL/DISLIKED satisfaction — from review sites (G2/Capterra/TrustRadius), community forums, Reddit, HN. Output: pain-theme list + satisfaction table with proxy citations + honest "no vendor sentiment telemetry; review sentiment is self-selection-biased" disclaimer. The sentiment lens; pairs with `feature-usage-researcher` as a usage × satisfaction 2x2. NOT for usage frequency, cross-product comparison, vendor-doc presence, or trends. | `core/` |

> Related: `ideation-partner` (Core Implementation above) — brainstorming new features that can then be passed to `feature-prioritization-expert` for ranking. `external-claims-auditor` (§ 1 Plan Review) — single-product fact verification (this group's focus is multi-product analysis). The five product-research lenses on one feature set: `competitive-product-analyst` (cross-product presence) + `external-claims-auditor` (single-product vendor-doc presence) + `feature-usage-researcher` (within-product usage frequency) + `voice-of-customer-researcher` (within-product sentiment: pain + satisfaction) + `feature-prioritization-expert` (criticality/ranking). Usage × satisfaction is the highest-value pairing (HIGH-usage × DISLIKED = differentiation opportunity).

---

## 4. SWARM PATTERNS

### Convergence Infrastructure

| Agent | Purpose | Location |
|-------|---------|----------|
| `convergence-reviewer` | Detects semantic thrashing across rounds — classifies reversals as justified/unjustified/indeterminate | `review/` |
| `scope-drift-reviewer` | Validates code changes implement plan requirements — catches unrelated fixes, refactorings, and opportunistic cleanup | `review/` |
| `drive-by-reviewer` | Detects drive-by changes unrelated to the feature: dead code removal, pre-existing bug fixes, opportunistic refactoring, unasked-for additions. Works without a plans/ file — infers scope from branch name and diff anchors. | `~/.claude/agents/` |

### Collection Validation

| Agent | Purpose | Location |
|-------|---------|----------|
| `agent-collection-validator` | Validates cross-agent consistency: registry accuracy, dead cross-references, contamination, buggy examples, format compliance, naming conventions, scope overlap. Run after adding or modifying any agent. | `review/` |
| `agent-reviewer` | Validates individual agent quality: frontmatter, tools, prompt structure, agentic design. | `review/` |
| `skill-reviewer` | Validates Claude Code skill files (.claude/skills/) against Anthropic's official best practices. Checks frontmatter, description quality, structure, progressive disclosure, anti-patterns, and token efficiency. | `review/` |

### Security Orchestration

> Orchestrators use Task to delegate — they MUST run as top-level agents, NOT as subagents.

`security-orchestrator` is catalogued in the Level 2 registry (`~/mattermost/.claude/agents/AGENT_REGISTRY.md` § "Top-Level"). It coordinates `xss-reviewer`, `permission-reviewer`, `threat-modeler`, and other security agents for comprehensive security passes.

### Orchestration Model

All agents in this registry are **leaf nodes** — they receive a prompt, do their work, and return findings. They do **not** self-coordinate.

Coordination is handled by the **orchestrator** (a skill like `/review-code --swarm`, or the main Claude Code session). The orchestrator:
1. Spawns agents via `Task(subagent_type=..., prompt=...)`
2. Collects results from each agent's return value
3. Synthesizes and deduplicates findings

For team-based coordination, the orchestrator (not agents) uses `TeamCreate`, `TaskCreate`, `TaskList`, and `SendMessage`.

### Swarm Error Handling

See `~/.claude/docs/swarm-harness.md` § "Agent Error Handling" for the canonical table.

### Swarm Result Format

All review agents MUST use the canonical format defined in `_shared/finding-format.md` (MUST_FIX / SHOULD_FIX / PASS with `[agent:TAG]` prefixes).

Leader deduplicates by file+line+tag, keeps highest severity when overlapping.

---

## 5. DOMAIN EXPERTS

Mattermost feature/core/infra/migration domain experts (`plugin-expert`, `copilot-ai-expert`, `mobile-expert`, `shared-channels-expert`, `calls-webrtc-expert`, `property-system-expert`, `config-expert`, `db-migration-expert`, `tech-debt-refactorer`, `performance-optimizer`, `caching-expert`, `migration-code-orchestrator`, `slack-migration-expert`, `confluence-migration-expert`, `playbooks-migration-reviewer`) are catalogued in the **Level 2** registry at `~/mattermost/.claude/agents/AGENT_REGISTRY.md` § "Mattermost Features", "Mattermost Migration", and "Mattermost Infrastructure".

For project-specific domain experts, see the project's own `.claude/agents/AGENT_REGISTRY.md` (Level 3).

---

## How to Use

### Skills (preferred — handle agent selection automatically)
```
/create-plan "feature description"    # Plan with review
/review-plan plan.md                  # Review a plan
/review-code                          # Sequential code review
/review-code --swarm                         # Parallel code review (3-5x faster)
/fix-test app --swarm                 # Parallel test fixing
```

### Direct Agent Use
```
Task(subagent_type="<agent-name>", prompt="<context + task>")
```

### Parallel Agent Use (orchestrator spawns multiple)
```
# Multiple Task calls in one message — agents run in parallel
Task(subagent_type="<agent-1>", prompt="...")
Task(subagent_type="<agent-2>", prompt="...")
```

Agents are leaf nodes. The orchestrator collects their results and synthesizes.

### Project-Specific Agents

Project registries (`.claude/agents/AGENT_REGISTRY.md`) define additional agents that are auto-discovered via three-level agent discovery (see `~/.claude/docs/project-context-loading.md`). Do NOT duplicate project agents here — they are loaded at runtime from the project level.

---

## 6. AGENT NAMING CONVENTIONS

Agent names follow a suffix convention that signals capabilities and tool access:

| Suffix | Meaning | Tool Access |
|--------|---------|-------------|
| `-expert` | Can both write code AND review | Read, Write, Edit, Grep, Glob (full write access) |
| `-reviewer` | Read-only review agent | Read, Grep, Glob only (plus Write for swarm output files) |
| `-auditor` | Deep verification agent | Read, Grep, Glob, WebSearch (reads code + external claims) |
| `-checker` | Lightweight structural validation | Read, Grep, Glob (fast, focused checks only) |
| `-writer` | Generates code or tests (test writers, code generators) | Read, Write, Edit, Bash, Grep, Glob |
| `-debugger` | Diagnoses and fixes failures interactively | Read, Write, Edit, Bash, Grep, Glob |
| `-refactorer` | Restructures existing code | Read, Write, Edit, Bash, Grep, Glob |
| `-optimizer` | Improves performance of existing code | Read, Write, Edit, Bash, Grep, Glob |
| `-orchestrator` | Coordinates other agents via Task delegation | Read, Write, Grep, Glob, Task |
| `-coordinator` | Coordinates parallel workflows | Read, Write, Bash, Grep, Glob, Task |
| `-validator` | Validates collections or configurations (heavier than -checker) | Read, Write, Grep, Glob |
| `-analyst` | Multi-source analytical research producing non-findings artifacts (matrices, classification reports) | Read, Write, WebSearch, WebFetch (+ Grep, Glob only if local docs are in scope) |
| `-researcher` | Mines emerging patterns from primary external evidence (vendor launches, papers, funding events) — produces trend reports, not findings | Read, Write, WebSearch, WebFetch (+ Grep, Glob only if local docs are in scope) |

**Rules**:
- Do NOT give `-reviewer` agents `Edit` or `Bash` tools — they should never modify source files
- `-expert` agents may be called by orchestrators to both diagnose and fix
- `-auditor` agents use `WebSearch` to verify external claims (e.g., `architecture-assertion-auditor`, `external-claims-auditor`)
- `-checker` agents are fast-path validators suitable for blocking plan approval (e.g., `plan-completeness-checker`)
- `-analyst` and `-researcher` agents produce analytical artifacts (matrices, ranked lists, trend reports), NOT severity-graded findings — they do NOT follow `_shared/finding-format.md` and instead use a custom output template per agent (the `[agent:NAME]` prefix is still required for multi-agent attribution)

**Accepted exceptions**:
- `-reviewer` agents MAY have `Bash` when their review requires running diagnostic commands (git diff, test runners, build checks)
- `-reviewer` agents MAY have `Edit` when they operate in BOTH plan and code phases and need to apply fixes
- `-reviewer` agents MAY have `WebSearch` or MCP read-only tools when their review scope includes verifying external claims — but prefer `-auditor` suffix in that case
- `-expert` agents whose output is analytical documentation (not source-code edits) MAY omit `Edit` and `Bash` from their tool set — e.g., `feature-prioritization-expert` produces a prioritization report, so `Read, Write, Grep, Glob` is the correct minimal set; the `-expert` suffix is retained because the agent encodes methodological expertise (framework knowledge), not artifact type
- These exceptions MUST be documented in the agent's frontmatter or prompt
