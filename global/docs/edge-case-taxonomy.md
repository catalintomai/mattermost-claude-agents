# Edge Case Taxonomy

Systematic off-happy-path test categories. Referenced by `/create-test` for coverage beyond the obvious.

**Philosophy**: Anyone can test the happy path. Principal-level coverage means systematically covering what happens when things go wrong, go sideways, or go to extremes.

## 1. State Edges

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Empty/zero state | No items, empty string, null, undefined, 0 | Missing guards, division by zero, "no results" UI absent |
| Single item | Exactly 1 item in a list, 1 character string | Off-by-one in pagination, plural/singular text |
| At limit | Max items, max depth, max length, max file size | Truncation, overflow, timeout, OOM |
| Just over limit | limit+1 items, maxLength+1 chars | Validation bypass, silent truncation vs error |
| Transition states | Loading→loaded, online→offline, logged-in→expired | Race between state check and action |
| Deleted/archived | Operating on soft-deleted item, archived channel | Stale references, ghost data, cascade failures |
| Concurrent state | Two users editing same item, two tabs open | Last-write-wins data loss, optimistic lock failures |

## 2. Timing & Concurrency

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Slow network | 3G, high latency, packet loss | Timeout before completion, duplicate submissions |
| Rapid repeated action | Double-click submit, spam Enter key | Duplicate records, race conditions |
| Stale data | Edit after someone else deleted, act on cached version | 404/409 errors with no recovery path |
| Out-of-order events | WebSocket events arrive non-sequentially | UI shows wrong state, data corruption |
| Long-running operation interrupted | Browser close during save, network drop during upload | Partial writes, orphaned data, no resume |
| Debounce/throttle edge | Action right at debounce boundary | Lost input, delayed feedback |

## 3. Input & Data

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Unicode / emoji | 🎉 in titles, CJK characters, combining marks | Encoding issues, display overflow, search failure |
| RTL text | Arabic/Hebrew mixed with LTR content | Layout breaks, cursor position wrong |
| Extremely long text | 100K character document, 500-word title | Performance degradation, UI overflow |
| Special characters | `<script>`, SQL injection patterns, `../`, null bytes | XSS, injection, path traversal |
| Whitespace variants | Only spaces, tabs, newlines, zero-width chars | Passes "not empty" but displays as empty |
| Deeply nested structures | 50-level JSON, recursive references | Stack overflow, infinite loops |
| Mixed content | Markdown in plain text fields, HTML in markdown | Rendering artifacts, injection |

## 4. Permission & Auth Boundaries

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Role transition | Admin demoted to member mid-session | Cached permissions allow forbidden actions |
| Cross-resource access | User A's data accessed with User B's token | IDOR, missing authorization checks |
| Expired session | Token expires during long editing session | Silent failure, data loss on save |
| Guest restrictions | Guest tries every endpoint/action | Missing permission checks on new features |
| System admin bypass | SysAdmin accesses channel they're not in | Implicit access grants hiding bugs |
| Permission + deletion combo | Deleting an item you can view but not delete | Permission check happens on wrong operation |

## 5. Browser & Client

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Back/forward navigation | Back button after create, forward after delete | Stale page, form resubmission, 404 |
| Multiple tabs | Same page in 2 tabs, edit in both | Data conflict, stale state, double operations |
| Page refresh mid-operation | F5 during draft save, refresh during upload | Lost data, orphaned server state |
| Tab backgrounded | Tab inactive for 30min, then resumed | Stale WebSocket, expired session, outdated data |
| Copy-paste | Paste rich text from Word, paste HTML, paste image | Sanitization failures, format corruption |
| Keyboard-only | Tab order, focus traps, screen reader | Inaccessible features, focus lost |

## 6. Data Integrity & Cascades

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Parent deleted before child | Delete wiki, then access its pages | Orphaned records, null references, 500 errors |
| Circular references | Page A parent of B, B parent of A | Infinite loops, stack overflow |
| Referential consistency | Move page to different wiki, linked bookmarks break | Stale references, broken links |
| Bulk operation partial failure | Delete 10 items, #7 fails | Inconsistent state, no rollback, unclear error |
| Import/export roundtrip | Export → import → export: identical? | Data loss during serialization/deserialization |
| Migration edge cases | Data created before feature existed | Missing fields, null handling, default values |

## 7. Error Recovery

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Retry after failure | Save fails, retry: duplicate or idempotent? | Duplicate records, conflicting state |
| Error message quality | What does the user see? Can they fix it? | Generic "something went wrong" with no action |
| Partial operation recovery | Upload 3 files, #2 fails: what happens to 1 and 3? | Orphaned files, inconsistent attachment list |
| Undo after error | Error during move, undo: original state restored? | Undo operates on error state, makes it worse |
| Conflict resolution | Optimistic lock fails: merge, overwrite, or abort? | Data loss, confusing UI, no path forward |

## 8. Cross-Feature Interactions

| Edge | Examples | Why it breaks |
|------|----------|---------------|
| Feature A changes affect Feature B | Renaming a page breaks bookmarks/links/search | Missing event propagation, stale caches |
| Search after mutation | Create item, immediately search: found? | Eventual consistency, index delay |
| Notifications from deleted content | Comment notification for deleted page | Dead links in notifications |
| WebSocket + REST consistency | WS says "page updated" but GET returns old version | Cache staleness, event ordering |

## Usage in `/create-test`

When the skill reaches Step 1.5 (Test Strategy), consult this taxonomy:

1. **Identify which categories apply** to the feature under test
2. **For each applicable category**, pick 2-3 highest-risk edges
3. **Prioritize off-happy-path over happy path** — happy path is table stakes
4. **Weight by blast radius**: data loss > bad UX > cosmetic issue
5. **Map each selected edge to a concrete test scenario**

The goal is not to test every cell in every table — it's to systematically consider what a principal SDET would think about and pick the highest-value off-happy-path tests.
