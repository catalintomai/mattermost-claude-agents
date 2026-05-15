# Confluence Migration Reference

## Confluence Export Format

### Export ZIP Structure
```
export/
├── entities.xml          # Main data file with pages, comments, users
├── exportDescriptor.properties
└── attachments/          # Binary attachments organized by content ID
    └── {contentId}/
        └── {attachmentId}
```

### Key XML Elements in entities.xml
```xml
<!-- Page object -->
<object class="Page">
  <id>123456</id>
  <property name="title">Page Title</property>
  <property name="bodyContents">...</property>  <!-- Storage format HTML -->
  <property name="parent" class="Page"><id>789</id></property>
  <property name="creator" class="ConfluenceUserImpl">...</property>
  <property name="creationDate">2024-01-01 00:00:00</property>
  <property name="lastModifier">...</property>
  <property name="lastModificationDate">...</property>
  <property name="version">1</property>
  <collection name="comments">...</collection>
  <collection name="attachments">...</collection>
</object>

<!-- Comment object -->
<object class="Comment">
  <id>789012</id>
  <property name="body"><![CDATA[Comment text]]></property>
  <property name="owner" class="Page"><id>123456</id></property>  <!-- parent page -->
  <property name="parent" class="Comment"><id>null</id></property> <!-- for replies -->
  <property name="creator">...</property>
  <property name="creationDate">...</property>
</object>
```

## Migration Pipeline

### 1. mmetl Transform (services/confluence/)

> Note: mmetl is a separate repository (github.com/mattermost/mmetl), not part of this project. The paths below are relative to a local clone of that repository.

**Key Files:**
- `parser.go` - Parses entities.xml
- `transformer.go` - Converts to intermediate format
- `tiptap_converter.go` - Confluence storage format → TipTap JSON
- `hierarchy.go` - Builds page tree
- `links.go` - Handles cross-page links (→ placeholders)
- `export.go` - Outputs JSONL + manifest

**JSONL line types and PageImportData struct:**

```go
// JSONL line types
{"type": "version", "version": 1}
{"type": "wiki", "wiki": {...}}
{"type": "page", "page": {...}}
{"type": "page_comment", "page_comment": {...}}

// Page import data
type PageImportData struct {
    Team                  *string           `json:"team"`
    Channel               *string           `json:"channel"`
    User                  *string           `json:"user"`
    Title                 *string           `json:"title"`
    Content               *string           `json:"content"`  // TipTap JSON
    ParentImportSourceId  *string           `json:"parent_import_source_id,omitempty"`
    CreateAt              *int64            `json:"create_at,omitempty"`
    Props                 *model.StringInterface `json:"props,omitempty"`
}

// Props must include import_source_id for idempotency
Props: {"import_source_id": "<confluence_page_id>"}
```

**Link Placeholder Format:**
```
{{CONF_PAGE_ID:<confluence_id>}}
```

### 2. Server Import (channels/app/import_wiki_functions.go)

**Key Functions:**
- `importWiki()` - Creates/updates wiki for channel
- `importPage()` - Creates page with hierarchy
- `importPageComment()` - Creates comments on pages
- `updatePostPropsFromImport()` - Sets import_source_id prop

**Idempotency:** Uses `import_source_id` prop to detect existing pages. Re-running import skips already-imported pages.

**Hierarchy Resolution:** Parent resolved by `parent_import_source_id`. If parent not found, page becomes root (logged as warning).

### 3. mmctl Commands (cmd/mmctl/commands/wiki.go)

**`mmctl wiki verify`**
- Compares manifest counts vs actual
- Checks for orphaned pages (PageParentId → missing parent)
- Scans for unresolved {{CONF_PAGE_ID:...}} placeholders

**`mmctl wiki resolve-links`**
- Builds mapping: import_source_id → Mattermost page ID
- Replaces {{CONF_PAGE_ID:x}} with /pages/<mm_id>
- Updates page content via UpdatePage API

## Common Issues & Solutions

### 1. Import Source ID Type Validation
**Issue:** Non-string values in import_source_id break idempotency
**Check:** Ensure `props["import_source_id"]` is always a string

### 2. Hierarchy Field Usage
**Issue:** Using `GetProp("page_parent_id")` instead of `PageParentId` field
**Check:** Hierarchy operations use `post.PageParentId`

### 3. Title Preservation on Update
**Issue:** UpdatePage clobbers title when props["title"] is missing
**Check:** Fetch existing title before updating content

### 4. User Mapping
**Issue:** Confluence users don't exist in Mattermost
**Check:** mmetl creates user mapping file, verify all users mapped

### 5. TipTap Conversion
**Issue:** Confluence storage format → TipTap JSON conversion errors
**Check:** Complex formatting (macros, tables) may not convert perfectly

### 6. Attachment References
**Issue:** Attachments referenced in content but not imported
**Check:** Attachment URLs in TipTap content should be rewritten

### 7. HTML Entity Encoding
**Issue:** Confluence stores text with HTML entities (`&apos;`, `&quot;`, `&amp;`, `&lt;`, `&gt;`)
**Check:** All text extraction from XML/HTML must decode entities using `html.UnescapeString()`

```go
// BAD: Raw text extraction (entities preserved)
anchorText := extractTextFromXML(content)  // Returns "don&apos;t"

// GOOD: Decode HTML entities
anchorText := html.UnescapeString(extractTextFromXML(content))  // Returns "don't"
```

**Common entities:** `&apos;` → `'`, `&quot;` → `"`, `&amp;` → `&`, `&lt;` → `<`, `&gt;` → `>`, `&#NNN;` → numeric refs

**Affected areas:** Inline comment anchor text, page titles from CDATA, comment body text, any user-displayed text

### 8. Content Status Filtering
**Issue:** Confluence pages have `contentStatus` field: `current`, `draft`, `deleted`, `archived`
**Check:** Only import `current` pages; filter out others

## Removing Import Fields or Pipeline Steps

### Removing a field from `PageImportData`
1. Remove from mmetl output — stop writing in `transformer.go` / `export.go`
2. Remove from `PageImportData` struct in both mmetl and server `model/`
3. Search server import code: `grep -r "FieldName" server/channels/app/import_wiki_functions.go`
4. Remove from import processing
5. Update manifest if tracked
6. Update mmctl verify if checked

### Removing a transformation step
1. Remove from transformer — the function in `services/confluence/`
2. Remove from pipeline chain — the call site in `transform()` or `export()`
3. Remove test data that exercises the step
4. Update manifest expectations if output format changes

**CRITICAL**: Removing a field from `PageImportData` struct without removing server import code that reads it causes compile errors. Removing it from mmetl output but not the struct causes silent data loss (field is zero-valued).

## Review Checklists

### mmetl Transform Review
- [ ] Parser correctly handles all XML element types
- [ ] User mapping file generated
- [ ] Page hierarchy preserved (parent_import_source_id)
- [ ] Comments linked to correct pages
- [ ] Link placeholders generated for cross-page links
- [ ] TipTap conversion handles tables, code blocks, macros
- [ ] Attachment paths rewritten correctly
- [ ] Manifest counts match actual output
- [ ] HTML entities decoded in all extracted text
- [ ] Content status filtering — only `current` pages imported

### Server Import Review
- [ ] import_source_id validated as non-empty string
- [ ] Idempotency works (re-import skips existing)
- [ ] Parent page resolution handles missing parents
- [ ] Comment threading preserved (parent_comment_import_source_id)
- [ ] Props injection prevented (only allowed props)
- [ ] Transaction handling for page+comments

### mmctl Commands Review
- [ ] Verify uses PageParentId field (not prop)
- [ ] Verify fails on orphans/broken links
- [ ] Resolve-links preserves page title
- [ ] URL normalization (no double slashes)
- [ ] Dry-run mode works correctly

## Test Commands

```bash
# Run mmetl transform
mmetl transform confluence \
  --file /path/to/confluence-export.zip \
  --team myteam \
  --channel wiki \
  --output wiki-import.jsonl

# Verify output
head -5 wiki-import.jsonl
cat wiki-import-manifest.json

# Run tests
cd /path/to/mmetl && go test -v ./services/confluence/...
cd /path/to/server && go test -v -run "TestImportImportWiki|TestImportImportPage" ./channels/app/
go test -v -tags unit -run "TestMmctlUnitSuite/TestWiki" ./cmd/mmctl/commands/
```
