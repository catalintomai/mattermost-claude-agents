---
name: agent-registry-mattermost
description: Registry of Mattermost-suite agents shared across all Mattermost project clones (mattermost-server, plugin repos, forks). Universal/cross-project agents live in the global registry; project-specific agents live in the project's own .claude/agents/AGENT_REGISTRY.md.
---

# Agent Registry - Mattermost Suite (Level 2)

**Location**: `~/mattermost/.claude/agents/`

This is the **Level 2** registry per the three-level discovery in `~/.claude/docs/project-context-loading.md`. It owns Mattermost-specific agents that apply across every Mattermost clone in this directory tree but are NOT generic enough to live globally.

- **Level 1** (global, language-agnostic): `~/.claude/agents/AGENT_REGISTRY.md`
- **Level 2** (this file, Mattermost-suite): `~/mattermost/.claude/agents/AGENT_REGISTRY.md`
- **Level 3** (per-project): `<project>/.claude/agents/AGENT_REGISTRY.md`

Phase tags (`[PLAN]`, `[CODE]`, `[BOTH]`) defined in `~/.claude/agents/AGENT_REGISTRY.md` § "Phase Tags".

The Parallel Groups routing table for `/review-code` lives in the **global** registry — agent names there resolve to files at any level via discovery.

---

## Catalog

### Mattermost Core Layer Reviewers

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `api-reviewer` | [CODE] | API handler patterns; verifies API → App layer, never API → Store | `mattermost/core/api-reviewer.md` |
| `app-reviewer` | [CODE] | App layer patterns and layer-boundary enforcement | `mattermost/core/app-reviewer.md` |
| `store-reviewer` | [CODE] | Store layer patterns, squirrel query builder, transaction scope | `mattermost/core/store-reviewer.md` |
| `go-backend-expert` | [CODE] | Go idioms across api4/, app/, store/, model/ | `mattermost/core/go-backend-expert.md` |
| `react-frontend-expert` | [CODE] | MM webapp React patterns | `mattermost/core/react-frontend-expert.md` |
| `redux-expert` | [CODE] | Redux patterns and MM-specific code-gen conventions | `mattermost/core/redux-expert.md` |
| `config-expert` | [CODE] | Server settings, feature flags, env vars, plugin settings | `mattermost/core/config-expert.md` |
| `db-migration-expert` | [CODE] | Schema migrations, morph patterns, rollback planning | `mattermost/core/db-migration-expert.md` |

### Mattermost Review (Pattern + Compatibility + Domain Reviewers)

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `pattern-reviewer` | [CODE] | MM upstream conventions per layer | `mattermost/review/pattern-reviewer.md` |
| `comment-reviewer` | [CODE] | Comment accuracy, godoc, copyright headers | `mattermost/review/comment-reviewer.md` |
| `error-handling-reviewer` | [CODE] | Missing/swallowed errors (Go + TS, MM layer-specific) | `mattermost/review/error-handling-reviewer.md` |
| `hardcoded-values-reviewer` | [CODE] | Magic numbers, repeated strings, constants that should be hoisted | `mattermost/review/hardcoded-values-reviewer.md` |
| `production-reviewer` | [CODE] | Mock/stub/placeholder code in production paths | `mattermost/review/production-reviewer.md` |
| `duplication-reviewer` | [CODE] | Duplication and reusability opportunities | `mattermost/review/duplication-reviewer.md` |
| `db-call-reviewer` | [CODE] | N+1 queries, unnecessary DB calls, missing batching | `mattermost/review/db-call-reviewer.md` |
| `transaction-reviewer` | [CODE] | DB transaction scope across multi-table writes | `mattermost/review/transaction-reviewer.md` |
| `concurrent-go-reviewer` | [CODE] | Go concurrency: races, TOCTOU, deadlocks, goroutine leaks | `mattermost/review/concurrent-go-reviewer.md` |
| `logging-reviewer` | [CODE] | Log levels, structured mlog, PII, duplicate logs | `mattermost/review/logging-reviewer.md` |
| `websocket-event-reviewer` | [CODE] | WS event naming, payload, broadcast scope, handler registration | `mattermost/review/websocket-event-reviewer.md` |
| `component-reviewer` | [CODE] | React component + modal + theme patterns | `mattermost/review/component-reviewer.md` |
| `responsive-reviewer` | [CODE] | Breakpoints, touch targets, narrow-width layout | `mattermost/review/responsive-reviewer.md` |
| `i18n-reviewer` | [CODE] | Translation keys, plural forms, RTL, locale formatting | `mattermost/review/i18n-reviewer.md` |
| `ha-reviewer` | [CODE] | High-availability correctness in multi-node deployments | `mattermost/review/ha-reviewer.md` |
| `xss-reviewer` | [CODE] | XSS prevention in Go templates and React renders | `mattermost/review/xss-reviewer.md` |
| `validation-reviewer` | [CODE] | Input validation at API/App entry points | `mattermost/review/validation-reviewer.md` |
| `permission-reviewer` | [CODE] | Authorization across layers, permission bypasses | `mattermost/review/permission-reviewer.md` |
| `permission-design-auditor` | [PLAN] | Permission model design — semantic correctness, completeness | `mattermost/review/permission-design-auditor.md` |
| `backwards-compatibility-reviewer` | [BOTH] | Breaking API/behavior changes, removed fields, migration gaps; PLAN-mode tightening detector | `mattermost/review/backwards-compatibility-reviewer.md` |
| `batch-operations-reviewer` | [CODE] | Unbounded batches, missing pagination, N+1 queries | `mattermost/review/batch-operations-reviewer.md` |
| `null-safety-reviewer` | [CODE] | Null/nil dereferences in Go and TypeScript | `mattermost/review/null-safety-reviewer.md` |
| `mm-deprecation-reviewer` | [CODE] | MM-specific deprecation patterns, removal timelines | `mattermost/review/mm-deprecation-reviewer.md` |
| `license-reviewer` | [CODE] | License/SKU checks, feature flag gating, cloud vs self-hosted | `mattermost/review/license-reviewer.md` |
| `file-structure-reviewer` | [CODE] | File/directory placement conventions for new/moved files | `mattermost/review/file-structure-reviewer.md` |
| `config-migration-reviewer` | [CODE] | Config restart vs hot-reload, backward compatibility, env var naming | `mattermost/review/config-migration-reviewer.md` |
| `type-design-reviewer` | [BOTH] | Go struct + TS interface design, encapsulation, invariants | `mattermost/review/type-design-reviewer.md` |
| `client-server-alignment-reviewer` | [BOTH] | client4.ts ↔ client4.go ↔ api4 alignment | `mattermost/review/client-server-alignment-reviewer.md` |
| `api-contract-reviewer` | [PLAN] | API contract completeness before implementation | `mattermost/review/api-contract-reviewer.md` |
| `test-coverage-reviewer` | [CODE] | Test coverage gaps for new/changed code | `mattermost/review/test-coverage-reviewer.md` |
| `ci-failure-reviewer` | [CODE] | CI failure diagnosis: flaky vs real | `mattermost/review/ci-failure-reviewer.md` |
| `jira-alignment-reviewer` | [BOTH] | Codebase alignment with Jira-described architecture | `mattermost/review/jira-alignment-reviewer.md` |

### Mattermost Features (Domain Experts)

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `plugin-expert` | [CODE] | MM plugin architecture: manifest, hooks, KV store, webapp registry | `mattermost/features/plugin-expert.md` |
| `copilot-ai-expert` | [CODE] | LLM integration: SSE streaming, context window, PII redaction, RAG | `mattermost/features/copilot-ai-expert.md` |
| `mobile-expert` | [CODE] | React Native MM mobile: offline sync, push, touch targets, safe-area | `mattermost/features/mobile-expert.md` |
| `shared-channels-expert` | [CODE] | Remote-cluster federation, cross-server sync, conflict resolution | `mattermost/features/shared-channels-expert.md` |
| `calls-webrtc-expert` | [CODE] | WebRTC peer lifecycle, screen sharing, SFU, SRTP/DTLS | `mattermost/features/calls-webrtc-expert.md` |
| `property-system-expert` | [BOTH] | PropertyGroupStore/PropertyFieldStore/PropertyValueStore patterns | `mattermost/features/property-system-expert.md` |
| `playbooks-expert` | [BOTH] | Playbooks plugin: API/App/Store, SQL migrations, property/condition system | `mattermost/features/playbooks-expert.md` |
| `run-lifecycle-reviewer` | [BOTH] | Playbooks run state machine, status transitions, permission paths | `mattermost/features/run-lifecycle-reviewer.md` |
| `attribute-template-reviewer` | [BOTH] | Playbooks channel-name templates, run-name construction, variable resolution | `mattermost/features/attribute-template-reviewer.md` |
| `playbooks-api-parity-reviewer` | [CODE] | Playbooks REST/GraphQL/slash command parity | `mattermost/features/playbooks-api-parity-reviewer.md` |

### Mattermost Migration (Data Imports)

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `migration-code-orchestrator` | [CODE] | Bulk import / mmetl correctness orchestrator (delegates to source experts) | `mattermost/migration/migration-code-orchestrator.md` |
| `slack-migration-expert` | [CODE] | Slack workspace migration pipeline | `mattermost/migration/slack-migration-expert.md` |
| `confluence-migration-expert` | [CODE] | Confluence XML → mmetl → MM import pipeline | `mattermost/migration/confluence-migration-expert.md` |
| `playbooks-migration-reviewer` | [CODE] | Playbooks plugin migrations.go pattern compliance | `mattermost/migration/playbooks-migration-reviewer.md` |

### Mattermost Infrastructure

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `tech-debt-refactorer` | [CODE] | Legacy code rehabilitation, incremental modernization | `mattermost/infra/tech-debt-refactorer.md` |
| `performance-optimizer` | [CODE] | Profiling and bottleneck elimination across MM stack | `mattermost/infra/performance-optimizer.md` |
| `caching-expert` | [BOTH] | Three-tier cache (LRU → Redis → PG), invalidation order, stampede prevention | `mattermost/infra/caching-expert.md` |

### Mattermost Debug & Implementation

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `debugger` | [CODE] | Investigate failures with MM layer awareness | `mattermost/debug/debugger.md` |
| `playwright-debugger` | [CODE] | E2E test debugging with DB / API / WebSocket inspection | `mattermost/debug/playwright-debugger.md` |
| `playwright-coordinator` | [CODE] | Coordinate multi-layer E2E test diagnosis | `mattermost/debug/playwright-coordinator.md` |
| `refactorer` | [CODE] | Atomic refactor: rename + all call sites in one commit, layer moves, interface changes | `mattermost/infra/refactorer.md` |

### Mattermost Design & System Architecture

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `system-design-reviewer` | [PLAN] | Holistic system design — semantic mismatches, lifecycle gaps, state machines | `mattermost/design/system-design-reviewer.md` |

### Mattermost Test Writers

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `go-test-writer` | [CODE] | Write/fix MM Go tests (`*_test.go`) | `mattermost/testing/go-test-writer.md` |
| `ts-test-writer` | [CODE] | Write/review MM TypeScript/Jest unit tests | `mattermost/testing/ts-test-writer.md` |

### Top-Level (Outside `mattermost/` subdirectory)

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `security-orchestrator` | [CODE] | Coordinates parallel security agents and synthesizes a unified prioritized security report. Must run top-level (uses Task delegation). | `security-orchestrator.md` |

---

## Notes

- The Parallel Groups routing table for `/review-code` lives in the **global** registry. Group definitions reference agent names — discovery resolves the actual file at whichever level it lives.
- When invoked in `--full` / `--thorough` mode, `/review-code` MUST consume the merged agent set from all three levels (see `~/.claude/docs/project-context-loading.md` § "Coverage guarantee").
