---
name: pb-lint
description: Run i18n extraction then all linters. Always run make i18n-extract before linting to keep webapp/i18n/en.json in sync.
version: 1.7.0
tags:
  - lint
  - i18n
---

# Lint (Playbooks)

Run i18n extraction first, then all linters. This prevents the CI failure:
`Please run "make i18n-extract" and commit the changes in webapp/i18n/en.json.`

## Working directory

All commands must run from the **current session's working directory** — the git worktree where the changed files live. Never `cd` to the main repo checkout just because the skill definition was found there. If the session is inside a split worktree (e.g. `.split-worktrees/create-placeholder-for-task-assignment/`), run every command from that directory.

## Steps

### 1. Regenerate GraphQL types

```bash
make graphql
```

Check if any generated files changed:

```bash
git diff --stat webapp/src/graphql/generated/
```

If they changed, **tell the user** so they can include the generated files in their commit. The CI check `git --no-pager diff --exit-code webapp/src/graphql/generated/` will fail if these are out of sync.

### 2. Extract i18n strings

```bash
make i18n-extract
```

Check if `webapp/i18n/en.json` changed:

```bash
git diff --stat webapp/i18n/en.json
```

If it changed, **tell the user** so they can include it in their commit.

### 3. Check gofmt (run this before golangci-lint — the cache can mask gofmt failures)

```bash
gofmt -l ./server/...
```

If any files are listed, they are not properly formatted. Fix them with:

```bash
gofmt -w <file>
```

Report which files were fixed. This step must always run uncached — do not skip it.

### 4. Clear caches, then run all linters

`make check-style` runs webapp ESLint, webapp TypeScript type-check, E2E linter, and golangci-lint in one shot. All lint caches and the golangci-lint cache must be cleared first — otherwise recently edited files (especially those changed in a worktree) are silently skipped.

```bash
rm -f webapp/.eslintcache webapp/.stylelintcache e2e-tests/.eslintcache
bin/golangci-lint cache clean
make check-style
```

If `make check-style` is unavailable, fall back to running each piece separately:

```bash
cd webapp && npm run lint          # ESLint + stylelint
cd webapp && npm run check-types   # TypeScript
cd e2e-tests && npm run check      # E2E lint (TypeScript files)
bin/golangci-lint run ./...        # Go
```

Run from the repo root (not inside `server/`). Report any errors. Fix them if possible.

## Output

After all steps complete, summarize:
- Whether `webapp/src/graphql/generated/` was updated (and needs to be committed)
- Whether `webapp/i18n/en.json` was updated (and needs to be committed)
- Whether any files needed gofmt and were fixed
- Any remaining lint errors

## Anti-patterns
- Skipping `make graphql` when the GraphQL schema changed — the CI check `git --no-pager diff --exit-code webapp/src/graphql/generated/` will fail if generated types are stale, even if all linters pass locally.
- Skipping the `gofmt -l` step because `make check-style` "should" catch it — the golangci-lint cache can mask gofmt failures that CI (which runs without a cache) will catch.
- Clearing only `webapp/.eslintcache` and forgetting `e2e-tests/.eslintcache` — TypeScript files in e2e-tests (e.g. `cypress.config.ts`) will be silently skipped if the e2e cache is stale. Always clear all three caches together.
- Forgetting `webapp/.stylelintcache` — stylelint also caches by file-content hash and can miss recently edited `.ts`/`.tsx`/`.scss` files.
- Running `make check-style` without first deleting lint caches — ESLint and stylelint skip files they think haven't changed, so files edited in a worktree or outside the main repo will be silently ignored. This is how TS/ESLint errors slip past a local lint run but still fail CI.
- Running `make check-style` without clearing the golangci-lint cache first when Go files were recently edited.
- Running commands from the main repo checkout when the session is in a split worktree — ESLint lints the main repo's files and silently misses all changes in the worktree, producing a false-clean result.
- Trusting a clean cache-cleared run in a split worktree without spot-checking recently modified test files — the `.eslintcache` can reflect a pre-modification state for files that were last cached before the worktree's changes landed. After `make check-style` passes, always run ESLint directly on the diff'd TypeScript files to confirm: `git diff master --name-only | grep -E '\.(tsx?|jsx?)$' | xargs npx eslint --quiet`.

## Self-rewrite hook
After every 5 uses OR on any failure:
1. Check if a new CI failure appeared that this skill missed.
2. If so, add it to Anti-patterns and tighten the step language.
3. Commit: `skill-update: pb-lint, <one-line reason>`.