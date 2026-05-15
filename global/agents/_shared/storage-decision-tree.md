---
name: storage-decision-tree
description: Shared decision tree for storage placement. Referenced by schema-necessity-reviewer and database-architecture-auditor.
---

# Storage Decision Tree

Shared reference for deciding WHERE to store data. Used by `schema-necessity-reviewer` (is a migration necessary at all?) and `database-architecture-auditor` (if a column, is the schema correct?).

---

## Level 0: Do You Need Storage At All?

```
Can the value be computed from existing data at query time?
├── YES → No storage needed. Use computed properties or derived views.
└── NO  → Proceed to Level 1.
```

---

## Level 1: Choose Storage Tier

**Hierarchy of preference** (most preferred first, least migration cost):

```
1. No storage change      — compute from existing data
2. Existing flexible storage — property system, JSON blobs, Props fields, metadata tables
3. Extend existing JSON column — add a field to an existing JSON blob (zero migration cost)
4. New column on existing table — only when SQL WHERE/JOIN/ORDER BY is needed
5. New table              — only when the data has its own lifecycle, relationships, and query patterns
```

---

## Level 2: Column vs Props/JSON Decision Tree

```
Is the field queried in WHERE / JOIN / ORDER BY on a large table (10k+ rows)?
├── YES → Dedicated column (index-friendly, type-safe)
│         → Proceed to Level 3 (when is a column justified?)
└── NO  → Is the field's schema stable and well-defined?
    ├── YES → Dedicated column (if few fields, ≤3) or JSONB with CHECK constraint (if many fields)
    └── NO  → Is the field user/plugin-defined or highly variable?
        ├── YES → JSONB / Props column (flexible, schema-free)
        │         ⚠ Add GIN index if queried via @> or ?
        └── NO  → Dedicated column (prefer explicitness for core/intrinsic data)
```

**Key principle**: Columns queried by SQL belong in columns. Opaque metadata belongs in Props/JSONB. Never store queryable data only in JSON; never create dozens of columns for sparse, variable metadata.

---

## Level 3: When Is a New Column Justified?

Use a new column when ALL of the following apply:

| Signal | Example |
|--------|---------|
| Data appears in SQL WHERE clauses on large tables | Filter runs by `status` — 100k+ rows |
| Data needs database-level constraints | `NOT NULL`, `CHECK`, `UNIQUE` |
| Data is used in JOINs | FK relationships |
| Data needs atomic updates | Counters, sequences, compare-and-swap |
| Data needs indexing for query performance | Composite indexes, partial indexes |
| Data has a clear 1:1 intrinsic relationship with the row | Not metadata — core property of the entity |

Use **existing flexible storage** instead when:

| Signal | Use Instead |
|--------|------------|
| Data is per-entity metadata | Property system (PropertyGroup/Field/Value) |
| Data is rarely queried by SQL | JSON blob or user preferences |
| Data is user-configurable | Property system |
| Data fits key-value pattern | Props field, PluginKV, Preferences |
| Data is nested/structured | JSON field in existing blob |
| Row count is small (<10k) | In-memory filtering from JSON is acceptable |
| Data has no referential integrity needs | No FK constraints needed |

---

## Level 4: When Is a New Table Justified?

Use a new table when ALL of the following apply:

| Signal | Example |
|--------|---------|
| Data has its own lifecycle (CRUD independent of parent) | Status definitions deleted independently of runs |
| Data has 1:N or N:M relationships | Members, tags, comments |
| Data needs its own indexes and query patterns | Independent list/filter/sort |
| Data volume justifies separation | Millions of rows |
| Data has different access patterns than parent | Frequently read but rarely written |

---

## Level 5: When Is the Property System the Right Choice?

Use the PropertySystem (PropertyGroup/PropertyField/PropertyValue) when:

- The data is per-entity metadata (e.g., custom fields on a Run or Channel)
- The schema varies per team or per workspace
- The data is user-configurable (admin can add/remove fields)
- The feature already uses PropertySystem for similar data on the same entity

**Check first**: Does a PropertySystem already exist for this entity type?

```
Grep: PropertyField, PropertyValue, PropertyService, PropertyGroup
Grep: property_field, property_value, property_group
```

---

## Migration Cost Checklist

Before committing to a migration, verify:

- [ ] Can existing Props/JSON blob hold this data?
- [ ] Is there already a property/metadata system for this entity type?
- [ ] Does this data actually need a SQL WHERE clause on a large table?
- [ ] Is the migration system simple or painful (requires downtime, coordination)?
- [ ] What happens to this column/table if the feature is removed? (Migrations are permanent.)
- [ ] Is this data intrinsic to the entity or metadata about it?

---

## Decision Summary Table

| Scenario | Recommended Storage |
|----------|-------------------|
| Rarely queried metadata (<10k rows) | JSON blob / Props field |
| User-configurable custom fields | Property system |
| Core entity field, always queried | Dedicated column |
| Filtered in SQL WHERE on large table | Dedicated column + index |
| Nested structured config | JSON field in existing blob |
| Independent entity with own lifecycle | New table |
| Key-value per user/team | Preferences / PluginKV |
| Sparse, variable metadata | JSONB Props column |

---

## See Also

- `schema-necessity-reviewer` — challenges whether a migration is necessary at all
- `database-architecture-auditor` — validates correctness of schema IF a migration is justified
- `property-system-expert` — deep expertise on PropertyGroup/Field/Value stores
