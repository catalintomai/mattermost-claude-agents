# Error Handling Patterns

Universal Go, TypeScript, and React error handling patterns. Referenced by error-handling reviewers across projects.

---

## Go: Universal Anti-Patterns

### Ignored Errors (Critical)

```go
// BAD — error completely ignored
result, _ := someFunction()

// BAD — error assigned but never checked
err := doSomething()
// ... code continues without checking err
```

**Exception**: Explicitly documented ignores are acceptable:
```go
// We intentionally ignore this error because X
_ = closeResource()
```

### Missing Error Wrapping (High)

```go
// BAD — no context, caller cannot tell where the error originated
return nil, err

// GOOD — wrapped with context
return nil, errors.Wrap(err, "failed to get page children")
// or with format
return nil, fmt.Errorf("get page children: %w", err)
```

---

## TypeScript / JavaScript: Universal Anti-Patterns

### Swallowed Errors (High)

```typescript
// BAD — error silently discarded
try {
    await doSomething();
} catch (e) {
    // empty catch, or just console.log
}

// BAD — .catch with empty handler
promise.catch(() => {});

// GOOD — error surfaced to user or caller
try {
    await doSomething();
} catch (error) {
    handleError(error);    // log, dispatch, set state, throw — anything but silence
}
```

### Fire-and-Forget Promises (High)

```typescript
// BAD — unhandled rejection, no await, no .catch
dispatch(savePage(data));

// GOOD — awaited
await dispatch(savePage(data));

// GOOD — explicit catch
dispatch(savePage(data)).catch(handleError);
```

---

## React: Universal Anti-Patterns

### Missing Error State in UI (Medium)

```typescript
// BAD — no error handling in component
const Component = () => {
    const data = useSelector(selectData);
    return <div>{data}</div>;
};

// GOOD — handles loading and error states
const Component = () => {
    const {data, loading, error} = useSelector(selectDataWithStatus);
    if (loading) return <LoadingSpinner />;
    if (error) return <ErrorMessage error={error} />;
    return <div>{data}</div>;
};
```

### React Error Boundaries (Medium)

For components that render dynamic or external content:
1. Wrap the component tree in an Error Boundary
2. Show a useful fallback — not a blank screen
3. Note: Error Boundaries do NOT catch:
   - Event handler errors (use try/catch in handlers)
   - Async errors (use try/catch in async functions)
   - Server-side rendering errors

---

## Universal Review Scan Patterns

```bash
# Ignored errors (Go)
grep -n ", _.*:=" <file>
grep -n "_ =" <file>

# Missing error check (Go) — verify each has a following `if err != nil`
grep -n "err :=" <file>

# Empty catch blocks (TypeScript)
grep -n "catch.*{}" <file>
grep -n "\.catch\(\(\) =>" <file>
```

---

## Promise Chain Completeness

For async operations:
1. Every `await` is inside a `try` block — or has `.catch()` handling
2. `Promise.all` vs `Promise.allSettled` — use the right one for the scenario (`.all` fails fast; `.allSettled` collects all results regardless of failure)
3. No fire-and-forget promises (missing `await` or `.catch()`)
