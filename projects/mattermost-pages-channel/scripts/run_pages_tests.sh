#!/bin/bash

# Exit immediately if a command in a pipeline fails
set -o pipefail

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function to kill all processes and exit immediately
cleanup_on_interrupt() {
    echo ""
    echo -e "${YELLOW}Interrupt received, stopping all processes...${NC}"

    # Kill all child processes (including running tests)
    jobs -p | xargs -r kill -TERM 2>/dev/null
    pkill -TERM -P $$ 2>/dev/null

    # Give processes a moment to terminate gracefully
    sleep 0.2

    # Force kill any remaining processes
    jobs -p | xargs -r kill -KILL 2>/dev/null
    pkill -KILL -P $$ 2>/dev/null

    # Clean up temp files
    rm -f /tmp/test_counts_$$.txt /tmp/test_failing_$$.txt /tmp/test_output.log 2>/dev/null

    echo -e "${RED}Tests interrupted by user${NC}"
    exit 130
}

# Normal cleanup on exit
cleanup_on_exit() {
    # Only clean up temp files on normal exit
    rm -f /tmp/test_counts_$$.txt /tmp/test_failing_$$.txt 2>/dev/null
}

# Set up trap for SIGINT (CTRL+C) and SIGTERM
trap cleanup_on_interrupt SIGINT SIGTERM
trap cleanup_on_exit EXIT

# Function to display usage
usage() {
    echo "=========================================="
    echo "Pages/Wiki Feature Test Suite"
    echo "=========================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  all, --all              Run all tests (default)"
    echo "  backend, go             Run all backend Go tests"
    echo "  frontend, jest          Run all frontend Jest tests"
    echo "  e2e, playwright         Run all E2E Playwright tests"
    echo "  mmctl                   Run mmctl E2E tests (wiki export/import)"
    echo "  jobs                    Run Jobs layer tests only (wiki_export/wiki_import workers)"
    echo "  model                   Run Model layer tests only"
    echo "  store                   Run Store layer tests only"
    echo "  app                     Run App layer tests only"
    echo "  api                     Run API layer tests only"
    echo "  channel-independence    Run wiki channel-independence feature tests only"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "E2E Category Options (run specific E2E test groups):"
    echo "  e2e:crud                Core CRUD operations"
    echo "  e2e:navigation          Navigation tests"
    echo "  e2e:hierarchy           Hierarchy & structure tests"
    echo "  e2e:editor              Editor & content tests"
    echo "  e2e:collaboration       Collaboration & real-time tests"
    echo "  e2e:ai                  AI feature tests"
    echo "  e2e:drafts              Drafts & version control tests"
    echo "  e2e:wiki                Wiki management tests"
    echo "  e2e:permissions         Permissions & security tests"
    echo "  e2e:integration         Integration & migration tests"
    echo "  e2e:ui                  UI & display tests"
    echo "  e2e:debug               Debug & minimal tests"
    echo "  e2e:export              Wiki export/import tests"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests"
    echo "  $0 backend              # Run all backend tests"
    echo "  $0 jest                 # Run all frontend tests"
    echo "  $0 playwright           # Run all E2E tests"
    echo "  $0 model store          # Run model and store tests"
    echo "  $0 backend e2e          # Run backend and E2E tests"
    echo "  $0 jobs                 # Run jobs worker tests only"
    echo "  $0 channel-independence # Run only wiki channel-independence feature tests"
    echo "  $0 e2e:navigation       # Run only navigation E2E tests"
    echo "  $0 e2e:editor e2e:drafts  # Run editor and drafts E2E tests"
    echo ""
    exit 0
}

# Parse command line arguments
RUN_MODEL=false
RUN_STORE=false
RUN_APP=false
RUN_API=false
RUN_FRONTEND=false
RUN_E2E=false
RUN_MMCTL=false
RUN_JOBS=false
RUN_CHANNEL_INDEPENDENCE=false

# E2E category flags
E2E_CRUD=false
E2E_NAVIGATION=false
E2E_HIERARCHY=false
E2E_EDITOR=false
E2E_COLLABORATION=false
E2E_AI=false
E2E_DRAFTS=false
E2E_WIKI=false
E2E_PERMISSIONS=false
E2E_INTEGRATION=false
E2E_UI=false
E2E_DEBUG=false
E2E_EXPORT=false
E2E_CATEGORY_SPECIFIED=false

# If no arguments, run all tests (except mmctl which requires special setup)
if [ $# -eq 0 ]; then
    RUN_MODEL=true
    RUN_STORE=true
    RUN_APP=true
    RUN_API=true
    RUN_JOBS=true
    RUN_CHANNEL_INDEPENDENCE=true
    RUN_FRONTEND=true
    RUN_E2E=true
    # RUN_MMCTL=true  # Disabled by default - run with: ./run_pages_tests.sh mmctl
fi

# Parse arguments
for arg in "$@"; do
    case $arg in
        -h|--help|help)
            usage
            ;;
        all|--all)
            RUN_MODEL=true
            RUN_STORE=true
            RUN_APP=true
            RUN_API=true
            RUN_JOBS=true
            RUN_CHANNEL_INDEPENDENCE=true
            RUN_FRONTEND=true
            RUN_E2E=true
            # RUN_MMCTL=true  # Disabled by default - run with: ./run_pages_tests.sh mmctl
            ;;
        backend|go)
            RUN_MODEL=true
            RUN_STORE=true
            RUN_APP=true
            RUN_API=true
            RUN_JOBS=true
            ;;
        mmctl)
            RUN_MMCTL=true
            ;;
        frontend|jest)
            RUN_FRONTEND=true
            ;;
        e2e|playwright)
            RUN_E2E=true
            ;;
        e2e:crud)
            RUN_E2E=true
            E2E_CRUD=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:navigation)
            RUN_E2E=true
            E2E_NAVIGATION=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:hierarchy)
            RUN_E2E=true
            E2E_HIERARCHY=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:editor)
            RUN_E2E=true
            E2E_EDITOR=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:collaboration)
            RUN_E2E=true
            E2E_COLLABORATION=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:ai)
            RUN_E2E=true
            E2E_AI=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:drafts)
            RUN_E2E=true
            E2E_DRAFTS=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:wiki)
            RUN_E2E=true
            E2E_WIKI=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:permissions)
            RUN_E2E=true
            E2E_PERMISSIONS=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:integration)
            RUN_E2E=true
            E2E_INTEGRATION=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:ui)
            RUN_E2E=true
            E2E_UI=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:debug)
            RUN_E2E=true
            E2E_DEBUG=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        e2e:export)
            RUN_E2E=true
            E2E_EXPORT=true
            E2E_CATEGORY_SPECIFIED=true
            ;;
        jobs)
            RUN_JOBS=true
            ;;
        channel-independence)
            RUN_CHANNEL_INDEPENDENCE=true
            ;;
        model)
            RUN_MODEL=true
            ;;
        store)
            RUN_STORE=true
            ;;
        app)
            RUN_APP=true
            ;;
        api)
            RUN_API=true
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Pages/Wiki Feature Test Suite (Batched)"
echo "=========================================="
echo ""
echo "Test configuration:"
echo "  Model layer:    $([ "$RUN_MODEL" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
echo "  Store layer:    $([ "$RUN_STORE" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
echo "  App layer:      $([ "$RUN_APP" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
echo "  API layer:      $([ "$RUN_API" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
echo "  Jobs layer:     $([ "$RUN_JOBS" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
echo "  Chan-Indep:     $([ "$RUN_CHANNEL_INDEPENDENCE" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
echo "  Frontend:       $([ "$RUN_FRONTEND" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
if [ "$RUN_E2E" = true ] && [ "$E2E_CATEGORY_SPECIFIED" = true ]; then
    e2e_cats=""
    [ "$E2E_CRUD" = true ] && e2e_cats="${e2e_cats}crud,"
    [ "$E2E_NAVIGATION" = true ] && e2e_cats="${e2e_cats}navigation,"
    [ "$E2E_HIERARCHY" = true ] && e2e_cats="${e2e_cats}hierarchy,"
    [ "$E2E_EDITOR" = true ] && e2e_cats="${e2e_cats}editor,"
    [ "$E2E_COLLABORATION" = true ] && e2e_cats="${e2e_cats}collaboration,"
    [ "$E2E_AI" = true ] && e2e_cats="${e2e_cats}ai,"
    [ "$E2E_DRAFTS" = true ] && e2e_cats="${e2e_cats}drafts,"
    [ "$E2E_WIKI" = true ] && e2e_cats="${e2e_cats}wiki,"
    [ "$E2E_PERMISSIONS" = true ] && e2e_cats="${e2e_cats}permissions,"
    [ "$E2E_INTEGRATION" = true ] && e2e_cats="${e2e_cats}integration,"
    [ "$E2E_UI" = true ] && e2e_cats="${e2e_cats}ui,"
    [ "$E2E_DEBUG" = true ] && e2e_cats="${e2e_cats}debug,"
    [ "$E2E_EXPORT" = true ] && e2e_cats="${e2e_cats}export,"
    e2e_cats="${e2e_cats%,}"  # Remove trailing comma
    echo -e "  E2E:            ${GREEN}${e2e_cats}${NC}"
else
    echo "  E2E:            $([ "$RUN_E2E" = true ] && echo -e "${GREEN}ALL${NC}" || echo -e "${YELLOW}SKIP${NC}")"
fi
echo "  mmctl E2E:      $([ "$RUN_MMCTL" = true ] && echo -e "${GREEN}YES${NC}" || echo -e "${YELLOW}SKIP${NC}")"
echo ""

failed_tests=()
passed_tests=()

# Temp file to store test counts (since bash 3.2 doesn't support associative arrays)
TEST_COUNTS_FILE="/tmp/test_counts_$$.txt"
TEST_FAILING_FILE="/tmp/test_failing_$$.txt"
rm -f "$TEST_COUNTS_FILE" "$TEST_FAILING_FILE"
touch "$TEST_COUNTS_FILE" "$TEST_FAILING_FILE"

# Strip ANSI escape codes from /tmp/test_output.log so grep/sed work reliably.
# Playwright output contains escape codes that make grep report "Binary file matches".
strip_log() {
    LC_ALL=C sed 's/\x1B\[[0-9;]*[A-Za-z]//g' /tmp/test_output.log 2>/dev/null
}

# Extract and display failing tests from /tmp/test_output.log
# Usage: show_failing_tests <test_name>
show_failing_tests() {
    local test_name=$1
    local clean
    clean=$(strip_log)

    # --- Go test failures (--- FAIL: lines) ---
    local go_fails
    go_fails=$(printf '%s\n' "$clean" | grep "^--- FAIL:")
    if [ -n "$go_fails" ]; then
        echo -e "${RED}Failing tests:${NC}"
        while IFS= read -r line; do
            local test_id
            test_id=$(echo "$line" | sed 's/^--- FAIL: //' | sed 's/ ([0-9.]*s)$//')
            echo -e "  ${RED}✗${NC} $test_id"
            echo "$test_name|$test_id" >> "$TEST_FAILING_FILE"
        done <<< "$go_fails"
        echo ""
        echo -e "${RED}Error context:${NC}"
        printf '%s\n' "$clean" \
            | grep -v "^=== RUN\|^=== PAUSE\|^=== CONT\|^--- PASS:\|    --- PASS:" \
            | grep -v '{"timestamp"' \
            | grep -v '^[[:space:]]*$' \
            | tail -40 \
            | sed 's/^/  /'
        return
    fi

    # --- Playwright test failures ---
    # Match only the numbered failures section (e.g. "  1) [chrome] › ...") to avoid
    # triple-reporting: Playwright emits the same failure in the real-time run marker,
    # the numbered list, and the final summary. The numbered list is the canonical one.
    local pw_fails
    pw_fails=$(printf '%s\n' "$clean" | grep -E "[0-9]+\) \[(chrome|firefox|webkit)\]")
    if [ -n "$pw_fails" ]; then
        echo -e "${RED}Failing tests:${NC}"
        while IFS= read -r line; do
            # Extract title: everything after the last › separator, strip timing and tags
            local title
            title=$(printf '%s' "$line" | sed 's/.*› //' | sed 's/ @[a-zA-Z]*//' | sed 's/ ([0-9.]*s)$//')
            echo -e "  ${RED}✗${NC} $title"
            echo "$test_name|$title" >> "$TEST_FAILING_FILE"
        done <<< "$pw_fails"

        # Show assertion/timeout error details
        local err_block
        err_block=$(printf '%s\n' "$clean" \
            | grep -A 10 "Error:.*expect\|TimeoutError:\|toBeVisible.*failed\|Expected:.*\nReceived:" \
            | grep -v "^--$" \
            | head -50)
        if [ -n "$err_block" ]; then
            echo ""
            echo -e "${RED}Error details:${NC}"
            printf '%s\n' "$err_block" | sed 's/^/  /'
        else
            # Fallback: show last meaningful lines from the log
            echo ""
            echo -e "${RED}Last output:${NC}"
            printf '%s\n' "$clean" \
                | grep -v '^[[:space:]]*$' \
                | tail -20 \
                | sed 's/^/  /'
        fi
        return
    fi

    # --- Fallback: unknown test runner format ---
    echo -e "${RED}Error output:${NC}"
    printf '%s\n' "$clean" \
        | grep -v "^=== RUN\|^=== PAUSE\|^=== CONT\|^--- PASS:\|    --- PASS:" \
        | grep -v '{"timestamp"' \
        | grep -v '^[[:space:]]*$' \
        | tail -40 \
        | sed 's/^/  /'
}

# Function to run a test and track results
run_test() {
    local test_name=$1
    local test_command=$2

    echo -e "${YELLOW}Running: $test_name${NC}"

    # Run command - trap will handle CTRL+C and kill this and all children
    if eval "$test_command" > /tmp/test_output.log 2>&1; then
        # Extract test counts from output (for Playwright tests) - using sed for macOS compatibility
        local passed=$(LC_ALL=C sed -n 's/.* \([0-9][0-9]*\) passed.*/\1/p' /tmp/test_output.log | tail -1)
        local failed=$(LC_ALL=C sed -n 's/.* \([0-9][0-9]*\) failed.*/\1/p' /tmp/test_output.log | tail -1)
        local skipped=$(LC_ALL=C sed -n 's/.* \([0-9][0-9]*\) skipped.*/\1/p' /tmp/test_output.log | tail -1)

        passed=${passed:-0}
        failed=${failed:-0}
        skipped=${skipped:-0}
        local total=$((passed + failed + skipped))

        if [ $total -gt 0 ]; then
            echo -e "${GREEN}✓ PASSED: $passed/$total tests passed${NC}\n"
            echo "$test_name|$passed|$failed|$total" >> "$TEST_COUNTS_FILE"
        else
            echo -e "${GREEN}✓ PASSED${NC}\n"
        fi
        passed_tests+=("$test_name")
    else
        # Extract test counts even on failure
        local passed=$(LC_ALL=C sed -n 's/.* \([0-9][0-9]*\) passed.*/\1/p' /tmp/test_output.log | tail -1)
        local failed=$(LC_ALL=C sed -n 's/.* \([0-9][0-9]*\) failed.*/\1/p' /tmp/test_output.log | tail -1)
        local skipped=$(LC_ALL=C sed -n 's/.* \([0-9][0-9]*\) skipped.*/\1/p' /tmp/test_output.log | tail -1)

        passed=${passed:-0}
        failed=${failed:-0}
        skipped=${skipped:-0}
        local total=$((passed + failed + skipped))

        if [ $total -gt 0 ]; then
            echo -e "${RED}✗ FAILED: $passed/$total tests passed | $failed failed${NC}"
            echo "$test_name|$passed|$failed|$total" >> "$TEST_COUNTS_FILE"
        else
            echo -e "${RED}✗ FAILED${NC}"
        fi
        failed_tests+=("$test_name")

        show_failing_tests "$test_name"
        echo ""
    fi
}

# Store the root directory (script lives in .claude/scripts/, project root is 3 levels up)
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Change to server directory
cd "$ROOT_DIR/server" || exit 1

if [ "$RUN_MODEL" = true ]; then
    echo "=========================================="
    echo "MODEL LAYER TESTS"
    echo "=========================================="
    echo ""

    # Batch all public/model tests into a single go test call
    run_test "Model: All model tests (public/model)" \
        "go test -v -count=1 -timeout 300s ./public/model -run '^(TestWikiIsValid|TestWikiJSON|TestWikiPreSave|TestWikiPreUpdate|TestWikiLinkIsValid|TestWikiLinkPreSave|TestWikiLinkAuditable|TestPageContentIsValid|TestPageContentPreSave|TestPageContentSetGetDocumentJSON|TestDraftIsPageDraft|TestDraftIsValid|TestDraftPreSave|TestPostIsValidPageParentId|TestParsePageUrl|TestIsPageUrl|TestBuildPageUrl|TestBuildSearchText|TestSanitizeTipTapDocument|TestParseTipTapDocument|TestTipTapDocumentScanValue|TestValidateTipTapDocument|TestExtractSimpleText|TestExtractSimpleTextWithMentions|TestExtractTextFromNode|TestCleanText|TestGetPageSortOrder|TestSetPageSortOrder)$'"

    # public/utils tests (separate package)
    run_test "Model: Utils tests (public/utils)" \
        "go test -v -count=1 -timeout 300s ./public/utils -run '^(TestPager)$'"

    # public/pluginapi tests (separate package)
    run_test "Model: Pluginapi wiki tests (public/pluginapi)" \
        "go test -v -count=1 -timeout 300s ./public/pluginapi -run '^(TestLinkPageToFirstWiki|TestGetFirstWikiForChannel|TestCreatePage)$'"
fi

if [ "$RUN_STORE" = true ]; then
    echo "=========================================="
    echo "STORE LAYER TESTS"
    echo "=========================================="
    echo ""

    # Batch all sqlstore tests into a single go test call
    run_test "Store: All sqlstore tests (channels/store/sqlstore)" \
        "go test -v -count=1 -timeout 300s ./channels/store/sqlstore -run '^(TestWikiStore|TestWikiLinkStore|TestPageContentStore|TestDraftStore|TestPageStore|TestBuildPageHierarchyCTE|TestBuildPageHierarchyCTE_SQLSyntaxValidity|TestChannelMemberLinkStore)$'"

    # localcachelayer tests (separate package)
    run_test "Store: LocalCacheLayer tests (channels/store/localcachelayer)" \
        "go test -v -count=1 -timeout 300s ./channels/store/localcachelayer -run '^(TestPageStore)$'"
fi

if [ "$RUN_APP" = true ]; then
    echo "=========================================="
    echo "APP LAYER TESTS"
    echo "=========================================="
    echo ""

    # Batch ALL app layer tests into a single go test call
    run_test "App: All app layer tests (channels/app)" \
        "go test -v -count=1 -timeout 300s ./channels/app -run '^(TestCreatePageWithContent|TestGetPageWithContent|TestUpdatePage|TestDeletePage|TestRestorePage|TestPermanentDeletePage|TestDuplicatePage|TestGetPageChildren|TestGetPageAncestors|TestGetPageDescendants|TestGetChannelPages|TestMovePage|TestMovePageWithReorder|TestPageDepthLimit|TestGetPageStatus|TestSetPageStatus|TestGetPageStatusField|TestCreatePageComment|TestCreatePageCommentReply|TestCreateThreadEntryForPageComment|TestHandlePageCommentThreadCreation|TestExtractMentionsFromTipTapContent|TestGetExplicitMentionsFromPage|TestTipTapMentionParser_ImplementsMentionParserInterface|TestTipTapMentionParser_InvalidJSON|TestTipTapMentionParser_ProcessText|TestPageMentionSystemMessages|TestPageVersionHistory|TestUpdatePageWithOptimisticLocking_Success|TestUpdatePageWithOptimisticLocking_Conflict|TestUpdatePageWithOptimisticLocking_DeletedPage|TestUpdatePageWithOptimisticLocking_ErrorDetailsIncludeModifier|TestConvertPlainTextToTipTapJSON|TestCreatePageContentValidation|TestGetWikisForChannel_SoftDelete|TestUpdateWiki|TestCreateWikiWithDefaultPage|TestCreatePage|TestMovePageToWiki|TestMoveWikiToChannel|TestCreateDraft|TestGetDraft|TestUpdateDraft|TestUpsertDraft|TestDeleteDraft|TestGetDraftsForUser|TestPublishPageDraft|TestPageDraftWhenPageDeleted|TestSavePageDraftWithMetadata|TestGetPageDraft|TestDeletePageDraft|TestGetPageDraftsForWiki|TestCheckPageDraftExists|TestSystemMessages_WikiAdded|TestSystemMessages_PageAdded|TestSystemMessages_PageUpdated|TestCalculateMentionDelta|TestGetPreviouslyNotifiedMentions|TestSetNotifiedMentions|TestFetchExternalImageAsFile_URLValidation|TestFetchExternalImageAsFile_ImageProxyRequired|TestExtractPageImageText_AIAvailabilityCheck|TestCleanMarkdownCodeBlocks|TestSanitizeTipTapDoc|TestGetPageImageExtractionPromptForAction|TestGetPage|TestGetPageWithDeleted|TestPlainTextConversion|TestGetPageVersionHistory|TestRestorePageVersion|TestBuildBreadcrumbPath|TestCalculateMaxDepthFromPostList|TestCalculatePageDepth|TestCalculateSubtreeMaxDepth|TestLoadPageContent|TestGetPageActiveEditors|TestExtractFileIdsFromContent|TestCreatePageAttachesFiles|TestUpdatePageAttachesFiles|TestUpdatePageWithOptimisticLockingAttachesFiles|TestUpsertPageDraft|TestMovePageDraft|TestGetWiki|TestGetWikiPages|TestDeleteWiki|TestGetWikiIdForPage|TestGetWikiIdForPost|TestAddPageToWiki|TestWikiBulkExportEmptyChannelIds|TestWikiBulkExportVersionLine|TestWriteExportLine|TestGetPageComments|TestResolvePageComment|TestUnresolvePageComment|TestCanResolvePageComment|TestTransformPageCommentReply|TestCreateBookmarkFromPage|TestHandlePageUpdateNotification|TestCreateNewPageUpdateNotification|TestImportImportWiki|TestImportImportPage|TestImportImportPageComment|TestImportUpdatePostPropsFromImport|TestImportPageWithMissingParent|TestGetPostsByTypeAndProps|TestImportPageWithNestedComments|TestImportThreadedCommentReplies|TestImportPageWithAttachments|TestImportWikiEndToEnd|TestResolvePageTitlePlaceholders|TestResolvePageIDPlaceholders|TestCleanupUnresolvedPlaceholders|TestRepairOrphanedPageHierarchy|TestLinkWikiToChannel|TestUnlinkWikiFromChannel|TestGetWikiLinksForChannel|TestGetWikisLinkedToChannel|TestEnrichPageWithProperties|TestEnrichPagesWithProperties|TestGetPagePropertyFieldByName|TestSummarizeThreadToPage_AIAvailabilityCheck|TestSummarizeThreadToPage_InputValidation|TestBuildConversationTextFromPostList|TestSessionHasWikiPermission|TestSessionHasPagePermission|TestIsWikiOwner|TestAddWikiPagePermissionsMigration)$'"

    # Slashcommands tests (separate package)
    run_test "App: Slashcommands wiki mentions tests (channels/app/slashcommands)" \
        "go test -v -count=1 -timeout 300s ./channels/app/slashcommands -run '^(TestWikiMentionsGetTrigger|TestWikiMentionsGetCommand|TestWikiMentionsDoCommand)$'"
fi

if [ "$RUN_API" = true ]; then
    echo "=========================================="
    echo "API LAYER TESTS"
    echo "=========================================="
    echo ""

    # Batch ALL api layer tests into a single go test call
    run_test "API: All api layer tests (channels/api4)" \
        "go test -v -count=1 -timeout 300s ./channels/api4 -run '^(TestCreateWiki|TestGetWiki|TestGetTeamWikis|TestListChannelWikis|TestUpdateWiki|TestDeleteWiki|TestGetPages|TestGetPage|TestCrossChannelAccess|TestWikiValidation|TestWikiPermissions|TestPageDraftToPublishE2E|TestPagePublishWebSocketEvent|TestCreatePage|TestCreatePageViaWikiApi|TestGetPageBreadcrumb|TestDuplicatePage|TestMovePage|TestMovePageWithReorder|TestPagePermissionMatrix|TestPagePermissionsMultiUser|TestPageGuestPermissions|TestMultiUserPageEditing|TestConcurrentPageHierarchyOperations|TestMovePageToWiki|TestGetChannelPagesPermissions|TestPageDraftPermissions|TestPageDraftOwnershipValidation|TestMovePageDraft|TestPageCommentsE2E|TestResolvePageComment|TestUpdatePageStatus|TestGetPageStatus|TestGetPageStatusField|TestGetPageActiveEditors|TestPublishPageDraft_OptimisticLocking_Returns409|TestPublishPageDraft_OptimisticLocking_Success|TestPublishPageDraft_WrongBaseEditAtReturns409|TestSearchPages|TestPageDraftPermissionViolations|TestWikiPermissionViolations|TestDownloadWikiExportJob|TestGetChannelPages|TestGetPageComments|TestUpdatePage|TestDeletePage|TestRestorePage|TestGetWikiPage|TestLinkWikiToChannelAPI|TestGetWikiLinksForChannelAPI|TestUnlinkWikiFromChannelAPI|TestWikiEndpointsRequireAuth|TestWikiLinksRejectCrossTeam|TestWikiLinksRequireBookmarkPermission|TestWikiLinksRequireWikiModifyPermission|TestWikiLinksUnauthenticated|TestUpdatePageOptimisticLocking|TestCreatePageValidation|TestCrossWikiIDOR|TestDraftOwnership|TestPageCommentsSecurityAndValidation)$'"
fi

if [ "$RUN_JOBS" = true ]; then
    echo "=========================================="
    echo "JOBS LAYER TESTS"
    echo "=========================================="
    echo ""

    run_test "Jobs: Wiki Export Worker (channels/jobs/wiki_export)" \
        "go test -v -count=1 -timeout 60s ./channels/jobs/wiki_export -run '^(TestMakeWorker)$'"

    run_test "Jobs: Wiki Import Worker (channels/jobs/wiki_import)" \
        "go test -v -count=1 -timeout 60s ./channels/jobs/wiki_import -run '^(TestMakeWorker)$'"
fi

if [ "$RUN_CHANNEL_INDEPENDENCE" = true ]; then
    echo "=========================================="
    echo "CHANNEL INDEPENDENCE FEATURE TESTS"
    echo "=========================================="
    echo ""
    echo "Runs targeted tests for the wiki channel-independence feature:"
    echo "  ChannelMemberLinks store, wiki link/unlink (app + api), jobs, frontend UI, E2E"
    echo ""

    # Store: ChannelMemberLink store
    run_test "Chan-Indep: Store (ChannelMemberLinkStore)" \
        "go test -v -count=1 -timeout 300s ./channels/store/sqlstore -run '^(TestChannelMemberLinkStore)$'"

    # App: wiki link/unlink and wiki independence
    run_test "Chan-Indep: App (WikiLinks)" \
        "go test -v -count=1 -timeout 300s ./channels/app -run '^(TestLinkWikiToChannel|TestUnlinkWikiFromChannel|TestGetWikiLinksForChannel|TestGetWikisLinkedToChannel)$'"

    # API: wiki link/unlink endpoints and auth checks
    run_test "Chan-Indep: API (WikiLinks)" \
        "go test -v -count=1 -timeout 300s ./channels/api4 -run '^(TestLinkWikiToChannelAPI|TestGetWikiLinksForChannelAPI|TestUnlinkWikiFromChannelAPI|TestWikiEndpointsRequireAuth)$'"

    # Jobs: wiki export/import workers
    run_test "Chan-Indep: Jobs (wiki_export worker)" \
        "go test -v -count=1 -timeout 60s ./channels/jobs/wiki_export -run '^(TestMakeWorker)$'"

    run_test "Chan-Indep: Jobs (wiki_import worker)" \
        "go test -v -count=1 -timeout 60s ./channels/jobs/wiki_import -run '^(TestMakeWorker)$'"

    # Frontend: channel tabs, link/unlink modals
    cd "$ROOT_DIR/webapp/channels" || exit 1
    run_test "Chan-Indep: Frontend (WikiLinks UI)" \
        "npm run test -- src/components/link_wiki_modal/link_wiki_modal.test.tsx src/components/wiki_unlink_modal/wiki_unlink_modal.test.tsx --silent"
    cd "$ROOT_DIR/server" || exit 1

    # E2E: wiki links
    cd "$ROOT_DIR/e2e-tests/playwright" || exit 1
    if curl -s http://localhost:8065/api/v4/system/ping > /dev/null 2>&1; then
        run_test "Chan-Indep: E2E (WikiLinks)" "npm run test -- pages_wiki_links --project=chrome"
    else
        echo -e "${YELLOW}⚠ Server not running — skipping Chan-Indep E2E tests${NC}"
        echo ""
    fi
    cd "$ROOT_DIR/server" || exit 1
fi

if [ "$RUN_FRONTEND" = true ]; then
    # Change to webapp directory for frontend tests
    cd "$ROOT_DIR/webapp/channels" || exit 1

    echo "=========================================="
    echo "FRONTEND TESTS"
    echo "=========================================="
    echo ""

    # --- Components: Pages Hierarchy Panel (batched) ---
    run_test "Frontend: Hierarchy Panel" \
        "npm run test -- src/components/pages_hierarchy_panel/heading_node.test.tsx src/components/pages_hierarchy_panel/page_tree_node.test.tsx src/components/pages_hierarchy_panel/page_tree_view.test.tsx src/components/pages_hierarchy_panel/pages_hierarchy_panel.test.tsx src/components/pages_hierarchy_panel/page_actions_menu.test.tsx src/components/pages_hierarchy_panel/utils/tree_builder.test.ts --silent"

    # --- Components: Wiki View Core (batched) ---
    run_test "Frontend: Wiki View Core" \
        "npm run test -- src/components/wiki_view/wiki_view.test.tsx src/components/wiki_view/hooks.test.ts src/components/wiki_view/page_anchor.test.ts src/components/wiki_view/page_breadcrumb/page_breadcrumb.test.tsx src/components/wiki_view/page_status_selector/page_status_selector.test.tsx --silent"

    # --- Components: Wiki Page Header (batched) ---
    run_test "Frontend: Wiki Page Header" \
        "npm run test -- src/components/wiki_view/wiki_page_header/wiki_page_header.test.tsx src/components/wiki_view/wiki_page_header/translation_indicator.test.tsx --silent"

    # --- Components: Wiki Page Editor (excluding ai/ and ai_utils/) ---
    run_test "Frontend: Wiki Page Editor" \
        "npm run test -- src/components/wiki_view/wiki_page_editor/wiki_page_editor.test.tsx src/components/wiki_view/wiki_page_editor/tiptap_editor.test.tsx src/components/wiki_view/wiki_page_editor/formatting_actions.test.ts src/components/wiki_view/wiki_page_editor/callout_extension.test.ts src/components/wiki_view/wiki_page_editor/video_extension.test.ts src/components/wiki_view/wiki_page_editor/file_attachment_extension.test.ts src/components/wiki_view/wiki_page_editor/file_attachment_node_view.test.tsx src/components/wiki_view/wiki_page_editor/file_upload_helper.test.ts src/components/wiki_view/wiki_page_editor/channel_mention_mm_bridge.test.tsx src/components/wiki_view/wiki_page_editor/comment_anchor_mark.test.ts src/components/wiki_view/wiki_page_editor/use_page_rewrite.test.tsx src/components/wiki_view/wiki_page_editor/slash_command_menu.test.tsx src/components/wiki_view/wiki_page_editor/link_bubble_menu.test.tsx src/components/wiki_view/wiki_page_editor/paste_markdown_extension.test.ts --silent"

    # --- Components: Wiki Page Editor - AI ---
    run_test "Frontend: Wiki Page Editor AI" \
        "npm run test -- src/components/wiki_view/wiki_page_editor/ai/ai_tools_dropdown.test.tsx src/components/wiki_view/wiki_page_editor/ai/proofread_action.test.ts src/components/wiki_view/wiki_page_editor/ai/translate_page_modal.test.tsx src/components/wiki_view/wiki_page_editor/ai/image_ai_bubble.test.tsx src/components/wiki_view/wiki_page_editor/ai/image_extraction_dialog.test.tsx src/components/wiki_view/wiki_page_editor/ai/image_extraction_complete_dialog.test.tsx --silent"

    # --- Components: Wiki Page Editor - AI Utils ---
    run_test "Frontend: Wiki Page Editor AI Utils" \
        "npm run test -- src/components/wiki_view/wiki_page_editor/ai_utils/content_validator.test.ts src/components/wiki_view/wiki_page_editor/ai_utils/tiptap_reassembler.test.ts src/components/wiki_view/wiki_page_editor/ai_utils/tiptap_text_extractor.test.ts --silent"

    # --- Components: Wiki RHS ---
    run_test "Frontend: Wiki RHS" \
        "npm run test -- src/components/wiki_rhs/wiki_rhs.test.tsx src/components/wiki_rhs/wiki_new_comment_view.test.tsx src/components/wiki_rhs/all_wiki_threads.test.tsx src/components/wiki_rhs/wiki_page_thread_viewer.test.tsx --silent"

    # --- Components: Modals ---
    run_test "Frontend: Modals" \
        "npm run test -- src/components/page_link_modal/page_link_modal.test.tsx src/components/delete_page_modal/delete_page_modal.test.tsx src/components/move_page_modal/move_page_modal.test.tsx src/components/wiki_delete_modal/wiki_delete_modal.test.tsx src/components/move_wiki_modal/move_wiki_modal.test.tsx src/components/page_version_history/page_version_history_modal.test.tsx src/components/unsaved_draft_modal/unsaved_draft_modal.test.tsx src/components/conflict_warning_modal/conflict_warning_modal.test.tsx src/components/text_input_modal/text_input_modal.test.tsx src/components/link_wiki_modal/link_wiki_modal.test.tsx src/components/wiki_unlink_modal/wiki_unlink_modal.test.tsx --silent"

    # --- Admin Console ---
    run_test "Frontend: Admin Console" \
        "npm run test -- src/components/admin_console/wiki_export_settings.test.tsx --silent"

    # --- Components: Other ---
    run_test "Frontend: Other Components" \
        "npm run test -- src/components/active_editors_indicator/active_editors_indicator.test.tsx src/components/inline_comment_context/inline_comment_context.test.tsx src/components/search_results/post_search_results_item.test.tsx --silent"

    # --- Hooks ---
    run_test "Frontend: Hooks" \
        "npm run test -- src/components/pages_hierarchy_panel/hooks/usePageMenuHandlers.test.ts src/hooks/useActiveEditors.test.ts src/hooks/usePageComments.test.ts src/hooks/usePageDraft.test.ts src/hooks/usePageForComment.test.ts src/hooks/usePublishedDraftCleanup.test.ts src/components/common/hooks/useVisionCapability.test.ts src/components/wiki_view/wiki_page_editor/ai/use_page_translate.test.tsx src/components/wiki_view/wiki_page_editor/ai/use_page_proofread.test.tsx src/components/wiki_view/wiki_page_editor/ai/use_image_ai.test.tsx --silent"

    # --- Actions ---
    run_test "Frontend: Actions" \
        "npm run test -- src/actions/pages.test.ts src/actions/page_drafts.test.ts src/actions/wiki_actions.test.ts src/actions/wiki_edit.test.ts src/actions/websocket_page_comments.test.ts src/actions/views/create_page_comment.test.ts src/actions/views/pages_hierarchy.test.ts src/actions/views/wiki_rhs.test.ts --silent"

    # --- Redux (actions + reducers) ---
    run_test "Frontend: Redux" \
        "npm run test -- src/packages/mattermost-redux/src/actions/active_editors.test.ts src/packages/mattermost-redux/src/actions/page_threads.test.ts src/packages/mattermost-redux/src/actions/wikis.test.ts src/packages/mattermost-redux/src/reducers/entities/pages.test.ts src/packages/mattermost-redux/src/reducers/entities/wiki_pages.test.ts src/packages/mattermost-redux/src/reducers/entities/wikis.test.ts src/packages/mattermost-redux/src/reducers/entities/active_editors.test.ts src/packages/mattermost-redux/src/reducers/requests/wiki.test.ts --silent"

    # --- Selectors ---
    run_test "Frontend: Selectors" \
        "npm run test -- src/selectors/pages.test.ts src/selectors/page_drafts.test.ts src/selectors/pages_hierarchy.test.ts src/selectors/wiki_posts.test.ts src/selectors/wiki_rhs.test.ts src/packages/mattermost-redux/src/selectors/entities/active_editors.test.ts --silent"

    # --- Reducers/Views ---
    run_test "Frontend: Reducers/Views" \
        "npm run test -- src/reducers/views/pages_hierarchy.test.ts src/reducers/views/wiki_rhs.test.ts src/reducers/views/rhs.test.js --silent"

    # --- Utils ---
    run_test "Frontend: Utils" \
        "npm run test -- src/utils/page_outline.test.ts src/utils/page_utils.test.ts src/utils/draft_autosave.test.ts src/utils/tiptap_to_markdown.test.ts src/utils/markdown_roundtrip.test.ts src/utils/markdown_full_roundtrip.test.ts --silent"

    # --- Additional Editor Components ---
    run_test "Frontend: Additional Editor" \
        "npm run test -- src/components/wiki_view/wiki_page_editor/emoticon_mm_bridge.test.tsx src/components/wiki_view/wiki_page_editor/suggestion_renderer.test.tsx --silent"
fi

if [ "$RUN_E2E" = true ]; then
    # Change to e2e-tests directory for Playwright tests
    cd "$ROOT_DIR/e2e-tests/playwright" || exit 1

    echo "=========================================="
    echo "E2E TESTS (PLAYWRIGHT)"
    echo "=========================================="
    echo ""

    echo -e "${YELLOW}Note: E2E tests require a running Mattermost server${NC}"
    echo -e "${YELLOW}If server is not running, E2E tests will be skipped${NC}"
    echo ""

    # Set default workers for parallel execution (can be overridden with PW_WORKERS env var)
    export PW_WORKERS="${PW_WORKERS:-2}"

    # Check if server is running (port 8065)
    if curl -s http://localhost:8065/api/v4/system/ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Server is running on localhost:8065${NC}"
        echo -e "${YELLOW}Using $PW_WORKERS parallel workers${NC}"
        echo ""

        # Helper function to check if category should run
        should_run_category() {
            local category=$1
            # If no category specified, run all
            if [ "$E2E_CATEGORY_SPECIFIED" = false ]; then
                return 0
            fi
            # Check specific category flag
            case $category in
                crud) [ "$E2E_CRUD" = true ] ;;
                navigation) [ "$E2E_NAVIGATION" = true ] ;;
                hierarchy) [ "$E2E_HIERARCHY" = true ] ;;
                editor) [ "$E2E_EDITOR" = true ] ;;
                collaboration) [ "$E2E_COLLABORATION" = true ] ;;
                ai) [ "$E2E_AI" = true ] ;;
                drafts) [ "$E2E_DRAFTS" = true ] ;;
                wiki) [ "$E2E_WIKI" = true ] ;;
                permissions) [ "$E2E_PERMISSIONS" = true ] ;;
                integration) [ "$E2E_INTEGRATION" = true ] ;;
                ui) [ "$E2E_UI" = true ] ;;
                debug) [ "$E2E_DEBUG" = true ] ;;
                export) [ "$E2E_EXPORT" = true ] ;;
                *) return 1 ;;
            esac
        }

        # Show which categories will run
        if [ "$E2E_CATEGORY_SPECIFIED" = true ]; then
            echo "E2E categories to run:"
            [ "$E2E_CRUD" = true ] && echo "  - CRUD"
            [ "$E2E_NAVIGATION" = true ] && echo "  - Navigation"
            [ "$E2E_HIERARCHY" = true ] && echo "  - Hierarchy"
            [ "$E2E_EDITOR" = true ] && echo "  - Editor"
            [ "$E2E_COLLABORATION" = true ] && echo "  - Collaboration"
            [ "$E2E_AI" = true ] && echo "  - AI"
            [ "$E2E_DRAFTS" = true ] && echo "  - Drafts"
            [ "$E2E_WIKI" = true ] && echo "  - Wiki"
            [ "$E2E_PERMISSIONS" = true ] && echo "  - Permissions"
            [ "$E2E_INTEGRATION" = true ] && echo "  - Integration"
            [ "$E2E_UI" = true ] && echo "  - UI"
            [ "$E2E_DEBUG" = true ] && echo "  - Debug"
            [ "$E2E_EXPORT" = true ] && echo "  - Export"
            echo ""
        fi

        # --- Core CRUD ---
        if should_run_category crud; then
            run_test "E2E: CRUD Operations" "npm run test -- pages_crud --project=chrome"
        fi

        # --- Navigation (batched) ---
        if should_run_category navigation; then
            run_test "E2E: Navigation" "npm run test -- pages_navigation pages_anchor_navigation pages_search pages_bookmarks --project=chrome"
        fi

        # --- Hierarchy & Structure (batched) ---
        if should_run_category hierarchy; then
            run_test "E2E: Hierarchy & Structure" "npm run test -- pages_hierarchy.spec.ts pages_drag_drop.spec.ts pages_hierarchy_outline.spec.ts pages_large_hierarchy pages_duplicate --project=chrome"
        fi

        # --- Editor & Content (batched) ---
        if should_run_category editor; then
            run_test "E2E: Editor & Content" "npm run test -- pages_editor pages_editor_resilience pages_formatting pages_callout pages_emoji pages_mentions pages_link_bubble pages_slash_commands pages_file_attachment pages_video_upload pages_external_image_paste pages_paste_markdown test_outline_minimal test_outline_navigation --project=chrome"
        fi

        # --- Collaboration & Real-time (batched) ---
        if should_run_category collaboration; then
            run_test "E2E: Collaboration & Real-time" "npm run test -- pages_active_editors pages_concurrent_editing pages_realtime_sync pages_realtime_hierarchy pages_wiki_realtime_creation pages_realtime_wiki_ops pages_realtime_page_moves pages_comments pages_threads --project=chrome"
        fi

        # --- AI Features (batched) ---
        if should_run_category ai; then
            run_test "E2E: AI Features" "npm run test -- pages_ai_rewrite pages_image_ai pages_translation pages_summarize --project=chrome"
        fi

        # --- Drafts & Version Control (batched) ---
        if should_run_category drafts; then
            run_test "E2E: Drafts & Version Control" "npm run test -- pages_drafts pages_version_history pages_status --project=chrome"
        fi

        # --- Wiki Management (batched) ---
        if should_run_category wiki; then
            run_test "E2E: Wiki Management" "npm run test -- pages_wiki_management pages_rename pages_cross_wiki pages_wiki_links --project=chrome"
        fi

        # --- Permissions & Security (batched) ---
        if should_run_category permissions; then
            run_test "E2E: Permissions & Security" "npm run test -- pages_permissions pages_data_integrity --project=chrome"
        fi

        # --- Integration & Migration (batched) ---
        if should_run_category integration; then
            run_test "E2E: Integration & Migration" "npm run test -- pages_integration pages_publish_confluence_content pages_pdf_export --project=chrome"
        fi

        # --- UI & Display (batched) ---
        if should_run_category ui; then
            run_test "E2E: UI & Display" "npm run test -- pages_author_avatar pages_browser_edge_cases pages_modal_reopen --project=chrome"
        fi

        # --- Debug & Minimal Tests (batched) ---
        if should_run_category debug; then
            run_test "E2E: Debug & Minimal" "npm run test -- pages_navigation_isolated --project=chrome"
        fi

        # --- Wiki Export/Import ---
        if should_run_category export; then
            echo -e "${YELLOW}No E2E export tests exist yet (wiki_export spec not written)${NC}"
            echo ""
        fi
    else
        echo -e "${YELLOW}⚠ Server not detected on localhost:8065${NC}"
        echo -e "${YELLOW}Skipping E2E tests (requires running server)${NC}"
        echo ""
        echo "To run E2E tests:"
        echo "  1. Start server: cd server && make run"
        echo "  2. Re-run this script"
        echo ""
    fi
fi

if [ "$RUN_MMCTL" = true ]; then
    # Change back to server directory for mmctl tests
    cd "$ROOT_DIR/server" || exit 1

    echo "=========================================="
    echo "MMCTL E2E TESTS (Wiki Export/Import)"
    echo "=========================================="
    echo ""

    echo -e "${YELLOW}Note: mmctl E2E tests require a running Mattermost server with job scheduler${NC}"
    echo -e "${YELLOW}These tests create jobs and wait for completion, which requires active schedulers${NC}"
    echo ""

    # Check if server is running (port 8065)
    if curl -s http://localhost:8065/api/v4/system/ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Server is running on localhost:8065${NC}"
        echo ""

        # Run permission test (doesn't require job completion)
        run_test "mmctl: WikiExportJobPermissions" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiExportJobPermissions' -timeout 120s"

        # Job-based tests (require job scheduler)
        echo -e "${YELLOW}Running job-based tests (may timeout if scheduler not active)...${NC}"
        run_test "mmctl: WikiExportJob" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiExportJob' -timeout 180s"
        run_test "mmctl: WikiImportJob" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiImportJob' -timeout 180s"
        run_test "mmctl: WikiExportImportComprehensive" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiExportImportComprehensive' -timeout 300s"
        run_test "mmctl: WikiExportWithAttachments" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiExportWithAttachments' -timeout 180s"
        run_test "mmctl: WikiExportMultipleChannels" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiExportMultipleChannels' -timeout 180s"
        run_test "mmctl: WikiVerifyCommand" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiVerifyCommand' -timeout 120s"
        run_test "mmctl: WikiResolveLinksCommand" "go test -v -tags e2e ./cmd/mmctl/commands -run 'TestMmctlE2ESuite/TestWikiResolveLinksCommand' -timeout 120s"
    else
        echo -e "${YELLOW}⚠ Server not detected on localhost:8065${NC}"
        echo -e "${YELLOW}Skipping mmctl E2E tests (requires running server with job scheduler)${NC}"
        echo ""
        echo "To run mmctl E2E tests:"
        echo "  1. Start server with job scheduler: cd server && make run"
        echo "  2. Re-run this script"
        echo ""
    fi
fi

echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="
echo ""
echo -e "${GREEN}Passed: ${#passed_tests[@]}${NC}"
for test in "${passed_tests[@]}"; do
    # Look up counts from temp file
    counts=$(grep "^$test|" "$TEST_COUNTS_FILE" 2>/dev/null)
    if [ -n "$counts" ]; then
        passed=$(echo "$counts" | cut -d'|' -f2)
        failed=$(echo "$counts" | cut -d'|' -f3)
        echo -e "  ${GREEN}✓${NC} $test - ${passed} PASS ${failed} FAIL"
    else
        echo -e "  ${GREEN}✓${NC} $test"
    fi
done
echo ""

if [ ${#failed_tests[@]} -gt 0 ]; then
    echo -e "${RED}Failed: ${#failed_tests[@]}${NC}"
    for test in "${failed_tests[@]}"; do
        # Look up counts from temp file
        counts=$(grep "^$test|" "$TEST_COUNTS_FILE" 2>/dev/null)
        if [ -n "$counts" ]; then
            passed=$(echo "$counts" | cut -d'|' -f2)
            failed=$(echo "$counts" | cut -d'|' -f3)
            echo -e "  ${RED}✗${NC} $test - ${passed} PASS ${failed} FAIL"
        else
            echo -e "  ${RED}✗${NC} $test"
        fi
        # Show individual failing tests for this group (fgrep for literal match)
        individual=$(fgrep "${test}|" "$TEST_FAILING_FILE" 2>/dev/null | cut -d'|' -f2-)
        if [ -n "$individual" ]; then
            while IFS= read -r t; do
                echo -e "      ${RED}✗${NC} $t"
            done <<< "$individual"
        fi
    done
    echo ""
    echo "To debug failures, run individual tests:"
    echo ""
    echo "  Backend:"
    echo "    cd server"
    echo "    go test -v ./channels/api4 -run TestWiki"
    echo "    go test -v ./channels/app -run TestPage"
    echo ""
    echo "  Frontend:"
    echo "    cd webapp/channels"
    echo "    npm run test -- src/selectors/pages.test.ts"
    echo ""
    echo "  E2E (Playwright):"
    echo "    cd e2e-tests/playwright"
    echo "    npm run test -- pages_crud --project=chrome"
    echo ""
    rm -f "$TEST_COUNTS_FILE"
    exit 1
else
    echo -e "${GREEN}All ${#passed_tests[@]} test groups passed!${NC}"
    echo ""
    rm -f "$TEST_COUNTS_FILE"
    exit 0
fi
