---
name: Create Test
description: Project-specific test writing. Extends global create-test with run_pages_tests.sh registration, layer-specific patterns, and wiki/pages edge case coverage.
tags:
  - testing
  - go
  - typescript
  - playwright
---

# Create Test (Pages Project)

Extends `~/.claude/skills/create-test/SKILL.md` — follow that skill's workflow, agents, modes, output format, and safety rules with the project-specific overrides below.

> `/create-plan` -> `/create-code` -> `/create-test` -> `/fix-test` -> `/review-code`

**Related**: `/create-code`, `/fix-test`

## Project-Specific Scope

| Scope | What it does |
|-------|-------------|
| `mmctl` | mmctl E2E tests (requires running server with job scheduler) |

mmctl tests are excluded from auto-detect — use `mmctl` scope explicitly.

## Override: Test Infrastructure (replaces global Step 3 detection)

This project uses `.claude/scripts/run_pages_tests.sh` as the central test runner.
Targets: `all`, `backend`/`go`, `model`, `store`, `app`, `api`, `frontend`/`jest`, `e2e`/`playwright`, `e2e:<category>`, `mmctl`.

## Override: Layer -> File Mapping (augments global Step 2)

| File pattern | Test type | Layer |
|-------------|-----------|-------|
| `server/public/model/*.go` | Go unit (`*_test.go`) | model |
| `server/channels/store/**/*.go` | Go store (`storetest/`) | store |
| `server/channels/app/**/*.go` | Go app (`*_test.go`) | app |
| `server/channels/api4/**/*.go` | Go API (`*_test.go`) | api |
| `webapp/**/*.ts(x)` | Jest (`*.test.ts(x)`) | frontend |
| `server/cmd/mmctl/**/*.go` | mmctl E2E (only if explicit) | mmctl |
| Cross-cutting features | Playwright E2E | e2e |

See `.claude/docs/test-patterns.md` for all Go, Jest, and Playwright test patterns.

## Override: E2E Test Helper Study (augments global Step 3)

**MANDATORY before writing any E2E test**: Read and internalize the project's test helpers.

1. **Read** `e2e-tests/playwright/specs/functional/channels/pages/test_helpers.ts`
2. **Read** `.claude/docs/pages-e2e-helpers-reference.md` (anti-patterns + helper API)
3. **Internalize these rules:**
   - Use `uniqueName()` not `pw.random.id()`
   - Use `loginAndNavigateToChannel()` not manual login sequences
   - Use `getEditor()`, `getEditorAndWait()`, not `.ProseMirror` selectors
   - Use `getHierarchyPanel()`, `getWikiTab()`, not raw CSS selectors
   - Use named timeout constants (`EDITOR_LOAD_WAIT`, `WEBSOCKET_WAIT`), never magic numbers
   - Use `createPageViaAPI()` / `createWikiViaAPI()` for test data setup, not UI clicks
   - Each test creates its own channel/wiki/page — never reuse across tests

## Override: Test Strategy — Pages-Specific Edge Cases (augments global Step 1.5)

In addition to the generic edge case taxonomy (`~/.claude/docs/edge-case-taxonomy.md`), the coverage matrix MUST include these wiki/pages-specific categories:

### Wiki/Pages Domain Edge Cases

| Category | Edge Cases to Test | Priority |
|----------|-------------------|----------|
| **Hierarchy integrity** | Delete parent → children orphaned? Move page → depth exceeds limit? Circular parent ref? | CRITICAL |
| **Concurrent editing** | Two users edit same page → optimistic lock works? WS update during local edit → merge or conflict? | CRITICAL |
| **Draft lifecycle** | Draft exists + page deleted → draft orphaned? Publish draft with stale base_edit_at → 409? Auto-save during network loss? | HIGH |
| **Cross-wiki operations** | Move page between wikis → hierarchy preserved? Links to moved page → broken? Wiki deleted → pages cascade? | HIGH |
| **Permission boundaries** | Guest edits page → denied? Channel member views linked wiki from other channel → denied? Role demoted mid-edit → save fails? | HIGH |
| **Content edge cases** | Empty TipTap doc (just `{type:"doc",content:[]}`)? 100KB document? Paste from Confluence/Word? Emoji-only title? | MEDIUM |
| **Comment system** | Comment on deleted page → error? Resolve comment without permission → denied? Reply to resolved thread → behavior? | MEDIUM |
| **Real-time sync** | Page created by user B appears in user A's hierarchy? Page moved by B updates A's tree? Wiki deleted broadcasts to all viewers? | HIGH |
| **Import/export roundtrip** | Export wiki → import → export: identical? Import with missing parent pages → repair? Import with duplicate titles? | MEDIUM |
| **State transitions** | Page status: rough draft → done → back to rough draft? Deleted → restored → hierarchy intact? | MEDIUM |

### E2E Scenario Derivation from User Journeys

For E2E tests, derive scenarios from **user journeys**, not code structure:

**Error recovery journeys** (prioritize these):
1. User starts editing → network drops → reconnects → no data lost
2. User publishes draft → 409 conflict → sees conflict UI → resolves
3. User deletes parent page → child pages show appropriate state
4. User moves page to full-depth wiki → gets clear error, page stays put
5. Admin demotes user mid-edit → next save shows permission error

**Cross-feature journeys**:
1. Create page → add mention → recipient sees notification → clicks → lands on page
2. Create page → bookmark it → move page to different wiki → bookmark still works
3. Import from Confluence → pages appear in hierarchy → search finds them

**Multi-user journeys**:
1. User A creates page → User B sees it in real-time → User B edits → User A sees update
2. User A and B edit simultaneously → one gets conflict → conflict resolution works

## Override: Negative Testing Checklist for Wiki/Pages

Before finalizing the coverage matrix, verify each of these is covered:

**Actions on deleted resources:**
- [ ] Edit a deleted page (should error, not silently fail)
- [ ] Comment on a deleted page
- [ ] Move a deleted page
- [ ] Publish a draft for a deleted page
- [ ] Access a page in a deleted wiki
- [ ] Access a page in a deleted channel

**Invalid state transitions:**
- [ ] Create page at depth > MAX_PAGE_DEPTH
- [ ] Move page creating circular reference
- [ ] Publish draft with no content
- [ ] Create wiki with empty/whitespace-only name
- [ ] Set page status to invalid value

**Permission violations (test with guest, member, non-member):**
- [ ] Create page in channel user can't access
- [ ] Edit page user can only view
- [ ] Delete page without delete permission
- [ ] Move page to channel user can't access
- [ ] Access wiki linked to channel user isn't in

**Concurrent operations:**
- [ ] Two users update same page simultaneously
- [ ] Delete page while someone is editing it
- [ ] Move page while someone is viewing it
- [ ] Publish draft while another user publishes the same draft

## Additional Step: Register in run_pages_tests.sh

**After writing tests (global Step 5) and BEFORE running them (global Step 6):**

1. **Read** `.claude/scripts/run_pages_tests.sh`
2. **Find** the correct section based on layer/type
3. **Dedup check**: grep for the test name first — if entry exists, update in place
4. **Add** a `run_test` entry following the exact pattern of surrounding entries

**Go tests** — add to the appropriate layer section:
```bash
# MODEL section:
run_test "Model: NewFeature - TestName" "go test -v ./public/model -run '^TestName$'"

# STORE section:
run_test "Store: NewFeatureStore" "go test -v ./channels/store/sqlstore -run '^TestNewFeatureStore$'"

# APP section:
run_test "App: NewFeature - TestName" "go test -v ./channels/app -run '^TestName$'"

# API section:
run_test "API: NewFeature - TestName" "go test -v ./channels/api4 -run '^TestName$'"
```

**Jest tests** — add to the FRONTEND section:
```bash
run_test "Frontend: Components - new_component" "npm run test -- src/components/path/new_component.test.tsx --silent"
```

**E2E tests** — add to the appropriate E2E category section:
```bash
run_test "E2E: New Feature" "npm run test -- new_feature_spec --project=chrome"
```

## Override: Swarm Task Decomposition

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1: Model tests | test-writer | `test-model` | Independent Work | -- |
| T2: Store tests | test-writer | `test-store` | Independent Work | -- |
| T3: App tests | test-writer | `test-app` | Independent Work | -- |
| T4: API tests | test-writer | `test-api` | Independent Work | -- |
| T5: Jest tests | test-writer | `test-frontend` | Independent Work | -- |
| T6: E2E tests | playwright-test-writer | `test-e2e` | Independent Work | -- |
| T7: Multi-LLM coverage | general-purpose | `multi-llm-coverage` | Independent Work | -- |
| T8: Cross-pollination | (same as T1-T6, Variant A) | Dedup + fill gaps | Cross-Validation | T1-T7 |
| T9: Register all | coder | `test-register` | -- | T8 |
| T10: Quality gate | test-coverage-reviewer + playwright-test-reviewer | Validate coverage matrix | -- | T9 |

T9 collects all new test names from T1-T6 and registers in `run_pages_tests.sh`.
T10 compares written tests against the coverage matrix from Step 1.5.

## Additional Safety Rules

- **SAFETY RULE**: ALWAYS register new tests in `run_pages_tests.sh`
- **SAFETY RULE**: ALWAYS read `test_helpers.ts` and `pages-e2e-helpers-reference.md` before writing E2E tests
- **SAFETY RULE**: NEVER write E2E tests that share state between test cases
