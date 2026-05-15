---
name: test-alignment-rules
description: Mock-implementation alignment rules for test agents
---

# Mock-Implementation Alignment Check

**CRITICAL: Verify mocks match actual implementation before writing tests.**

1. **Read the actual implementation** before writing mock return values
2. Check return types: Does the real function return `null` or `undefined` for missing values?
3. Match exactly in mocks and expectations

**Common Pitfall — null vs undefined:**
```typescript
// Implementation returns null for missing:
export function getDraft(...): PostDraft | null {
    return getGlobalItem<PostDraft | null>(state, key, null);  // Returns NULL
}

// WRONG:
expect(result.current.draft).toBeUndefined();  // FAILS

// CORRECT:
expect(result.current.draft).toBeNull();  // Matches implementation
```

### Checklist Before Writing/Reviewing Tests:
- [ ] Read the actual function being tested (not just the interface)
- [ ] Mock return values match real return types exactly
- [ ] Expectations match what implementation actually returns
- [ ] Empty/missing states handled correctly (null vs undefined vs empty string vs empty array)
- [ ] Default values in selectors/hooks are reflected in test expectations
