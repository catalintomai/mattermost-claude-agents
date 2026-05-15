# Karpathy Coding Guidelines — Examples

Real-world code examples demonstrating disciplined LLM coding. Based on [Andrej Karpathy's observations](https://github.com/forrestchang/andrej-karpathy-skills).

---

## 1. Think Before Coding

### Hidden Assumptions

**User Request:** "Add a feature to export user data"

**❌ Wrong — silent assumptions:**

```python
def export_users(format='json'):
    """Export all users to a file."""
    users = User.query.all()
    
    if format == 'json':
        with open('users.json', 'w') as f:
            json.dump([u.to_dict() for u in users], f)
    elif format == 'csv':
        with open('users.csv', 'w') as f:
            writer = csv.DictWriter(f, fieldnames=['id', 'email', 'name'])
            writer.writeheader()
            writer.writerows([u.to_dict() for u in users])
    
    return f"Exported {len(users)} users"
```

Problems: Assumed ALL users (privacy?), assumed file location, assumed which fields, assumed CSV fieldnames.

**✅ Right — surface assumptions:**

```
Before implementing, I need to clarify:

1. **Scope**: Export all users or filtered subset? (privacy implications)
2. **Format**: Download file? Background job? API endpoint?
3. **Fields**: Which user fields? (some might be sensitive)
4. **Volume**: How many users typically? (affects approach)

Simplest approach: Add an API endpoint that returns paginated JSON.
What's your preference?
```

### Multiple Interpretations

**User Request:** "Make the search faster"

**❌ Wrong — pick silently:**

```python
# Adds caching, database indexes, and async processing
# without asking which "faster" matters
@lru_cache(maxsize=1000)
async def search(query: str) -> List[Result]:
    # ... 200 lines of optimization code
```

**✅ Right — present options:**

```
"Make the search faster" could mean:

1. **Faster response time** — Add indexes, cache frequent queries
2. **Handle more concurrent searches** — Add async, connection pooling
3. **Faster perceived speed** — Show partial results, progressive loading

Current search takes ~500ms. Which aspect matters most?
```

---

## 2. Simplicity First

### Over-abstraction

**User Request:** "Add a function to calculate discount"

**❌ Wrong — strategy pattern for a single calculation:**

```python
class DiscountStrategy(ABC):
    @abstractmethod
    def calculate(self, amount: float) -> float: ...

class PercentageDiscount(DiscountStrategy): ...
class FixedDiscount(DiscountStrategy): ...

@dataclass
class DiscountConfig:
    strategy: DiscountStrategy
    min_purchase: float = 0.0
    max_discount: float = float('inf')

class DiscountCalculator:
    def __init__(self, config: DiscountConfig): ...
    def apply_discount(self, amount: float) -> float: ...
# 40+ lines for a single calculation
```

**✅ Right — one function:**

```python
def calculate_discount(amount: float, percent: float) -> float:
    """Calculate discount amount. percent should be 0-100."""
    return amount * (percent / 100)
```

Add complexity only when you actually need multiple discount types.

### Speculative Features

**User Request:** "Save user preferences to database"

**❌ Wrong — caching, validation, notifications nobody asked for:**

```python
class PreferenceManager:
    def __init__(self, db, cache=None, validator=None):
        self.db = db
        self.cache = cache or InMemoryCache()
        self.validator = validator or DefaultValidator()
    
    def save(self, user_id, prefs, merge=True, validate=True, notify=False):
        # 40 lines handling optional merging, validation, notifications
```

**✅ Right — just what was asked:**

```python
def save_preferences(db, user_id: int, preferences: dict):
    db.execute(
        "UPDATE users SET preferences = ? WHERE id = ?",
        (json.dumps(preferences), user_id)
    )
```

---

## 3. Surgical Changes

### Drive-by Refactoring

**User Request:** "Fix the bug where empty emails crash the validator"

**❌ Wrong — fixes bug + adds docstring + improves email validation + adds username validation:**

```diff
  def validate_user(user_data):
-     # Check email format
-     if not user_data.get('email'):
+     """Validate user data."""
+     email = user_data.get('email', '').strip()
+     if not email:
          raise ValueError("Email required")
-     if '@' not in user_data['email']:
+     if '@' not in email or '.' not in email.split('@')[1]:
          raise ValueError("Invalid email")
-     if not user_data.get('username'):
+     username = user_data.get('username', '').strip()
+     if not username:
          raise ValueError("Username required")
+     if len(username) < 3:
+         raise ValueError("Username too short")
```

**✅ Right — only the bug fix:**

```diff
  def validate_user(user_data):
      # Check email format
-     if not user_data.get('email'):
+     email = user_data.get('email', '')
+     if not email or not email.strip():
          raise ValueError("Email required")
-     if '@' not in user_data['email']:
+     if '@' not in email:
          raise ValueError("Invalid email")
```

### Style Drift

**User Request:** "Add logging to the upload function"

**❌ Wrong — changes quotes, adds type hints, adds docstring, reformats whitespace:**

```diff
- def upload_file(file_path, destination):
+ def upload_file(file_path: str, destination: str) -> bool:
+     """Upload file to destination with logging."""
```

**✅ Right — add logging, match existing style (single quotes, no type hints):**

```diff
+ import logging
+ logger = logging.getLogger(__name__)
+
  def upload_file(file_path, destination):
+     logger.info(f'Starting upload: {file_path}')
      try:
```

---

## 4. Goal-Driven Execution

### Vague vs. Verifiable

**User Request:** "Fix the authentication system"

**❌ Wrong — vague plan:**

```
I'll fix the authentication system by:
1. Reviewing the code
2. Identifying issues
3. Making improvements
```

**✅ Right — verifiable goals:**

```
If the issue is "users stay logged in after password change":

1. Write test: Change password → verify old session invalidated
   Verify: Test fails (reproduces bug)
2. Implement: Invalidate sessions on password change
   Verify: Test passes
3. Check edge cases: Multiple active sessions
   Verify: Additional tests pass
4. Verify no regression: Existing auth tests still pass
```

### Multi-Step with Verification

**User Request:** "Add rate limiting to the API"

**✅ Incremental with verification:**

```
1. Add basic in-memory rate limiting (single endpoint)
   Verify: Test 100 requests → first 10 succeed, rest get 429

2. Extract to middleware (apply to all endpoints)
   Verify: Rate limits apply to /users and /posts, existing tests pass

3. Add Redis backend (for multi-server)
   Verify: Rate limit persists across app restarts

Each step is independently verifiable and deployable.
```

### Test-First Verification

**User Request:** "The sorting breaks when there are duplicate scores"

**❌ Wrong — fix without reproducing:**

```python
def sort_scores(scores):
    return sorted(scores, key=lambda x: (-x['score'], x['name']))
```

**✅ Right — reproduce first, then fix:**

```python
# 1. Write a test that reproduces the issue
def test_sort_with_duplicate_scores():
    scores = [
        {'name': 'Alice', 'score': 100},
        {'name': 'Bob', 'score': 100},
        {'name': 'Charlie', 'score': 90},
    ]
    result = sort_scores(scores)
    assert result[0]['score'] == 100
    assert result[1]['score'] == 100
    assert result[2]['score'] == 90

# Verify: Run test → fails with inconsistent ordering

# 2. Now fix with stable sort
def sort_scores(scores):
    return sorted(scores, key=lambda x: (-x['score'], x['name']))

# Verify: Test passes consistently
```

---

## Anti-Patterns Summary

| Principle | Anti-Pattern | Fix |
|-----------|-------------|-----|
| Think Before Coding | Silently assumes format, fields, scope | List assumptions explicitly, ask |
| Simplicity First | Strategy pattern for single calculation | One function until complexity is needed |
| Surgical Changes | Reformats quotes, adds type hints while fixing bug | Only change lines that fix the reported issue |
| Goal-Driven | "I'll review and improve the code" | "Write test for bug X → make it pass → verify no regressions" |

## Key Insight

The overcomplicated examples aren't obviously wrong — they follow design patterns and best practices. The problem is **timing**: they add complexity before it's needed. Good code solves today's problem simply, not tomorrow's problem prematurely.
