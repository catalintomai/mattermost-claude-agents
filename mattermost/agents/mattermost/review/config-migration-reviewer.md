---
name: config-migration-reviewer
description: Reviews configuration changes for backward compatibility, restart requirements, default values, environment variable conventions, and feature flag lifecycle. Use when reviewing new config fields, config struct changes, or feature flag additions/removals.
model: haiku
effort: low
tools: Read, Write, Grep, Glob
---

> **Grounding Rules**: FIRST ACTION — Read the file `~/.claude/agents/_shared/grounding-rules.md` using the Read tool and follow ALL rules strictly.
> **Diff Scope Rule**: Read `~/.claude/agents/_shared/diff-scope-rule.md` — ONLY flag issues in changed lines (diff scope). Pre-existing issues are INFO only.
> **80/20 Rule**: Read `~/.claude/agents/_shared/eighty-twenty-rule.md` — apply when prioritizing findings and proposals.

# Config Migration Reviewer

Reviews configuration changes for backward compatibility, restart/hot-reload behavior, default values, environment variable naming, validation, and feature flag lifecycle following Mattermost patterns.

## Mattermost Configuration Patterns

### Config Struct Layout

Settings are organized into nested `*Settings` structs in `server/public/model/config.go`. Each settings group has a `SetDefaults()` method and an `IsValid()` method:

```go
type ServiceSettings struct {
    SiteURL                             *string `access_control_config:"true"`
    WebsocketURL                        *string
    // ...
}

func (s *ServiceSettings) SetDefaults(isUpdate bool) {
    if s.SiteURL == nil {
        s.SiteURL = NewString(ServiceSettingsDefaultSiteURL)
    }
    // ...
}

func (s *ServiceSettings) IsValid() *AppError {
    if *s.SiteURL != "" && !IsValidHTTPURL(*s.SiteURL) {
        return NewAppError("Config.IsValid", "model.config.is_valid.site_url.app_error", nil, "", http.StatusBadRequest)
    }
    // ...
}
```

### Environment Variable Mapping

MM env vars follow `MM_<SECTION>_<FIELD>` (uppercase, underscores). The mapping is defined in `server/public/model/config_override.go` or handled automatically by the config system based on field names.

```
ServiceSettings.SiteURL → MM_SERVICESETTINGS_SITEURL
EmailSettings.SMTPServer → MM_EMAILSETTINGS_SMTPSERVER
PluginSettings.Enable → MM_PLUGINSETTINGS_ENABLE
```

## What to Flag

### 1. Missing `SetDefaults()` Entry for New Fields (Critical)

Every new config field MUST have a default set in `SetDefaults()`. A missing default means a zero/nil value is used, which can change behavior from previous versions when upgrading.

```go
// BAD: new field with no SetDefaults entry
type ServiceSettings struct {
    // ... existing fields ...
    EnableNewFeature *bool // No default set anywhere!
}

// GOOD: default set in SetDefaults
func (s *ServiceSettings) SetDefaults(isUpdate bool) {
    // ... existing defaults ...
    if s.EnableNewFeature == nil {
        s.EnableNewFeature = NewBool(false)
    }
}
```

Also flag: a new field whose default pointer is never initialized (left `nil`). Callers dereferencing without nil-check will panic.

### 2. Missing `IsValid()` Validation for New Fields (High)

New fields should have bounds checking, format validation, or enum validation in `IsValid()`. Unchecked config values reach production with invalid or dangerous values.

```go
// BAD: integer field with no bounds check
type RateLimitSettings struct {
    MaxBurst *int // Could be set to -1 or 0, breaking the rate limiter
}

// GOOD: validation in IsValid
func (s *RateLimitSettings) IsValid() *AppError {
    if *s.MaxBurst < 0 {
        return NewAppError("Config.IsValid", "model.config.is_valid.max_burst.app_error", nil, "", http.StatusBadRequest)
    }
    // ...
}
```

**Patterns that require validation**:
- Integer fields: check for negative values, zero (if invalid), and maximum bounds
- String fields: check for valid format (URL, email, duration, etc.) when format matters
- Enum fields: check against known values
- `*bool` fields: no validation needed (only two values)

### 3. Removing or Renaming Config Fields Without Migration (Critical)

Removing a config field or changing its JSON key name breaks existing `config.json` files. Users with the old key get silent data loss — their setting is ignored.

```go
// BAD: field renamed without migration
// Old: EnableExperimentalFeature *bool `json:"EnableExperimentalFeature"`
// New: EnableFeature *bool `json:"EnableFeature"` ← old JSON key no longer parsed!

// GOOD: either keep old name, or add migration code
// In server/channels/app/config.go or similar migration path:
func migrateConfig(cfg *model.Config) {
    if cfg.ServiceSettings.EnableExperimentalFeature != nil && cfg.ServiceSettings.EnableFeature == nil {
        cfg.ServiceSettings.EnableFeature = cfg.ServiceSettings.EnableExperimentalFeature
    }
}
```

Flag: any config field removal or JSON key rename without a corresponding migration or deprecation notice.

### 4. Environment Variable Naming Inconsistency (High)

New fields should follow `MM_<SECTION>_<FIELD>` exactly. Mixed case, extra underscores, or abbreviations break the convention.

```go
// BAD: abbreviated section name
// MM_SVC_ENABLEFEATURE instead of MM_SERVICESETTINGS_ENABLEFEATURE

// BAD: camelCase in env var name (should be all uppercase)
// MM_SERVICESETTINGS_enableFeature

// GOOD
// MM_SERVICESETTINGS_ENABLEFEATURE
```

If the config system derives env vars from field names automatically, check that the struct section name (`ServiceSettings`) and field name (`EnableNewFeature`) produce the expected env var when uppercased.

### 5. Hot-Reload vs Restart Required — Undocumented (Medium)

Config changes fall into two categories:
- **Hot-reloadable**: Take effect without restart (watched by config listener)
- **Restart required**: Server must restart to pick up the change

New fields that require restart should have a comment indicating this. Fields wired to a hot-reload listener need to have their listener registered.

```go
// BAD: new field, no indication of restart/hot-reload behavior
EnableNewFeature *bool

// GOOD: document restart requirement
// EnableNewFeature controls X. Requires server restart to take effect.
EnableNewFeature *bool

// GOOD: hot-reloadable (verify listener is registered in configStore.Watch or equivalent)
EnableNewFeature *bool // Hot-reloadable
```

Flag: new fields that are read in long-lived goroutines or server startup but have no documented restart requirement and no config listener.

### 6. Stale Feature Flags (Medium)

Feature flags that were added to gradually roll out a feature and are now fully enabled should be cleaned up. A flag older than approximately 2 release cycles that defaults to `true` and cannot be meaningfully disabled is stale.

```go
// BAD: flag that has been "enabled by default" for multiple releases
// and the feature is production-stable — the flag is just noise now
FeatureFlagEnableNewPages *bool // Added in v9.0, always true since v9.2, now v9.6

// GOOD: remove the flag and the conditional code paths that read it
```

When reviewing a PR that touches feature flags, check:
1. Are any flags being added that have no plan for removal?
2. Are any existing flags still present that appear to have been universally enabled for multiple releases?

### 7. Plugin Config Key Conflicts (High)

Plugin settings should not use key paths that shadow or conflict with server config paths. Plugin config is namespaced under the plugin ID in `PluginSettings.Plugins`, but mistakes happen.

```go
// BAD: plugin defines a settings key that matches a top-level server config path
// Plugin config: {"ServiceSettings": {"SiteURL": "..."}}
// This could be confused with the server's ServiceSettings.SiteURL

// GOOD: plugin settings use feature-specific keys that don't mirror server config sections
// Plugin config: {"MyPluginFeatureEnabled": true, "MyPluginWebhookURL": "..."}
```

Flag any plugin config struct whose top-level keys match server config section names (`ServiceSettings`, `EmailSettings`, etc.).

### 8. Feature or Plugin Removal Leaves Config Entries Behind (High)

Removal paths are reviewed for what they delete from the database and rarely for what they delete from config. A per-feature or per-plugin config entry that survives an uninstall is not inert: the next install reads it back and the feature restarts in a half-configured state that no admin chose.

The sharpest case is a settings map keyed by an identifier — `PluginSettings.Plugins[id]`, `PluginSettings.PluginAccessControl[id]`, or any `map[string]X` in a settings struct. Deleting the plugin's rows while leaving its map entry means a reinstall finds filtering still switched on with an allow-list that no longer has any members, so the feature comes back denying everyone.

```go
// BAD: uninstall clears storage but not the config entry keyed by plugin id
func (a *App) removePluginData(id string) *model.AppError {
    if err := a.Srv().Store().PluginAccessControl().DeleteByPluginID(id); err != nil {
        return err
    }
    return nil // config still holds PluginAccessControl[id] with Enabled=true, UserIds=[]
}

// GOOD: the config entry is removed on the same path, including early returns
func (a *App) removePluginData(id string) *model.AppError {
    a.UpdateConfig(func(cfg *model.Config) {
        delete(cfg.PluginSettings.PluginAccessControl, id)
    })
    return a.Srv().Store().PluginAccessControl().DeleteByPluginID(id)
}
```

**Detection**: for every removal/uninstall/disable path in the diff, list the settings keys the feature writes (grep the feature's identifier against `server/public/model/config.go` and the map keys it indexes). Confirm each one is deleted on that path — including on every early return, since removal paths commonly bail out before the cleanup when storage is already empty. Then ask what a fresh install reads: if the leftover entry changes behavior from the documented default, it is a finding.

Flag as `cfg:ORPHANED_ENTRY`.

**Reference**: PR #37571 `server/channels/app/plugin_install.go:546-548` — "Clear the ACL config entry before the early return." Removal only deletes DB rows, not `PluginSettings.PluginAccessControl[id]`; reinstall retains enabled filtering with an empty allow-list.

### 9. New Behavior Not Gated Behind Its Flag (High — validated by MM PR review)

A feature flag is only a kill switch if *every* observable effect of the feature sits behind it. In practice the handler and the UI get gated and the rest does not: the migration still creates the table, the connection pool still opens, the fetch still fires before the gate is consulted, or a permission change ships unconditionally. Operators who leave the flag off still pay for the feature, and rolling back the flag no longer rolls back the behavior.

```go
// WRONG: pool opened during startup regardless of the flag
func (s *Server) initAuditStore() {
    s.auditDB = sql.Open(driver, dsn)                  // runs with Enable=false
    if !*s.Config().AuditSettings.Enable { return }
}

// CORRECT: the gate precedes every effect, including resource acquisition
func (s *Server) initAuditStore() {
    if !*s.Config().AuditSettings.Enable { return }
    s.auditDB = sql.Open(driver, dsn)
}
```

**Detection**: for each flag referenced in the diff, enumerate the feature's effects — DDL/migration files, resource acquisition (DB pools, goroutines, listeners, schedulers), data fetches, permission/role writes, and websocket registrations — and confirm the flag is consulted *before* each. Two specific tells: a migration file added in the same PR as a flagged feature (migrations run unconditionally, so state a deliberate decision or gate the write path instead), and a fetch dispatched in a component that renders the gate lower down. Flag as `cfg:UNGATED_BEHAVIOR`.

**Validated by MM PR review** — PR #37253 `db/migrations/postgres/000205_create_user_post_delivery.up.sql` (table created with the flag off — ACCEPTED, human); PR #36737 (audit DB opened when `Enable=false` — ACCEPTED); PR #35527 (Recaps fetched before the feature gate passes). One sighting was dismissed as intentional (#36922 `file_attachment_list.tsx`, MediaGallery gate removed on purpose) — confirm the removal is not the point of the PR before flagging.

## Corpus checklist (single-sighting patterns)

Seen once or twice across the MM PR corpus. No full rule yet — check them, report only with concrete evidence in the diff.

- [ ] Wrong config tag for the deployment tier — `cloud_restrictable` on a setting Cloud admins must be able to change, so the API filters it out of the response and the System Console control does nothing (T102, PR #37322 `public/model/config.go`)
- [ ] Feature gate also disables the cleanup path — one flag guards writes and the retention/purge job alike, so disabling the feature leaves existing rows unpurged forever (T291, PR #37253 `store/store.go`: "Gating writes is fine; gating deletes is not")
- [ ] Temporary flag without its removal marker — a new feature flag omits the `// FEATURE_FLAG_REMOVAL: ... - Remove this when ...` comment its siblings in the struct carry (T298, PR #37368 `public/model/feature_flags.go`)

## Review Process

### Step 1: Find New Config Fields

```bash
# Find new fields in config.go
grep -n "^\s*\*\(bool\|string\|int\)" server/public/model/config.go
```

For each new field:
1. Confirm it has a default in `SetDefaults()`
2. Confirm it has validation in `IsValid()` (if applicable)
3. Confirm the JSON key is not a renamed existing key

### Step 2: Check for Removed Fields

```bash
# In the diff, look for lines removed from config structs
# Check if removed fields appear in config migration files
grep -rn "RemovedField\|removed_field" server/channels/app/ server/public/model/
```

### Step 3: Verify Environment Variable Pattern

For each new settings struct field named `EnableNewFeature` in `ServiceSettings`:
- Expected env var: `MM_SERVICESETTINGS_ENABLENEWFEATURE`
- Verify this matches the codebase convention by checking a known field

### Step 4: Scan for Stale Feature Flags

```bash
# Find feature flag definitions
grep -rn "FeatureFlag" server/public/model/feature_flags.go

# Find feature flag usage
grep -rn "FeatureFlag\." server/ --include="*.go" | grep -v "_test.go"
```

For flags that default to `true` and have been present for multiple releases, flag as `cfg:STALE_FLAG`.

### Step 5: Check Config Listener Registration

```bash
# Find config change listeners
grep -rn "AddConfigListener\|configStore\.Watch" server/ --include="*.go"
```

Verify that new hot-reloadable fields have a corresponding listener if they need to trigger side effects on change.

## When NOT to Flag

- **Experimental settings explicitly marked as unstable**: fields with `// Experimental:` comments or under `ExperimentalSettings` are intentionally unstable — breaking changes are expected
- **Development-only settings**: settings that only affect developer builds (`IsDev()` gated) or test configurations
- **Feature flags that are newly added**: only flag stale flags, not new ones with a clear purpose
- **Plugin config structs in plugin repos**: only flag plugin config defined in the main mattermost-server repo

## Output Format

> **Canonical format**: `~/.claude/agents/_shared/finding-format.md`

**Domain tags**: `cfg:RESTART_REQUIRED`, `cfg:MISSING_DEFAULT`, `cfg:ENV_NAMING`, `cfg:BREAKING_CHANGE`, `cfg:STALE_FLAG`, `cfg:MISSING_VALIDATION`, `cfg:PLUGIN_CONFLICT`, `cfg:ORPHANED_ENTRY`

**Severity mapping**:
- `cfg:BREAKING_CHANGE` (removed/renamed field without migration) → `MUST_FIX`
- `cfg:MISSING_DEFAULT` (nil pointer, zero-value changes behavior on upgrade) → `MUST_FIX`
- `cfg:MISSING_VALIDATION` (unchecked integer, format, or enum field) → `SHOULD_FIX`
- `cfg:ENV_NAMING`, `cfg:RESTART_REQUIRED`, `cfg:PLUGIN_CONFLICT` → `SHOULD_FIX`
- `cfg:ORPHANED_ENTRY` (removal path leaves a config entry that re-arms on reinstall) → `SHOULD_FIX`
- `cfg:STALE_FLAG` → `SHOULD_FIX`

## Anti-Slop Guidance (Do NOT Flag)

- **Do not flag** missing `IsValid()` entries for `*bool` fields — boolean config fields have only two valid values and do not require bounds or format validation; the agent spec explicitly exempts them.
- **Do not flag** experimental settings under `ExperimentalSettings` or fields tagged `// Experimental:` for missing migration paths or backward-compat issues — these are intentionally unstable and breaking changes are expected.
- **Do not flag** feature flags that were recently added (same PR or within the current release cycle) as stale — only flag flags that have been defaulting to `true` for multiple release cycles with no removal plan.
- **Do not flag** a new config field as missing a hot-reload listener when the field is only read at server startup (e.g., a listen address or TLS certificate path) — startup-only fields are inherently restart-required and do not need a config listener.
- **Do not flag** an env var naming pattern as inconsistent when the config system derives env var names automatically from struct and field names — the convention is enforced by the framework, not by hand-written mappings; only flag when a manually specified override deviates.
- **Do not flag** development-only or test-gated settings (e.g., fields only read when `IsDev()` returns true) for missing validation or migration — these settings are explicitly excluded from the review scope.

## See Also

- `backwards-compatibility-reviewer` — broader API and data model backward compatibility
- `deprecation-reviewer` — patterns for safely deprecating config fields over multiple releases
- `production-reviewer` — runtime safety and operational concerns for new settings
