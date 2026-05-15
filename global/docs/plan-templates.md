# Plan Templates

Reference doc for `/create-plan`. Contains all plan templates extracted for progressive disclosure.

## Frontend Pattern References (Auto-Include When Planning UI)

When plan contains UI/component/frontend keywords, include these patterns in the Technical Approach:

### Component Patterns
```markdown
## Component Structure
- Folder-by-feature: `my_component/`, `my_component.tsx`, `my_component.scss`, `my_component.test.tsx`
- Functional components with hooks (`useSelector`, `useDispatch`, `useCallback`, `useMemo`)
- Code splitting with `makeAsyncComponent` for heavy routes

## Styling Requirements
- Co-located SCSS files imported in component
- BEM naming: `.MyComponent`, `.MyComponent__title`
- CSS variables for colors: `var(--center-channel-color)`
- No `!important`

## Accessibility (MANDATORY)
- Semantic HTML (`<button>`, `<input>`) over `<div>` with roles
- Keyboard support for all interactive elements
- Use `GenericModal`, `Menu`, `WithTooltip` primitives

## Internationalization (MANDATORY)
- All UI strings via `<FormattedMessage>` or `useIntl()`
```

### Redux Patterns
```markdown
## Actions
- Return `{data}` on success, `{error}` on failure
- Use `bindClientFunc` for simple API calls
- Call Client4 ONLY from actions, never components
- Handle errors with `forceLogoutIfNecessary` + `logError`

## Selectors
- Memoize with `createSelector` when returning arrays/objects
- First param is selector name: `createSelector('getSomething', ...)`
- Use `makeGet*` factory for parameterized selectors
- Use `useMemo(makeGetX, [])` in components

## Reducers
- Immutable updates (spread operator)
- Always handle `UserTypes.LOGOUT_SUCCESS` to clear state
- `state.entities.*` for server data, `state.views.*` for UI
```

### Testing Patterns
```markdown
- RTL tests alongside components (`*.test.tsx`)
- Use `userEvent` and `getByRole` queries
- No snapshots - assert visible behavior
- Mock store with `renderWithRedux`
```

---

## Generic Plan Template

```markdown
# [Feature Name]

## Overview
[1-2 sentence summary]

## Problem Statement
[What problem does this solve? Why is it needed now?]

## Current State
[How does it work today? What hooks/components exist?]

### Current Gaps
- [Gap 1: e.g., No cancellation support]
- [Gap 2: e.g., No progress tracking]

## Design Principles (MM-Aligned)
| Pattern | MM Approach | NOT MM | Reference |
|---------|-------------|--------|-----------|
| [e.g., Navigation] | Allow freely, never block | useBlocker, Prompt dialogs | - |
| [e.g., Async tracking] | Redux state `{[id]: data}` | Local component state | `marketplace.installing` |
| [e.g., Cancellation] | `AbortController.abort()` | Just ignore results | `file_upload.tsx:570` |
| [e.g., Notifications] | Toast component | Modal popup | `toast/toast.tsx` |

## Reference Patterns
Similar MM features to follow:
- `[file:line]` - [what pattern it demonstrates]
- `[file:line]` - [what pattern it demonstrates]

## Requirements
- [ ] Requirement 1
- [ ] Requirement 2

## Out of Scope
- NOT doing X
- NOT doing Y

## Technical Approach
[How we'll build it - aligned with MM patterns above]

## Decisions
| Question | Decision | Rationale |
|----------|----------|-----------|
| [e.g., State complexity?] | [Minimal] | [Only track active ops] |
| [e.g., Error structure?] | [Simple string] | [Typed errors add complexity] |

## Files to Modify
| File | Change |
|------|--------|

## Tasks
1. [ ] Task 1
2. [ ] Task 2

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|

## UX Summary (for UI features)
| Scenario | Behavior |
|----------|----------|
| [User starts operation] | [Progress bar appears] |
| [User clicks cancel] | [Operation dismissed, server may complete] |
| [Operation completes] | [Toast with action link] |

## Testing Plan
**Unit**: [e.g., Reducer state transitions, selector logic]
**Integration**: [e.g., Cancel during progress, navigation away/back]
**E2E**: [e.g., Full flow: start → progress → complete → navigate]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

### Template Section Guidelines

| Section | When to Include |
|---------|-----------------|
| **Problem Statement** | Always - provides context |
| **Current State / Gaps** | Always - shows what exists |
| **Design Principles** | Always for MM projects - key differentiator |
| **Reference Patterns** | When following existing MM patterns |
| **Decisions** | When making non-obvious choices |
| **UX Summary** | UI/frontend features only |
| **Testing Plan** | Features requiring new tests |
| **Phase Strategy** | Large features (>1 week) - see below |

### Completeness Checklists (used by Step 2.25 in `/create-plan`)

These define the MANDATORY sections per template. The completeness check verifies every required section is present and non-empty after drafting.

#### Generic Template — Required Sections

| Section | Required | Notes |
|---------|----------|-------|
| Problem Statement | ALWAYS | |
| Current State / Gaps | ALWAYS | |
| Technical Approach | ALWAYS | |
| Files to Modify | ALWAYS | With specific file paths |
| Tasks / Implementation Order | ALWAYS | Numbered, actionable |
| Risks & Mitigations | ALWAYS | At least 2 risks |
| Testing Plan | ALWAYS | Unit + integration at minimum |
| Acceptance Criteria | ALWAYS | Concrete pass/fail conditions |
| Out of Scope / Non-Goals | ALWAYS | Explicit boundaries |
| Decisions | WHEN non-obvious choices exist | Table with rationale |
| Design Principles | WHEN MM project | |
| UX Summary | WHEN UI changes | Scenario → behavior table |
| Phase Strategy | WHEN multi-phase | |

#### MM Layer Template — Required Sections

| Section | Required | Notes |
|---------|----------|-------|
| Summary | ALWAYS | |
| Problem Statement | ALWAYS | |
| Proposed Solution | ALWAYS | |
| Key Design Decisions | ALWAYS | Table with rationale |
| Layer 1: Model | WHEN server changes | Structs + validation + files |
| Layer 2: Store | WHEN DB changes | Interface + SQL + migrations |
| Layer 3: App | WHEN server changes | Methods + business logic |
| Layer 4: API | WHEN endpoints added | Routes + permissions + error table |
| Layer 5: Webapp | WHEN frontend changes | Types + Client4 + Redux + components |
| Testing Strategy | ALWAYS | Go + TS + E2E sections |
| Implementation Order | ALWAYS | Numbered waves with dependencies |
| Risks & Mitigations | ALWAYS | At least 3 risks with severity |
| Non-Goals | ALWAYS | Explicit boundaries |
| Acceptance Criteria | ALWAYS | Concrete pass/fail conditions |
| Phase Strategy | WHEN multi-phase | |

#### Layer-Specific Completeness (MM Template)

When a layer section is present, it MUST contain architectural decisions — not code. `/create-code` derives code from the codebase; the plan tells it what to build and why.

| Layer | Must Include |
|-------|-------------|
| Model | New/modified entities described (fields, relationships, validation rules), "Files to modify" list |
| Store | New operations described (what data in, what data out), migration strategy (new columns/tables, backward compat), "Files to modify" list |
| App | Business logic flow (what calls what, what data moves where), error policies (soft vs hard failure), WS events if real-time, "Files to modify" list |
| API | Endpoint table (method + path + description), permission model (who can do what), error response table, feature flag/license gating |
| Webapp | Component relationships (which existing components to reuse and why), state management (where state lives, what triggers updates), UX behavior (empty/loading/error states), "Files to modify" list |

---

## MM Layer Template (Auto-Used in Mattermost Repos)

When MM project detected (or `--mm` flag), use this layer-by-layer structure:

```markdown
# [Feature Name]

## Summary
[1-2 sentence description]

## Problem Statement
[What problem does this solve? Why now?]

## Proposed Solution
[High-level approach]

---

## Layer 1: Model (`server/public/model/`)

### New/Modified Structs
- [ ] `model/page_*.go` - Describe changes

### Validation
- [ ] `IsValid()` method updates if needed

### Files to modify:
- `server/public/model/page.go`

---

## Layer 2: Store (`server/channels/store/`)

### Interface Changes
- [ ] `server/channels/store/store.go` - New methods

### SQL Implementation
- [ ] `server/channels/store/sqlstore/page_store.go` - Implementation

### Database Migrations (if needed)
- [ ] `server/channels/db/migrations/postgres/` - Migration files

### Files to modify:
- `server/channels/store/store.go`
- `server/channels/store/sqlstore/page_store.go`

---

## Layer 3: App (`server/channels/app/`)

### Business Logic
- [ ] New methods with proper error handling
- [ ] Logging with mlog
- [ ] Permission checks if needed

### Files to modify:
- `server/channels/app/page_*.go`

---

## Layer 4: API (`server/channels/api4/`)

### Endpoints
- [ ] HTTP handler implementation
- [ ] Request/response structs
- [ ] Route registration

### Files to modify:
- `server/channels/api4/page_api.go`

---

## Layer 5: Webapp (`webapp/channels/src/`)

### Redux State
- [ ] Actions in `src/actions/pages.ts`
- [ ] Reducers if needed
- [ ] Selectors in `src/selectors/`

### Components
- [ ] New/modified components in `src/components/`

### Files to modify:
- `webapp/channels/src/actions/pages.ts`
- `webapp/channels/src/components/wiki_view/`

---

## Testing Strategy

### Go Tests (TDD - write first!)
- [ ] Store tests: `server/channels/store/sqlstore/page_store_test.go`
- [ ] App tests: `server/channels/app/page_*_test.go`

### TypeScript Tests
- [ ] Component tests: `*.test.tsx`
- [ ] Action tests if complex logic

### E2E Tests
- [ ] `e2e-tests/playwright/specs/functional/channels/pages/`

---

## Implementation Order

1. **Model layer** - Define data structures
2. **Store layer** - Database operations (with tests first)
3. **App layer** - Business logic (with tests first)
4. **API layer** - HTTP endpoints
5. **Webapp** - Frontend implementation
6. **E2E tests** - Integration verification

---

## Risks & Dependencies
- [List potential issues]
- [External dependencies]

## Non-Goals (Out of Scope)
- [What we're NOT doing]
```

---

## Phase Strategy (for large features)

For features spanning multiple phases, add after Problem Statement:

```markdown
## Phase Strategy

| Phase | Focus | Value |
|-------|-------|-------|
| **Phase 1** | Core MVP: [key deliverables] | **80% of value** |
| **Phase 2** | Polish: [edge cases, cleanup] | Robustness |
| **Phase 3** | Enhanced: [nice-to-haves] | Optional |
| **Phase 4** | Future: [out of scope for now] | Deferred |

### Phase 1 Scope (this plan)
[Details for Phase 1 only - keep focused]

### Deferred to Phase 2+
- [Item] - Phase 2
- [Item] - Phase 3
```
