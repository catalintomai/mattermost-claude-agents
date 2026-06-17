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

## RED FLAGS - Stop and Search
- Adding constants to files with 100+ existing constants
- Creating types that sound like they might exist (DataSource, Protocol, Config)
- Implementing "basic" or "common" functionality (likely exists)
- Adding environment variables or config fields
