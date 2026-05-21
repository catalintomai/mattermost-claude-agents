# mattermost-claude-agents

A curated collection of [Claude Code](https://claude.ai/code) agents, skills, and shared rules built for Mattermost engineering. Packaged for easy installation and sharing across team members.

## Structure

```
├── global/
│   ├── agents/     → ~/.claude/agents/                    language-agnostic agents (any project)
│   ├── skills/     → ~/.claude/skills/                    slash-command skills
│   └── docs/       → ~/.claude/docs/                      shared rule & reference docs
├── mattermost/
│   └── agents/     → ~/mattermost/.claude/agents/         MM-suite agents (all Mattermost repos)
└── projects/
    ├── mattermost-plugin-playbooks/   → ~/mattermost/mattermost-plugin-playbooks/.claude/
    ├── mattermost-pages-channel/          → ~/mattermost/mattermost-pages-channel/.claude/
    └── mattermost-plugin-agents/ → ~/mattermost/mattermost-plugin-agents/.claude/
```

**Three-tier discovery**: Claude Code loads agents from global → workspace → project, so MM-suite agents are available in all Mattermost clones without duplicating them per repo.

## Install

```bash
git clone <repo-url> ~/mattermost/mattermost-claude-agents
cd ~/mattermost/mattermost-claude-agents
./install.sh all          # install everything
./install.sh global       # only global agents + skills + docs
./install.sh mattermost   # only MM-suite agents
./install.sh all --dry-run  # preview without copying
```

Restart Claude Code after installing.

---

## Global Agents

Install location: `~/.claude/agents/`  
Available in **any project**.

### Core

| Agent | Description |
|-------|-------------|
| `coder` | Generalist implementation agent for cross-language work |
| `ideation-partner` | Structured ideation: HMW problem → variations → convergence → one-pager |
| `pr-decomposition-sequencer` | Splits a large branch into ordered, independently-mergeable PRs |
| `refactorer` | Atomic refactor: rename everywhere, extract function, move between layers — one commit |
| `tech-debt-refactorer` | Incremental legacy-code rehabilitation planned as a sequence of independently-mergeable PRs |

### Code Review

| Agent | Description |
|-------|-------------|
| `code-reviewer` | General-purpose reviewer: correctness, readability, architecture, security, performance |
| `simplicity-reviewer` | Catches over-engineering, YAGNI violations, speculative abstractions |
| `naming-consistency-reviewer` | Detects naming drift across files, config keys, CLI flags, API fields |
| `structural-health-reviewer` | Finds shotgun surgery, god types, tangled dependencies, orphaned indirection |
| `separation-of-concerns-reviewer` | Catches backend/frontend conflation and false "X requires Y" couplings |
| `drive-by-reviewer` | Finds unrelated changes that slipped into a branch |
| `behavioral-change-reviewer` | Catches semantic changes disguised as refactoring or cleanup |
| `scope-drift-reviewer` | Validates every changed file traces to a requirement in the plan |
| `deprecation-reviewer` | Catches missing migration guides and active consumers of removed code |
| `duplication-reviewer` | Finds copy-paste and missed reuse opportunities |
| `comment-reviewer` | Reviews comment accuracy, godoc completeness, comment rot |
| `hardcoded-values-reviewer` | Catches magic numbers, repeated strings, config values that should be constants |
| `production-reviewer` | Scans for mock/stub/placeholder code in production paths |
| `type-duplication-reviewer` | Audits TS/Go type definitions for duplicate consolidation opportunities |
| `go-silent-failure-reviewer` | Detects ignored errors, blank-identifier suppression, empty handlers (Go) |
| `ts-silent-failure-reviewer` | Same as above for TypeScript/JavaScript |
| `null-safety-reviewer` | Nil pointer dereferences and missing null checks (Go + TS) |
| `error-handling-reviewer` | Missing wrapping, wrong propagation, incorrect error types by layer |
| `skill-reviewer` | Validates Claude Code skill files for frontmatter, description quality, and anti-patterns |

### Architecture & Design Review

| Agent | Description |
|-------|-------------|
| `architecture-assertion-auditor` | Audits ADRs for wrong facts AND invalid reasoning chains |
| `architecture-tradeoff-reviewer` | Compares architectural options across migration cost, complexity, reversibility |
| `design-flaw-reviewer` | Finds logical contradictions, impossible states, mechanism-guarantee mismatches |
| `doc-consistency-reviewer` | Detects internal contradictions, schema-text mismatches, stale cross-references |
| `external-claims-auditor` | Verifies claims about external products against official vendor docs |
| `plan-assertion-reviewer` | Verifies codebase facts named in plans (schemas, signatures, constants) |
| `plan-completeness-checker` | Checks plans for missing/empty sections against template checklists |
| `system-design-reviewer` | Reviews feature designs for semantic mismatches and missing state transitions |
| `multi-agent-architecture-reviewer` | Reviews multi-agent system designs for coordination anti-patterns |
| `agent-reviewer` | Validates Claude Code agent `.md` files for frontmatter and design quality |
| `agent-collection-validator` | Audits the full `~/.claude/agents/` collection for registry accuracy |
| `convergence-reviewer` | Detects semantic thrashing across multi-round swarm review cycles |
| `ux-design-auditor` | Reviews UX designs against Nielsen's heuristics, six persona profiles, and HEART metrics |
| `ux-edge-case-reviewer` | Reviews plans and code for user-facing edge cases: empty states, errors, loading UX |

### Backend

| Agent | Description |
|-------|-------------|
| `go-backend-expert` | Go backend specialist: api4/, app/, store/, model/ |
| `go-expert` | Go expert for non-Mattermost codebases |
| `go-test-writer` | Go test specialist (`*_test.go`) |
| `concurrent-go-reviewer` | Go concurrency: races, deadlocks, goroutine leaks |
| `db-call-reviewer` | N+1 queries, unnecessary DB calls, missing batching |
| `db-migration-expert` | Schema migrations, morph patterns, rollback planning |
| `transaction-reviewer` | Multi-table transaction scope and patterns |
| `batch-operations-reviewer` | Unbounded batches, missing pagination, goroutine spawning in loops |
| `caching-expert` | Three-tier caching (LRU→Redis→PostgreSQL), invalidation order, stampede prevention |
| `postgres-expert` | Complex SQL, indexing, EXPLAIN plans, transaction isolation |
| `database-architecture-auditor` | Schema reviews: missing indexes, normalization, N+1 risks |
| `schema-necessity-reviewer` | Challenges every proposed migration — can existing storage handle it? |
| `ha-reviewer` | HA correctness in multi-node deployments |
| `websocket-expert` | WebSocket lifecycle, reconnection, presence tracking, event design |
| `websocket-event-reviewer` | WS event naming, payload, broadcast scope, handler registration |
| `rest-api-expert` | REST API design: resources, HTTP methods, status codes, pagination |
| `api-design-reviewer` | Reviews REST API implementations (code-level) for contract correctness |
| `api-contract-reviewer` | Reviews API designs and schema proposals (pre-implementation) |
| `backwards-compatibility-reviewer` | Breaking changes in APIs, removed fields, permission tightening |
| `logging-reviewer` | Log levels, structured logging, PII prevention, duplicate logs |

### Frontend

| Agent | Description |
|-------|-------------|
| `react-frontend-expert` | React/TypeScript specialist for Mattermost webapp |
| `react-expert` | React expert for non-Mattermost projects |
| `redux-expert` | Redux actions, reducers, selectors, thunks, RTK |
| `ts-expert` | Advanced TypeScript: conditional types, mapped types, discriminated unions |
| `component-reviewer` | React component patterns, hooks, compound components |
| `race-condition-reviewer` | Async race conditions, stale closures, event handler races (TS/React) |
| `ts-test-writer` | TypeScript/Jest unit tests for components, Redux, hooks |
| `responsive-reviewer` | Breakpoints, touch targets, narrow-width layout |
| `i18n-reviewer` | Translation keys, plural forms, RTL support, locale formatting |
| `ui-pattern-reviewer` | AI aesthetic anti-patterns, WCAG violations, hardcoded colors |
| `accessibility-reviewer` | WCAG 2.1 AA compliance, screen reader support, keyboard navigation |
| `browser-testing-expert` | Uses Chrome DevTools MCP to verify live browser state: screenshots, DOM, console errors, network, performance |

### Security

| Agent | Description |
|-------|-------------|
| `security-auditor` | OWASP Top 10 audit across input handling, auth, data protection |
| `security-orchestrator` | Orchestrates parallel specialist security agents into one report |
| `threat-modeler` | Security architect for threat modeling and security design reviews |
| `permission-reviewer` | Authorization across layers, permission bypasses |
| `permission-design-auditor` | Permission model design — semantic correctness, completeness |
| `xss-reviewer` | XSS prevention in Go templates and React renders |
| `validation-reviewer` | Input validation at API/App entry points |
| `owasp-agentic-auditor` | OWASP Top 10 for Agentic Applications 2026 |
| `aws-ec2-hardening-auditor` | EC2 deployment plans for Security Group misconfigs, IMDSv1, IAM over-permissions |
| `deployment-hardening-auditor` | AI agent deployment plans for process isolation, credential management |

### Testing

| Agent | Description |
|-------|-------------|
| `test-engineer` | Unit and integration test suites, coverage gaps, mock abuse detection |
| `test-coverage-reviewer` | Ensures new functionality has corresponding tests |
| `playwright-test-reviewer` | Playwright E2E tests (`*.spec.ts`): selector stability, wait patterns, anti-patterns |
| `cypress-test-reviewer` | Cypress E2E tests (`*_spec.js`, `*.cy.ts`): DOM detachment, wait patterns, selector stability |
| `playwright-test-writer` | Writes and fixes Playwright E2E tests |
| `playwright-coordinator` | Orchestrates multi-layer Playwright failure diagnosis across DB, API, WebSocket, and UI |
| `playwright-debugger` | Playwright/E2E debugger with database access for inspecting DB state, API responses, and WebSocket events |
| `test-parallelization-reviewer` | Test parallel-safety: shared state, fixture isolation, race conditions |

### Domain Experts

| Agent | Description |
|-------|-------------|
| `plugin-expert` | MM plugin architecture: manifests, hooks, KV store, webapp registry |
| `playbooks-expert` | Mattermost Playbooks: API/App/Store layers, checklist lifecycle, React webapp |
| `playbooks-migration-reviewer` | Playbooks migration additions in `server/sqlstore/migrations.go` |
| `mobile-expert` | React Native mobile patterns for Mattermost mobile app |
| `calls-webrtc-expert` | WebRTC lifecycle, screen sharing, SFU architecture, SRTP/DTLS |
| `copilot-ai-expert` | LLM integration: streaming, context management, rate limiting, RAG |
| `shared-channels-expert` | Shared Channels and remote cluster federation |
| `property-system-expert` | PropertyGroupStore/PropertyFieldStore/PropertyValueStore interfaces |
| `caching-expert` | Mattermost three-tier caching system |
| `slack-migration-expert` | Slack-to-Mattermost migration pipeline |
| `confluence-migration-expert` | Confluence-to-Mattermost wiki migration pipeline |
| `migration-code-orchestrator` | Orchestrates review of mmetl/import*.go for idempotency, integrity, and error handling. Must be top-level — not a subagent |

### Infrastructure & CI

| Agent | Description |
|-------|-------------|
| `ci-expert` | CI/CD pipelines, GitHub Actions, merge gates, branch protection |
| `ci-failure-reviewer` | Diagnoses CI failures: flaky vs real |
| `ci-design-reviewer` | Reviews CI/CD design proposals and workflow changes |
| `ci-gate-reviewer` | Verifies CI merge-gate enforcement when `continue-on-error` or `fail-fast` is touched |
| `launch-readiness-reviewer` | Production readiness: rollback, monitoring, feature flags, staged rollout |

### Python

| Agent | Description |
|-------|-------------|
| `py-async-reviewer` | Python asyncio: blocking calls, fire-and-forget tasks, missing cleanup |
| `py-datetime-reviewer` | Python datetime: timezone consistency, naive datetimes, deprecated APIs |
| `py-sqlite-reviewer` | Python sqlite3: connection management, WAL mode, parameterized queries |

### Shared Rules (`_shared/`)

These files are loaded by agents at runtime — not invoked directly.

| File | Purpose |
|------|---------|
| `grounding-rules.md` | Evidence-based grounding: no unanchored claims |
| `finding-format.md` | Canonical output format for all review agents |
| `eighty-twenty-rule.md` | Minimum change that solves the actual problem |
| `delegation-contract.md` | Goal + Constraints + Return format + Budget for every delegation |
| `diff-scope-rule.md` | Only flag issues in changed lines |
| `false-positive-prevention.md` | Universal false positive prevention principles |
| `review-modes.md` | Default vs thorough review mode convention |
| `reasoning-techniques.md` | Shared verification techniques for assertion auditing |
| `storage-decision-tree.md` | Decision tree for storage placement |
| `test-alignment-rules.md` | Mock-implementation alignment rules |
| `elevated-identity-escalation-pattern.md` | Two privilege-escalation patterns: elevated-identity execution and ownership-flag/mutable-ID decoupling |
| `layer-bypass-vulnerability-pattern.md` | Business logic bypass via parallel entry points that skip layer-level validation |
| `validation-layer-consistency.md` | Business rule enforcement must live at service layer entry points, not just API handlers |
| `error-handling-patterns.md` | Universal Go, TypeScript, and React error handling patterns |
| `db-reference.md` | Relational database reference material for database review agents |
| `security-pr-policy.md` | No exploit details in public PR descriptions |

---

## Mattermost-Suite Agents

Install location: `~/mattermost/.claude/agents/`  
Available in **all Mattermost project clones** under `~/mattermost/`.

These are MM-specific versions of reviewers that understand Mattermost's layer architecture, patterns, and conventions. They override or extend the global agents of the same name.

### Core Layer Experts

| Agent | Purpose |
|-------|---------|
| `api-reviewer` | API handler patterns; verifies API → App layer (never API → Store) |
| `app-reviewer` | App layer patterns and layer-boundary enforcement |
| `store-reviewer` | Store layer patterns, squirrel query builder, transaction scope |
| `go-backend-expert` | Go idioms across api4/, app/, store/, model/ with MM context |
| `react-frontend-expert` | MM webapp React patterns (webapp/channels/src/) |
| `redux-expert` | Redux + MM-specific code-gen conventions |
| `config-expert` | Server settings, feature flags, env vars, plugin settings |
| `db-migration-expert` | Schema migrations with morph, rollback planning |

### Pattern & Compatibility Reviewers

| Agent | Purpose |
|-------|---------|
| `pattern-reviewer` | MM upstream conventions per layer |
| `backwards-compatibility-reviewer` | Breaking API/behavior changes with MM migration gaps |
| `error-handling-reviewer` | MM layer-specific error handling (Go + TS) |
| `comment-reviewer` | Comment accuracy, godoc, copyright headers |
| `hardcoded-values-reviewer` | Magic numbers and constants in MM codebase |
| `production-reviewer` | Mock/stub/placeholder code in MM production paths |
| `duplication-reviewer` | Duplication and reuse opportunities |
| `db-call-reviewer` | N+1 queries, unnecessary DB calls |
| `transaction-reviewer` | DB transaction scope across multi-table writes |
| `concurrent-go-reviewer` | Go concurrency with MM-specific patterns |
| `logging-reviewer` | mlog structured logging, PII, duplicate logs |
| `websocket-event-reviewer` | WS event naming, payload, broadcast scope |
| `component-reviewer` | React component + modal + theme patterns |
| `responsive-reviewer` | Breakpoints, touch targets |
| `i18n-reviewer` | Translation keys, plural forms, RTL |
| `ha-reviewer` | HA correctness in multi-node deployments |
| `xss-reviewer` | XSS prevention in Go templates and React renders |
| `validation-reviewer` | Input validation at API/App entry points |
| `permission-reviewer` | Authorization across layers |
| `permission-design-auditor` | Permission model semantic correctness |
| `batch-operations-reviewer` | Unbounded batches, missing pagination |
| `null-safety-reviewer` | Nil/null safety (Go + TS) |
| `mm-deprecation-reviewer` | MM-specific deprecation patterns and removal timelines |
| `license-reviewer` | License/SKU checks, feature flag gating, cloud vs self-hosted |
| `file-structure-reviewer` | File placement conventions |
| `config-migration-reviewer` | Config restart vs hot-reload, backward compatibility |
| `type-design-reviewer` | Go struct + TS interface design |
| `client-server-alignment-reviewer` | client4.ts ↔ client4.go ↔ api4 alignment |
| `api-contract-reviewer` | API contract completeness before implementation |
| `test-coverage-reviewer` | Test coverage gaps for new/changed code |
| `ci-failure-reviewer` | CI failure diagnosis |
| `jira-alignment-reviewer` | Codebase alignment with Jira-described architecture |

### Feature Domain Experts

| Agent | Purpose |
|-------|---------|
| `plugin-expert` | MM plugin architecture: manifests, hooks, KV store, webapp registry |
| `copilot-ai-expert` | LLM integration: SSE streaming, context window, PII redaction, RAG |
| `mobile-expert` | React Native MM mobile: offline sync, push, touch targets |
| `calls-webrtc-expert` | WebRTC lifecycle, screen sharing, SFU architecture |
| `caching-expert` | Three-tier caching (LRU→Redis→PostgreSQL) |
| `shared-channels-expert` | Shared Channels and remote cluster federation |
| `property-system-expert` | PropertyGroupStore/PropertyValueStore interfaces |
| `slack-migration-expert` | Slack-to-Mattermost migration pipeline |
| `confluence-migration-expert` | Confluence-to-Mattermost wiki migration |
| `playbooks-expert` | Mattermost Playbooks: full stack |
| `playbooks-migration-reviewer` | Playbooks migrations in sqlstore |
| `playbooks-api-parity-reviewer` | Playbooks REST/GraphQL/slash-command API parity |
| `run-lifecycle-reviewer` | Playbooks run state-machine transitions |
| `attribute-template-reviewer` | Playbooks template variable substitution |

### Infrastructure & Debug

| Agent | Purpose |
|-------|---------|
| `debugger` | Root cause analysis with MM layer awareness |
| `performance-optimizer` | DB query optimization, frontend performance, bundle size |
| `playwright-coordinator` | Multi-layer Playwright failure diagnosis |
| `playwright-debugger` | Playwright/E2E debugger with database access |
| `ci-expert` | CI/CD pipelines and GitHub Actions for MM repos |
| `ci-design-reviewer` | Reviews CI/CD design proposals |
| `ci-gate-reviewer` | CI merge-gate enforcement |

### Design & Architecture

| Agent | Purpose |
|-------|---------|
| `system-design-reviewer` | Feature designs for semantic mismatches |
| `architecture-assertion-auditor` | Audits ADRs for wrong facts and invalid reasoning |
| `architecture-tradeoff-reviewer` | Compares architectural options |
| `database-architecture-auditor` | Schema reviews: indexes, normalization, N+1 risks |
| `schema-necessity-reviewer` | Challenges proposed migrations |
| `plan-assertion-reviewer` | Verifies codebase facts in plans |
| `scope-drift-reviewer` | Validates changes trace to requirements |

---

## Skills

Install location: `~/.claude/skills/`  
Invoked as slash commands: `/skill-name`

| Skill | Trigger | Description |
|-------|---------|-------------|
| `review-code` | `/review-code` | Comprehensive code review via specialized agents + multi-LLM. Works on local changes or GitHub PRs (`--pr <num>`) |
| `review-plan` | `/review-plan` | Multi-LLM + domain agent validation for implementation plans |
| `create-plan` | `/create-plan` | Parse requirements → research codebase → consult domain agents → draft structured plan |
| `create-prd` | `/create-prd` | Create PRD via Socratic interviewing and codebase exploration |
| `create-code` | `/create-code` | Implement from an approved plan, with auto-review and TDD support |
| `create-test` | `/create-test` | Generate tests for implemented or planned features |
| `fix-test` | `/fix-test` | Diagnose and fix failing tests with regression test generation |
| `triage-issue` | `/triage-issue` | Diagnose a bug, identify root cause, design TDD fix plan, create Jira ticket |
| `security-fix` | `/security-fix` | TDD-driven fix for security tickets — failing tests first, then implementation |
| `multi-review` | `/multi-review` | Multi-LLM review (GPT + Gemini + Claude) for code and architecture decisions |
| `git-guardrails` | `/git-guardrails` | Install a PreToolUse hook blocking dangerous git commands |

---

## Docs

Install location: `~/.claude/docs/`  
Referenced from `CLAUDE.md` and agents via `@docs/...`.

| File | Purpose |
|------|---------|
| `karpathy-guidelines.md` | Coding discipline examples: think before coding, simplicity, surgical changes |
| `git-safety.md` | Absolute git prohibitions and safe alternatives |
| `file-safety.md` | Pre-operation checks before any destructive file operation |
| `search-first-workflow.md` | Mandatory pre-implementation search workflow |
| `skill-writing.md` | Principles for writing skills that compound rather than rot |
| `multi-llm-review.md` | How to run multi-LLM reviews (GPT + Gemini + Claude) |
| `session-management.md` | Context hygiene, session naming, checkpoints |
| `plan-templates.md` | Structural templates for implementation plans |
| `swarm-harness.md` | How swarm reviews are orchestrated |
| `review-prompts.md` | Standard review prompt patterns |
| `project-context-loading.md` | Three-level agent discovery (global → workspace → project) |
| `selection-rationale.md` | How to choose the right agent for a task |
| `pattern-completeness-rule.md` | Ensures pattern libraries are complete |
| `edge-case-taxonomy.md` | Taxonomy of edge cases for review agents |

---

## Project-Specific Agents & Skills

Install location: `~/mattermost/<project>/.claude/`  
Available **only inside that project directory**.

```bash
./install.sh project:mattermost-plugin-playbooks
./install.sh project:mattermost-pages-channel
./install.sh project:mattermost-plugin-agents
```

---

### mattermost-plugin-playbooks

**Agents**

| Agent | Description |
|-------|-------------|
| `playbooks-e2e-test-reviewer` | Reviews Playwright E2E tests for Playbooks: selectors, fixtures, playbook-specific helpers |
| `playbooks-isolation-reviewer` | Ensures Playbooks plugin code is properly isolated from MM core; no illegal cross-plugin imports |
| `playbooks-pattern-reviewer` | Enforces Playbooks-specific code patterns across API/App/Store layers |

**Skills**

| Skill | Trigger | Description |
|-------|---------|-------------|
| `pb-lint` | `/pb-lint` | Lint Playbooks code for plugin-specific rules and pattern violations |

**Docs**

| File | Purpose |
|------|---------|
| `playbooks-isolation-reference.md` | Reference for plugin isolation boundaries and allowed import paths |

---

### mattermost-pages-channel

**Agents**

| Agent | Description |
|-------|-------------|
| `boards-alignment-reviewer` | Verifies Pages implementation aligns with Boards data model and patterns |
| `confluence-alignment-reviewer` | Checks Pages migration/rendering against Confluence behavior reference |
| `pages-e2e-test-reviewer` | Reviews Playwright E2E tests for Pages: page-specific helpers, editor state, fixtures |
| `pages-isolation-reviewer` | Ensures Pages code is isolated from other plugin boundaries |
| `tiptap-reviewer` | Reviews Tiptap editor integration: extensions, commands, schema, serialization |

**Skills** (project overrides of global skills)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `create-test` | `/create-test` | Pages-aware test generator: knows Pages helpers, E2E patterns, editor test utilities |
| `fix-test` | `/fix-test` | Pages-aware test fixer: understands Pages-specific fixtures and async editor state |

**Commands**

| Command | Description |
|---------|-------------|
| `reset-db` | Reset local Pages development database to clean state |

**Docs**

| File | Purpose |
|------|---------|
| `boards-alignment-reference.md` | Boards data model reference for alignment checks |
| `confluence-migration-reference.md` | Confluence migration patterns and transformation rules |
| `confluence-pattern-reference.md` | Confluence rendering patterns for equivalence testing |
| `pages-e2e-helpers-reference.md` | Available E2E helper functions for Pages tests |
| `pages-isolation-reference.md` | Plugin isolation boundaries for Pages |
| `test-patterns.md` | Pages-specific test patterns and conventions |
| `tiptap-reference.md` | Tiptap schema, extensions, and serialization reference |
| `wiki-api-reference.md` | Wiki API surface and endpoint reference |

---

### mattermost-plugin-agents

**Agents**

| Agent | Description |
|-------|-------------|
| `playwright-test-generator` | Drives a live browser to record user interactions and write a Playwright test file from them |
| `playwright-test-healer` | Runs failing Playwright tests in debug mode, inspects live browser state, and edits the test code to fix failures |
| `playwright-test-planner` | Navigates a live app, maps user flows, and writes a structured test plan document |

> **MCP dependency**: the `browser_*` tools are standard `@playwright/mcp`. The `generator_*`, `planner_*`, `test_run`, and `test_debug` tools are custom — they require the MCP server shipped in `mattermost-plugin-agents`. A plain `@playwright/mcp` install is not sufficient.

---

## Contributing

1. Add or improve an agent/skill in your local `~/.claude/` or `~/mattermost/.claude/`
2. Copy the updated file to the corresponding location in this repo
3. Update the relevant `AGENT_REGISTRY.md` if adding a new agent
4. Open a PR with a description of what the agent/skill does and when to use it
