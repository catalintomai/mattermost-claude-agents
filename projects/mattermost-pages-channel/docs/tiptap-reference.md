# TipTap Integration Reference

## Review Checklist

### 1. Memory Leaks and Cleanup

- [ ] `editor.destroy()` called on unmount (useEffect cleanup or componentWillUnmount)
- [ ] `onExit` removes event listeners, unmounts React components, and removes popup from DOM
- [ ] References nullified after cleanup to prevent retention
- [ ] `ReactDOM.unmountComponentAtNode(popup)` called before removing element from DOM
- [ ] Try/catch around cleanup so one failure does not skip remaining teardown

### 2. Collaborative Editing and Suggestion Plugin

- [ ] `shouldShow` checks `!isChangeOrigin(transaction)` to prevent popups for remote users
- [ ] `allowedPrefixes` used instead of custom `allow()` regex to prevent triggering in URLs/times
- [ ] `pluginKey` set when multiple suggestion types coexist in the same editor
- [ ] `items()` always resolves (returns `[]` on error), never rejects

### 3. Keyboard and Command Handling

- [ ] `onKeyDown` returns `false` for Escape (let TipTap handle suggestion exit)
- [ ] `onKeyDown` returns `true` only for actually handled keys (arrows, Enter, Tab)
- [ ] `onKeyDown` returns `false` for all unhandled keys (so typing continues)
- [ ] Navigation guards against empty items list before accessing by index
- [ ] `editor.chain().focus()` used in command functions (missing `focus()` loses cursor)
- [ ] Content manipulation uses transactions/chains, never direct DOM manipulation

### 4. Performance

- [ ] Query cancellation implemented for async `items()` (stale query guard with instance-scoped ID)
- [ ] Query ID is instance-scoped, not module-scoped (module-scoped causes cross-editor interference)
- [ ] Expensive computations (locale, messages, store reads) cached in `onStart`, not re-read on every `onUpdate`/render
- [ ] Async operations have a timeout to prevent indefinite hangs
- [ ] Network-hitting queries debounced on rapid typing

### 5. Accessibility

- [ ] Popup or list has `role="listbox"` with `aria-label`
- [ ] Each item has `role="option"` with `aria-selected={isSelected}`
- [ ] Keyboard navigation works: arrows to navigate, Enter/Tab to select, Escape to close
- [ ] No keyboard traps (unhandled keys pass through to editor)

### 6. React and Provider Integration

- [ ] Popup wrapped with Redux `<Provider>` and `<IntlProvider>` when rendering outside React tree
- [ ] User-visible strings use `formatMessage` or `FormattedMessage` (no hardcoded English)
- [ ] `ReactDOM.render` calls have corresponding cleanup in `onExit`

## Severity Mapping

- **CRITICAL**: Memory leak, data loss, or crash (e.g., missing `editor.destroy()`, missing cleanup in `onExit`)
- **HIGH**: Broken UX or accessibility failure (e.g., keyboard trap, missing ARIA, lost cursor focus)
- **MEDIUM**: Performance degradation or fragile pattern (e.g., missing query cancellation, module-scoped state)
- **LOW**: Minor deviation from best practice, cosmetic only
