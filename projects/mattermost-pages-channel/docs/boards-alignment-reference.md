# Boards Alignment Reference

Reference material for the `boards-alignment-reviewer` agent. Contains the current state of boards implementation, spec quotes, schema details, and detailed dimension descriptions.

> **Last synced**: 2026-04-17 — against upstream PRs 35604 (merged 2026-03-26), 35512 (merged 2026-03-25), 35887 (open).
> When reviewing, verify against the PRs, not only the older PDFs — boards pivoted from "posts in regular channels" to "dedicated `BO`/`BP` channel types" after the original Tech Spec.

## Source Documents (Source of Truth)

Authority order: **merged upstream code** > **open upstream PRs** > **implementation-plan markdown** > **original Tech Spec PDFs** (now partially superseded).

### Upstream PRs (authoritative — reflects what actually shipped / is shipping)

1. **PR 35604** (merged) — `Add API endpoint to retrieve posts for a specific view`
   - Introduces `PostTypeCard = "card"` constant, wired into `Post.IsValid()` whitelist
   - `GET /api/v4/channels/{channel_id}/views/{view_id}/posts` — paginated view-post endpoint
   - Cards excluded from search indexing: `searchlayer/post_layer.go`, `elasticsearch/common/indexing_job.go`, `sqlstore/post_store.go` (marked `FIXME(IntegratedBoardMVP)`)
   - Cards excluded from `GetPostsSinceForSync` for shared channels (`sharedchannel/sync_recv.go`, `sync_send_remote.go`)
   - **Collaborative edit/delete model**: cards bypass `edit_others_posts`/`delete_others_posts` — any channel member with `edit_post`/`delete_post` can modify or delete any card. Applies to `updatePost`, `patchPost`, `deletePost`, `getPostEditHistory`. Gated by `FeatureFlags.IntegratedBoards`.
   - Jira: MM-66519, MM-66520

2. **PR 35512** (merged) — `Adds basic implementation of the generic redux store for PSAv2`
   - New `entities.properties` Redux slice containing `fields`, `values`, `groups`
   - New files:
     - `webapp/channels/src/packages/mattermost-redux/src/action_types/properties.ts`
     - `webapp/channels/src/packages/mattermost-redux/src/reducers/entities/properties.ts`
     - `webapp/channels/src/packages/mattermost-redux/src/selectors/entities/properties.ts`
     - `webapp/channels/src/packages/mattermost-redux/src/utils/property_utils.ts`
   - Updates `webapp/platform/types/src/properties.ts` and `store.ts` (new `PropertiesState` shape in `GlobalState`)
   - Jira: MM-67796

3. **PR 35887** (open as of 2026-04-17) — `Add board channel types (BO/BP) for Integrated Boards` — **MAJOR ARCHITECTURAL PIVOT**
   - `ChannelTypeOpenBoard = "BO"` and `ChannelTypePrivateBoard = "BP"` — boards are now a **new channel type**, not posts inside existing channels
   - DB migration `000168_add_board_channel_types` adds BO/BP to the `channel_type` PostgreSQL enum
   - Helpers on `Channel`: `IsBoard()`, `IsOpenBoard()`, `IsPrivateBoard()`
   - `SaveBoardChannel()` store method — atomic channel + default kanban view + creator-as-admin in one transaction
   - **`Save()` rejects board types** — forces callers to use `SaveBoardChannel`
   - **`Get()` excludes board types** via `WHERE Type NOT IN ('BO','BP')` — boards are invisible to all `/channels` handlers
   - `GetBoardChannel()` for `/boards` endpoints
   - All channel listing/search queries exclude boards (`GetTeamChannels`, `GetAll`, `GetChannels`, `GetChannelsByUser`, `GetDeleted`, autocomplete, `channelSearchQuery`)
   - `POST /boards` endpoint (feature-flagged) — creates channel + kanban view + admin member atomically, publishes `board_created` and `view_created` WS events
   - System property migration at app startup: registers `boards` property group, creates two **protected system-wide fields** — `Assignee` (user), `Status` (select: Todo / In Progress / Complete). Idempotent.
   - Channel `Props[ChannelPropsBoardLinkedProperties]` (= `"board:linked_properties"`) stores the property field IDs linked to the board
   - Typed `KanbanProps` / `KanbanColumn` / `KanbanGroupBy` structs with `ToProps()` / `KanbanPropsFromProps()` round-tripping
   - WS event: `board_created`
   - Authorization: open boards (`BO`) get public-read semantics matching open channels (`O`)

### Local docs (derived — may lag upstream)

4. `~/mattermost/mattermost-integrated-boards/implementation-plans/integrated-boards-implementation-plan.md`
   - Predates PR 35887's BO/BP split — still refers to `ChannelTypeBoard = "B"` (single type). **Treat as historical context; prefer PR 35887 for channel-type facts.**
5. `~/mattermost/mattermost-integrated-boards/implementation-plans/wave-5a-tab-bar-board-view.md`
   - Webapp wave for tab bar + board view + kanban components
6. `~/mattermost/mattermost-integrated-boards/implementation-plans/wave-5b-card-detail-rhs-property-editors.md`
7. `~/mattermost/mattermost-integrated-boards/implementation-plans/INTEGRATED_BOARDS_SPECIFICATION.md`
8. `~/mattermost/mattermost-integrated-boards/implementation-plans/archive/BOARDS_VS_PAGES_ARCHITECTURE_COMPARISON.md`
   - Useful as a starting point for the pages/boards deltas, but pre-dates BO/BP pivot.

### Original Tech Spec PDFs (partially superseded — check PRs first)

9. **Integrated Boards Tech Spec** (12 pages):
   `~/mattermost/mattermost-integrated-boards/implementation-plans/_5c333c236d9c474cefb13319-Integrated Boards Tech Spec-170226-210816.pdf`
10. **Linked Channel Memberships Tech Spec** (7 pages):
    `~/mattermost/mattermost-integrated-boards/implementation-plans/_5c333c236d9c474cefb13319-Linked Channel Memberships Tech Spec-170226-211210.pdf`
11. **UX Spec: Integrated Boards MVP** (14 pages):
    `~/mattermost/mattermost-integrated-boards/implementation-plans/DES-UX Spec_ Integrated Boards MVP-160226-131223.pdf`

### Jira Epics

- **MM-67606** — Integrated Boards: Milestone 2 (Property System and API foundation)
- **MM-67607** — Integrated Boards: Milestone 3 (Posts as Cards)
- Key tickets: MM-66519, MM-66520, MM-66527, MM-66528, MM-66522, MM-66524, MM-66545, MM-66526, MM-67796

## Shared Architecture Principles

### Layering comparison

Both pages and boards store leaf content as `Post` records with a custom type, scoped to a channel. They differ at the **container** and **host channel** layers:

| Layer | Pages | Boards |
|---|---|---|
| Host channel | Regular `O`/`P` channel (shared with messages) | Dedicated `BO`/`BP` channel (PR 35887) — contains only cards + view metadata, no chat messages |
| Container entity | **Wiki** — first-class entity with its own ID in the `Wikis` table; referenced by `page.props[WIKI_ID]`; pages can move between wikis | **None** as a separate entity — the `BO`/`BP` channel itself IS the board; cards are addressed by `channel_id` |
| Rendering config | — (pages render via hierarchy) | **View** — row in the `Views` table with `ChannelId` = board channel id and `Type = "kanban"` (list/calendar future) — see § "Boards shipping structure" below |
| Leaf entity | `Post` with `type='page'`, hierarchical via `page_parent_id`, scoped to a wiki | `Post` with `type='card'`, `channel_id` = board channel id |

Key correction: **boards do NOT use a first-class "board entity" separate from the channel**. In PR 35887, the `BO`/`BP` channel IS the board. The `Views` table stores rendering configs (kanban today, list/calendar future) over the cards in that channel.

### Boards shipping structure (three peer layers under a board channel)

The shipping PR 35887 flattened an earlier design. It's worth being explicit about what the final structure looks like and what the old plan called things:

**Shipping model (PR 35887 + PR 35604):**

```
Board  =  BO/BP channel                                  ← row in Channels table, Type='BO' or 'BP'
   │
   ├─ View  (row in Views table, ChannelId = board channel id, Type='kanban')
   │   └─ View.Props holds typed KanbanProps { GroupBy: { FieldID, Columns[] } }
   │
   ├─ View  (another row, Type='list' or 'calendar' — future)
   │   └─ View.Props holds the relevant typed config
   │
   └─ Cards (posts in the BO/BP channel, Type='card')    ← rows in Posts table
       ├─ Card (linked to a view's grouping via property values, not by "being in" a view)
       ├─ Card
       └─ ...
```

**Key properties of this structure:**

- **Views and cards are peer children of the board channel.** Views do NOT contain cards; both are independent children of the same channel.
- **Cards are NOT "in" a view.** A card lives in the BO/BP channel. The view provides a way to group/filter those cards for display, via property values (specifically, the field referenced by `KanbanProps.GroupBy.FieldID`). Delete a view and the cards still exist. Create a new view on the same channel and all existing cards appear, grouped by whatever field the new view uses.
- **Multiple views per board.** Each View row is one rendering directly (e.g., a kanban with its columns). A single board channel can have multiple View rows for different slices of the same cards.
- **ViewType is the rendering type directly.** `ViewTypeKanban = "kanban"` — not `"board"`. There is no intermediate View-of-type-board entity in the shipping code.

**Old plan (archived, does not match shipping):**

The implementation plan originally described a different shape with a single `View` entity of `Type = "board"` containing a JSONB array of subviews:

```
Regular O/P channel
   └─ View (Type='board')                              ← called "a board" in the plan
       └─ View.Props.Subviews = [                      ← JSONB array
             { type='kanban', columns, group_by },
             { type='list' },
             { type='calendar' },
           ]
   └─ Cards (posts, Type='card', in the regular channel)
```

PR 35887 collapsed this: there is no `ViewType = "board"` any more; each subview rendering is now its own peer View row with `Type = "kanban"` (etc.) directly. The "board" moved up to become the `BO`/`BP` channel. If you see references to `Props.Subviews` or `ViewTypeBoard` in an old plan or doc, **they describe a design that was not shipped**.

**Terminology to use when reviewing:**
- **Board** → the `BO`/`BP` channel (the addressable thing, the thing with membership)
- **View** → a row in the `Views` table, bound to a board channel, one rendering config per row
- **Card** → a `type='card'` post in the board channel
- **Subview** → **obsolete term**; do not use. If a plan uses it, flag as describing the archived design.

### Entity-Identity Asymmetry (Boards vs. Wikis — Transitional)

Both features have **dedicated tables for richer state** (`Views` for boards, `Wikis` for wikis) and **container/backing channels for membership** (`BO`/`BP` and `ChannelTypeWiki` respectively). The asymmetry is in **user-facing identity**:

| Dimension | Boards (PR 35887) | Wikis (stash) |
|---|---|---|
| User-facing entity | The `BO`/`BP` channel IS the board | The `Wikis` table entity is the wiki; backing channel is hidden |
| Container-level metadata storage | `Channel.Props[ChannelPropsBoardLinkedProperties]` (JSON blob) | First-class columns on `Wikis` (`Title`, `Description`, `Icon`, `TeamId`, `CreatorId`, `Props`, `SortOrder`) |
| Channel-type enum footprint | 2 values (`BO`, `BP`) | 1 value (`ChannelTypeWiki`) — open/private distinction lives on the `Wikis` table |
| Cross-container movement | Not supported — a card can't move between boards (different channels) | Supported — a page can move between wikis |
| Multiple source-channel linking | Not supported today (1 board = 1 channel) | Supported via `ChannelMemberLink` (1 wiki linkable to up to 50 channels) |

**Treat this asymmetry as transitional, not a permanent design choice.** The wiki pattern (separate entity + hidden backing channel) is more extensible:

- Avoids `channel_type` enum pollution as more container-like features land
- Reduces reliance on `Channel.Props` JSON for container-level structured metadata (boards' `ChannelPropsBoardLinkedProperties` stores a list of IDs in `Channel.Props` today — a pattern MM uses elsewhere for channel bookmarks and banners, but one that doesn't scale comfortably once the stored data grows beyond small lists)
- Allows cross-team ownership, multiple source channels, and richer entity-level state without schema acrobatics

**Migration trigger criteria for moving boards to the wiki pattern.** The channel-subtype approach is defensible while boards' container-level state fits comfortably in `Channel` + `Channel.Props` + additional `View` rows. Migrate to a dedicated `Boards` table (with a hidden `ChannelTypeBoard` backing channel, mirroring the wiki stash) when at least one **Strong** trigger below lands. **Mild** triggers alone do not justify migration — they can be absorbed by `Channel.Props` with some stretch.

| Trigger | Strength | Why |
|---|---|---|
| Board-level icon / description distinct from `Channel.Header` | Mild | Fits in `Channel.Props` with a soft stretch |
| Archive vs. delete lifecycle | Not a trigger | `Channel.DeleteAt` already handles it |
| More than 3–4 view types per board (kanban + list + calendar + ...) | Not a trigger | Keep adding View rows — the three-layer structure absorbs this |
| Multi-channel boards (one board surfaced in many source channels via links) | **Strong** | Channel-as-board cannot be linked-to without inventing `BoardMemberLinks`; wikis already solve this via `ChannelMemberLinks` |
| Board templates (board creation from saved templates with prepopulated views + properties) | **Strong** | Templates are a new entity type on top of boards and don't fit in `Channel.Props` |
| Team-scoped boards (one board spans a whole team, not a single channel) | **Strong** | Channels are team-scoped by membership, not team-scoped as entities; boards at team-entity level need their own table |
| Board-level properties distinct from card properties (e.g., board status, board priority) | **Strong** | Channel-level structured properties don't fit in `Channel.Props` cleanly and would collide with card properties |
| Cross-team boards | **Strong** | Channel `TeamId` is a hard boundary; cross-team requires an entity with `team_ids []string` or no team scoping |
| Board-level versioning / history | **Strong** | No place on `Channels` row for this |
| Per-board audit trail beyond channel-level audits | **Mild→Strong** | Minor board-level audits fit in existing channel audits; rich per-board audit requires its own entity |

**Until a Strong trigger lands, do NOT migrate** — the reversal cost (user-facing identity change, URL shape change, webapp store shape change) outweighs the cleanup benefit.

**For reviewers**:
- Do NOT flag wikis' use of a separate entity as a boards misalignment. The wiki design is forward-looking; boards will likely follow when a Strong trigger lands.
- Do NOT propose migrating boards to the wiki pattern for preference-based reasons alone (preference for narrower enums, preference for first-class columns over `Channel.Props`, preference for structural consistency). These are reasonable design preferences but not worth the rework in isolation.
- DO flag a boards proposal that hits a Strong trigger while continuing the channel-subtype pattern. That's the signal the migration is due.

### What pages and boards share

- Custom post types excluded from regular post queries/search (pages: `type='page'`, cards: `type='card'`)
- Collaborative edit model — custom types bypass `edit_others_posts`/`delete_others_posts` (boards explicit; pages already do via collaborative editing)
- Generic property system — server (`PropertyFields`/`PropertyValues`, ObjectType-centric) and webapp (`entities.properties.{fields,values,groups}` from PR 35512)
- Feature flag gating (boards behind `IntegratedBoards`; pages not gated)
- Channel-inherited permissions (both read member/permission state from a channel)
- Idempotent app-layer startup migrations for seeding system-wide property fields (boards seeds `boards` property group with Assignee/Status)
- WebSocket event naming convention: `<entity>_<verb>` with feature prefix (e.g. `board_created`, `view_created`, `channel_view_*`)

### Where pages and boards diverge

- **Host channel type**: pages live in regular `O`/`P` channels alongside messages; boards have dedicated `BO`/`BP` channels that are excluded from all `/channels/*` endpoints at store level (`Save()` rejects boards, `Get()` filters them).
- **Container layer**: pages have an intermediate first-class entity (`wiki`) that owns pages and is addressable independently of the backing channel; boards use the channel itself as the user-facing container. See § "Entity-Identity Asymmetry" above — this is treated as transitional (boards will likely migrate to the wiki pattern when container state grows), not a permanent design split.
- **Rendering configs**: pages render via hierarchy (the `page_parent_id` tree); boards use the `Views` table for kanban/list/calendar renderings over the cards in the board channel. Each View row is one rendering directly (`Type = "kanban"`, etc. — there is no `ViewType = "board"` / subviews shape in shipping code; see § "Boards shipping structure"). Pages don't have an analogue of views and don't need one today.
- **Routing**: pages reached via `/channels/{id}/wikis/*` and related page routes on regular channels; boards reached via `/boards/*` and `/api/v4/channels/{channel_id}/views/{view_id}/posts` (where `channel_id` is the `BO`/`BP` channel).
- **Property store placement**: pages currently keep `statusField` in `entities.wikiPages.statusField` (and the pending `client-pages-redux-store.md` plan propagates that into `entities.pages.statusField`); boards consumes the shared `entities.properties.fields.byObjectType["post"]` store that landed in PR 35512. This is a real misalignment, not a design difference.
- **Cross-channel membership propagation (`ChannelMemberLinks`)**: described in the older Linked Memberships spec but NOT implemented in PR 35887 (which just creates a standalone board channel with creator-as-admin). Pages doesn't need it either. Flag only if future work introduces a parallel link mechanism that should be using `ChannelMemberLinks`.

## Dimension Details

### 1. Post Type Isolation

- Both `type='page'` and `type='card'` must be excluded from regular post queries and search.
- **From PR 35604**: cards are filtered out of `searchlayer/post_layer.go`, Elasticsearch bulk indexing, SQL search query, and `GetPostsSinceForSync`. All sites marked `FIXME(IntegratedBoardMVP)`.
- **Prefer an extensible exclusion pattern** (e.g., `NON_POST_TYPES = new Set([PostTypes.PAGE, PostTypes.CARD])`) over hardcoded single-type checks. Pages' current `IGNORE_POST_TYPES` list already includes PAGE and PAGE_COMMENT; when boards lands this should extend to CARD.
- **From original Tech Spec**: "each area that interacts with posts will need to be evaluated to determine whether it should handle all post types uniformly or apply type specific logic"
- Cards are INCLUDED in compliance exports and data retention; EXCLUDED from shared channel sync, unread counts, search index.

### 2. Channel Tabs / Tab Bar (pages-only after PR 35887)

This dimension is pages-specific now. Boards do NOT show up as tabs on the host channel — a board is its own channel. The UX Spec's tab-bar integration is for showing **bookmarks + boards** together in a single bar, but "boards" here means references to board channels from a source channel, not tabs on a regular channel.

- **From UX Spec**: tab bar combines bookmarks + boards beneath channel header; `manage_bookmarks` permission expanded to cover tab bar management (add/remove/reorder).
- **From wave-5a plan**: board tabs use `BoardTabItem` chip rendered alongside `BookmarkItem` in `channel_bookmarks.tsx`. A "Messages" chip also renders when any view exists, clearing the active board.
- **From wave-5a plan**: `activeBoardId` is per-channel: `state.views.board.activeBoardByChannelId: Record<channelId, viewId | null>`.
- Max tab width 140px with tooltip, overflow "+N more" dropdown.
- **IMPORTANT DISTINCTION**: Tab-bar management permissions (`manage_bookmarks` family) and entity creation permissions (`create_post` / `create_board`) are SEPARATE. Do NOT conflate.

Pages' wiki tabs follow a similar but independent pattern (pages are tabs on the regular channel).

### 3. API Patterns

- **Board creation**: `POST /boards` — boards have their own top-level route, feature-flagged. (From PR 35887.)
- **View endpoints**: `POST/GET /api/v4/channels/{channel_id}/views`, `GET/PATCH/DELETE /api/v4/channels/{channel_id}/views/{view_id}`. PATCH (not PUT) for partial updates.
- **View posts**: `GET /api/v4/channels/{channel_id}/views/{view_id}/posts` — paginated (from PR 35604).
- **Generic Property API**: ObjectType-scoped routes — `POST/GET /api/v4/properties/posts/fields`, `GET/PATCH /api/v4/properties/posts/values/{post_id}`. Bulk property values use POST body (URL length limits).
- **WebSocket event naming**: `channel_view_*` prefix for view events, `board_created` for board creation. Matches `channel_bookmark_*` pattern.
- **Boards are invisible to `/channels/*` endpoints** — any page-related endpoint that ever accepts a channelId should not need to defend against boards specifically because the store filters them out, but new `/channels/*` endpoints wiki/pages adds should verify they follow the same exclusion pattern.

### 4. Channel Membership Model (Linked Channel Memberships)

- **`ChannelMemberLinks` table schema** (from Linked Memberships Tech Spec):
  ```sql
  CREATE TABLE ChannelMemberLinks (
    sourceID      VARCHAR(26) NOT NULL,
    sourceType    VARCHAR(32) NOT NULL,
    destinationID VARCHAR(26) NOT NULL,
    createAt      BIGINT NOT NULL,
    PRIMARY KEY (sourceID, sourceType, destinationID)
  );
  ```
- **`SourceID` column on `ChannelMembers`** — NULL = direct membership, channelID = synthetic membership propagated from that source channel.
- **Rules**:
  - Direct membership always wins (PK prevents duplicates)
  - Synthetic memberships get `channel_user` role initially
  - No transitive links (A→B→C explicitly prevented)
  - Propagation ideally in same DB transaction as direct membership; MVP uses best-effort propagation (`addUserToChannel` doesn't expose a transaction handle — Phase 2 can add `SaveMemberWithPropagation`)
  - On member removal: check alternative links before deleting synthetic memberships
- **Cache invalidation**: member count cache + channel membership cache for affected users.
- **MVP link cardinality**: one link per board, auto-created on board creation. No REST API for link management.
- **Pages do not currently use this machinery** — pages exist in the same channel as their viewers. Flag if a page-related change introduces cross-channel membership propagation that should be using `ChannelMemberLinks` instead of a parallel mechanism.

### 5. Property System Compatibility (ObjectType-centric)

- **From Tech Spec**: Property System shifted from group-centric to **ObjectType-centric**.
- `ObjectType` column on `PropertyFields` (e.g., `"post"` for card and page properties).
- Property uniqueness enforced within hierarchy path (system > team > channel).
- **Protected properties** — cannot be modified via generic API. Boards seeds `Assignee` and `Status` at startup as protected system-wide fields in the `boards` property group (PR 35887).
- `Channel.Props[ChannelPropsBoardLinkedProperties]` on boards — list of property field IDs the board uses.
- Generic property endpoints check blacklist for protected feature groups.
- **Pages alignment**: `entities.wikiPages.statusField` (soon `entities.pages.statusField`) conflicts with this pattern. Pages should read its status field from `entities.properties.fields.byObjectType["post"]` (or a pages property group) once the property store lands (PR 35512). Document any continued use of `pages.statusField` as a known boards-integration-blocker, not a deferred cleanup.

### 6. Store Layer Patterns

- Boards uses `view_store.go` with standard CRUD + channel-scoped queries.
- **From Tech Spec**: database queries JOIN posts with `propertyvalues` for board-card filtering.
- **From implementation plan**: column naming uses lowercase (`channelid`, `creatorid`) — match MM convention.
- No FK constraints on `views` table — match MM convention.
- **From PR 35887**: `SaveBoardChannel()` is the ONLY way to create a board channel. `Save()` rejects board types. `Get()` excludes board types. If pages ever introduces its own channel type (not currently planned), follow this pattern.

### 7. App Layer Patterns

- **Card permissions**: any channel member with `edit_post`/`delete_post` can edit/delete any card — cards bypass post edit window and `edit_others_posts`/`delete_others_posts`. Pages' page-comment model should follow the same collaborative pattern (flag if page edits enforce stricter ownership than channel membership).
- **Compensating cleanup** on card creation: create card post, then upsert properties; if property upsert fails, delete the orphan post.
- **Startup migration** pattern (PR 35887): boards registers its property group and two system-wide property fields idempotently at app startup, following the content-flagging precedent.

### 8. Frontend State Management

- **`entities.properties`** (PR 35512) — new Redux slice with sub-stores `fields`, `values`, `groups`. This is where pages' `statusField` should ultimately live.
- **`entities.views`** (from wave-5a) — boards' views state, keyed `byChannelId`; each channel has a `Record<viewId, View>`.
- **Per-channel active selection**: `state.views.board.activeBoardByChannelId` — per-channel, not global. Pages-side equivalents (active wiki, current page) should follow this pattern.
- **Action type namespacing**: boards uses `ViewTypes.*` and property actions use `PropertyActionTypes.*`. Pages uses `WikiTypes.*` — consistent with the pattern.
- **Redux structure**: Boards and views have dedicated store sections per channel; property sections are feature-agnostic (any feature can store properties).
- **Specialized selectors** filter properties by object type and group.

### 9. Unread / Notification Handling

- **Cards excluded from unread counts** — exclude from both `CountPostsAfter` AND `TotalMsgCount` increment at post save time. (Pages already exclude via `IGNORE_POST_TYPES`; mirror for CARD.)
- Card creation events appear in channel message feed as rich formatted messages linking to the card (per Tech Spec).

### 10. Database Migration Patterns

- **DB migrations** for boards:
  - `000168_add_board_channel_types` — extends `channel_type` PostgreSQL enum with `BO`/`BP` (PR 35887)
  - `ChannelMemberLinks` table with indexes on sourceID and destinationID
  - Conditional index on `ChannelMembers` for `SourceID`: `WHERE sourceid IS NOT NULL`
  - `views` table with `channelid` and `channelid+deleteat` indexes
  - `PropertyFields` gets `ObjectType`, `CreatedBy`, `UpdatedBy` columns
- **App-layer migrations** (startup, idempotent): boards property group + Assignee/Status protected fields. Uses existing content-flagging precedent.
- Pages migrations should follow both patterns where applicable: extend enums via DB migration; seed property fields via app-layer startup migration.

### 11. Feature Flag Gating

- **All boards features gated behind `IntegratedBoards`** (default off).
- **When disabled**: `/boards` endpoint gated; card post type still allowed at model level but feature-specific behaviors (collaborative edit, view-posts endpoint, kanban UI) are flag-gated.
- **Webapp helper** (`getIsIntegratedBoardsEnabled`): checks both the feature flag AND an enterprise license.
- Pages is not behind a feature flag currently. If pages follows boards' path, use the same helper pattern (flag + license).

### 12. Post-API inheritance vs. dedicated API surface (design divergence)

This dimension captures the **architectural choice** that differs most visibly between boards and pages on the server: what rides on the existing post API and what gets its own routes/handlers.

**Boards / cards approach** (from PRs 35604, 35887):
- **Leaf CRUD on the generic post API**: cards are created via standard `POST /posts`, updated via `PUT`/`PATCH /posts/{id}`, deleted via `DELETE /posts/{id}`. Card-specific behavior lives as `if post.Type == model.PostTypeCard` branches inside the shared handlers in `server/channels/api4/post.go` (collaborative permissions, audit details, etc.).
- **Only net-new read endpoint**: `GET /api/v4/channels/{channel_id}/views/{view_id}/posts` (paginated, view-scoped post list).
- **Explicit opt-out of post-layer features that don't apply to cards**: search indexing, Elasticsearch bulk indexing, SQL search, and `GetPostsSinceForSync` all got `if post.Type == PostTypeCard { skip }` branches (marked `FIXME(IntegratedBoardMVP)`). These opt-outs are a cost paid for the benefit of the generic post API carrying cards "for free."
- **Net-new handler footprint**: `view.go` + `board.go` + `<10 branches inside post.go`.

**Pages approach** (this fork):
- **Dedicated resource routes under `/wikis/{wiki_id}/pages/*`** (see `server/channels/api4/wiki_api.go:16-41`). ~25 routes registered: create/get/put/delete page, move, restore, duplicate, comments CRUD, active_editors, version_history, breadcrumb, extract-image, summarize-thread.
- **Dedicated app layer**: 14+ `server/channels/app/page_*.go` files (page_core, page_hierarchy, page_draft, page_comments, page_mentions, page_notifications, page_bookmarks, page_properties, page_ai, …).
- **Helper `PageContentTypes()`** in `server/channels/store/sqlstore/post_store.go:64-68` returns `[PostTypePage, PostTypePageComment]` for filtering, but its call sites must be audited — it's not a universal sharedchannel / search exclusion like cards' explicit opt-outs.

**Why each approach exists**:
- Cards are semantically thin — "a post with typed properties." The post API gives them threading, files, reactions, audit, edit history, search, compliance exports, and data retention with minimal type-branching. The cost is explicit opt-outs where card semantics differ (no unread badges, no sync as chat message, no search-index entry).
- Pages are semantically rich — drafts, hierarchy, cross-wiki moves, versioning, translations, collaborative-editor active_editors tracking, page-scoped comments with resolve/unresolve, AI summarization/extraction. Shoehorning these into `post.go` as type-branches would fragment the generic handler with wiki-specific logic.

**This is a design divergence, not a misalignment**. Neither pattern is wrong. But it creates ongoing maintenance obligations the reviewer MUST flag.

#### Review checklist for this dimension

When a page-related change lands, verify:

1. **Feature-parity audit** — has something changed in MM-core's post API that pages needs to mirror? Examples:
   - A new permission model on `editPost` (e.g., the collaborative-edit pattern PR 35604 added for cards) — does `updatePage` / `updatePageContent` follow the same rule?
   - A new audit event format in `post.go` — is `page_api.go` emitting equivalent audit events (`AuditEventCreatePage`, `AuditEventUpdatePage`, …)?
   - A new WS event, error envelope, or pagination convention — does the page-side surface match?

2. **Post-layer opt-outs must be mirrored** — cards explicitly excluded themselves from:
   - `server/channels/store/searchlayer/post_layer.go` (search indexing)
   - `server/enterprise/elasticsearch/common/indexing_job.go` (ES bulk index)
   - `server/channels/store/sqlstore/post_store.go` (SQL search query)
   - `server/platform/services/sharedchannel/sync_recv.go` + `sync_send_remote.go` (cross-cluster sync)
   - `CountPostsAfter` + `TotalMsgCount` increment (unread counts — pages covers this via `IGNORE_POST_TYPES` at the webapp layer, but verify the server-side `TotalMsgCount` increment path also skips `PostTypePage`).

   **Pages should audit the same sites and either exclude `PostTypePage` / `PostTypePageComment` OR document why inclusion is correct.** A quick `grep -r PostTypePage server/platform/services/sharedchannel server/channels/store/searchlayer` should show hits — if it doesn't, that's a finding.

3. **New page features: post-API branch or dedicated route?** — for every new leaf-level capability (e.g., "bookmark a page"), the reviewer should ask: *could this be a type-branch in the generic handler (saving code duplication and auto-inheriting post-layer features) or does it genuinely need a dedicated endpoint?* Usually pages needs a dedicated endpoint because of richer semantics, but the decision should be explicit, not defaulted.

3a. **Don't reinvent post-layer features that already exist** — before building a page-specific subsystem, check whether the post layer already has an equivalent that can be reused (possibly with a `type='page'` branch). Examples:
   - *Edit history*: post edit history (`GET /posts/{id}/edit-history`) captures per-edit revisions. Pages builds `version_history` separately because confluence "versions" are user-published snapshots, not every keystroke edit — legitimate divergence, but the decision should be explicit in the plan.
   - *Reactions*: `entities.posts.reactions[pageId]` already works for pages (post ID keyed, type-agnostic) — no page-specific reaction store needed. This one's already right.
   - *Flags / saved items*: if pages ever adds "save this page," check whether post flags (`SavedPosts`) could carry it before building `PageBookmarks`.
   - *File attachments*: `entities.files.fileIdsByPostId` works for any post — no page-specific file store needed.
   - *Threading*: page comments use post thread infrastructure (`root_id` → page). Good reuse.
   For every new page subsystem, the plan must answer: "Does post layer have an equivalent? If yes, why isn't it being reused? If no, is the divergence semantic (genuinely different concept) or incidental (could be unified)?"

4. **Permission-check duplication — prefer shared helpers over reinvention** — use MM's channel-permission helpers instead of hand-rolling equivalent logic:
   - `SessionHasPermissionToChannel(ctx, session, channelID, PermissionX)` — for channel-scoped permission checks
   - `SessionHasPermissionToTeam(ctx, session, teamID, PermissionX)` — for team-scoped
   - `HasPermissionToReadChannel(...)` — for read permission (handles open-channel public-read semantics including `BO` boards)
   - `HasPermissionToChannelMemberCount(...)` — for membership visibility

   Cards check `PermissionEditPost` inside the shared `post.go` handler via these helpers. Pages has its own `CheckPagePermission(page, PageOperationUpdate)` wrapper in `page_api.go` — **that's fine as long as the wrapper delegates to `SessionHasPermissionToChannel` internally**. Flag:
   - Any new page handler that does raw `channelMember, err := ... GetChannelMember(...)` lookups instead of calling the permission helpers
   - Any new page handler that re-implements the channel-admin / channel-user role-check logic inline
   - Any page code that rolls its own "user is member of channel" check instead of using the session helpers

   If MM-core changes the post-layer permission model (e.g., adds a new session-level check), pages does NOT pick it up automatically. The mitigation is that `CheckPagePermission` should be a thin wrapper over the same helpers post.go uses — NOT a parallel implementation.

5. **Request/response shape parity** — card request/response shapes match MM's `Post` type (they ARE posts). Page shapes are custom (see `model/page.go`). Flag any drift from MM JSON conventions: `snake_case` fields, error envelope shape, pagination params (`page`, `per_page`), `update_at` / `create_at` / `delete_at` timestamps.

#### Tag for findings

Use `boards:POST_API_PARITY` for this dimension. Examples:
- *Pages missing sharedchannel sync exclusion for `PostTypePage` while cards have one* → `[MEDIUM] boards:POST_API_PARITY` (unless intentional with rationale)
- *New page feature adds a `/wikis/{id}/pages/{id}/flag` endpoint when post.go already has equivalent flag logic* → `[MEDIUM] boards:POST_API_PARITY`
- *`updatePage` does not mirror the collaborative-edit bypass that PR 35604 added to `post.go:updatePost` for custom types* → `[HIGH] boards:POST_API_PARITY`
