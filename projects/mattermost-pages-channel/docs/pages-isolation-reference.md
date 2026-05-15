# Pages Isolation Reference

## Architecture Context

Pages use a **channel-subservient architecture**:
- Pages stored in `Posts` table with `Type = 'page'`
- Page comments stored with `Type = 'page_comment'`
- Regular posts have `Type = ''` (empty string) or other system types
- Both share the same table, WebSocket infrastructure, and API patterns

## Critical Isolation Points

### 1. Store Layer: Post Queries MUST Filter Pages

Any query on Posts for channel feeds, pagination, counts, or ETags MUST exclude pages.

```go
// CORRECT
query = AddRegularPostsFilter(query, "p")

// WRONG — no type filter
query := s.getQueryBuilder().Select("*").From("Posts").
    Where(sq.Eq{"ChannelId": channelId})
```

**Functions to check in `post_store.go`:**
`GetPostsSince`, `GetPostsBefore`, `GetPostsAfter`, `GetPostsForChannel`, `GetPostIdAroundTime`, `GetEtag`, `GetFlaggedPosts`, `AnalyticsPostCount`

### 2. Store Layer: Page Queries MUST Only Return Pages

```go
// CORRECT
query := s.getQueryBuilder().Select("*").From("Posts").
    Where(sq.Eq{"Type": model.PostTypePage})

// WRONG — returns regular posts too
query := s.getQueryBuilder().Select("*").From("Posts").
    Where(sq.Eq{"ChannelId": channelId})
```

### 3. App Layer: Shared Functions Must Branch on Type

```go
// CORRECT
if post.Type == model.PostTypePage {
    a.handlePageUpdate(post)
    return
}
a.handleRegularPostUpdate(post)

// WRONG — assumes all posts are regular
a.SendPostNotifications(post)  // Would notify for pages too!
```

**Functions to check:** `UpdatePost`, `DeletePost`, `GetSinglePost`, `PreparePostForClient`

### 4. WebSocket Events: Proper Event Types

Pages should use page-specific events (`PagePublished`, `PageDeleted`, `PageMoved`, `PageTitleUpdated`), not overload post events.

Check that `handlePostEditEvent` and `handlePostDeleteEvent` ignore pages or handle them distinctly.

### 5. Frontend: Separate State Management

```typescript
// CORRECT — separate reducers
state.entities.wikiPages.pages
state.entities.wikiPages.drafts

// WRONG — pages mixed into post state
state.entities.posts.posts[pageId]
```

Check: `wikiPages` reducer, `posts` reducer, selectors, components.

### 6. Frontend: WebSocket Handler Isolation

Page events must route to page handlers, not post handlers.

### 7. API Layer: Route Separation

Page APIs under `/wiki/{wikiId}/pages/`, not mixed with `/posts/`. Post endpoints should reject page IDs where appropriate.

### 8. Channel-Substrate Concealment

Pages are backed by regular channels, but wiki users/clients should NOT perceive that. The channel is an implementation detail; wiki surfaces must not expose it.

**API responses (Go):** wiki endpoint responses should surface page identity (`wiki_id`, `page_id`, `parent_id`) not raw channel identity. If `channel_id` leaks on a wiki DTO, justify it or strip it.

```go
// SUSPECT — channel_id on a wiki response the UI doesn't need it for
type WikiPageResponse struct {
    ID        string `json:"id"`
    ChannelID string `json:"channel_id"` // why does the wiki client need this?
    ...
}
```

**Webapp (TypeScript):** wiki components/selectors must not import from channel modules to read channel membership, channel header, channel mentions, typing, or read state.

```typescript
// WRONG — wiki component reaching into channel state
import {getCurrentChannel} from 'mattermost-redux/selectors/entities/channels';
// in components/wiki_view/*

// CORRECT — wiki selectors pull from entities.wikiPages only
import {getCurrentWiki} from 'selectors/wikis';
```

**WebSocket:** wiki screens must not subscribe to channel-level events (`typing`, `channel_viewed`, `channel_updated`, `channel_member_updated`) to drive wiki UI. Page-specific events only.

**Routing:** `/channels/{id}/posts` and related channel-post endpoints must not be a back door that returns page posts. Post endpoints reject `Type='page'` IDs.

**mmctl / REST parity:** a wiki-facing CLI or REST consumer should be able to complete wiki operations without ever needing a `channel_id` argument.

## Audit Checklist

### Store Layer
- [ ] `post_store.go`: Channel feed queries use `regularPostsFilter`
- [ ] `post_store.go`: Pagination queries exclude pages
- [ ] `post_store.go`: Count queries exclude pages
- [ ] `page_store.go`: All queries filter by `Type = 'page'`
- [ ] `page_store.go`: No queries that could return regular posts
- [ ] Hierarchy queries use bounded depth (no unbounded recursive CTEs)

### App Layer
- [ ] `post.go`: Shared functions check post type where needed
- [ ] `page_*.go`: Functions only operate on pages
- [ ] Notifications: Page updates don't trigger post notifications
- [ ] Caching: Page cache invalidation doesn't affect post cache

### API Layer
- [ ] `post.go`: Post endpoints reject or properly handle pages
- [ ] `page_*.go`: Page endpoints only accept pages
- [ ] Permissions: Page permissions don't affect post permissions

### Frontend
- [ ] `reducers/`: Page state separate from post state
- [ ] `actions/websocket_actions.ts`: Page events routed correctly
- [ ] `actions/websocket_actions.ts`: Page WebSocket handlers don't dispatch post actions
- [ ] `selectors/`: Post selectors filter out pages if needed
- [ ] `components/`: Components check post type before rendering

### Channel-Substrate Concealment
- [ ] Wiki API DTOs: no gratuitous `channel_id` / channel membership fields
- [ ] `components/wiki_view/`, `pages_hierarchy_panel/`, `wiki_rhs/`: no imports from `selectors/entities/channels` or channel actions
- [ ] Wiki screens do not subscribe to `typing`, `channel_viewed`, `channel_updated`, `channel_member_updated`
- [ ] `/channels/{id}/posts` and similar endpoints reject page-type posts
- [ ] mmctl wiki commands operate on wiki/page IDs, not channel IDs

## Common Isolation Bugs

| Bug Pattern | Impact | Detection |
|-------------|--------|-----------|
| Post query missing `regularPostsFilter` | Pages appear in channel feed | Grep for `GetPosts*` without filter |
| Page query missing `Type = 'page'` | Regular posts returned as pages | Grep for `page_store.go` queries |
| `UpdatePost` called on page | Wrong update flow, missing events | Check callers of `UpdatePost` |
| POST_EDITED without type check | Page edits trigger post UI updates | Check `handlePostEditEvent` |
| Page in `posts` reducer | State corruption | Check reducer action types |
| Post endpoint accepts page ID | Bypasses page permissions | Check ID validation |
| `channel_id` in wiki response DTO | Leaks substrate; couples clients to channel model | Grep wiki response structs for `ChannelId`/`channel_id` |
| Wiki component imports channel selector | Wiki UI breaks if channel model changes | Grep `components/wiki_*` for `entities/channels` |
| Wiki screen subscribes to `typing`/`channel_viewed` | Channel-level noise drives wiki UI | Grep WS handlers on wiki routes |
