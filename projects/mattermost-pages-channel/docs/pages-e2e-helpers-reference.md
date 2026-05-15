# Pages E2E Test Helpers Reference

Source: `e2e-tests/playwright/specs/functional/channels/pages/test_helpers.ts`

## Anti-Patterns to Flag

### CRITICAL: `pw.random.id()` → `uniqueName()`

```typescript
// BAD
const name = `Test Wiki ${await pw.random.id()}`;

// GOOD
import { uniqueName } from './test_helpers';
const name = uniqueName('Test Wiki');
```
`uniqueName()` is synchronous, cleaner, no await needed.

### CRITICAL: Manual Login → `loginAndNavigateToChannel()`

```typescript
// BAD
const {page, channelsPage} = await pw.testBrowser.login(user);
await channelsPage.goto(team.name, channel.name);
await page.waitForLoadState('networkidle');
await channelsPage.toBeVisible();

// GOOD
import { loginAndNavigateToChannel } from './test_helpers';
const {page, channelsPage} = await loginAndNavigateToChannel(pw, user, team.name, channel.name);
```

### HIGH: Wiki Tab Selectors

```typescript
// BAD
page.locator('.channel-tabs-container__tab-wrapper--wiki')

// GOOD
import { getAllWikiTabs, getWikiTab, waitForWikiTab } from './test_helpers';
getAllWikiTabs(page)
getWikiTab(page, wikiName)
await waitForWikiTab(page, wikiName, HIERARCHY_TIMEOUT)
```

### HIGH: Editor Selectors

```typescript
// BAD
page.locator('.ProseMirror')

// GOOD
import { getEditor, getEditorAndWait } from './test_helpers';
getEditor(page)
await getEditorAndWait(page)
```

### HIGH: Hierarchy Panel Selectors

```typescript
// BAD
page.locator('[data-testid="pages-hierarchy-panel"]')

// GOOD
import { getHierarchyPanel } from './test_helpers';
getHierarchyPanel(page)
```

### MEDIUM: Hardcoded Timeout Values

```typescript
// BAD
await page.waitForTimeout(1000);

// GOOD
import { EDITOR_LOAD_WAIT } from './test_helpers';
await page.waitForTimeout(EDITOR_LOAD_WAIT);
```

### MEDIUM: Other Selectors

| Anti-Pattern | Helper |
|--------------|--------|
| `[data-testid="breadcrumb"]` | `getBreadcrumb(page)` |
| `.wiki-page-viewer` | `getPageViewerContent(page)` |
| `[data-testid="page-actions-menu"]` | `openPageActionsMenu(page)` |

## Timeout Constants

| Constant | Value | Use Case |
|----------|-------|----------|
| `UI_MICRO_WAIT` | 100ms | Micro UI updates |
| `SHORT_WAIT` | 500ms | Short UI updates |
| `EDITOR_LOAD_WAIT` | 1000ms | Editor loading |
| `AUTOSAVE_WAIT` | 2000ms | Autosave completion |
| `MODAL_CLOSE_TIMEOUT` | 2000ms | Modal close |
| `WEBSOCKET_WAIT` | 3000ms | WebSocket propagation |
| `ELEMENT_TIMEOUT` | 5000ms | Standard element visibility |
| `HIERARCHY_TIMEOUT` | 10000ms | Hierarchy operations |
| `PAGE_LOAD_TIMEOUT` | 15000ms | Full page load |

## Available Helpers

### Setup & Navigation
- `loginAndNavigateToChannel(pw, user, teamName, channelName)`
- `createTestChannel(adminClient, teamId, channelName)`
- `createTestUserInChannel(pw, adminClient, team, channel, username)`
- `setupWikiInChannel(pw, sharedPagesSetup, wikiName, channelName)`

### Wiki Operations
- `createWikiThroughUI(page, wikiName)`
- `getWikiTab(page, wikiTitle)` / `getAllWikiTabs(page)`
- `waitForWikiTab(page, wikiName, timeout)`
- `openWikiByTab(page, wikiName)`
- `renameWikiThroughModal(page, oldName, newName)`

### Page Operations
- `createPageThroughUI(page, pageTitle, pageContent)`
- `createChildPageThroughContextMenu(page, parentTitle, childTitle)`
- `deletePageThroughUI(page, pageTitle)`
- `publishPage(page)` / `enterEditMode(page)`

### Locators
- `getEditor(page)` / `getEditorAndWait(page)`
- `getHierarchyPanel(page)`
- `getPageViewerContent(page)`
- `getBreadcrumb(page)`

### Utilities
- `uniqueName(prefix)` — **NOT** `await pw.random.id()`
- `waitForWikiViewLoad(page)`
- `waitForEditModeReady(page)`
