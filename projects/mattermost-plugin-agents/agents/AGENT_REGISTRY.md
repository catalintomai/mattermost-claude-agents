# Agent Registry — mattermost-plugin-agents-pages-mcp

Project-specific agents for Playwright E2E test generation for the Mattermost plugin.

These agents are loaded alongside global agents from `~/.claude/agents/`.

Phase tags: `[PLAN]` = design/planning phase; `[CODE]` = implementation/review phase; `[BOTH]` = either phase.

---

## E2E Testing Agents

| Agent | Phase | Purpose | Model | Speed | Prerequisites | Parallel-safe |
|-------|-------|---------|-------|-------|---------------|---------------|
| `playwright-test-planner` | [PLAN] | Creates comprehensive test plans by navigating the live app and mapping user flows | sonnet | medium | none | yes |
| `playwright-test-generator` | [CODE] | Generates automated Playwright test files by executing each test plan step in real-time | opus | slow | `playwright-test-planner` | yes |
| `playwright-test-healer` | [CODE] | Debugs and fixes failing Playwright tests by running, inspecting, and patching broken selectors or assertions | opus | medium | none | yes |

---

## When to Use

- **Writing new E2E tests** → `playwright-test-planner` (plan first), then `playwright-test-generator`
- **Fixing flaky/broken E2E tests** → `playwright-test-healer`

---

## Parallel Groups

These agents can run in parallel within the same swarm when independent:

### E2E Test Generation
```
playwright-test-planner    (plan phase — runs first)
playwright-test-generator  (implements the plan)
```

### E2E Test Healing
```
playwright-test-healer     (independent — can run in parallel with other agents)
```

---

## Note on Duplication

These agents also exist in `mattermost-plugin-agents/.claude/agents/` with identical definitions. Both projects use Playwright for E2E testing and maintain their own copy. Consider symlinking if they diverge.
