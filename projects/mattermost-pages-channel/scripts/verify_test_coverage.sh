#!/bin/bash
# Verify that run_pages_tests.sh covers all wiki/pages tests in the codebase

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.claude/scripts/run_pages_tests.sh"

echo "============================================"
echo "TEST COVERAGE VERIFICATION"
echo "============================================"
echo ""

# === GO TESTS ===
echo "=== GO BACKEND TESTS ==="

GO_TESTS=$(cd "$ROOT/server" && for f in $(find channels/app channels/store/sqlstore channels/store/localcachelayer public/model -name "*wiki*_test.go" -o -name "*page*_test.go" 2>/dev/null); do
  grep "^func Test" "$f" 2>/dev/null | sed 's/func \(Test[^(]*\).*/\1/'
done | sort -u)

GO_COUNT=$(echo "$GO_TESTS" | wc -l)
echo "Test functions in codebase: $GO_COUNT"

SCRIPT_TESTS=$(grep -E "go test.*-run '\^\(" "$SCRIPT" | grep -oE "Test[A-Za-z0-9_]+" | sort -u)
SCRIPT_COUNT=$(echo "$SCRIPT_TESTS" | wc -l)
echo "Test functions in script:   $SCRIPT_COUNT"

MISSING=$(comm -23 <(echo "$GO_TESTS") <(echo "$SCRIPT_TESTS"))
if [ -z "$MISSING" ]; then
  echo "Status: ✓ All Go tests covered"
else
  echo "Status: ✗ Missing Go tests:"
  echo "$MISSING" | sed 's/^/  - /'
  exit 1
fi

echo ""
echo "=== E2E TESTS ==="

E2E_SPECS=$(find "$ROOT/e2e-tests/playwright/specs/functional/channels/pages" -name "*.spec.ts" -exec basename {} .spec.ts \; | sort)
E2E_COUNT=$(echo "$E2E_SPECS" | wc -l)
echo "Spec files in codebase: $E2E_COUNT"

E2E_IN_SCRIPT=$(grep -oE "pages_[a-z_]+|test_outline_[a-z_]+" "$SCRIPT" | sort -u)
E2E_SCRIPT_COUNT=$(echo "$E2E_IN_SCRIPT" | wc -l)
echo "Spec files in script:   $E2E_SCRIPT_COUNT"

MISSING_E2E=$(comm -23 <(echo "$E2E_SPECS") <(echo "$E2E_IN_SCRIPT"))
if [ -z "$MISSING_E2E" ]; then
  echo "Status: ✓ All E2E tests covered"
else
  echo "Status: ✗ Missing E2E tests:"
  echo "$MISSING_E2E" | sed 's/^/  - /'
  exit 1
fi

echo ""
echo "============================================"
echo "✓ COMPLETE COVERAGE: All tests accounted for"
echo "============================================"
