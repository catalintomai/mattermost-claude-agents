# Validation Layer Consistency Rule

**Problem**: Business rule enforcement scattered across layers (API only, service only, inconsistently) creates bypasses.

**Rule**: All business logic validations must be enforced at the **service layer entry points** (Create, Update, Delete, Import methods), not just in API handlers.

## Why Service Layer?

- **Single source of truth**: Service layer is the actual business logic boundary
- **Closes all bypasses**: Protects against direct service layer calls, imports, migrations, webhooks, internal functions
- **API layer validates input format**, service layer validates business logic
- **Consistency**: All paths to the same operation enforce the same rules

## Validation Flow (Correct Pattern)

```
User Input
   ↓
API Handler (validates format: ID validity, required fields, bounds)
   ↓
Service Layer Entry Point (validates business logic: relationships, state, constraints)
   ↓
Store Layer (executes SQL only)
```

## Red Flags: Validation in Wrong Layer

### Anti-Pattern 1: Validation Only in API Handler

```go
// ❌ VULNERABLE
// api/playbook.go
func createPlaybook(c *Context, w http.ResponseWriter, r *http.Request) {
    ValidateNewChannelOnlyMode(pb.NewChannelOnly, pb.ChannelMode)  // Only here!
    c.App.CreatePlaybook(pb)  // ← Service layer doesn't validate
}

// app/playbook_service.go
func (s *Service) CreatePlaybook(pb Playbook) error {
    return s.Store().Create(pb)  // ← No validation! Vulnerable to direct calls
}

// ← Anyone calling service directly bypasses validation
service.CreatePlaybook(invalidConfig)  // Accepted when it shouldn't be
```

### Anti-Pattern 2: Validation Only in Store Layer

```go
// ❌ VULNERABLE
// store/playbook_store.go
func (s *SqlStore) Create(pb Playbook) error {
    if pb.NewChannelOnly && pb.ChannelMode == LinkExisting {
        return errors.New("invalid")
    }
    return exec(pb)  // ← Validation at wrong layer
}

// app/playbook_service.go
func (s *Service) CreatePlaybook(pb Playbook) error {
    // No validation before store call
    // If store call fails, no audit log or proper error handling
    return s.Store().Create(pb)
}

// Problem: Store layer is too low-level for business logic. Errors aren't logged properly,
// and business logic rules are mixed with SQL concerns.
```

### Anti-Pattern 3: Validation in Multiple Layers (Redundant)

```go
// ⚠️ WASTEFUL (not a security issue, but poor performance)
func createPlaybook(c *Context, ...) {
    ValidateNewChannelOnlyMode(...)  // Check 1
    c.App.CreatePlaybook(pb)
}

func (s *Service) CreatePlaybook(pb Playbook) error {
    ValidateNewChannelOnlyMode(...)  // Check 2 (redundant)
    s.Store().Create(pb)
}
```

## Correct Pattern: Service Layer Validation

```go
// ✅ CORRECT
// app/playbook.go (Validation Functions - Used by Service Layer)
func ValidateNewChannelOnlyMode(newChannelOnly bool, channelMode RunChannelMode) error {
    if newChannelOnly && channelMode == PlaybookRunLinkExistingChannel {
        return errors.New("cannot link existing channel when NewChannelOnly is true")
    }
    return nil
}

// app/playbook_service.go (Service Layer - Enforces All Business Rules)
func (s *Service) Create(pb Playbook, userID string) (string, error) {
    // Setup audit record
    auditRec := s.auditor.MakeAuditRecord("Playbook.Create", model.AuditActionCreate, nil)
    defer s.auditor.LogAuditRec(auditRec)

    // ✅ Validate business logic at entry point
    if err := ValidateNewChannelOnlyMode(pb.NewChannelOnly, pb.ChannelMode); err != nil {
        auditRec.AddErrorDesc(err.Error())
        return "", err
    }

    // Proceed with business logic
    id, err := s.Store().Create(pb)
    if err != nil {
        auditRec.AddErrorDesc(err.Error())
        return "", err
    }

    auditRec.Success()
    auditRec.AddEventResultState(pb)
    return id, nil
}

// api/playbook.go (API Handler - Validates Input Format Only)
func createPlaybook(c *Context, w http.ResponseWriter, r *http.Request) {
    // 1. Validate request format (this is API's job)
    var req model.CreatePlaybookRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        c.SetInvalidParamWithErr("body", err)
        return
    }

    // 2. Call service layer (which validates business logic)
    pb, err := c.App.CreatePlaybook(c.AppContext, &req, userID)
    if err != nil {
        c.Err = err
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(pb)
}
```

## Audit Checklist

For each business rule validation function (typically `Validate*`):

- [ ] Function is defined in the app layer (types.go, playbook.go, etc.)
- [ ] Function is called from **ALL service layer entry points**: Create, Update, Delete, Import
- [ ] Function is called BEFORE any Store operations
- [ ] Validation error is logged to audit record
- [ ] API handlers call the service layer (and don't duplicate validation)

## How Security Agents Should Check

### For security-auditor:

```bash
# Find validation functions
grep -rn "^func Validate" server/app/

# For each validation, find all callers
grep -rn "ValidateName" server/

# Check if called from service layer entry points
grep -rn "func.*Create\|func.*Update\|func.*Import" server/app/ | grep -A5 "ValidateName"
```

### For permission-reviewer:

Apply "Blast Radius Audit" to validation functions, not just permission functions. Same principle: verify all entry points enforce the rule.

### For validation-reviewer:

Add check: "If validation exists in API layer, verify it ALSO exists in service layer entry points."

## Common Patterns to Look For

| Pattern | Risk | Fix |
|---------|------|-----|
| `Validate*` only called from one API handler | Bypass via direct service call | Call from service entry point |
| `Validate*` called before store, not in service method | Audit/error handling missing | Move to service method |
| Different validation in Create vs Update | Inconsistent state possible | Unify in shared function |
| Import calls Create but Create isn't validated | Bulk import bypass | Ensure Create validates |
| Admin function calls service directly | Admin bypass | Same validation applies to all |

## Real-World Example: The NewChannelOnly Vulnerability

**What was found**: `ValidateNewChannelOnlyMode` was called only in the API handler for playbook creation, not in the service layer methods (Create, Update, Import).

**Why it was a vulnerability**:
- Direct service layer calls: `service.Create(invalidConfig)` → Accepted
- Import function: `service.Import()` → calls `service.Create()` → No validation → Invalid config persisted
- Admin function: Could create playbooks with invalid configuration

**How it was fixed**:
1. Added `ValidateNewChannelOnlyMode` call in `Create` method of service layer
2. Added same validation in `Update` method
3. `Import` method automatically protected (since it calls `Create` internally)
4. All paths now enforce the same rule

**Test coverage**:
- Create: Rejects invalid, accepts valid
- Update: Rejects invalid, accepts valid
- Import: Rejects invalid (transitively via Create)
