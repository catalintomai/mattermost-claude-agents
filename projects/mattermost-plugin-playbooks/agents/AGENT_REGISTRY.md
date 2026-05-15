# Agent Registry — mattermost-plugin-playbooks

Project-specific agents for the Mattermost Playbooks plugin.

Loaded alongside global agents from `~/.claude/agents/`. This file lists **only agents unique to this project** — agents already covered by global Parallel Groups (Backend, Frontend, Compatibility, Playbooks domain, Playbooks migrations, Testing, etc.) are not repeated here.

Phase tags: `[PLAN]` = design/planning phase; `[CODE]` = implementation/review phase; `[BOTH]` = either phase.

---

## Project-Specific Agents

These agents are added to the global **Project** group and run on every PR in this repo.

| Agent | Phase | Purpose | When |
|-------|-------|---------|------|
| `playbooks-pattern-reviewer` | [CODE] | Reviews new code against established patterns in every layer: squirrel builder in store, sentinel errors and template/validation/creation-rules helpers in app, resolver structure and `classifyAppError` in GraphQL, fail-open permission checks, and client library patterns (`*[]string` for update-option slices, error return style). | Always |
| `playbooks-isolation-reviewer` | [CODE] | Reviews Playbooks plugin code for clean integration with Mattermost core: no writes to core tables, pluginAPI used for single-entity lookups, layer boundaries respected (API→App→Store), no duplication of existing utilities, property system scoped to groupID, WebSocket events namespaced, config writes scoped to plugin namespace, scheduler started before migrations. | Always |
| `scope-drift-reviewer` | [CODE] | Validates that every code change traces to a requirement in `plans/` and flags unrelated fixes, refactorings, or improvements to pre-existing master code. Catches scope drift and opportunistic cleanup. | Always |
| `property-system-expert` | [CODE] | Reviews PropertyGroup/Field/Value CRUD patterns, property system integration, and `server/app/property_service.go` conventions. | When `server/app/property*.go` or `server/sqlstore/property*.go` changed |
| `playbooks-e2e-test-reviewer` | [CODE] | Reviews Cypress E2E specs in `e2e-tests/` for Playbooks conventions: `--browser chrome` requirement, support helper usage (`cy.api*`, `cy.playbooks*`), utility imports, `{testIsolation: true}`, `before`/`beforeEach`/`afterEach` separation, resource cleanup, `getRandomId()` naming, and named GraphQL intercepts. | When `e2e-tests/tests/integration/playbooks/**/*_spec.js` changed |

---

## Parallel Groups

**Project-specific additions only.** Global groups (Cross-cutting, Backend, Frontend, Compatibility, Playbooks domain, Playbooks migrations, Testing) run automatically based on file type — do not repeat them here.

### Always (any server-side change in this repo)
```
playbooks-pattern-reviewer
playbooks-isolation-reviewer
scope-drift-reviewer
```

### When `server/app/property*.go` or `server/sqlstore/property*.go` changed
```
property-system-expert
```

### When `e2e-tests/tests/integration/playbooks/**/*_spec.js` changed
```
playbooks-e2e-test-reviewer
```

---

## Domain-Specific Result Extensions

Appended after the canonical finding format:

| Agent | Appended Section |
|-------|-----------------|
| `playbooks-pattern-reviewer` | Pattern Alignment Checklist (18 rows: squirrel, txn, lock-timeout, field-map, json-size, error-wrap, sentinel, template, validation, cross-layer-validation-dup, creation-rules, permissions, GraphQL resolver order, GraphQL AssigneeType norm, sentinel-registration, handler-bypass, client *[]string, client err pattern). Body also covers Dim 15 Project Conventions (anti-slop drop-rules), Dim 16 Security Patterns (IDOR child-vs-parent, error-code symmetry, console.error leaks, markdown-injection in bot posts, client-only license gates, audit log PII), Dim 17 Webapp React/Redux (ActionResult.data optional, Promise.allSettled with redux thunks, index-positional race, stale-snapshot dispatch, run-team fallback leak, EMPTY arrays, setTimeout cleanup, trim-on-blur), and Dim 18 Type/Code Quality (omitempty in responses, []interface{} returns, as any/unknown, etc.). |
| `playbooks-isolation-reviewer` | Integration Checklist (16 rows: activation guard, core-table writes, pluginAPI single-entity lookups, layer boundaries, utility duplication, property scoping, WebSocket namespace, config scope, scheduler order, teamless run URL leak, teamless SlashCommand.Execute guard, ChannelID-empty guard, permission-service centralization, store-layer auth gap, UpdateAt invariant on nested mutation, WebSocket scope-change audience). |
| `playbooks-e2e-test-reviewer` | E2E Test Convention Checklist (17 rows: browser, API helpers, UI helpers, utils import, testIsolation, hooks, cleanup, naming, intercept/no-cy.wait, library class selectors, modal `.not.exist` dismissal, `.find()` guards, narrow `apiGetAllPlaybookRuns` lookups, new-spec required for new UI flows, `queryBy*` for negative assertions, comment style, duplicate-assertion bug). |
