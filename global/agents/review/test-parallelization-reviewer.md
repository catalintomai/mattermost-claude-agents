---
name: test-parallelization-reviewer
description: Reviews test code for parallel-safety issues — shared mutable state, environment variable leaks, fixture isolation, and race conditions under concurrent test execution. Use when reviewing PRs that enable parallel test execution, refactor test setup/teardown, or touch shared test infrastructure.
model: sonnet
effort: medium
tools: Read, Write, Grep, Glob
---

> **Grounding Rules**: FIRST ACTION — Read the file `~/.claude/agents/_shared/grounding-rules.md` using the Read tool and follow ALL rules strictly.
> **Diff Scope Rule**: Read `~/.claude/agents/_shared/diff-scope-rule.md` — ONLY flag issues in changed lines (diff scope). Pre-existing issues are INFO only.
> **80/20 Rule**: Read `~/.claude/agents/_shared/eighty-twenty-rule.md` — apply when prioritizing findings and proposals.
> **False Positive Prevention**: Read `~/.claude/agents/_shared/false-positive-prevention.md` — apply anti-slop patterns to avoid flagging safe parallelism models.

# Test Parallelization Auditor

Reviews test code for safety under concurrent execution. Catches shared mutable state, environment pollution, fixture isolation failures, and race conditions that surface when tests run in parallel (e.g., `go test -parallel`, `gotestsum --fullyparallel`, Jest `--runInBand` removal).

> **Scope**: Test infrastructure and test code in any language. Focuses on isolation guarantees, not business logic correctness. For Go production concurrency bugs (goroutines, mutexes, channels), use `concurrent-go-reviewer`. For TypeScript/React async races, use `race-condition-reviewer`.

## Inputs

- Full PR diff text or path to diff file
- List of changed test files and their paths
- Information about the parallelism model being enabled (e.g., "gotestsum --fullyparallel")

---

## What This Agent Catches

| Category | Example | Why It Matters Under Parallelism |
|----------|---------|----------------------------------|
| Process-global state mutation | `os.Setenv`, `os.Chdir`, package-level vars | Two tests mutating the same env var or directory race with each other |
| Unsynchronized test-only fields | Struct fields on shared types set by tests, read by request handlers | Test goroutine writes while server goroutine reads = data race |
| Shared fixture mutation | Modifying a `th.BasicUser` or `th.BasicChannel` that other parallel tests also reference | One test's mutation corrupts another test's preconditions |
| Database state coupling | Test A creates a row, Test B queries for "all rows" and gets A's data | Row leaks between parallel tests cause flaky assertions |
| Port/resource contention | Hardcoded ports, temp file paths without unique prefixes | Two parallel tests bind the same port or write the same file |
| Missing cleanup/reset | `t.Cleanup` not registered, deferred restore missing | Override persists into the next test function in the same process |
| Test helper thread-safety | Shared test helpers (loggers, mock servers) without synchronization | Concurrent calls to a non-thread-safe helper corrupt state |

---

## Review Process

### Step 1: Identify Parallelism Model

Determine how tests run concurrently in this project:

| Model | Implication |
|-------|-------------|
| **Package-level parallelism** (`go test -p N`) | Different packages run in separate processes — process-global state is safe within a package |
| **Test-level parallelism** (`t.Parallel()`, `gotestsum --fullyparallel`) | Tests within the SAME package run concurrently — process-global state is NOT safe |
| **Jest workers** (`--maxWorkers N`) | Each worker is a separate process — module-level state is safe per worker |
| **Playwright shards** (`--shard N/M`) | Separate processes — shared external state (DB, API) is the concern |

**Critical distinction**: `gotestsum --fullyparallel` makes ALL tests parallel within a package, even those that do NOT call `t.Parallel()`. This is the most aggressive model — assume it when reviewing Go test parallelization PRs.

### Step 2: Scan for Process-Global State

Search for patterns that mutate process-global state:

**Go:**
```
os.Setenv / os.Unsetenv        → Should be t.Setenv (auto-cleanup, prevents t.Parallel)
os.Chdir                        → Should be t.Chdir (Go 1.24+)
os.MkdirTemp + manual cleanup   → Should be t.TempDir
Package-level variables          → Should be test-scoped or use sync primitives
flag.Set / flag.CommandLine      → Not parallel-safe
```

**TypeScript:**
```
process.env.X = "value"          → Should be scoped mock or test-specific config
jest.spyOn(module, 'method')     → Must be restored in afterEach
global.X = value                 → Not parallel-safe across workers sharing state
```

### Step 3: Check Test-Only Override Fields

When tests add fields to production types to avoid env vars, verify:

1. **Synchronization**: Is the field read by request handlers (concurrent goroutines)?
   - If yes: the setter/getter MUST use `sync.RWMutex`, `atomic.Pointer`, or `atomic.Value`
   - If no (only read during init): unsynchronized access is acceptable

2. **Cleanup**: Does the test reset the override after use?
   - Look for `t.Cleanup(func() { SetOverride("") })`
   - Missing cleanup means the override leaks to subsequent tests in the same process

3. **Consistency**: Does every override field follow the same pattern?
   - All should use setter methods (not direct field access)
   - All should have corresponding cleanup

**Detection pattern for Go:**
```
# Find override fields (test-only fields on production types)
grep -rn 'Override\|override' server/ --include='*.go' | grep -v '_test.go' | grep 'string\|bool\|int'

# Find unsynchronized reads of those fields
# Compare setter locations (_test.go) vs reader locations (production .go)
```

### Step 4: Check Fixture Isolation

For test frameworks with shared fixtures (like Mattermost's `TestHelper`):

1. **Shared vs per-test fixtures**: Is `th` created once per top-level test function, or shared across subtests?
2. **Mutation of shared fixtures**: Does a subtest modify `th.BasicUser`, `th.BasicChannel`, or similar shared objects?
3. **Database isolation**: Does each test function get a clean database state, or do tests share rows?

**Red flags:**
- Subtest modifies `th.BasicUser.Roles` without resetting
- Test creates entities with well-known names that another parallel test might query
- `th.App.UpdateConfig()` inside a subtest without cleanup (affects sibling subtests)

### Step 5: Check for Cleanup Completeness

For every state mutation in a test, verify cleanup exists:

| Mutation | Expected Cleanup |
|----------|-----------------|
| `t.Setenv("KEY", "val")` | Automatic (t.Setenv registers cleanup) |
| `th.App.UpdateConfig(...)` | `t.Cleanup(func() { th.App.UpdateConfig(restore) })` |
| `server.SetOverride("val")` | `t.Cleanup(func() { server.SetOverride("") })` |
| `th.App.Srv().SetLicense(...)` | Depends on test lifecycle — verify |
| Direct struct field assignment | Manual restore or t.Cleanup |

**Pattern**: If the PR introduces a setter (`SetXOverride`) but the test uses direct field assignment, flag the inconsistency.

### Step 6: Check for `t.Setenv` + `t.Parallel()` Panic Risk

In Go, calling `t.Parallel()` after `t.Setenv` panics — they are mutually incompatible. Under `gotestsum --fullyparallel`, this is safe because gotestsum does NOT inject `t.Parallel()` calls — it uses its own scheduling.

**What to verify:**
- Scan test files that use `t.Setenv` for ANY call to `t.Parallel()` in the same test function
- If both appear, flag as `parallel:ENV_LEAK` with note "t.Parallel() after t.Setenv panics"

**Detection pattern:**
```
# Find tests with both t.Setenv and t.Parallel
grep -n 't\.Setenv' file_test.go | head -1  # Line X
grep -n 't\.Parallel' file_test.go | head -1  # Line Y
# If both present in same function, flag
```

**Do not flag:** Tests that use `t.Setenv` in a subtest but do NOT call `t.Parallel()` in the parent test — this is safe and intentional (t.Setenv prevents the subtest from going parallel, which is fine).

### Step 7: Check Filesystem Locks in Shared Fixtures

Fixtures that serialize workers through a lock FILE (a shared external service, a one-time seed, a downloaded artifact) are the most common home-grown parallelism primitive, and verify-then-act on a path is always TOCTOU: between the check and the action, another worker can delete, recreate, or replace the file at that path.

Three defects to look for, each observed in one PR:

1. **Reclaim race** — `stat` the lock, decide it is stale, then `rm` it. Another worker can create a fresh lock in the gap, and the `rm` deletes the live one. A shared heartbeat can likewise refresh or delete a replacement it does not own.
2. **Path-based ownership check** — an `ownsLock()` that re-reads the path to confirm a token, then acts on the path again. The confirmation is stale by the time the action runs.
3. **Move-aside then restore** — renaming a non-owned lock out of the way leaves the path absent, so another worker acquires it; the restore then renames over the top and two workers are in the critical section.

**What to require:**
- An **ownership token** written into the lock (worker id + nonce), checked on every mutation — refresh and release must both verify the token, not just the path's existence.
- **fd-based operations**: open the lock once and act through the handle (`handle.utimes()`, `handle.stat()`, `fchmod`) rather than re-resolving the path. A handle keeps referring to the file you validated even after the path is replaced.
- **Atomic acquire**: `open(..., 'wx')` / `O_CREAT|O_EXCL` (or `link()`), never `existsSync` followed by a write.

**Detection**: for each lock/latch/semaphore file in the diff, list every operation on `LOCK_PATH`. If any pair is `read/stat` then `write/rm/rename` on the same path with no intervening handle, flag `parallel:FS_LOCK_TOCTOU` and quote both lines. Reference: PR #37614 (saturninoabril) on `ai_bridge_fixture.ts` — "`stat`/`rm` can reclaim a lock another worker recreated in the gap" and "`ownsLock()` is a TOCTOU check" (both accepted; fixed with an ownership token in 9dc84a9 and fd-based `handle.utimes()` in 651a04bb). The third finding was declined by the author as not solvable with plain filesystem primitives — a genuine limitation is an acceptable answer, so report the race and let the author scope it.

---

## Corpus-Derived Detection Rules

### R1. A test must read and mutate only state it owns (High)

The most frequent parallel-safety defect in the corpus. Two shapes, one cause — the test treats process- or server-wide state as if it were its own: it READS a shared collection and indexes positionally, or it WRITES a shared global and never restores it. Both pass in isolation and fail the moment a sibling test runs in the same process, worker, or server.

```go
// BAD — reads the server's whole log buffer and indexes by position
logs, _ := th.SystemAdminClient.GetLogs(ctx, 0, 10)
require.Equal(t, expected, logs[i-10])

// BAD — mutates config for the subtest, relies on a LATER subtest's cleanup
th.App.UpdateConfig(func(cfg *model.Config) { *cfg.ServiceSettings.MaximumURLLength = 100 })

// GOOD — filter to rows this test created, and restore in the test's own cleanup
mine := filterByPrefix(logs, testRunID)
require.Len(t, mine, 1)
original := *th.App.Config().ServiceSettings.MaximumURLLength
t.Cleanup(func() { th.App.UpdateConfig(func(cfg *model.Config) { *cfg.ServiceSettings.MaximumURLLength = original }) })
```

**Detection**: (a) flag every positional index (`[0]`, `[i-10]`, `.first()`, `getLastPost()`) into the result of a query the test did not scope to its own fixtures — a system post or a sibling's row satisfies it just as well; (b) flag every global stubbed or mutated in the diff — `global.fetch`, `Date.now`, `window.open`, `console.error`, `jest.spyOn`, `viper` state, a process-global set by a setup route, a role patch, an ABAC/banner/config field — with no `t.Cleanup`/`afterEach` restore in the SAME test that set it; (c) flag a subtest whose precondition is state an earlier subtest left behind, and any object shared across subtests then mutated in place (`opts`, a struct passed to `Sanitize()`); (d) flag unscoped destructive SQL (`DELETE FROM TeamMembers` with no `WHERE` on this test's ids). Tag `parallel:SHARED_STATE` (reads) or `parallel:MISSING_CLEANUP` (unrestored writes). Validated by MM PR review: #35816 `server/config/logger.go` (accepted), #36659 `system_test.go` positional `logs[i-10]` (accepted), #37073 `long_url_embedded_image_spec.js` (`MaximumURLLength` never restored, accepted), #37143 `type_change_value_cleanup_test.go` (shared mutable `opts` across subtests, accepted), #37159 `mmctl/commands/post_e2e_test.go` (viper hard-reset, accepted), #36638 masking specs (`purgeFieldsByPrefix` cross-worker, accepted), #34536 `brand_image_setting.test.tsx` (`global.fetch` mock never restored), #35465 `product_notices.test.tsx` (`Date.now`/`window.open`/`console.error` never restored), #36325 `api4/channel_test.go` (subtest relies on the previous subtest's cleanup), #36797 `sqlstore/integrity_test.go` (unscoped `DELETE FROM TeamMembers`), #37457 `webhook_serve.js` (`/setup` stores baseUrl and admin creds in process globals), #37370 `api4/data_retention_test.go` (in-place `Sanitize()`).

### R2. Resource names must be unique per run and per worker (Medium)

A fixture named by a constant — `"testbot"`, `Masking*`, a fixed LDAP group — is the same row for every worker and every rerun against a shared server. The second worker either collides on a uniqueness constraint or, worse, silently operates on the first worker's object; a purge-by-prefix teardown then deletes a sibling's live fixtures.

```go
// BAD — collides on rerun and across workers
bot, _, _ := client.CreateBot(ctx, &model.Bot{Username: "testbot"})

// GOOD — unique per run; teardown scoped to this test's own id
bot, _, _ := client.CreateBot(ctx, &model.Bot{Username: "testbot-" + model.NewId()})
```

**Detection**: flag every literal name/username/prefix used to create or look up a server-side fixture (bot, team, remote cluster, LDAP group, property field) in a test that can run concurrently or rerun against a persistent server. Flag prefix-scoped teardown (`purgeFieldsByPrefix('Masking')`, `deleteAllTeamsNamed(...)`) whose prefix is not unique to the worker. Require a `model.NewId()`/worker-index suffix on both create and cleanup. Tag `parallel:PORT_CONTENTION`. Validated by MM PR review: #37460 `group_mentions/support.ts`, `ldap/support.ts`, `group_configuration/support.ts` (fixed shared LDAP groups and users mutated across workers), #36642 `editor_states.spec.ts:31` and `modes_and_role_views.spec.ts:36` (global `purgeFieldsByPrefix('Masking')`), #36355 `bot_e2e_test.go` (hardcoded `"testbot"` username).

### R3. Test-side concurrency primitives must be bounded and on the test goroutine (Medium)

Tests spawn goroutines to exercise concurrent code, then get the test harness's own rules wrong: `require`/`FailNow` outside the test goroutine leaves the test hung instead of failed, an unbounded channel receive hangs until the package timeout with no diagnostic, and an assertion made while holding the lock under test can deadlock against the code it is testing.

```go
// BAD — hangs forever if the backend never starts; no timeout, no message
<-be.started

// GOOD — bounded, and the failure names what did not happen
select {
case <-be.started:
case <-time.After(5 * time.Second):
    t.Fatal("backend never signalled started")
}
```

**Detection**: in any test that starts a goroutine or waits on a channel, flag (a) a bare `<-ch` or `wg.Wait()` with no `select`/`time.After` bound, (b) `require.*`/`t.Fatal`/`FailNow` called inside a spawned goroutine — require `assert.*` plus a channel-reported error instead, (c) an assertion or `require.Len` evaluated while a mutex the production code also takes is held, and (d) a resource release (slot, connection, semaphore) asserted immediately after `close()` with no wait for the release to land. Tag `parallel:TEST_CONCURRENCY_MISUSE`. Validated by MM PR review: #36856 `docextractor_test.go` (unbounded receive on `be.started`, accepted), #37301 `docextractor_test.go` (slot release not awaited after `close()`, accepted), #36862 `api4/shared_channel_metadata_test.go` (`require.Len` while holding `muA`).

---

## Output Format

Use the canonical format from `~/.claude/agents/_shared/finding-format.md`.

**Critical requirements:**
- Every MUST_FIX finding MUST include a `Diff evidence:` field with a verbatim `+` line from git diff
- Every finding MUST include `[VERIFIED]` (evidence re-read from source after forming conclusion) or `[UNVERIFIED]` (not independently verified)
- Findings in pre-existing unchanged code must be tagged as `[PRE-EXISTING][INFO]` and excluded from MUST_FIX/SHOULD_FIX counts

Domain tags:

| Tag | Category |
|-----|----------|
| `parallel:ENV_LEAK` | Process-global env var mutation without proper scoping |
| `parallel:SHARED_STATE` | Mutable shared state between concurrent tests |
| `parallel:UNSYNCED_OVERRIDE` | Test-only override field without synchronization primitives |
| `parallel:MISSING_CLEANUP` | State mutation without corresponding cleanup/reset |
| `parallel:FIXTURE_MUTATION` | Shared test fixture modified without isolation |
| `parallel:PORT_CONTENTION` | Hardcoded ports or resources that conflict under parallelism |
| `parallel:DB_COUPLING` | Test relies on database state from another test |
| `parallel:INCONSISTENT_PATTERN` | Override pattern inconsistency (e.g., direct field access vs setter) |
| `parallel:FS_LOCK_TOCTOU` | Verify-then-act on a lock file path; missing ownership token or fd-based operations |
| `parallel:TEST_CONCURRENCY_MISUSE` | Unbounded channel wait, `require` off the test goroutine, assertion under a contended lock |

## Anti-Slop Guidance (Do NOT Flag)

- **Do not flag** `t.Setenv` usage — it is the CORRECT pattern for parallel-safe env manipulation
- **Do not flag** `t.Chdir` or `t.TempDir` usage — these are CORRECT patterns with automatic cleanup
- **Do not flag** `os.Setenv` in package-level parallelism (`go test -p N`) — separate processes have isolated env, this is safe
- **Do not flag** module-level state in Jest workers — each worker is a separate process, module state is isolated per worker
- **Do not flag** direct struct field access in same-package tests — Go's same-package rule allows this; check if the field is read by concurrent goroutines, not just accessed from test code
- **Do not flag** database state from sibling tests IF each test gets a clean database snapshot — fixture isolation is the check, not "tests share a DB"

---

## See Also

- `concurrent-go-reviewer` — Go production concurrency bugs (goroutines, mutexes, channels, TOCTOU)
- `race-condition-reviewer` — TypeScript/React async race conditions
- `test-engineer` — Test strategy, coverage analysis, mock quality
- `ci-design-reviewer` — CI/CD workflow design and merge gate correctness
