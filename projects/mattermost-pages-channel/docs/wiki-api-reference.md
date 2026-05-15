# Wiki API Reference

Reference for wiki/pages API routes. Source of truth: `server/channels/api4/wiki_api.go`, `drafts.go`, `wiki_links_api.go`.

## Routes

Base: `/api/v4`

### Wiki CRUD

```
POST   /wikis                              - Create wiki
GET    /wikis/{wiki_id}                    - Get wiki
PATCH  /wikis/{wiki_id}                    - Update wiki
DELETE /wikis/{wiki_id}                    - Delete wiki
GET    /channels/{channel_id}/wikis        - List channel wikis
GET    /teams/{team_id}/wikis              - List team wikis
```

### Pages

```
GET    /wikis/{wiki_id}/pages                              - List wiki pages
POST   /wikis/{wiki_id}/pages                              - Create page
GET    /wikis/{wiki_id}/pages/{page_id}                    - Get page
PUT    /wikis/{wiki_id}/pages/{page_id}                    - Update page
DELETE /wikis/{wiki_id}/pages/{page_id}                    - Delete page
PATCH  /wikis/{wiki_id}/pages/{page_id}/restore            - Restore page
GET    /wikis/{wiki_id}/pages/{page_id}/active_editors      - Active editors
GET    /wikis/{wiki_id}/pages/{page_id}/version_history     - Version history
GET    /wikis/{wiki_id}/pages/{page_id}/breadcrumb          - Breadcrumb
PUT    /wikis/{wiki_id}/pages/{page_id}/move                - Move page (reorder/reparent)
PATCH  /wikis/{wiki_id}/pages/{page_id}/move-to-wiki        - Move page to another wiki
POST   /wikis/{wiki_id}/pages/{page_id}/duplicate           - Duplicate page
GET    /channels/{channel_id}/pages                         - Get all pages in channel
```

### Comments

```
GET    /wikis/{wiki_id}/pages/{page_id}/comments                                    - List comments
POST   /wikis/{wiki_id}/pages/{page_id}/comments                                    - Create comment
POST   /wikis/{wiki_id}/pages/{page_id}/comments/{parent_id}/replies                - Reply to comment
POST   /wikis/{wiki_id}/pages/{page_id}/comments/{comment_id}/resolve               - Resolve comment
POST   /wikis/{wiki_id}/pages/{page_id}/comments/{comment_id}/unresolve             - Unresolve comment
```

### Drafts

```
POST   /wikis/{wiki_id}/drafts                              - Create draft
GET    /wikis/{wiki_id}/drafts                              - List wiki drafts
GET    /wikis/{wiki_id}/drafts/{page_id}                    - Get draft
PUT    /wikis/{wiki_id}/drafts/{page_id}                    - Save draft
DELETE /wikis/{wiki_id}/drafts/{page_id}                    - Delete draft
POST   /wikis/{wiki_id}/drafts/{page_id}/move               - Move draft
POST   /wikis/{wiki_id}/drafts/{page_id}/publish            - Publish draft
POST   /wikis/{wiki_id}/drafts/{page_id}/editor_stopped     - Notify editor stopped
```

### Wiki Links

```
POST   /channels/{channel_id}/wiki-links                    - Link wiki to channel
GET    /channels/{channel_id}/wiki-links                    - List channel wiki links
DELETE /channels/{channel_id}/wiki-links/{wiki_link_id}     - Unlink wiki from channel
```

### AI Features

```
POST   /wikis/{wiki_id}/pages/extract-image                 - Extract text from image
POST   /wikis/{wiki_id}/pages/summarize-thread              - Summarize thread to page
```

## Review Checklist

When reviewing wiki API changes:
- [ ] Routes under `/api/v4/wikis/{wiki_id}/`
- [ ] Uses standard MM pagination headers
- [ ] Follows MM error response format
- [ ] Permission checks via App layer (not Store)
