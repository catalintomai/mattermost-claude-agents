# Elevated-Identity Escalation Patterns

Two related patterns where a low-privilege user gains the effective permissions of a service account or bot. Referenced by `permission-reviewer` and `security-auditor`.

---

## Pattern 1: Elevated-Identity Execution as Indirect Privilege Escalation

When a service, bot, or plugin executes a sensitive operation under its own elevated identity, any user who can trigger that code path gains the elevated permission for that operation — even if they don't hold it directly.

**The attack shape**:
1. User has permission P1 (lower) to trigger action A (e.g., "finish a run", "close a ticket")
2. Action A internally calls privileged operation O (e.g., `Channel.Delete`) under the service's elevated identity
3. O would require permission P2 (higher) if the user called it directly
4. Net effect: a P1 user performs a P2-gated operation without P2 authorization

**Two valid designs — require one to be explicit in the code**:

| Design | When appropriate | Required signal in code |
|--------|-----------------|------------------------|
| **Policy enforcement** | Admin pre-configured the behavior; bot is the admin's delegate | An admin-set policy flag (e.g., `AutoArchiveChannel=true`) gates the elevated call |
| **User action requires equivalent permission** | User is directly requesting the sensitive operation | Explicit `HasPermissionTo*(userID, resource, P2)` check before the elevated call |

If neither is explicit, flag as `SHOULD_FIX` for design acknowledgment. If the user can arbitrarily redirect the target resource (see Pattern 2), escalate to `MUST_FIX`.

**Detection workflow** — for every elevated-identity call in the diff:
```bash
# Find elevated-identity API calls (adapt to your stack)
grep -rn "pluginAPI\.Channel\.Delete\|pluginAPI\.Channel\.Update\|pluginAPI\.Channel\.Create" server/ --include="*.go"
grep -rn "adminClient\.\|botClient\.\|RunAsSystemAdmin\|WithSystemAdmin" server/ --include="*.go"
# For each hit:
#   1. Trace back to user-triggered entry points
#   2. What is the minimum permission required to reach this call?
#   3. What direct permission would the equivalent operation require?
#   4. If (2) < (3) AND no admin policy flag → flag
```

**Code example**:
```go
// ACCEPTABLE: admin-configured policy flag gates the elevated call
func (s *Service) FinishRun(userID, runID string) {
    if !s.permissions.RunManageProperties(userID, runID) { return }  // P1
    run := s.store.GetRun(runID)
    if run.AutoArchiveChannel {  // admin pre-configured → bot is admin's delegate
        s.pluginAPI.Channel.Delete(run.ChannelID)  // P2 — acceptable
    }
}

// VULNERABLE: no policy flag; any ticket manager can archive arbitrary channels
func (s *Service) CloseTicket(userID, ticketID string) {
    if !s.permissions.ManageTicket(userID, ticketID) { return }  // P1
    ticket := s.store.GetTicket(ticketID)
    s.pluginAPI.Channel.Delete(ticket.ChannelID)  // P2, no admin gate → MUST_FIX
}
```

**Severity**:
- No policy flag + user can redirect target → **MUST_FIX**
- No policy flag + target fixed to user's own resource → **SHOULD_FIX** (design acknowledgment required)
- Policy flag present, well-scoped → **PASS** (add a comment documenting the design intent)

---

## Pattern 2: Ownership Flag / Mutable Identifier Decoupling

A boolean flag encoding creation/ownership provenance is set at one point in time, but the target identifier can be mutated independently without clearing the flag. An attacker sets the flag on a resource they control, swaps the identifier to a victim resource, then triggers the privileged operation that trusts the stale flag.

**Attack chain**:
```
create(entity, resource=A) → OwnershipFlag=true, ResourceID=A
update(entity, ResourceID=B) → OwnershipFlag still true, ResourceID=B  ← invariant broken
trigger(entity)             → checks OwnershipFlag (true) → operates on B ← escalation
```

**Required permission for the direct operation**: e.g., `DeletePublicChannel`.
**Required permission to execute the attack**: e.g., `ManageChannelProperties` (to swap ID) + a lower trigger permission.

**Vulnerable struct shape**:
```go
type Run struct {
    ChannelID           string  // mutable via UpdateRun
    ChannelCreatedByRun bool    // set at creation; should be cleared when ChannelID changes
    AutoArchiveChannel  bool    // gates: if true && ChannelCreatedByRun → bot archives ChannelID
}
// INVARIANT BROKEN: UpdateRun sets ChannelID without clearing ChannelCreatedByRun
// After update, OwnershipFlag=true but ChannelID now points to a victim
```

**Detection**:
```bash
# Find ownership/creation boolean flags paired with mutable ID fields
grep -rn "\bCreatedByRun\b\|\bCreatedByUs\b\|\bOwnedBy\b\|\bWasCreated\b\|\bWasLinked\b" server/ --include="*.go"
# For each flag, find the corresponding ID field on the same struct
# Check: is that ID field written in any update path without clearing the flag?
grep -rn "ChannelID\s*=\|ResourceID\s*=" server/ --include="*.go" | grep -v "_test.go"
```

**Required fix** — in every update path that reassigns the target identifier, atomically clear the ownership flag:
```sql
UPDATE PlaybookRuns SET ChannelID = $1, ChannelCreatedByRun = FALSE WHERE ID = $2
```
Alternative: snapshot the original identifier at flag-set time in a dedicated immutable field (`OriginalChannelID`) and use that — not the mutable current value — as the predicate for privileged operations.

**Severity**: When the ownership flag gates a destructive or irreversible operation (archive, delete, message), this is **MUST_FIX**.

---

## Real-World Example

**Mattermost Playbooks — PR #2254 (2026-05-18, edgarbellot)**

Pattern 1: `FinishPlaybookRun` calls `pluginAPI.Channel.Delete` under bot identity. Any run participant (`RunManageProperties`) can finish the run and archive the channel, even without `DeletePublicChannel`. Accepted as policy enforcement because `AutoArchiveChannel` is admin-configured.

Pattern 2: `ChannelCreatedByRun=true` was set at run creation but `ChannelID` was mutable via `UpdateRun` (GraphQL). An attacker could create a run with auto-archive, swap `ChannelID` to a victim channel, then finish the run to archive the victim. Fixed by clearing `ChannelCreatedByRun` whenever `ChannelID` changes via `UpdateRun`.

## Related Documentation

- `~/.claude/agents/_shared/layer-bypass-vulnerability-pattern.md` — service-layer entry-point bypass
- `~/.claude/agents/security/security-auditor.md` — §2 Authentication & Authorization
- `~/.claude/agents/mattermost/review/permission-reviewer.md` — §7–8 Red Flags
