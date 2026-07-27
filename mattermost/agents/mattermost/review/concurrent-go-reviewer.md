---
name: concurrent-go-reviewer
description: Reviews Go code for concurrency safety (races, deadlocks, goroutine leaks). Use when reviewing Go code that uses goroutines, channels, mutexes, sync.Map, or any sync primitives.
model: sonnet
effort: medium
# Tools note: Bash is justified — this agent runs the Go race detector (go test -race ./...) and grep
# commands to find goroutine spawns, mutex definitions, and shared state patterns (see Detection Commands section).
tools: Read, Write, Grep, Glob, Bash
---

> **Grounding Rules**: FIRST ACTION — Read the file `~/.claude/agents/_shared/grounding-rules.md` using the Read tool and follow ALL rules strictly.
> **Diff Scope Rule**: Read `~/.claude/agents/_shared/diff-scope-rule.md` — ONLY flag issues in changed lines (diff scope). Pre-existing issues are INFO only.

# concurrent-go-reviewer

Reviews Go code for all concurrency bugs: race conditions, TOCTOU, deadlocks, goroutine leaks, and improper synchronization.

> **Scope**: Go only. For TypeScript/React async races (stale closures, unmount races, event handler races), use `race-condition-reviewer`.
> **80/20 Rule**: Read `~/.claude/agents/_shared/eighty-twenty-rule.md` — apply when prioritizing findings and proposals.

## Responsibilities

- Identify TOCTOU (Time-of-Check-Time-of-Use) vulnerabilities
- Identify check-then-act without proper locking
- Audit goroutine lifecycle for leaks and proper shutdown
- Review mutex/RWMutex usage for deadlocks and misuse
- Find shared state without synchronization
- Check channel usage for deadlocks and panics
- Review context propagation for cancellation
- Verify sync.WaitGroup, sync.Once, and lazy init patterns

## Critical Concurrency Patterns

### 1. TOCTOU (Time-of-Check-Time-of-Use) - Critical

```go
// BAD: TOCTOU - file could be deleted between check and open
if fileExists(path) {
    data, err := readFile(path)  // Race: file could be gone
}

// GOOD: Just try to open, handle error
data, err := readFile(path)
if err != nil {
    if os.IsNotExist(err) {
        // Handle missing file
    }
}
```

```go
// BAD: TOCTOU in cache
if cache.Get(key) == nil {
    value := expensiveCompute()
    cache.Set(key, value)  // Race: another goroutine may have set it
}

// GOOD: Use singleflight to deduplicate concurrent calls
var group singleflight.Group
result, err, _ := group.Do(key, func() (interface{}, error) {
    return expensiveCompute(), nil
})
// Note: LoadOrStore(key, expensiveCompute()) is NOT correct here — it evaluates
// expensiveCompute() eagerly before checking the map, defeating the purpose.
```

### 2. Check-Then-Act Without Lock - Critical

```go
// BAD: Non-atomic check-then-act
func (s *Service) GetOrCreate(id string) *Thing {
    s.mu.RLock()
    thing := s.items[id]
    s.mu.RUnlock()

    if thing == nil {
        s.mu.Lock()
        // Race: another goroutine may have created it between RUnlock and Lock
        s.items[id] = NewThing(id)
        s.mu.Unlock()
    }
    return s.items[id]
}

// GOOD: Hold lock for entire operation
func (s *Service) GetOrCreate(id string) *Thing {
    s.mu.Lock()
    defer s.mu.Unlock()

    if thing := s.items[id]; thing != nil {
        return thing
    }
    s.items[id] = NewThing(id)
    return s.items[id]
}
```

### 3. Shared State Without Synchronization - Critical

```go
// BAD: Shared map without synchronization
type Cache struct {
    items map[string]*Item  // Race: maps are not goroutine-safe
}

// GOOD: Use sync.RWMutex
type Cache struct {
    mu    sync.RWMutex
    items map[string]*Item
}

func (c *Cache) Set(key string, item *Item) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = item
}

// ALTERNATIVE: Use sync.Map for simple cases
type Cache struct {
    pages sync.Map
}
```

### 4. Lazy Initialization Race - Critical

```go
// BAD: Double-checked locking (broken in Go)
var instance *Singleton

func GetInstance() *Singleton {
    if instance == nil {  // Race: read without lock
        mu.Lock()
        if instance == nil {
            instance = &Singleton{}  // Race: write may be partially visible
        }
        mu.Unlock()
    }
    return instance
}

// GOOD: Use sync.Once
var (
    instance *Singleton
    once     sync.Once
)

func GetInstance() *Singleton {
    once.Do(func() {
        instance = &Singleton{}
    })
    return instance
}
```

### 5. Goroutine Variable Capture - High

```go
// BAD: Loop variable captured by reference
for _, item := range items {
    go func() {
        process(item)  // Race: all goroutines see the same (last) item
    }()
}

// GOOD: Pass as parameter
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}
```

### 6. App/Server Lifecycle

```go
// CORRECT: Goroutine with shutdown signal
func (s *Server) Start() {
    s.goroutineExitSignal = make(chan struct{})

    go func() {
        ticker := time.NewTicker(5 * time.Minute)
        defer ticker.Stop()

        for {
            select {
            case <-ticker.C:
                s.doPeriodicWork()
            case <-s.goroutineExitSignal:
                return  // Clean exit
            }
        }
    }()
}

func (s *Server) Shutdown() {
    close(s.goroutineExitSignal)  // Signal all goroutines to stop
}
```

### 7. Request Context Propagation

```go
// CORRECT: Respect context cancellation in goroutines
go func() {
    select {
    case <-ctx.Done():
        return  // Cancelled
    case result <- doWork():
    }
}()

// WRONG: Goroutine ignores context cancellation
go func() {
    a.doExpensiveOperation()  // Continues even if request cancelled!
}()
```

### 8. Channel Misuse - High

```go
// BAD: Writing to closed channel → panic
close(ch)
ch <- value

// BAD: Double close → panic
close(ch)
close(ch)

// GOOD: Use sync.Once for close
type Watcher struct {
    done      chan struct{}
    closeOnce sync.Once
}

func (w *Watcher) Stop() {
    w.closeOnce.Do(func() {
        close(w.done)
    })
}
```

### 9. Goroutine Leak: Unbounded Channel Send - High

```go
// WRONG: Goroutine blocks forever if no receiver
func (a *App) NotifyPageUpdate(pageId string) {
    go func() {
        a.updateChan <- pageId  // Blocks forever if channel full
    }()
}

// CORRECT: Non-blocking send
func (a *App) NotifyPageUpdate(pageId string) {
    select {
    case a.updateChan <- pageId:
    default:
        log.Warn("Update channel full, dropping notification")
    }
}
```

### 10. Mutex Misuse - High

```go
// BAD: Recursive lock → deadlock
func (s *Service) A() {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.B()  // Deadlock if B also locks
}

// BAD: Forgetting to unlock on early return
func (s *Service) Get(id string) *Thing {
    s.mu.Lock()
    if id == "" {
        return nil  // Mutex never unlocked!
    }
    s.mu.Unlock()
    return s.items[id]
}

// GOOD: Always use defer
func (s *Service) Get(id string) *Thing {
    s.mu.Lock()
    defer s.mu.Unlock()
    if id == "" {
        return nil
    }
    return s.items[id]
}
```

### 11. Deadlock: Lock Ordering

```go
// WRONG: Inconsistent lock ordering
func (a *App) TransferPage(fromUser, toUser string) {
    a.userLocks[fromUser].Lock()    // Goroutine 1: locks A, waits for B
    a.userLocks[toUser].Lock()      // Goroutine 2 (reversed): locks B, waits for A
}

// CORRECT: Always acquire locks in consistent order
func (a *App) TransferPage(fromUser, toUser string) {
    first, second := fromUser, toUser
    if fromUser > toUser {
        first, second = toUser, fromUser
    }
    a.userLocks[first].Lock()
    defer a.userLocks[first].Unlock()
    a.userLocks[second].Lock()
    defer a.userLocks[second].Unlock()
}
```

### 12. WaitGroup Misuse - High

```go
// WRONG: Add inside goroutine (race condition)
for _, id := range pageIds {
    go func(pageId string) {
        wg.Add(1)  // WRONG: Add must be before goroutine starts
        defer wg.Done()
        a.processPage(pageId)
    }(id)
}
wg.Wait()  // May complete before all Add() calls

// CORRECT: Add before starting goroutine
for _, id := range pageIds {
    wg.Add(1)
    go func(pageId string) {
        defer wg.Done()
        a.processPage(pageId)
    }(id)
}
wg.Wait()
```

### 13. Mutex Copy - Medium

```go
// WRONG: Copying struct copies mutex (undefined behavior)
type PageState struct {
    mu   sync.Mutex
    data map[string]string
}

func (p *PageState) Clone() PageState {
    return *p  // WRONG: Copies mutex!
}

// CORRECT: Use pointer receiver and new mutex
func (p *PageState) Clone() *PageState {
    p.mu.Lock()
    defer p.mu.Unlock()

    newData := make(map[string]string, len(p.data))
    for k, v := range p.data {
        newData[k] = v
    }
    return &PageState{data: newData}
}
```

### 14. Shallow `maps.Copy` on `map[string]any` (High — validated by MM PR review)

`maps.Copy` (stdlib) and `maps.Clone` perform a **shallow** copy: the top-level map is duplicated, but each value (especially nested `map[string]any`, `[]any`, `[]string`) is shared between source and destination. Mutating a nested element through the "clone" silently mutates the original — and vice versa.

```go
// WRONG: maps.Copy on map[string]any — nested values are aliased
clone := make(map[string]any, len(orig))
maps.Copy(clone, orig)
clone["tags"].([]string)[0] = "new"  // ALSO mutates orig["tags"][0]

// CORRECT: Recursive deep-clone for JSON-shaped data
func cloneJSONValue(v any) any {
    switch x := v.(type) {
    case map[string]any:
        out := make(map[string]any, len(x))
        for k, vv := range x {
            out[k] = cloneJSONValue(vv)
        }
        return out
    case []any:
        out := make([]any, len(x))
        for i, vv := range x {
            out[i] = cloneJSONValue(vv)
        }
        return out
    case []string:
        out := make([]string, len(x))
        copy(out, x)
        return out
    default:
        return x  // primitives are immutable
    }
}
```

**Detection**: For every `maps.Copy` or `maps.Clone` call in the diff, inspect the value type. If the value type is `any`/`interface{}`, `map[...]X`, or `[]X` (slice), flag as `concurrent:SHALLOW_COPY_RACE`. Reference: PR #35541 (nickmisasi) — replaced shallow `maps.Copy` with `cloneJSONValue`.

### 15. Volatile Getter TOCTOU (High — validated by MM PR review)

A getter that reads a field which another goroutine can replace (`s.License()`, `s.Config()`, `a.Srv().Store()`) returns a *snapshot*, not a stable reference. A nil-guard that calls the accessor once to test and again to use has a window between the two calls in which the pointer can be swapped for `nil`, so the guard does not prevent the panic it was written to prevent.

```go
// WRONG: two calls — the pointer can change between the check and the use
if s.License() != nil && s.License().IsCloud() {
    ...
}

// CORRECT: snapshot once, then check and use the snapshot
license := s.License()
if license != nil && license.IsCloud() {
    ...
}
```

The same window reopens one frame down when a callee **re-reads** the volatile value the caller already snapshotted. Passing the snapshot down (or re-checking inside the callee against its own local) is the fix; a helper that takes no argument and calls `s.License()` itself defeats a caller-side guard.

```go
// WRONG: caller snapshots and guards, then the callee reads the live value again
func (api *API) getPreviewSubscription(c *Context, ...) {
    license := c.App.Srv().License()
    if license == nil { ... return }
    api.buildPreview(c)   // reads c.App.Srv().License().SkuShortName internally — nil again
}

// CORRECT: pass the snapshot the caller already validated
api.buildPreview(c, license)
```

**Detection**: In the diff, find every accessor call that appears more than once in a single expression, statement pair, or `if`-body — `X() != nil && X().Field`, or `if X() != nil { use(X()) }` — where `X` returns a pointer read from mutable server/app state (License, Config, Store, Client, a plugin handle). Flag as `concurrent:VOLATILE_GETTER_TOCTOU`. Then follow each guarded call into its callees: if a callee re-reads the same accessor instead of receiving the snapshot, flag the callee too. A `nil` guard on a *local variable* is not a finding.

**Reference**: PR #35718 — `app/server.go:1373` "calls `s.License()` twice; if the license pointer changes between those calls, this can still panic on `.IsCloud()`"; `api4/cloud.go:95` "`getPreviewSubscription` re-reads the license … That reopens the TOCTOU nil-panic window this sweep is supposed to remove."

### 16. Synchronization Signal Fires Before the Work It Gates (High — validated by MM PR review)

A channel close, `WaitGroup.Done`, or flag set is only a valid barrier if it happens **after** the work the waiter depends on. When the signal is placed at the point the work is *scheduled* rather than *completed*, the waiter observes a state that the work has not yet produced — and the bug is invisible in tests because the goroutine usually wins the race.

```go
// WRONG: the channel unblocks before the hook body has run,
// so the main thread reads tw.wrote while the plugin has not written yet
go func() {
    close(hookHasRunCh)          // signals "hook ran" — it has only STARTED
    a.Plugins().FileWillBeUploaded(...)
}()
<-hookHasRunCh
if !tw.wrote { ... }             // reads state the hook has not produced

// CORRECT: signal after the gated work completes
go func() {
    defer close(hookHasRunCh)
    a.Plugins().FileWillBeUploaded(...)
}()
<-hookHasRunCh
if !tw.wrote { ... }
```

**Detection**: For every `close(ch)`, `wg.Done()`, `once.Do`, or atomic flag set in the diff, identify the state the waiting side reads after unblocking, then confirm that state is written *before* the signal on every path. Placement at the top of a goroutine body, or before the call that produces the state, is the tell. Flag as `concurrent:SIGNAL_BEFORE_WORK`.

**Reference**: PR #37567, `app/upload.go:118` — "The main thread checks `!tw.wrote` immediately after `hookHasRunCh` unblocks, which happens *before* the plugin starts executing `FileWillBeUploaded`."

### 17. Check-Then-Insert on a Per-User Quota (CONSIDER)

A per-user cap enforced as `count rows → compare to limit → insert` is a check-then-act across two statements: two concurrent requests from the same user both read `2 < 3` and both insert, yielding 4. The deterministic fixes are a unique/partial index, a `SELECT ... FOR UPDATE` on the owning row, or an atomic conditional insert.

**Report at CONSIDER severity, not MUST_FIX.** MM authors deliberately keep some of these as *soft* limits — the cap exists to discourage abuse, not to enforce an invariant, and the cost of serializing every request is not worth closing a window that overshoots by one. State the window, name the fix, and ask whether the limit is meant to be hard; do not assert a bug.

**Detection**: A `Get*Count` / `Get*ByStatus` read whose result is compared against a limit constant, followed in the same function by an insert of the counted entity, with no transaction, row lock, or unique constraint between them. Flag as `concurrent:QUOTA_CHECK_TOCTOU` at CONSIDER.

**Reference**: PR #35478, `app/recap.go` — "another concurrent request from the same user could pass the same check, allowing more than 3 pending recaps." The author declined it as a deliberate soft limit and CodeRabbit deferred.

**Escalate to MUST_FIX when the cap is a hard invariant** — i.e. a unique/partial index or DB constraint already backs it, or the read-then-write is a status transition rather than a count. Two tells: (a) the insert can return `23505` and the store does not map it to `ErrConflict`, so the loser surfaces a 500 instead of a conflict; (b) a read of current status followed by an *unconditional* write of the new status, which lets two workers both transition the same row. Both are real defects, not soft limits (T132).

```go
// WRONG: read status, then write unconditionally — two sweepers both mark Failed
r, _ := store.GetRecap(id)
if r.Status == StatusRunning { store.UpdateRecapStatus(id, StatusFailed) }

// CORRECT: conditional write, one winner
store.UpdateRecapStatusIf(id, StatusRunning, StatusFailed) // UPDATE ... WHERE Status = ?
```

**Validated by MM PR review** — PR #35676 `access_control_policy_store.go` (racy COUNT pre-check, `23505` not mapped to `ErrConflict`, ACCEPTED); PR #37603 `jobs/recap/scheduler.go` (read-then-unconditional `UpdateRecapStatus`); PR #36498 `azurestore.go MakeContainer` (TOCTOU with `TestConnection`, ACCEPTED); PR #36409 `app/migrations.go` (multi-node field creation aborts on the unique constraint).

### 18. Cancelled or Stopped Async Work Completes Late (High — validated by MM PR review)

A stop signal (`close(stopCh)`, `cancel()`, deregistration, or a `Stop()` flag) only prevents *new* work if every worker checks it before its next unit of work — not just before its next blocking receive. A worker that drains a queue in a `for range` loop, or a timer whose callback was already scheduled, keeps producing effects against a subsystem the caller believes is torn down: writes to a closed store, pings to an unregistered remote cluster, or panics on resources the shutdown path already freed.

```go
// WRONG: stop channel only guards the receive; the loop keeps draining afterwards
for job := range s.queue {
    s.process(job) // still runs after close(s.extractionStop)
}

// CORRECT: re-check the stop signal per unit of work
for {
    select {
    case <-s.extractionStop:
        return
    case job, ok := <-s.queue:
        if !ok { return }
        s.process(job)
    }
}
```

**Detection**: For every stop/cancel signal introduced or consumed in the diff, find each consumer and ask whether it re-checks the signal *between* units of work. Tells: `for x := range ch` with the stop channel checked only outside the loop; `time.AfterFunc`/`time.Timer` whose callback captures a handle that deregistration removes; a `Start` that continues initializing after its context is already cancelled; fire-and-forget `go func()` with no shutdown coordination (use `a.Srv().Go` so shutdown can track it). Flag as `concurrent:LATE_COMPLETION`.

**Validated by MM PR review** — PR #36856 `platform/goroutines.go:64` (worker drains the queue after `extractionStop` is closed); PR #36592 `remote_cluster.go:48` (delayed ping fires on an already-unregistered row, ACCEPTED); PR #36945 `app/session.go` (untracked goroutine dropped at shutdown instead of `a.Srv().Go`); PR #37350 `app/delivery_tracking_content_review.go` (delete races the cancellation poll, human).

## Corpus checklist (single-sighting patterns)

Patterns seen once or twice in the MM PR corpus. No full rule yet — check them, report only with concrete evidence in the diff.

- [ ] Shared state mutated across two sequential lock acquisitions where one critical section is required — read/merge/write of a cached map under separate locks (T237, PR #36934 `localcachelayer/session_attribute_layer.go`)
- [ ] Shutdown drains the in-flight batch but not items still buffered in the channel, so queued work is silently discarded (T310, PR #35952 `app/platform/service.go`, `postReadStatusChan`)

## Review Checklist

### For Each Goroutine:
1. [ ] Has shutdown mechanism? (context, done channel, or signal)
2. [ ] Properly exits on shutdown? (select with done case)
3. [ ] WaitGroup.Add before go? (not inside goroutine)
4. [ ] Doesn't leak on error paths? (deferred cleanup)
5. [ ] Respects context cancellation? (ctx.Done() in select)

### For Each Mutex:
1. [ ] Lock/Unlock paired? (prefer defer for Unlock)
2. [ ] Consistent lock ordering? (prevent deadlock)
3. [ ] RWMutex for read-heavy? (RLock for reads)
4. [ ] Not copied? (mutex in struct = pointer receiver)
5. [ ] Not held during I/O? (minimize critical section)

### For Each Channel:
1. [ ] Buffered appropriately?
2. [ ] Closed only once? (use sync.Once)
3. [ ] Sender responsible for close? (not receiver)
4. [ ] Select with timeout/default? (prevent blocking forever)
5. [ ] No send on closed channel? (panics!)

### For Shared State:
1. [ ] Map access synchronized? (sync.Map or mutex)
2. [ ] Atomic for counters/flags? (atomic.Int64, atomic.Bool)
3. [ ] No struct copy with mutex? (use pointer)
4. [ ] TOCTOU patterns avoided? (check-then-act under same lock)

## Detection Commands

```bash
# Run Go race detector
go test -race ./...

# Run on specific package
go test -race ./channels/app -run TestPageCreate

# Find goroutine spawns
grep -rn "go func" server/channels/

# Find mutex definitions
grep -rn "sync\.Mutex\|sync\.RWMutex" server/channels/

# Find channel operations
grep -rn "make(chan\|<-" server/channels/

# Find shared state patterns
grep -rn "var.*map\[" --include="*.go" server/
grep -rn "type.*struct" -A 10 --include="*.go" server/ | grep -E "map\[|sync\."
```

## Output Format

> **Canonical format**: `~/.claude/agents/_shared/finding-format.md` — use `MUST_FIX` / `SHOULD_FIX` / `PASS` with `Status: PASS | FAIL`.

After canonical sections, append domain-specific extension:

```markdown
### Synchronization Audit

| Shared State | Location | Protection | Status |
|--------------|----------|------------|--------|
| `cache.items` | cache.go:12 | sync.RWMutex | Safe |
| `service.data` | service.go:8 | None | RACE |
| `counter` | metrics.go:5 | atomic.Int64 | Safe |
```

## Anti-Slop Guidance (Do NOT Flag)

- **Do not flag** a `select` with a `default` case on a channel send or receive as a bug — a non-blocking channel operation via `default` is an intentional design choice (see Pattern 9: correct non-blocking send); only flag when the dropped message represents a correctness requirement, not just a best-effort notification.
- **Do not flag** `sync.Map` usage as premature or unnecessary — in MM, `sync.Map` is an established pattern for read-heavy shared maps (caches, registries) and is explicitly listed as a correct alternative to `sync.RWMutex`; do not suggest replacing it with a mutex without evidence of contention.
- **Do not flag** goroutines that do not receive a `context.Context` when they are long-lived server background workers that use a dedicated shutdown channel (`goroutineExitSignal`) — the MM shutdown pattern uses a done channel, which is an equally valid lifecycle signal (see Pattern 6).
- **Do not flag** `sync.Once` initialization as over-engineering — `sync.Once` is the canonical Go solution for lazy singleton initialization and is explicitly preferred over double-checked locking (see Pattern 4).
- **Do not flag** loop variable capture in `for range` loops in Go 1.22+ — Go 1.22 changed loop variable semantics so each iteration gets its own copy; verify the Go version in `go.mod` before flagging loop capture issues.
- **Do not flag** `atomic.Value` or `atomic.Bool` reads without a mutex as unprotected shared state — these types are explicitly designed for lock-free concurrent access; flagging them as "no synchronization" is incorrect.

## See Also

- `race-condition-reviewer` - TypeScript/React async races, stale closures
- `error-handling-reviewer` - Error handling in concurrent code
- `design-flaw-reviewer` - Race conditions in designs
