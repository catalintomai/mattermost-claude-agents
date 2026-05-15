# Test Patterns Reference

Shared test patterns for Go, Jest, and Playwright. Referenced by `/create-test` and `/fix-test`.

**CRITICAL**: Before writing ANY test, read 3-5 existing tests in the same file/directory and match their patterns exactly.

## Go Unit Tests (server/)

**Pattern audit checklist:**
- Test function naming: `TestFunctionName` or `TestFunctionName_Scenario`
- Setup pattern: `th := Setup(t).InitBasic()` vs custom setup
- Assertions: `require.NoError` vs `assert.NoError`
- Cleanup: `defer th.TearDown()` pattern
- Error checking: `require.Nil(t, err)` vs `require.NoError(t, err)`

### Layer-Specific Patterns

Model tests (`server/public/model/*_test.go`):
```go
func TestPageContentIsValid(t *testing.T) {
    // Direct struct creation, validation calls
    pc := &model.PageContent{...}
    err := pc.IsValid()
    require.NoError(t, err)
}
```

Store tests (`server/channels/store/storetest/*_store.go`):
```go
func testPageStoreGet(t *testing.T, rctx request.CTX, ss store.Store) {
    // Uses store directly, no app layer
}
```

App tests (`server/channels/app/*_test.go`):
```go
func TestCreatePage(t *testing.T) {
    th := Setup(t).InitBasic()
    defer th.TearDown()
    // Uses th.App.MethodName()
}
```

API tests (`server/channels/api4/*_test.go`):
```go
func TestCreatePage(t *testing.T) {
    th := Setup(t).InitBasic()
    defer th.TearDown()
    // Uses th.Client.MethodName() for API calls
    // Tests permissions with th.SystemAdminClient vs th.Client
}
```

### Table-Driven Tests
```go
func TestValidatePageTitle(t *testing.T) {
    tests := []struct {
        name    string
        title   string
        wantErr bool
    }{
        {"valid title", "My Page", false},
        {"empty title", "", true},
        {"too long", strings.Repeat("a", 300), true},
        {"with emoji", "Page 🎉", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validatePageTitle(tt.title)
            if tt.wantErr {
                require.Error(t, err)
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

### Subtests for Setup Reuse
```go
func TestPageStore(t *testing.T) {
    th := Setup(t)
    defer th.TearDown()

    t.Run("Save", func(t *testing.T) {
        // test save
    })

    t.Run("Get", func(t *testing.T) {
        // test get
    })
}
```

## Jest Tests (webapp/)

**Redux test patterns**: Use `renderWithContext` with initial state for Redux-connected components. Mock actions with `jest.fn()`, assert dispatch calls. For selectors, test with `createSelector` memoization. See existing Redux tests in `webapp/channels/src/packages/mattermost-redux/` for patterns.

**Pattern audit checklist:**
- Import style: named vs default
- Mock patterns: `jest.mock()` placement
- Render helpers: `renderWithContext` vs `render`
- Assertion style: `expect().toBe()` vs `expect().toEqual()`
- Async patterns: `waitFor`, `act`

### Basic Component Test
```typescript
import {renderWithContext} from 'tests/react_testing_utils';

describe('ComponentName', () => {
    const baseProps = {
        // Match existing prop patterns
    };

    it('renders correctly', () => {
        const {getByText} = renderWithContext(<Component {...baseProps} />);
        expect(getByText('Expected text')).toBeInTheDocument();
    });
});
```

### Arrange-Act-Assert
```typescript
it('displays error when save fails', async () => {
    // Arrange
    const mockSave = jest.fn().mockRejectedValue(new Error('Network error'));
    render(<PageEditor onSave={mockSave} />);

    // Act
    await userEvent.click(screen.getByRole('button', { name: /save/i }));

    // Assert
    expect(await screen.findByText(/failed to save/i)).toBeInTheDocument();
});
```

### Testing Async Behavior
```typescript
it('loads page content on mount', async () => {
    render(<PageView pageId="123" />);

    // Wait for loading to complete
    await waitForElementToBeRemoved(() => screen.queryByRole('progressbar'));

    expect(screen.getByText('Page Content')).toBeInTheDocument();
});
```

## Playwright E2E Tests

See `.claude/docs/pages-e2e-helpers-reference.md` for the full helper API, anti-patterns, timeout constants, and available helpers.

**Key rules:**
- Read existing E2E tests in `e2e-tests/playwright/specs/functional/channels/pages/` before writing new ones
- Always use helpers from `test_helpers.ts` — never inline what a helper already provides
- Use proper selectors (data-testid preferred)

## Workflow Commands

```bash
# Go: Run specific test
go test ./channels/app -run TestCreatePage -v

# Go: Run with race detection
go test ./channels/app -race -run TestCreatePage

# TypeScript: Watch mode
npm test -- --watch

# TypeScript: Single test
npm test -- --testNamePattern="PageEditor"
```
