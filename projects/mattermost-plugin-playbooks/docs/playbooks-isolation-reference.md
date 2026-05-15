# Playbooks Isolation Reference

## Architecture Context

Playbooks is a Mattermost plugin. It shares the same PostgreSQL instance and
process host as the Mattermost server. All communication between plugin and
server goes through the **Plugin API** (`pluginapi.*`) or the **DB RPC proxy**
(`ConnExec`/`ConnQuery`). The plugin owns exclusively the `IR_*` family of
tables; everything else belongs to Mattermost core.

---

## Critical Isolation Points

### 1. Integration Test: Plugin Auto-Activation Guard

When a test creates a Mattermost server with `sapp.NewServer` + `server.Start()`,
Mattermost's `syncPlugins` mechanism scans the file store for plugin bundles and
auto-activates any plugin whose `PluginStates` entry is `{Enable: true}`. Because
Mattermost's default config sets `PluginStates["playbooks"] = {Enable: true}`, a
**stale bundle** left in `data/plugins/playbooks.tar.gz` from a prior test run
will be activated with the old binary — not the freshly-built one. This can hang
migrations indefinitely if the old binary contains migrations that block on locks
held by the server's own startup operations.

**Required pattern** (must appear before `configStore.Set(config)` and `server.Start()`):

```go
// CORRECT — explicitly disable before server starts; test re-enables with fresh bundle
if config.PluginSettings.PluginStates == nil {
    config.PluginSettings.PluginStates = make(map[string]*model.PluginState)
}
config.PluginSettings.PluginStates["playbooks"] = &model.PluginState{Enable: false}
```

```go
// WRONG — relies on default; stale bundle activates during server.Start()
config.PluginSettings.Enable = model.NewPointer(true)
// (no explicit PluginStates["playbooks"] = false)
```

**Functions to check in `*_test.go`:**
Any call to `sapp.NewServer`, `server.Start()`, or the shared `Setup(t)` helper in
`main_test.go`. The guard must be present exactly once in `Setup()`.

---

### 2. Core Table Writes in SQL Store

The plugin's `sqlStore` proxies through the DB RPC driver straight to PostgreSQL.
Operational code (non-migration) **must never INSERT, UPDATE, or DELETE** rows in
Mattermost core tables (`Channels`, `Posts`, `Users`, `Teams`, `PluginKeyValueStore`,
etc.). **Read-only JOINs to core tables are expected and fine** — they are the normal
way to filter or sort by user/channel/bot data in bulk queries.

```go
// FINE — read-only JOIN for participant ordering
LEFT JOIN Bots b ON (b.UserId = rp.UserId)
ORDER BY (CASE WHEN b.UserId IS NULL THEN 0 ELSE 1 END), rp.UserId

// FINE — read-only JOIN in migration backfill
UPDATE IR_Incident SET Name = c.DisplayName FROM Channels c WHERE IR_Incident.ChannelID = c.Id

// WRONG — writing to a core table from operational code
UPDATE Posts SET Message = $1 WHERE Id = $2
INSERT INTO PluginKeyValueStore (PluginId, PKey, PValue) VALUES (...)
DELETE FROM Channels WHERE Id = $1
```

**Allowed exceptions (migrations only):**

Historical migrations may write to core Mattermost tables for **one-time operations**:
- `0.30→0.31`: `UPDATE PluginKeyValueStore` (re-key KV entries for plugin rename) — migration only ✓

**Rules for new migrations:**
- New migrations MUST NOT UPDATE or DELETE rows in Mattermost core tables (except approved one-time re-keying)
- Read-only JOINs to core tables for backfills are acceptable with a comment
- Any cross-table write needs a code review escalation

**Files to audit:** `sqlstore/playbook_run.go`, `sqlstore/playbook.go`,
`sqlstore/condition.go`, `sqlstore/category.go`, `sqlstore/channel_action.go`

---

### 3. Property System Scoping

The plugin registers a property group named `"playbooks"` on startup and stores its
`groupID`. **All property API calls must use `s.groupID`**. Using hardcoded strings
or borrowing group IDs from other plugins would cause cross-contamination in
Mattermost's shared property system.

```go
// CORRECT — all calls scoped to the registered group
createdField, err := s.api.Property.CreatePropertyField(mmPropertyField)  // mmPropertyField.GroupID = s.groupID
values, err := s.api.Property.SearchPropertyValues(s.groupID, opts)

// WRONG — hardcoded or borrowed group
values, err := s.api.Property.SearchPropertyValues("some-other-group", opts)
```

**Property target types:** must use `PropertyTargetTypePlaybook` (`"playbook"`) and
`PropertyTargetTypeRun` (`"playbook_run"`) — never borrow target types from other
plugins or leave `TargetType` empty.

**File to check:** `app/property_service.go` — every `s.api.Property.*` call must
reference `s.groupID`, not a literal string.

---

### 4. WebSocket Event Namespacing

Plugin WebSocket events must use a `playbook_` or `run_` prefix to avoid
collision with Mattermost core events (`posted`, `channel_created`, `user_updated`,
etc.). Events are published via `pluginAPI.Frontend.PublishWebSocketEvent`.

```go
// CORRECT — namespaced event
const playbookCreatedWSEvent = "playbook_created"
p.bot.PublishWebsocketEventToTeam(playbookCreatedWSEvent, payload, teamID)

// WRONG — generic name that could clash with core
const myEvent = "created"
p.bot.PublishWebsocketEventToTeam(myEvent, payload, teamID)
```

**Files to check:** `app/playbook_service.go`, `app/playbook_run_service.go`,
`config/service.go`, `bot/poster.go`

---

### 5. Config Mutation Scope

The plugin must only write to its **own plugin config namespace** via
`p.config.UpdateConfiguration(func(c *config.Configuration) {...})`. It must
never call Mattermost's global `SaveConfig()` or mutate non-plugin settings.

```go
// CORRECT — plugin config only
err = p.config.UpdateConfiguration(func(c *config.Configuration) {
    c.BotUserID = botID
})

// WRONG — mutating Mattermost global config
cfg := p.API.GetConfig()
cfg.ServiceSettings.SiteURL = model.NewPointer("https://example.com")
p.API.SaveConfig(cfg)
```

**Allowed:** `p.API.GetConfig()` for **read-only** access to Mattermost settings
(e.g., license checks, feature flags).

**File to check:** `plugin.go`, `config/service.go`

---

### 6. Scheduler Initialization Order

The `cluster.GetJobOnceScheduler` must follow this exact order in `OnActivate`:

1. `scheduler := cluster.GetJobOnceScheduler(p.API)` — create
2. Pass `scheduler` to `sqlstore.New` and `NewPlaybookRunService`
3. `scheduler.SetCallback(p.playbookRunService.HandleReminder)` — register callback
4. `scheduler.Start()` — start
5. `sqlStore.RunMigrations()` — **only after** scheduler started

If `RunMigrations` runs before `scheduler.Start()`, any migration that enqueues a
job will schedule it on a non-running scheduler, causing silent job loss.

**File to check:** `plugin.go` (lines around `scheduler.Start()` and `RunMigrations()`).

---

## Audit Checklist

### Integration Tests
- [ ] `Setup()` in `main_test.go`: `PluginStates["playbooks"] = {Enable: false}` before `server.Start()`
- [ ] No test helper calls `sapp.NewServer` + `server.Start()` without the guard
- [ ] Plugin is explicitly enabled post-startup via `UploadPluginForced` + `EnablePlugin`

### SQL Store (Operational)
- [ ] No `Exec`/`execBuilder` writes (INSERT/UPDATE/DELETE) targeting non-`IR_*` tables
- [ ] Read-only JOINs to core tables are acceptable — no action needed
- [ ] New migrations that write to core tables have a justification comment and explicit approval

### Property System
- [ ] Every `s.api.Property.*` call uses `s.groupID`, not a string literal
- [ ] `TargetType` set to `PropertyTargetTypePlaybook` or `PropertyTargetTypeRun`
- [ ] No cross-group property access

### WebSocket Events
- [ ] All new event name constants use `playbook_` or `run_` prefix
- [ ] Events published via `pluginAPI.Frontend.PublishWebSocketEvent`

### Config
- [ ] No calls to `p.API.SaveConfig()` or mutations to non-plugin settings
- [ ] `p.API.GetConfig()` used read-only only

### Scheduler
- [ ] `scheduler.SetCallback` and `scheduler.Start()` called before `RunMigrations()`
- [ ] No migration code assumes scheduler is stopped

---

## Common Isolation Bugs

| Bug Pattern | Impact | Detection |
|-------------|--------|-----------|
| Missing `PluginStates["playbooks"] = false` guard in test setup | Stale plugin bundle activates during `server.Start()`, migrations hang | Grep for `server.Start()` in test files without the guard |
| `sqlStore.db.Exec(...)` writing to `Channels`, `Posts`, or other core tables in operational code | Bypasses pluginAPI permissions and caching; data corruption risk | Grep for INSERT/UPDATE/DELETE targeting non-IR_ tables in `sqlstore/*.go` (outside migrations) |
| `s.api.Property.*` without `s.groupID` | Cross-contamination of property fields between plugins | Grep for `Property.` calls with hardcoded string group args |
| New WS event with unprefixed name | Collides with Mattermost core events in frontend dispatch | Grep for event name constants not matching `playbook_` or `run_` |
| `p.API.SaveConfig()` call | Mutates global Mattermost settings, visible to all plugins | Grep for `SaveConfig` in plugin code |
| `RunMigrations()` before `scheduler.Start()` | Jobs silently lost if migration enqueues scheduler work | Check order in `plugin.go:OnActivate` |
