---
name: db-reference
description: Generic relational database reference material for database review agents
---

# Database Reference

Generic PostgreSQL/relational database patterns, anti-patterns, and analysis reference. Used by `database-architecture-reviewer` and other DB-aware agents.

## Anti-Patterns

| Anti-Pattern | Severity | Detection | Impact |
|---|---|---|---|
| **Entity-Attribute-Value (EAV)** | CRITICAL | Tables with (entity_id, attribute_name, attribute_value) | Query complexity explosion, no type safety, no constraints |
| **God Table** | HIGH | Single table with 50+ columns | Insert/update contention, index bloat, poor cache efficiency |
| **Polymorphic Association** | HIGH | Foreign key to "any table" via type column | No referential integrity, complex queries |
| **Multi-Value Column** | CRITICAL | Comma-separated values in single column | 1NF violation, can't index, can't join |
| **Metadata Tribbles** | MEDIUM | Created_by, updated_by, etc. repeated everywhere | Schema bloat, inconsistent handling |
| **Adjacency List Anti-Pattern** | MEDIUM | Self-referential parent_id without closure table | Recursive queries for tree traversal |

## Normalization Violations

| Form | Violation | Example | Fix |
|---|---|---|---|
| **1NF** | Multi-valued attribute | `tags = "a,b,c"` | Create junction table |
| **1NF** | Repeating groups | `phone1, phone2, phone3` | Create child table |
| **2NF** | Partial dependency | Non-key depends on part of composite key | Split into separate tables |
| **3NF** | Transitive dependency | Non-key depends on another non-key | Extract to lookup table |
| **BCNF** | Determinant not a key | Functional dependency from non-candidate | Decompose carefully |

## Over-Normalization Signs

| Sign | Problem | When to Denormalize |
|---|---|---|
| 5+ JOINs for common queries | Performance cliff | Frequently accessed together |
| Lookup tables with 1 column | Over-engineering | Inline if rarely changes |
| 1:1 relationships everywhere | Artificial separation | Merge if always accessed together |
| Computed values requiring aggregation | Repeated expensive work | Materialize with triggers/views |

## Index Strategy

### Missing Index Detection

| Scenario | Required Index | Why |
|---|---|---|
| Foreign key column | `idx_table_fk_column` | JOIN performance, FK constraint checks |
| WHERE equality filter | `idx_table_column` | Query selectivity |
| WHERE range filter | Include in composite, position last | Range scans |
| ORDER BY clause | `idx_table_sort_col` | Avoid filesort |
| Covering query | Include all SELECT columns | Index-only scan |

### Index Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| **Redundant indices** | `idx(a)` + `idx(a,b)` | Remove `idx(a)`, composite covers it |
| **Wrong column order** | `idx(low_selectivity, high_selectivity)` | High selectivity first for equality |
| **Over-indexing** | Index on every column | Increases write latency, storage |
| **Unused indices** | Created but never used | Check `pg_stat_user_indexes` |
| **Missing partial index** | Full index when only subset queried | Add `WHERE` clause to index |
| **Expression without index** | `WHERE LOWER(email)` | Create expression index |

### Composite Index Rules

1. Equality columns FIRST (in any order among themselves)
2. Range/inequality columns LAST
3. ORDER BY columns after equality, same direction
4. Include columns for covering (PostgreSQL `INCLUDE` clause)

## Query Performance

### EXPLAIN Plan Red Flags

| Red Flag | In EXPLAIN | Fix |
|---|---|---|
| **Seq Scan on large table** | `Seq Scan` with rows > 10K | Add index |
| **Nested Loop on large sets** | `Nested Loop` with large outer | Use Hash/Merge Join, add index |
| **Sort in memory** | `Sort Method: external merge` | Increase work_mem or add index |
| **Hash table spillover** | `Batches: > 1` | Increase work_mem |
| **Filter removes most rows** | `Rows Removed by Filter: high` | Better index or partial index |
| **Index not used** | Seq Scan despite index existing | Analyze stats, check selectivity |

### N+1 Query Pattern

1 query to fetch parent records → N queries to fetch related data for each parent. Signs: loop with query inside, ORM lazy loading, missing JOIN or batch fetch.

### Join Type Selection

| Join Type | When Optimal | PostgreSQL Preference |
|---|---|---|
| **Nested Loop** | Small outer, indexed inner | Default for small tables |
| **Hash Join** | Large tables, no useful index | Equality joins |
| **Merge Join** | Pre-sorted or indexed data | Range joins, sorted output |

## Scalability

### Partitioning Readiness

| Signal | Threshold | Strategy |
|---|---|---|
| Table > 100M rows | Consider partitioning | Time-based or range |
| Table > 1B rows | Partition required | Evaluate sharding |
| Time-series data | Any size with retention | Partition by time |
| Multi-tenant data | Large variance in tenant size | Partition by tenant_id |
| Hot/cold data mix | Significant cold data | Archive partitions |

### Partition Strategies

| Strategy | Best For | Implementation |
|---|---|---|
| **Range** | Time-series, sequential IDs | `PARTITION BY RANGE (created_at)` |
| **List** | Status, region, tenant | `PARTITION BY LIST (tenant_id)` |
| **Hash** | Even distribution needed | `PARTITION BY HASH (id)` |

### Growth Projection Questions

1. Expected row growth rate?
2. Which tables grow fastest?
3. Query pattern at 10x scale?
4. Pre-computed aggregation tables needed?
5. Hot vs cold data ratio?

## Go Query Builder Pitfalls (squirrel)

Squirrel is a common Go SQL query builder. When configured with `sq.Dollar` placeholder format (required for PostgreSQL), every `?` inside `sq.Expr(...)` is treated as a positional placeholder and rewritten to `$1`, `$2`, etc. This breaks PostgreSQL jsonb existence operators because they use `?` as part of their syntax:

| Operator | Meaning | Problem |
|----------|---------|---------|
| `?`  | key exists in jsonb | `sq.Expr("col ? $1", key)` → `col $1 $2` — invalid |
| `?|` | any key exists | `sq.Expr("col ??| ARRAY[?]", k)` → `col $1$2| ARRAY[$3]` — invalid |
| `?&` | all keys exist | same issue |

**Fix**: replace jsonb existence checks with `EXISTS + jsonb_array_elements_text + ANY(ARRAY[...])`:

```go
// WRONG — squirrel rewrites '?' in '?|', producing invalid SQL like '$1$2|'
sq.Expr("PropertyOptionsIDs ??| ARRAY["+sq.Placeholders(n)+"]", args...)

// CORRECT — no '?' operator, squirrel handles ARRAY placeholders normally
sq.Expr(
    "EXISTS (SELECT 1 FROM jsonb_array_elements_text(PropertyOptionsIDs) AS _opt WHERE _opt = ANY(ARRAY["+sq.Placeholders(n)+"]))",
    args...,
)
```

### UNION Queries — Never Use sq.Expr with Builder Arguments

**Never** pass squirrel builders as arguments to `sq.Expr("(?) UNION (?)", builder1, builder2)`. Each builder calls `ToSql()` independently, producing its own `$1, $2...` sequence. The combined SQL has conflicting placeholder indices — PostgreSQL rejects it with `pq: got N parameters but the statement requires M`.

```go
// WRONG — each builder generates independent $1, $2... sequences
channelQuery := s.getQueryBuilder().Select(...).Where(sq.Eq{"cm.UserId": userId, "w.TeamId": teamId, "w.DeleteAt": 0})
teamQuery    := s.getQueryBuilder().Select(...).Where(sq.Eq{"w.Visibility": vis, "w.TeamId": teamId, "w.DeleteAt": 0})
unionExpr, args, _ := sq.Expr("(?) UNION (?)", channelQuery, teamQuery).ToSql()
// channelQuery → $1,$2,$3 and teamQuery also → $1,$2,$3 → PostgreSQL sees $1-$3 max but receives 6 args

// CORRECT option 1 — EXISTS subqueries in a single builder (all ? renumbered together)
query := s.getQueryBuilder().
    Select("w.Id", ...).From("Wikis w").
    Where(sq.Eq{"w.TeamId": teamId, "w.DeleteAt": 0}).
    Where(sq.Or{
        sq.Expr("EXISTS (SELECT 1 FROM ChannelMembers cm WHERE cm.ChannelId = w.ChannelId AND cm.UserId = ?)", userId),
        sq.And{sq.Eq{"w.Visibility": vis}, sq.Expr("EXISTS (SELECT 1 FROM TeamMembers tm WHERE tm.TeamId = w.TeamId AND tm.UserId = ?)", userId)},
    })

// CORRECT option 2 — raw SQL with a manually flat params slice
sql := `(SELECT ... FROM Wikis w JOIN ChannelMembers cm ON ... WHERE cm.UserId = $1 AND w.TeamId = $2 AND w.DeleteAt = $3)
UNION
(SELECT ... FROM Wikis w JOIN TeamMembers tm ON ... WHERE w.Visibility = $4 AND w.TeamId = $2 AND w.DeleteAt = $3)`
params := []any{userId, teamId, 0, model.WikiVisibilityTeam}
```

**Detection**: `sq.Expr(` with `UNION` in the format string, or a squirrel builder passed as an argument to `sq.Expr`.

Other squirrel limitations requiring raw SQL (add a comment explaining why):
- `RETURNING` clause (for atomic increment-and-read)
- CTEs (`WITH ... AS (...)`)
- `jsonb_array_elements` / `jsonb_array_elements_text` in FROM clause
