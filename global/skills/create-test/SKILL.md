---
name: create-test
description: Generate tests for implemented or planned features. Project-agnostic — detects test infrastructure dynamically. Uses domain agents for coverage validation. Prioritizes off-happy-path coverage. Supports TDD (--tdd) for writing failing tests before implementation.
version: 2.0.0
tags:
  - testing
  - quality
  - tdd
user_invocable: true
---

# Create Test

Generate comprehensive tests for implemented or planned features. **Project-agnostic** — detects test runners, frameworks, and conventions dynamically from the project context.

**Philosophy**: Happy-path tests are table stakes. This skill prioritizes off-happy-path coverage — error recovery, edge cases, permission boundaries, concurrency, and data integrity — the scenarios that distinguish principal-level test suites from checkbox testing.

> `/create-plan` -> `/create-code` -> `/create-test` -> `/fix-test` -> `/review-code`
> `/create-plan` -> `/create-test --tdd` -> `/create-code` -> `/fix-test` (TDD workflow)

**Related**: `/create-code` (implement), `/fix-test` (fix failures), `/review-code` (review)

## Usage

```
/create-test                              # Default: test code in uncommitted+staged changes (git diff HEAD)
/create-test --scope=branch               # Test all code changed on the branch (git diff <base>)
/create-test <plan-file>                  # Generate tests for plan's implementation (overrides --scope)
/create-test <file-or-directory>          # Generate tests for specific code (overrides --scope)
/create-test --unit                       # Unit tests only
/create-test --e2e                        # E2E/integration tests only
/create-test --coverage                   # Focus on coverage gaps
/create-test --tdd                        # TDD: write failing tests from plan (before implementation)
/create-test --tdd --unit                 # TDD: unit tests only
/create-test --tdd --security             # TDD: write secure-behavior tests (for security tickets)
/create-test --swarm                      # Agent teams for parallel test writing
/create-test --swarm --sequential         # Swarm tasks run serially
```

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Convergence |
|------|------------------|------------------|-------------|
| Default (no flags) | Parallel Task() calls (backend/frontend/E2E are independent) | SKIPPED | Single-pass |
| `--swarm` | Background agents with shared findings dir (test writers + multi-LLM) | Fresh agents cross-validate (dedup + fill gaps) | Canonical convergence (swarm-harness.md) |
| `--sequential` | Serial Task() calls | SKIPPED | Single-pass |

## Project Context Loading

See `~/.claude/docs/project-context-loading.md` for:
- **Three-level agent discovery** — load agents tagged `[CODE]` or `[BOTH]`
- **Test infrastructure detection** — discover project's test runners, frameworks, and conventions

## Test Infrastructure Detection

> **Shared algorithm**: See `~/.claude/docs/project-context-loading.md` § "Project Test Infrastructure Detection"

## Workflow

### Step 0: Resolve Scope (MANDATORY)

Determine the file set to test based on the invocation form:

| Invocation | Code-under-test source |
|------------|------------------------|
| `<plan-file>` argument | "Files to modify/create" list in the plan |
| `<file-or-directory>` argument | The named path |
| No argument, default scope | `git diff HEAD --name-only` (uncommitted+staged) |
| No argument, `--scope=branch` | `git diff <base> --name-only` (auto-detect base, fallback `master`) |

**Print the active scope as the first line of output**, e.g. `Testing 4 file(s) from uncommitted changes (vs HEAD). Use --scope=branch to test the whole branch.` This prevents users from believing they got branch-wide test coverage when only their unstaged work was scoped.

If scope resolves to zero files: stop and report. Do not silently proceed.

### Step 1: Verify Code Under Test Exists

**MANDATORY (skip in `--tdd` mode)** — mirrors create-code's dependency verification.

Before writing any tests, verify the code-under-test actually exists on disk:

1. Use the file set resolved in Step 0
2. **Glob for each implementation file** — check it exists
3. For API tests: grep for route registration / handler functions, not just model methods
4. **Print verification matrix:**
   ```
   Code-under-test verification:
   server/channels/app/page_core.go:     EXISTS (CreatePage, GetPage found)
   server/channels/app/page_draft.go:    EXISTS (CreateDraft found)
   server/channels/api4/page_api.go:     MISSING — no handlers registered
   → Tests for page_api.go will be SKIPPED (no code to test)
   ```
5. If >50% of target files missing: STOP and report "Code under test is incomplete — run `/create-code` first"

**`--tdd` mode**: Skip this step entirely. In TDD, the implementation does not exist yet — that's the point. Instead, verify the **plan file exists and contains testable requirements** (struct definitions, function signatures, API contracts, acceptance criteria). If no plan file is provided, STOP: "TDD mode requires a plan file — run `/create-test <plan-file> --tdd`"

Write tests as if the implementation already exists — import the packages, call the functions, assert on return values. The tests will fail to compile because the functions don't exist yet. That's the correct "red" state. `/create-code` makes them compile and pass.

### Step 1.5: Test Strategy (MANDATORY)

**Do NOT jump to writing tests.** First create a coverage strategy.

1. **Read the plan file** (if provided) — extract acceptance criteria, error handling requirements, permission model
2. **Identify ALL layers** the plan touches (Go backend, frontend, E2E) — see Step 2 `--tdd` layer inventory
3. **Build a per-method inventory** (see below)
4. **Consult the edge case taxonomy** — Read `~/.claude/docs/edge-case-taxonomy.md`
5. **Identify applicable edge case categories** for this feature
6. **Build a coverage matrix** that includes EVERY layer:

#### Per-Method Inventory (MANDATORY)

Enumerate **every new or modified public method/function** across all layers. Each method must have at least one **direct** test — a test that calls it explicitly, not one that exercises it transitively through a higher layer.

```markdown
## Per-Method Test Inventory

| Layer | File | Method/Function | Direct Test? | Test File |
|-------|------|----------------|--------------|-----------|
| Store | server/sqlstore/playbook.go | IncrementRunNumber | REQUIRED | server/sqlstore/playbook_test.go |
| Store | server/sqlstore/playbook.go | HasPlaybookRuns | REQUIRED | server/sqlstore/playbook_test.go |
| App | server/app/playbook_service.go | HasPlaybookRuns | REQUIRED | server/app/playbook_service_test.go |
| App | server/app/permissions_service.go | PlaybookEdit | REQUIRED | server/app/permissions_test.go |
| API | server/api/playbooks.go | handleUpdatePlaybook | REQUIRED | server/api_test.go |
| Frontend | webapp/src/components/Foo.tsx | FooComponent | REQUIRED | webapp/src/components/Foo.test.tsx |
```

**Rules:**
- **Direct > Transitive**: A store method tested only through an app-layer test with a mocked store does NOT count as covered. The store method needs its own test hitting actual SQL.
- **Every public method gets a row**: If a plan adds `IncrementRunNumber` to the store AND a wrapper `IncrementRunNumber` in the app layer, BOTH need direct tests — store tests exercise SQL, app tests exercise business logic + error handling.
- **Service wrappers that only delegate**: If an app method is a thin wrapper (calls store, returns result), it still needs at least one test verifying error propagation and any argument validation.
- **Permission methods**: New permission-check methods (e.g., `PlaybookEdit`, `RunFinish`) need direct tests with different role/ownership combinations.

```markdown
## Test Coverage Matrix

### Requirements → Test Mapping
| Requirement / AC | Happy Path | Error Path | Edge Cases | Test Type |
|------------------|------------|------------|------------|-----------|
| Create page | ✓ basic create | ✓ invalid input, ✓ no permission | ✓ duplicate title, ✓ max depth | unit+API |
| Edit page | ✓ basic edit | ✓ deleted page, ✓ conflict | ✓ concurrent edit, ✓ stale data | unit+API+E2E |

### Edge Case Categories (from taxonomy)
| Category | Applicable? | Selected Edges | Priority |
|----------|-------------|----------------|----------|
| State edges | YES | empty wiki, at-depth-limit, deleted parent | HIGH |
| Timing | YES | concurrent edit, stale save | HIGH |
| Permissions | YES | role transition, guest access, cross-channel | HIGH |
| Data integrity | YES | orphan cascade, circular ref | MEDIUM |
| Input | PARTIAL | unicode titles, long content | LOW |

### Coverage Allocation (80/20 rule)
- Unit tests: validation, model logic, pure functions
- Integration/API tests: permission boundaries, error responses, cascade behaviors
- E2E tests: user journey error recovery, concurrent editing, cross-feature interactions
```

**80/20 Rule**: Allocate 80% of test effort to off-happy-path scenarios. Happy paths should be minimal — 1-2 tests proving the feature works. The bulk of coverage targets what breaks.

### Step 2: Analyze Code Under Test

**Standard mode**: Read the target code. Identify:
- Functions/methods that need tests
- Public API surface
- Error paths and failure modes (prioritize these)
- Dependencies to mock
- Invariants that must be preserved

**`--tdd` mode**: Read the plan file. First, identify **every layer** the plan touches:

**Layer inventory (MANDATORY)** — scan the plan's "Files to modify" sections and code blocks to build:
```
Layers detected in plan:
- Go backend (server/app/, server/sqlstore/, server/api/) → Go unit + store tests
- REST API (server/api/) → Go integration tests (TestEnvironment)
- Frontend (webapp/src/components/, webapp/src/graphql/) → TypeScript/Jest tests
- E2E user journeys (modals, slash commands, UI flows) → E2E tests (framework detected in Step 3)
→ Must generate tests for ALL detected layers, not just the first one found.
```

Then extract per layer:
- **Go backend**: struct definitions, function signatures, permission rules, error conditions, store queries
- **Frontend**: component props, user interactions, form validations, conditional rendering, API call expectations
- **E2E**: user journeys spanning multiple layers (create playbook → configure → create run → verify), permission error UX, dialog flows, slash command responses

Write tests that call the planned functions/render the planned components directly, as if they exist. They won't compile — that's the expected "red" state.

**CRITICAL**: Do NOT stop after writing tests for one layer. Every layer in the inventory gets its own test files. Launch parallel agents (go-test-writer, ts-test-writer, playwright-test-writer) for each layer.

**E2E tests require a plan file.** E2E tests map to *behaviors* described in a plan/spec, not to individual files. If `--e2e` is requested and no plan file was provided:
1. Search for the most recent plan referencing the changed files — check `plans/` first, then `plans/`, then check CLAUDE.md for a documented plans location
2. If no plan found, **skip E2E test generation** and report: "E2E tests require a plan file — run `/create-test <plan-file> --e2e`"

**Dedup check before proposing tests:**
- For each test type, search for existing test files covering the same feature
- Go: grep for test function names in `*_test.go` near the implementation
- Jest: check for `*.test.ts(x)` alongside implementation files
- E2E: search the E2E specs directory for specs that reference the feature under test
- If existing tests found, report coverage and only propose tests for **uncovered paths**

### Step 3: Detect Test Infrastructure

Run the detection algorithm above. Read 2-3 existing test files in the project to learn conventions:
- File naming (`*_test.go`, `*.test.ts`, `*.spec.tsx`)
- Import patterns
- Setup/teardown patterns
- Mocking patterns
- Assertion style
- **Data isolation patterns** — how tests create/cleanup test data

**E2E framework detection (MANDATORY when E2E layer detected):**
The E2E framework varies by project. Do NOT hardcode Playwright or Cypress — detect dynamically:

1. Check for `cypress.config.*` → **Cypress** (use `*_spec.{js,ts}` naming, `cy.*` API, Cypress commands)
2. Check for `playwright.config.*` → **Playwright** (use `*.spec.ts` naming, `page.*` API, test fixtures)
3. Check the E2E test directory structure and read 2-3 existing E2E specs to learn:
   - API helper commands (e.g., `cy.apiCreatePlaybook()` vs `pw.installAndEnablePlugin()`)
   - Data setup patterns (Cypress custom commands vs Playwright fixtures)
   - Selector patterns (`cy.findByTestId()` vs `page.getByTestId()`)
   - Wait patterns (`cy.should('be.visible')` vs `expect(locator).toBeVisible()`)

**Print detection result:**
```
E2E framework detected: Cypress 13.x
  Config: e2e-tests/cypress.config.ts
  Spec pattern: tests/integration/**/*_spec.{js,ts}
  Support: tests/support/ (custom commands: apiCreatePlaybook, apiRunPlaybook, ...)
```

The detected framework determines which agent to use for E2E tests and what conventions to follow. Never mix Playwright patterns into a Cypress project or vice versa.

### Step 4: Domain Agent Consultation (MANDATORY)

Use three-level agent discovery. Spawn domain agents for test quality:

| Agent | Role | When |
|-------|------|------|
| `test-coverage-reviewer` | Validates coverage plan, identifies gaps | Always |
| `ts-test-writer` | Advises on unit test patterns, mocking | Unit tests |
| `playwright-test-writer` | Advises on E2E patterns, selectors | E2E tests |
| `playwright-test-reviewer` | Reviews E2E test conventions | E2E tests |

**Before spawning: read `~/.claude/agents/AGENT_REGISTRY.md` SS "Parallel Groups for Code Review". The table above lists defaults; the registry may have project-specific additions. Never select from memory.**

**Emit Selection Rationale (MANDATORY — before spawning)**: Print the `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. List every candidate test-related agent under SELECTED (with trigger reason — unit tests in scope, E2E framework detected, etc.) or SKIPPED (with specific reason — no E2E changes, no unit tests in scope, framework mismatch, project-only agent, etc.). The block is user-visible output, printed before any agent spawns.

Spawn agents from the table above (see AGENT_REGISTRY) with the plan file, coverage matrix, and relevant source files as context.

### Step 5: Write Tests

Write tests following detected conventions. Match the project's exact style.

**`--tdd` mode — write tests as if the implementation exists, for EVERY layer:**
Write tests that import packages, call functions, and assert on results exactly as you would in standard mode. The functions don't exist yet, so the tests won't compile. That's the correct first "red" — `/create-code` provides the implementation that makes them compile and pass.

Do NOT create stubs, placeholder files, or zero-value implementations. The test files are the only output.

**Per-layer test generation (MANDATORY)** — for each layer in the inventory from Step 2:
- **Store layer** (`server/sqlstore/*_test.go`): **Every new store method gets its own test function** exercising actual SQL against the test DB. Store tests verify SQL correctness, constraint handling, edge cases (empty ID, not-found, concurrent updates). These are NOT replaceable by app-layer tests with mocked stores — mocked stores hide SQL bugs.
- **App layer** (`server/app/*_test.go`): unit tests with mocked dependencies testing business logic, error wrapping, permission checks, and argument validation.
- **API layer** (`server/api_*_test.go`): integration tests via `TestEnvironment` testing HTTP contracts, response codes, serialization, and end-to-end permission enforcement.
- **Frontend**: Jest tests (`webapp/src/**/*.test.ts(x)`) — component rendering, prop validation, user interactions, API mocking
- **E2E**: tests using the **detected E2E framework** (see Step 3) — user journeys, dialog flows, permission error UX, slash command responses

**Store test mandate**: If the plan adds N new public store methods, there must be N new test functions (each with subtests for happy path, error cases, and edge cases). Store tests are the ONLY layer that validates SQL correctness — skipping them means SQL bugs (wrong placeholders, missing JOINs, incorrect WHERE clauses) go undetected until production.

Launch **parallel agents** for each layer (go-test-writer, ts-test-writer, playwright-test-writer). Do NOT write all tests yourself sequentially — delegate to specialists.

**Off-happy-path emphasis:**
- For every happy-path test, write 2-3 corresponding error/edge tests
- Every error path must assert on the specific error (message, code, type), not just "it errors"
- Permission tests must cover: no auth, wrong role, right role but wrong resource, expired session
- Concurrent tests must verify data integrity, not just absence of crash

**Negative testing checklist (verify for each feature):**
- What happens when the resource is deleted/archived before the action?
- What happens with invalid/missing required fields?
- What happens when the user lacks permission?
- What happens on conflict (optimistic lock, concurrent edit)?
- What happens when a parent/dependency is removed?

**Flakiness prevention (E2E):**
- Wait for specific conditions (Playwright: `waitForSelector`/`toBeVisible`; Cypress: `.should('be.visible')`/`.should('exist')`), never arbitrary timeouts (`waitForTimeout` / `cy.wait(ms)`)
- Assert on stable identifiers (data-testid, role, text content), not CSS classes or position
- Each test creates its own data — never depend on state from another test
- Playwright: use `test.describe.serial` only when test ordering genuinely matters
- Cypress: use `{testIsolation: true}` on describe blocks; use `cy.api*` commands for data setup
- After mutation, wait for confirmation (toast, URL change, element change) before asserting

### Step 6: Run Tests

Execute using the detected test runner.

**Standard mode** — verify:
- All new tests pass
- No existing tests broken
- Coverage improved (if measurable)

**`--tdd` mode** — verify:
- All new tests **fail to compile** (functions don't exist yet — this is the expected "red" state)
- No existing tests broken (test files must not interfere with existing code)
- Print a summary: "N test files written, all expected to fail compilation until implementation"
- Do NOT attempt to run the tests — they can't compile. The verification is: do the test files exist, and do they reference the correct packages/functions from the plan?

### Step 7: Post-Write Quality Gate (MANDATORY)

After tests pass, spawn review agents to validate quality:

1. **`test-coverage-reviewer`**: Compare actual tests written against the coverage matrix from Step 1.5. Identify gaps.
2. **`playwright-test-reviewer`** (if E2E): Check for flakiness patterns, proper waits, data isolation.

**MAX_REVIEW_ITERATIONS = 2**

If MUST_FIX findings (e.g., "no test covers the concurrent edit scenario listed in coverage matrix"):
1. Write the missing tests
2. Re-run tests
3. Re-run review
4. Stop after 2 rounds — report remaining gaps

### Step 8: Coverage Verification

**Two-part verification** — both must pass:

#### Part A: Scenario Coverage (from coverage matrix)

Compare final test suite against coverage matrix:
```
## Scenario Coverage
| Planned Scenario | Test Written? | File:Line |
|------------------|---------------|-----------|
| Create page (happy) | YES | page_test.go:45 |
| Create page (no permission) | YES | page_test.go:78 |
| Create page (max depth) | YES | page_test.go:112 |
| Concurrent edit conflict | NO — deferred (needs WebSocket test infra) | — |

Coverage: 15/17 planned scenarios (88%)
Uncovered: 2 scenarios documented with reason
```

#### Part B: Per-Method Direct Test Coverage (from per-method inventory)

Cross-check the per-method inventory from Step 1.5 against actual tests written. Every row marked REQUIRED must have a corresponding test function that calls it directly.

```
## Per-Method Coverage Verification
| Layer | Method | Direct Test? | Test Location | Status |
|-------|--------|-------------|---------------|--------|
| Store | IncrementRunNumber | YES | playbook_test.go:TestIncrementRunNumber | COVERED |
| Store | HasPlaybookRuns | YES | playbook_test.go:TestHasPlaybookRuns | COVERED |
| App | PlaybookEdit | YES | permissions_test.go:TestPlaybookEdit | COVERED |
| App | HasPlaybookRuns | NO — thin wrapper, store test sufficient? | — | GAP |

Method coverage: 14/16 methods have direct tests (87%)
Gaps: 2 methods documented with justification
```

**Acceptable gap justifications:**
- Thin delegation wrapper with no logic (e.g., `func (s *Service) Foo() { return s.store.Foo() }`) — but ONLY if the store test covers the SQL
- Method is a simple getter with no validation
- Method requires infrastructure not available in test env (document as tech debt)

**NOT acceptable justifications:**
- "Covered transitively by API test" — transitive coverage through mocked layers doesn't test the actual implementation
- "Happy path works so edge cases aren't needed" — edge cases are the point
- "Similar to another tested method" — similar != identical

## Output Format

```markdown
## Test Generation Summary

### Status: COMPLETE / PARTIAL

### Code Verification
- **Files verified**: N/M exist
- **Skipped**: [files that don't exist yet]

### Test Strategy
- **Edge case categories**: [applicable categories from taxonomy]
- **Coverage allocation**: N% off-happy-path, M% happy-path
- **Total planned scenarios**: N

### Test Infrastructure Detected
- **Framework**: [Jest / Go testing / Playwright / etc.]
- **Runner**: [exact command]
- **Convention**: [file naming pattern]

### Tests Written
| File | Tests | Coverage Focus |
|------|-------|----------------|
| [test file] | [N tests] | [error paths, permissions, concurrency, etc.] |

### Scenario Coverage
- **Planned scenarios**: N
- **Tests written**: M
- **Coverage**: M/N (X%)
- **Gaps**: [uncovered scenarios with reason]

### Per-Method Direct Coverage
- **New public methods**: N
- **Methods with direct tests**: M
- **Coverage**: M/N (X%)
- **Gaps**: [methods without direct tests + justification]

### Test Results
- **Mode**: Standard / TDD
- **New tests**: N passing, M failing
- **Existing tests**: all passing / N regressions
- **(TDD only) Test files written**: N files, M test functions
- **(TDD only) Status**: all expected to fail compilation (awaiting implementation)

### Quality Gate
- **test-coverage-reviewer**: [findings]
- **playwright-test-reviewer**: [findings, if applicable]
- **Rounds**: N/2
```

## Flags

| Flag | Effect |
|------|--------|
| `--scope=uncommitted` | (default when no plan/path arg) Scope to uncommitted+staged files (`git diff HEAD`) |
| `--scope=branch` | Scope to all files changed on the branch (`git diff <base>`); base auto-detects, fallback `master` |
| `--tdd` | TDD mode: write tests from plan before implementation. Tests reference functions that don't exist yet — they won't compile until `/create-code` runs. Requires a plan file. |
| `--security` | Security framing: assert *secure behavior* (what must be denied/omitted) rather than feature behavior. Use with `--tdd` for security ticket workflows. See Security TDD Mode below. |
| `--unit` | Unit tests only |
| `--e2e` | E2E/integration tests only |
| `--coverage` | Focus on coverage gaps |
| `--swarm` | Agent teams for parallel test writing (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: tasks run serially |

## Security TDD Mode (`--tdd --security`)

When fixing a security ticket, tests must encode **secure behavior contracts** — what the system must deny, omit, or reject — not just what it should return.

**Mindset shift**: A Staff Security Engineer writing regression tests asks "what must an attacker *not* be able to do?" rather than "what should this endpoint return?"

**Test assertion framing**:

| Standard TDD | Security TDD |
|---|---|
| `assert response.status == 200` | `assert response.status == 403` (must be denied) |
| `assert result.data == expected` | `assert "secret_field" not in result` (must be omitted) |
| `assert user.canRead(resource)` | `assert not otherUser.canRead(resource)` (cross-user isolation) |

**"Red" state discipline**: The test must fail for the *right* reason — because the current code is vulnerable, not because of a compile error or setup problem. If the test passes against the unfixed code, revise it until it correctly exposes the vulnerability.

**Coverage targets for security tests** (in addition to standard coverage):
- Other roles: guest, system admin, team admin — does the fix apply to all of them?
- Cross-resource: user A accessing user B's data
- Deleted/archived resources: does the check hold after the resource is removed?
- Adjacent endpoints: same pattern on similar routes

## When to Use

| Scenario | Use `/create-test` | Just write tests |
|----------|--------------------|-----------------------|
| After `/create-code` completes | yes | |
| TDD: write tests before implementation | yes (with `--tdd`) | |
| Multi-layer feature needs tests | yes | |
| Need systematic edge case coverage | yes | |
| Coverage gaps on existing feature | yes (with `--coverage`) | |
| Single function needs 2-3 tests | | yes |
| Fixing a bug (regression test) | | yes — add test, then fix |

## Swarm Mode (`--swarm`)

> **Swarm protocol**: See `~/.claude/docs/swarm-harness.md`

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1: Backend tests | go-test-writer | Write Go tests | Independent Work | -- |
| T2: Frontend tests | ts-test-writer | Write TS/React tests | Independent Work | -- |
| T3: E2E tests | playwright-test-writer | Write Playwright tests | Independent Work | -- |
| T4: Multi-LLM coverage | general-purpose | Identify coverage gaps | Independent Work | -- |
| T5: Cross-validation | 3-5 Phase 1 types covering major domains (see swarm-harness.md) | Dedup + fill gaps + contradiction check | Cross-Validation | T1-T4 |
| T6: Run all tests | coder | Execute test suite | -- | T5 |
| T7: Quality gate | test-coverage-reviewer + playwright-test-reviewer | Validate against coverage matrix | -- | T6 |

## Fix Prompts — Pattern Completeness Rule

When spawning test agents, **always include** the Pattern Completeness instruction from `~/.claude/docs/pattern-completeness-rule.md` in the agent prompt.

## Tips

- **Always read existing tests first** — match the project's exact patterns
- **Never hardcode test infrastructure** — detect it dynamically
- **80/20 rule**: 80% off-happy-path, 20% happy-path
- **Test behavior, not implementation** — focus on public API surface
- **Every error path needs a specific assertion** — not just "it errors"
- **Domain agents improve quality** — coverage reviewer catches blind spots
- **Verify code exists before writing tests** — don't test phantom code (standard mode)
- **TDD tests are real tests** — write them as if the code exists, let compilation failure be the "red"
- **Flakiness prevention > flakiness fixing** — get it right the first time
- **Store tests are non-negotiable** — mocked store tests pass while real SQL fails. Every new store method needs a direct integration test.
- **Direct tests > transitive coverage** — a method exercised only as a side effect of another test is NOT covered

## Anti-patterns
- Writing tests that mock every dependency — mocked tests pass while real integration fails.
- Testing implementation details instead of behavior — tests break on refactors that don't change behavior.
- Generating only happy-path tests — error paths and edge cases are where bugs live.
- Testing phantom code (standard mode) — write tests for code that doesn't exist yet, then be confused why nothing runs.
- Adding `--tdd` for trivial CRUD — TDD overhead only pays off for complex logic with non-obvious invariants.

## Self-rewrite hook
After every 10 test generation runs, or after any run where generated tests were immediately deleted or heavily rewritten:
1. Re-read the last 3 test outcomes — did the tests actually catch bugs, or were they just coverage padding?
2. If a recurring false-negative pattern appeared (test passes but bug exists), add a check for that coverage gap.
3. If the swarm table is out of date with current agent types, update it.
4. Commit: `skill-update: create-test, <one-line reason>`.
