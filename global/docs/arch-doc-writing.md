# Architecture Document Writing Rules

Rules for producing clean, publishable architecture docs — not internal working notes.

## "Exists" means master, not POC

When a doc says a feature "exists", "is present", or "is implemented", that claim must specify its context precisely:

- **"exists in master"** — the code is merged and ships.
- **"implemented in the POC"** — the code exists in a branch or staged repo, not in production.
- **"proposed"** — the code does not exist anywhere yet.

Never write "TipTap [existing in webapp]" when TipTap is only in a branch. Write "TipTap [implemented in the POC]". This prevents the doc from overstating shipping status. The same applies to "are all implemented" → "are all implemented in the POC".

The design doc describes the **target production state**, not the POC. The POC is evidence of feasibility, not the shipping artifact.

### Time-relative words have the same ambiguity

The words **"today"**, **"currently"**, **"right now"**, **"at present"**, **"as of now"**, **"presently"**, **"at this time"** carry the exact same defect as a bare "exists" claim: they describe a state without naming which version of the system the state belongs to. A reader cannot tell whether "today" means master, the POC branch, or the design's target state.

**Wrong:**

> "Channel-membership of wiki backing channels is not used as a permission gate today."
> "The store currently has no `GetWikiByID` method."
> "Page-move broadcasts are presently routed through the channel feed."

**Right (master):**

> "In master, channel-membership of wiki backing channels is not used as a permission gate."
> "Master has no `GetWikiByID` store method."

**Right (POC):**

> "In the POC, page-move broadcasts are routed through the channel feed."
> "The POC store has no `GetWikiByID` method yet."

**Right (proposed):**

> "In the proposed design, channel-membership of wiki backing channels is not used as a permission gate."

**The rule:** every time-relative statement must name its version anchor — `in master`, `in the POC`, `in the proposed design`. Strip the bare time-relative word and replace with the explicit anchor. If you cannot say which version you mean, the underlying claim is unsupported — verify against a specific version before asserting.

**At doc-generation time:** scan the draft for `today`, `currently`, `right now`, `at present`, `as of now`, `presently`, `at this time`. For each occurrence, ask: *which version of the system is this true of?* Rewrite with the explicit anchor. If the doc spans multiple versions (master + POC + proposed), every state claim needs its own anchor — do not let the reader infer which version from context.

## No dangling forward references to alternative files

Never write "described in Alternative N" or "see Alternative 2" in a proposed-design doc unless the alternative file exists at the time of writing. There are exactly two valid outcomes — choose one before finishing the sentence:

**Outcome 1 — create the file.** Write the alternative file (`01-alternative-*.md`) immediately. Then the cross-reference is valid.

**Outcome 2 — inline the alternative.** If the alternative is brief (a paragraph or less), fold it into the proposed-design doc under an "Alternatives considered" subsection rather than promising a separate file.

There is no third outcome: "mention the alternative by number, promise a file, and not create it." That produces dangling references that mislead readers and require cleanup later.

**The index rule:** The `00-index.md` must list every alternative file that the proposed-design doc references. If an alternative file is not in the index, it does not exist — fix the proposed-design doc, not the index.

**At doc-generation time, before finishing any section:** scan the draft for the phrases "Alternative N", "described in Alternative", "see Alternative". For each: either open the corresponding `0N-alternative-*.md` file or rewrite the reference as inline text. A section is not complete while it contains a reference to a non-existent file.

Failure mode caught (2026-05-25, `mattermost-pages-channel`): `08-filtering/00-proposed.md:122` said "The `ltree` alternative for large hierarchies (>5,000 pages) is described in Alternative 3; it is not built for MVP." No `01-alternative-ltree.md` or `03-alternative-ltree.md` file was ever created. Same pattern in `09-url/` — index referenced `01-alternative-channel-id.md` before the file existed.

## Cross-references must be working links

"See Storage." is not a cross-reference. Every internal reference must be a Markdown link:
```markdown
See [Storage – Proposed design](../02-storage/00-proposed.md).
```
Before publishing, verify every `[text](path)` resolves to a real file. A broken link in an architecture doc is a navigation dead-end.

## Alternative pages are children of their proposed page

In Confluence, alternative design pages (e.g. "Storage – Alternative: channels-as-wikis") must be child pages of their corresponding proposed design page ("Storage – Proposed design"), not siblings of it under the top-level parent. The hierarchy communicates: "this alternative was evaluated against the proposed design."

## No internal implementation coordinates in the final doc

The final published doc is a design document for engineers and PMs. It describes **what the system does and why** — not how the author verified it, which file it lives in, or what work remains. Strip all of the following before publishing:

**Verification trails**
- `[verified: server/public/model/post.go:62]`
- `[verified: Posts.Type, IX_Posts_Type partial index]`
- Codebase sweep summaries: "Codebase verification: Storage symbols confirmed present in branch: ..."
- Internal audit notes: "the Atlassian recommendation was not re-verified"

**File and line references**
- Migration file names: `000195_create_wiki_links.up.sql`
- Migration sequence numbers used as citations: "(migration 000198)"
- Source file paths used as evidence: "see `server/channels/app/page_core.go:223`"
- Query or function line references: "the CTE at store/sqlstore/page_store.go:412"

**Incomplete work markers**
- `[TODO: verify ...]`
- `[TODO: look up X]`
- `[proposed: not yet defined]` (replace with "proposed" or drop the parenthetical)

**Anchor-file citations and meta-vocabulary explanations**
- Any reference to `plans/architecture/anchors/` paths (these are author-discipline notes, not reader artifacts)
- Sentences starting with `Anchor:`, `Per anchor`, `Per the anchor`, or `Following the convention established in…`
- Paragraphs whose purpose is to explain *why the doc uses a particular word* — e.g. "The word 'X' in this doc refers exclusively to Y because…", "Note: we use 'import' instead of 'migration' because…". The reader does not need the author's reasoning about word choice; they need the doc to use the right words consistently.
- References to internal repo paths (`plans/`, `server/`, `webapp/`) used as **justification** rather than as a code citation. (Code citations are already banned above; this catches the variant where the path is cited as authority for a claim, e.g. "per `plans/architecture/decisions/…`".)

All of these belong in the intermediate working draft only. The rule: if a reader needs codebase access — or access to the author's working notes — to understand what the annotation means, it does not belong in the published doc. If a value cannot be verified before publishing, either verify it or omit the claim entirely. If the underlying fact an anchor enforces is needed in the doc, assert it directly without citing the anchor.

**At publish time, grep the draft:**

```
anchors/
^Anchor:
Per anchor
\[verified:
\[TODO:
\[proposed: not yet defined\]
```

Each match is either deleted outright or rewritten to state the fact directly without the citation. Zero matches before publish.

Failure mode caught (2026-05-28): Confluence page 4596269058 ("Master Feature Table") shipped with an "Anchor: Per plans/architecture/anchors/no-mm-pages-migration-no-backwards-compat.md, MM Pages has no deployed POC…" paragraph — pure author-to-author commentary, leaked into the published doc because the working draft was published without a strip pass.

## Standard section naming

| Non-standard | Standard |
|---|---|
| Space of options | Alternatives considered |
| Design space | Alternatives considered |
| Options | Alternatives considered |

"Alternatives considered" is the standard framing in ADRs and engineering design docs. It signals that the section evaluates options, not just lists them.

## Use standard architectural terms

Do not use opaque terms or terms imported from other systems without definition. Specific violations:

- "WikiACL table overlay" → "per-page access-control list" or "page-level ACL"
- "backing channel" is acceptable within this project because it is defined in the glossary. Any other project-specific term must be defined on first use.
- If you find yourself writing "then through the [ProjectSpecificTable] for any [domain-specific verb]", rewrite as "then checked against the page-level access control list".

## No filler/noise statements

Remove statements that add no information:

- "A senior engineer who values consistency with existing Boards infrastructure would choose this shape." — remove. Design arguments stand or fall on their technical merits, not on invented personas.
- "This approach is elegant/clean/simple." — remove. If the approach is simple, show the line count.
- Rhetorical setup sentences before a bullet list.

## Cite the code, never the comment

Architecture docs cite the **code** or another **design doc** as the source of a fact — never a code comment, godoc string, or migration header note. A human author would not write "the `FooBar` comment confirms 'X'"; if `X` is true, they would state `X` as a fact.

**Wrong:**

> "the `getAddWikiPagePermissionsMigration` comment confirms 'wiki backing channels have no member-based permission resolution, and page perms are team-scoped.'"
> "as the inline comment notes, the cache is invalidated on every write."
> "the docstring for `App.PublishPage` describes the broadcast as fire-and-forget."

**Right:**

> "Wiki backing channels have no member-based permission resolution; page permissions are team-scoped (see `app/page_permissions.go`)."
> "The cache is invalidated on every write."
> "`App.PublishPage` broadcasts fire-and-forget."

**The rule:** if a code comment is the clearest statement of a fact you want to make, **promote the content and drop the attribution.** The comment is your input; it is not the reader's source. The reader's source is the code itself (or another design doc). Citing the commentary exposes the synthesis process and reads as an LLM artifact.

Applies to: `//` line comments, `/* */` block comments, godoc strings, TODO/FIXME notes, migration header comments, SQL comments. All of them. The rule is **"cite the artifact, not its commentary."**

**At doc-generation time:** scan the draft for phrases like "the X comment says", "the comment confirms", "the docstring describes", "the inline comment notes", "the migration header explains". Rewrite each: either delete the citation and state the fact directly, or replace the comment-citation with a file/line code-citation. If neither rewrite is possible because the fact cannot be verified from code alone, the underlying claim is unsupported — flag it, do not paper over it with a comment quote.

## Write clear, not clever

If a sentence requires the reader to reconstruct what it means, rewrite it. Example of a confusing sentence:

> "Reusing RootId for page hierarchy would make every page look like a thread root to all existing code paths, requiring surgical exclusion in dozens of places."

Clearer:

> "MM's existing `Posts.RootId` field marks the root of a chat thread. If page hierarchy reused it, every page would appear to be a thread root. All code that reads `Posts.RootId` to detect threads — notification fan-out, Threads view, permalink generation — would need an explicit `AND Type != 'page'` exclusion added. That is not a two-line fix; it touches every consumer of thread-root semantics across the codebase."

Rule: one idea per sentence. If the reader has to hold two conditionals in their head to parse the sentence, split it.

## New-entity proposals require WHY-NEEDED + WHY-SUPERIOR

Every proposal of a new entity — a table, column, permission, role, flag, configuration field, helper function, mechanism, surface — must include both:

1. **WHY NEEDED.** What concrete failure mode forces the new entity? What does the system fail to do without it? "Confluence has X" / "Notion has Y" is not a sufficient answer; the doc must name the specific access pattern, query, user flow, or scale point that the existing mechanism cannot cover. The failure mode is the load-bearing fact — without it, the proposal looks discretionary.

2. **WHY SUPERIOR.** Name at least one alternative — an existing master-branch mechanism (preferred — see Rule 9 in `source-reading-discipline.md`) or a simpler addition — that was considered, and state why each is rejected. The rejection reason must point to a specific shortcoming (wrong cardinality, missing column, wrong scope, cross-cutting change required, exhausts a namespace, defeats an invariant) — not a generic "doesn't fit" or "is not a clean match." If no alternative was considered, the proposal is unsupported, regardless of how compelling the new entity sounds in isolation.

**The canonical pattern:** the proposal is preceded — in the same section, before the entity is formally defined — by a "Why a new X" or "Why this versus the alternatives" sub-section that enumerates 3-5 existing mechanisms, rejects each with a specific reason, and lands on the new entity as the residual choice. The 06-permissions doc's "Why new tables – what existing MM mechanisms were considered first" sub-section is the reference shape: five existing mechanisms (`Permissions` system, `ChannelMembers`, `AccessControlPolicies`, `Schemes`, the closest precedent of per-resource grants) are each named, the gap explained, and the rejection grounded in a specific structural mismatch.

**Symmetric rule for Non-goals.** Non-goals that REJECT a new entity ("we do NOT propose a wiki-guest role") must also justify the rejection — by naming the existing mechanism that already covers the concern, and showing it is sufficient. The asymmetry would be: proposals must justify themselves, but rejections get a pass. A Non-goal bullet that rejects an alternative without naming the existing mechanism is the inverse violation. Both polarities (propose-new or reject-new) carry the same evidence shape: the propose case is justified by (failure-mode + rejected alternatives); the reject case is justified by (existing-mechanism + sufficiency claim).

**Wrong (proposal without justification):**

> "We propose a new `WikiACL` table for per-wiki permission grants."

The reader cannot tell whether existing tables were considered, what specifically they fail at, or why the new table is the right shape.

**Right (proposal with WHY NEEDED + WHY SUPERIOR):**

> "The per-wiki grant concern ('user X has these permissions on wiki Y, beyond their team role') needs a per-principal table keyed on `WikiId`. Role-layer permissions (`Permissions` + `Schemes`) cannot express it: roles are team- or system-scoped, not per-wiki, and grafting per-wiki ids onto permission strings is not supported by the role evaluator. `ChannelMembers` rows on the wiki's backing channel cannot express it either: channel membership is binary (no permission-set column), and widening it cross-cuts every channel feature. The closest existing shape is the per-resource grant pattern (`(resource_id, principal, permissions)`) which has no master-branch table; `WikiACL` is the residual choice."

**Wrong (Non-goal without justification):**

> "A separate 'wiki guest' role distinct from MM's existing guest-user surface. We reuse MM guests for the external-sharing case."

Names the choice but does not explain why the existing `system_guest` role + per-channel `ChannelMember.SchemeGuest` flag is sufficient.

**Right (Non-goal with WHY-SUFFICIENT):**

> "A separate 'wiki-guest' role distinct from MM's existing guest-user surface. The existing `system_guest` role plus the per-channel `ChannelMember.SchemeGuest` flag already cover the external-vendor access pattern (internal users via SSO, external vendors via email/password); adding a wiki-scoped guest role would duplicate the surface without expressing any constraint the existing guest model cannot."

**At doc-generation time:** for each `[new]`-marked entity in the proposed design, search the surrounding section for the corresponding "WHY NEEDED" sentence (failure-mode language: "cannot express…", "would require widening…", "exhausts the namespace…") and the "WHY SUPERIOR" sub-section (alternatives enumerated + rejection reasons). For each Non-goal that rejects an entity, search for the existing-mechanism citation that justifies the rejection. If either is missing, the proposal — or the rejection — is incomplete; either add the justification or drop the assertion.

## Performance numbers require a stated source

Every latency figure, throughput number, row-count threshold, or time estimate in an architecture doc must be accompanied by its source. Bare numbers are not acceptable.

**The rule:** for every performance number, answer one of:
- **Measured**: "benchmark run on the branch, query X against Y rows, p95 = Z ms" — cite the benchmark tool or PR
- **Derived**: "PostgreSQL B-tree index lookup is O(log n); at 10,000 rows and 8 KB pages that is ~3 levels = 3 I/Os at ~1 ms each → ~3 ms" — show the arithmetic
- **Adopted from a known reference**: "PostgreSQL documentation states single-row lookup via primary key is typically sub-millisecond on modern hardware" — cite the source
- **Engineering estimate, unverified**: mark explicitly as `[engineering estimate, not benchmarked]` so readers know the number is a guess pending measurement

**What is not acceptable:**
- "Expected latency at 1,000 pages: 10–30 ms. At 10,000 pages: 100–500 ms." — no source, no derivation, numbers appear authoritative but are fabricated
- "The CTE runs in bounded time" without stating what that bound is and how it was established
- Round numbers with no derivation (100 ms, 500 ms, 5,000 pages) stated as thresholds without explaining why that specific value was chosen

**Why this matters.** Unjustified performance numbers become load-bearing design decisions. The 5,000-page CTE threshold drives the search-replaces-tree fallback design. If the number is wrong by 10×, the fallback triggers too early or too late. A reader cannot challenge a threshold they cannot verify.

**At doc-generation time:** before writing any number that implies performance (latency, throughput, row counts at which behavior changes), stop and ask: "where does this number come from?" If the answer is "I estimated it", write `[engineering estimate, not benchmarked]`. If the answer is "I derived it", write the derivation inline. If the answer is "I don't know", remove the number and replace with the question it depends on.

## Limit statements require WHY + HOW + impact

When the doc imposes a limit (size cap, count cap, rate limit), three things must follow:

1. **WHY**: what failure mode does the limit prevent? (e.g. "prevents a single page from consuming all available memory in the TipTap parser on large edits")
2. **HOW it is enforced**: where in the stack the check occurs (API handler, App layer, store query), and what the client receives when the limit is hit (HTTP 413, AppError code, etc.)
3. **System impact**: what the limit means for adjacent systems (search indexing, export, WebSocket payload size, etc.)

Without all three, a limit is an unexplained constraint that future engineers will remove or work around.

## Mention default behaviors explicitly

If the system creates a default artifact at initialization time (e.g. an untitled page draft when a wiki is created), state it explicitly. Default behaviors are invisible until a user encounters them; the design doc is the right place to make them visible.

## Separate sections for cross-cutting concerns

Cross-cutting mechanisms — optimistic locking, rate limiting, distributed tracing — deserve their own named sections, not inline mentions buried in a single feature's description. If optimistic locking applies to page updates, it gets a `### Optimistic locking` section in the versioning or concurrency part of the doc, not a one-liner in the update-page flow.

## Deployment considerations: one canonical section, per-section exceptions only

The "Deployment considerations" block (feature flag, configuration, CLI, upgrade behavior) must appear **once** in the architecture doc — in the top-level summary or a dedicated cross-cutting section. Every per-section copy that says "Feature flag: EnableWikis gates this. Configuration: no new fields. CLI: no changes. Upgrade behavior: additive." is pure noise that will drift out of sync.

**The rule:**

- The canonical section documents the default for the whole product: `EnableWikis` gates everything, no new config fields unless noted, no CLI changes unless noted, all migrations are additive.
- A per-section "Deployment considerations" subsection is only warranted when that section **deviates from the default** — a new config field, a new CLI command, a non-additive upgrade step, a sub-feature flag (`EnableWikiAI`).
- If a section has nothing to add beyond the default, omit the subsection entirely. Do not write a subsection that only restates the default.

**At doc-generation time:** before writing a per-section "Deployment considerations" block, ask: "Does this section add a config field, CLI command, or upgrade step that isn't covered by the top-level block?" If no: omit. If yes: write only the delta.

## "POC state" sections state coverage, not design

A "POC state: implemented" subsection answers one question only: **which parts of the design described above exist in the POC branch today, and which do not?** It does not re-describe the design.

The design is stated once, in the section prose above the POC state block. If a reader needs to understand what `PostTypePageComment` is, they read the design section. The POC state block should never restate it.

**Wrong (duplication):**

> **POC state: implemented.** Top-level page comments (`PostTypePageComment`) and inline comments (anchored via `PagePropsInlineAnchor`) are present. Resolve/unresolve lifecycle is implemented. The page-comment WS events (`page_comment_created`, …) are defined.
>
> What is present today:
> `PostTypePageComment = "page_comment"`: comment posts stored as Posts rows in the wiki's backing channel.

The last sentence repeats what the design section already says.

**Right (coverage delta only):**

> **POC state: implemented.** Top-level comments, inline anchors, resolve/unresolve lifecycle, and page-comment WS events are all present in the POC. Comment reply rendering in the RHS panel is not built in the POC.

The rule: if a sentence in the POC state block could be cut without losing any implementation-status information — because it restates a design fact rather than a coverage fact — cut it.

## "Not built" means "not built in the POC"

"proposed but not built", "not yet implemented", "not in the codebase" — all of these need the qualifier "in the POC". The design doc describes the target production state; "not built" without qualification implies the feature is simply absent from all reality, when the correct meaning is "absent from the POC, targeted for production implementation."

Correct: "Orphan auto-resolve is proposed but not built in the POC."
Wrong: "Orphan auto-resolve is proposed but not built."

Same rule applies to: "not yet defined", "not yet implemented", "does not exist", "is not present".

## Content checklist for the Editor section

Every Editor section must cover:

1. **Rich text editor**: which library (TipTap), version, POC state
2. **Optimistic locking**: how concurrent edits are detected and rejected — this is a cross-cutting concern that deserves its own subsection (not a one-liner in the update flow)
3. **Breadcrumbs**: how the hierarchy path above the current page is rendered and kept in sync with page moves; this is a visible UX surface that editors encounter on every page view and must be documented

If any of these three are absent from the Editor section, the section is incomplete.

## Punctuation in dense technical sentences

Two patterns that make sentences hard to parse:

**1. Run-on specification sentences.** Sentences like "quantify from mmetl import logs before ship this threshold drives the CTE-vs-ltree decision" need commas at every clause boundary:
> "Quantify from mmetl import logs before ship; this threshold drives the CTE-vs-ltree decision."
Or split into two sentences.

**2. Dense noun-phrase chains.** Sentences like "row-level caching via the shared buffer pool absorbs repeated reads of the same UserPageAccess row" are hard to parse because the subject is buried. Add commas and rewrite:
> "Row-level caching, via the shared buffer pool, absorbs repeated reads of the same `UserPageAccess` row."
Or restructure: "The shared buffer pool caches `UserPageAccess` rows, absorbing repeated reads."

Rule: if a sentence has more than two prepositional phrases or modifiers before reaching its verb, restructure it.

## Migrations: describe fully

A migration entry in the architecture doc must include:

- What schema change it makes (table created, column added, index added)
- Why the change is needed (what feature/concern it enables)
- FK-free convention note if applicable (with reason)

Do not include the migration file name or sequence number — those are internal implementation coordinates (see "No internal implementation coordinates in the final doc").

Sparse entries like "PageParentId index" are insufficient. Minimum:

> Adds a B-tree index on `Posts(PageParentId)` filtered to non-empty values. Required for O(log n) child-page lookups when rendering the page hierarchy panel; without it, hierarchy queries degrade to a full `Posts` scan on large wikis.
