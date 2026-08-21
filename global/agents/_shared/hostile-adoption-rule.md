---
name: hostile-adoption-rule
description: Adoption/get-or-create paths must treat found state as hostile input — payload equality is not identity. Checklist for reviewers of migrations, imports, and recovery paths.
---

# Hostile Adoption Rule

**Scope**: any code path that, instead of creating fresh state, **adopts** state it finds already present — get-or-create, adopt-on-conflict (lost insert race), import upsert, boot-migration recovery, cache warm from existing rows, restore-from-archive, sync adoption from a remote peer.

## The failure mode

Adoption code is written imagining one benign producer of the found state: *"a row under this name is my own earlier work, or a racing peer running the same code."* The validation then checks only what that story needs — usually **payload equality** (same permissions, same contents, same shape). But the found row may come from a hostile or merely different producer: direct SQL, an older version, a name squat, an unrelated feature. A row can match the payload perfectly and still be the wrong row to adopt.

**Payload equality is not identity.** Identity is payload + ownership + management + liveness + uniqueness.

## Checklist — for every adopted entity

1. **Ownership**: does the row belong to the adopter? (`SchemeId` points back at the adopting scheme; the record's FK matches; the creator field is this subsystem.) A referenced row owned by someone else means the adoption writes authority into a foreign object.
2. **Management flags**: do mutability/management markers match what the creator would have written? (`SchemeManaged`, `BuiltIn`, read-only markers.) A row with the wrong flags passes payload checks and then misbehaves in every guard that keys on the flag.
3. **Liveness**: is the row live? Reads frequently carry **no `DeleteAt` filter** — verify before assuming. Adopting a soft-deleted row marks the migration complete while leaving nothing usable behind, with no repair path once the completion key is written.
4. **Uniqueness / aliasing**: do N references resolve to N distinct rows? Two references converging on one row (scheme's user-role and admin-role fields naming the same role) merge writes that were designed to be disjoint.
5. **Existing references**: is the found row already assigned/referenced elsewhere? Seeding new authority into a row that is already attached outside the adopter's domain widens every existing assignment, below the runtime guards.
6. **Version/shape drift**: could the row come from a newer or older release? (Unknown permissions, extra fields.) Decide explicitly: preserve, strip, or refuse — silence here becomes data loss or authority leak on downgrade.

## Severity guidance

A missing check from 1, 2, or 5 on an authority-bearing entity (role, scheme, ACL, token) is MUST_FIX: the adoption path typically runs **store-direct, below the runtime guards**, so it is the one writer the guards cannot catch. Missing 3 or 4 is SHOULD_FIX unless the entity is authority-bearing.

## Reference case (MM-69269)

`validateAdoptableSpaceRole` and `validateAdoptedSpaceSchemeRoles` originally checked **only permission-set equality**. Escapes: a scheme row could reference a standalone role already assigned outside spaces (ownership, #1/#5) — store-direct seeding then pumped page/admin permissions into it; a `SchemeManaged=true` collision row was adopted and then refused by member assignment (#2); a deleted row was adoptable because role reads have no `DeleteAt` filter (#3); duplicate generated-role references merged the admin grant set into the user role (#4). All four passed payload-equality validation.

## Non-permissions instances of the same shape

- **Import upsert**: bulk import finds an existing team/channel/user by name and updates it — is it the *same* team, or a name squat that now inherits members and history?
- **Shared channels sync**: adopting a remote's row by shared ID — is the local row actually the synced twin, or a local original the sync will now overwrite?
- **Cache warm / reseed**: rebuilding a cache from rows that a partial migration half-transformed — shape matches, semantics don't.
- **Plugin KV / config adoption**: on activation, adopting an existing KV entry written by an older plugin version with different invariants.

## How reviewers apply this

For each adoption path in the diff, list the six checks and mark each **enforced / not-needed-with-reason / MISSING**. "The payloads are compared" answers only check 0. If the adopter cannot articulate why ownership, flags, liveness, uniqueness, and references are safe to skip, the missing ones are findings.
