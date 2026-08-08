# Search-First Workflow

**RULE**: If you're about to add something that "should probably exist already" → SEARCH FIRST

## Mandatory Pre-Implementation Searches

### 1. Constants/Types
Before adding ANY constant, type, or variable:
```bash
# Search for the concept
grep -r "DataSource\|data.*source" .
# Search for similar naming patterns
grep -r "const.*Source\|Source.*=" .
# Check target file for related constants
```

### 2. Functions/Methods
Before implementing ANY function:
```bash
# Search for similar function names
grep -r "functionPattern" .
# Search for the functionality
grep -r "what it does" .
# Check interfaces and existing implementations
```

### 3. Configuration/Settings
Before adding config fields:
- Search existing config structs and constants
- Check environment variable patterns
- Look for similar feature toggles

### 4. WebSocket events
Before claiming a WS event is missing or proposing a new one, grep the single authoritative registry first:
```bash
grep -n "WebsocketEvent" server/public/model/websocket_message.go
```
Then ask: does any existing event already cover this concern (same target object type, same lifecycle trigger)?

The failure mode is proposing `page_property_updated` when `property_values_updated` already exists and fires on every property value create/update/delete. The names differ but the concern — "a property value changed, clients should refresh" — is identical. A symbol sweep for the exact name `page_property_updated` returns nothing and looks like a gap; a concern-level grep (`property.*update\|update.*property`) finds `property_values_updated` immediately.

The check is two steps, not one:
1. Does an event with this exact name exist? (`grep "page_property_updated"`)
2. Does an event covering this concern exist? (`grep -i "property.*updat\|updat.*property"`)

Only after both return nothing is the event genuinely absent.

## Workflow

```
BEFORE: Adding new code
STEP 1: Search codebase for existing implementation
STEP 2: If found → use existing, extend if needed
STEP 3: If not found → proceed with implementation
NEVER: Skip the search step
```

## Negative Claims Need MORE Verification Than Positive Ones

"X is not used anywhere", "no consumer calls this", "zero references", "the only caller is Y" — these need **more** rigor than a positive finding, not less. A positive hit proves itself: the line is right there. A negative claim depends on two things that are invisible in the output — that the search space was **whole**, and that the query was **name-complete**. Either can silently fail.

**1. Never truncate a listing you are about to quantify over.**

`head`/`tail` are for *sampling* output you are eyeballing. They are wrong the moment the next sentence says "all", "both", "none", "zero", "the only". Print the listing whole, or `wc -l` first and check the count matches the claim.

```bash
# WRONG - the claim quantifies over a deliberately truncated list
ls -d ~/work/*repo* | head
# -> "both checkouts have zero references"

# RIGHT - enumerate fully, or count before claiming
ls -d ~/work/*repo*
ls -d ~/work/*repo* | wc -l
```

**2. Search the concern, not one spelling.**

When an API has a wrapper, alias, or SDK layer, production callers use the *wrapper's* names, not the underlying ones. Grepping a single spelling returns zero while the callers sit in plain sight.

```bash
# WRONG - greps the underlying plugin.API names only
grep -rn "CreateScheme\|PatchRole" --include="*.go" .
# -> 0 hits, because callers go through the SDK wrapper

# RIGHT - grep the concern, which catches every spelling
grep -rn "\.Scheme\.\|\.Role\.\|SchemeService\|RoleService" --include="*.go" .
# -> client.Scheme.Create, client.Role.Patch
```

Same rule as the WebSocket-events case above, applied to absence rather than presence.

**Before reporting absence, confirm both:** the search space was complete (no truncation, right directory, right branch) and the query covered every name the thing goes by. If you cannot confirm both, report "did not find" — not "does not exist".

**Why this exists:** a search for consumers of a new plugin API reported "zero references, the consumer is not yet written". Both halves were wrong. `ls ... | head` had hidden the one repo that mattered (`mattermost-plugin-docs-rbac`), and the grep used the `plugin.API` method names while production code called the `pluginapi` wrappers (`client.Scheme.Create`, `client.Role.Patch`). The consumer existed, was fully written, and its design turned out to be the decisive evidence for two open decisions.

## RED FLAGS - Stop and Search
- Adding constants to files with 100+ existing constants
- Creating types that sound like they might exist (DataSource, Protocol, Config)
- Implementing "basic" or "common" functionality (likely exists)
- Adding environment variables or config fields
