# Pattern Completeness Rule

**Include this instruction when spawning any coder/test agent.**

> **Pattern Completeness**: For each change/fix/test you make, search the same file AND sibling files for the same pattern. Apply it everywhere, not just the target location.

## Examples by Domain

**Code changes**:
- Fixing a naive `datetime.now()`? Search for ALL naive datetime calls in the file.
- Adding `.strip()` to a validation? Check all sibling fields and parallel classes.
- Adding a null fallback to `_row_to_property`? Check `_row_to_agent` and all `_row_to_*` methods.
- Removing a dead field from one SQL statement? Search ALL SQL statements in the file.

**Test writing**:
- Testing permission denial on create? Check update, delete, get for the same denial.
- Testing empty input validation? Check all sibling operations for the same validation.
- Testing concurrent edit on pages? Check concurrent edit on drafts and comments too.

**Test fixing**:
- Fixing a wrong assertion type? Check all assertions in the file for the same mistake.
- Fixing missing `await` on an async call? Grep the file for similar async calls without await.
- Fixing a mock return value? Check all mocks in the file for the same staleness pattern.
- Fixing cleanup in one test? Check all tests in the file for missing cleanup.

This prevents "fix exactly what was reported" tunnel vision that creates consistency gaps caught only in subsequent review rounds.
