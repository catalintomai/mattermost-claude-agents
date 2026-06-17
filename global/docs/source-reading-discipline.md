# Source-Reading Discipline

How to handle reference documents when generating architecture docs, design specs, ADRs, plans, or any output that rests on cited sources.

## Why this exists

Failure mode caught on `mattermost-pages-channel` (2026-05-22): an architecture document compared system A (wikis) and system B (Integrated Boards) and reached a wrong conclusion about their structural symmetry. Root cause: system A was read from primary source code, system B was delegated to a research subagent. The subagent's summary contained the resolving facts, but the load-bearing claim was extrapolated past what the summary actually supported. User pushback eventually forced a re-read; the re-read flipped the claim.

The rules below would have caught this earlier.

## Rules

### 0. "Exists" and "implemented" mean master — not POC, not branch

When writing an architecture doc, "exists", "is present", "is implemented", or "is available" must unambiguously specify their context:

- `[exists in master]` — shipped.
- `[implemented in the POC]` — in a branch or staged repo, not production.
- `[proposed]` — not yet in any code.

Never write "Editor: TipTap [existing in webapp]" when TipTap is only in a branch. The design doc describes the **target production state**; the POC is evidence of feasibility, not the shipping artifact.

This rule applies to every claim of the form "X is used", "X is available", "X ships with", "all Y are implemented". If the context is the POC, write "in the POC". If the context is master, verify with `git show master:<file>` before claiming it.

**Never say "the codebase" in a presence/absence tag.** "The codebase" is ambiguous — it reads as either the POC branch or upstream `master`, and these are two separate axes a reader must keep apart. A provenance tail must name a concrete frame: `– not in the POC` (build status: the proposed design has it, the prototype has not built it) or `– not in master` (upstream-platform axis: net-new platform infra). Writing `– not in the codebase` collapses the two. (2026-06-01, `mattermost-pages-channel`: standardized every `[new, proposed – not in the codebase]` tag to `– not in the POC`.)

Failure mode this catches (2026-05-25, `mattermost-pages-channel`): doc claimed "TipTap [existing in webapp]" and "all implemented" for POC-only features, misleading readers about production readiness.

**Corollary — POC state is never a design *justification*.** The tags above report *where* something lives; they never *argue for* a design. In a design doc / ADR, do not justify a choice with "the POC already has X" or "X already exists in the branch": the doc proposes new code on a no-backwards-compatibility branch, so the choice must stand on intrinsic merit (mechanism fit, platform-uniformity, parity, operational cost). The same branch fact kills the "no migration needed" argument — with no existing data to migrate, migration cost is zero for *every* storage shape and so cannot favour one over another; pick the shape on cleanliness alone. (2026-06-01, `mattermost-pages-channel`: a permissions design argued "membership rather than a wiki read-permission, because `read_wiki` already exists in the POC" and "a `Props` key avoids a migration" — both are non-arguments.)

### 1. Read primary sources directly

When the prompt names a reference doc by path or URL (PDF, Confluence page, plan file, code file), open it with the `Read` or `WebFetch` tool yourself. Delegation to a subagent is allowed only when the doc is too large to read directly (a multi-hundred-page PDF, an entire codebase directory).

If you delegate, label the resulting claims as `[via research-agent summary]` in the output so the epistemic distinction is visible.

### 2. Quote-back verification

For every load-bearing architectural claim — "X picked approach Y", "table T has column C", "system A solves problem P with mechanism M" — the output must include at minimum:

- a short verbatim quote from the source, OR
- a `file:line` / `page:N` anchor that lets a reader find it.

Claims with no anchor are unverified by default. Mark them `[TODO: verify]` and follow up before publishing.

### 3. Symmetric reading for symmetric arguments

If the output compares system A and system B, both must be read at the same depth. Asymmetric reading — A from primary source, B from research summary — biases the comparison and is forbidden.

Either read both at the primary-source level, or label both as `[via summary]` and accept that the comparison is provisional.

### 4. Surface contradictions explicitly

If two source-facts appear to conflict, or a source-fact conflicts with the draft synthesis, flag the contradiction inline as an **Open Question** rather than silently picking one interpretation. Examples:

- "Source X says boards are 'channel-bound by design'; same source also says boards use ChannelMemberLinks for cross-channel propagation. These two facts are in tension; we need to resolve which framing is the right one before relying on either." (← this is exactly the contradiction missed in the 2026-05-22 case.)

Do not silently resolve the contradiction by picking the convenient half.

### 5. Re-read source on pushback

When defending an architectural claim against user pushback, the FIRST action is to re-read the source-of-truth, not synthesize harder from existing context. If the re-read contradicts the prior claim, retract and revise. Do not extrapolate to defend a position the source does not support.

This is the rule that specifically catches the failure mode where "the source is in my context window, so I do not need to look at it again." That assumption is wrong if your context-window understanding of the source was already partial.

### 6. Distinguish derived from observed

In the output, mark each non-trivial claim as either:

- `[observed from <source>:<anchor>]` — verbatim or near-verbatim from a primary source.
- `[derived]` or `[inferred]` — a synthesis that uses observed facts as inputs.

Architecture decisions should rest on observed facts. If a decision rests on a derived/inferred chain, name the inference explicitly. A reviewer can then attack the inference rather than mistaking it for an observation.

This rule is the most intrusive — it makes documents noisier. Two ways to apply it:

- **Explicit form** (preferred for high-stakes architecture docs): every load-bearing claim is annotated.
- **Implicit form** (lighter weight): only annotate claims you have low confidence in. Default trust to high-confidence claims.

Pick the form that fits the document's stakes. The 2026-05-22 case was high-stakes (architectural foundation for a multi-quarter feature) — explicit form would have been warranted.

### 7. List sources actually read

At the end of the output, include a "Sources Read" section listing file paths, URLs, and PDF page ranges that were actually consulted in the writing of the doc.

If a source was named in the prompt but not read (because it was large and delegated, or because it turned out to be unavailable, or because it was deemed out of scope), state so explicitly with a brief reason. This makes coverage gaps visible to the reader rather than implicit.

### 8. Verify novelty claims against the base branch

When writing about a feature branch, any claim of the form "introduces a subsystem", "adds new infrastructure", "creates a pipeline", "is a new mechanism for X" must be checked by comparing the branch against its base (typically `master` or `main`). The branch in isolation does not tell you what's new — only the diff does.

The check has three parts:

1. **Enumerate prior art first.** Before writing "the feature introduces X for concern Y", state what already exists in the base branch that addresses concern Y. If you have not searched the base branch for prior art, you do not yet have grounds to claim novelty. The "what existed before" enumeration is a precondition for the "what's new" claim, not an optional appendix.

2. **Distinguish wrappers from net-new.** A new file that calls into existing base-branch code is a hook/wrapper, not a subsystem. If the load-bearing call in your "new" file is `existingSystem.DoThing(...)`, the correct verb is *plugs into* / *reuses* / *hooks into*, not *introduces* / *adds* / *creates*. The fact that the file is new does not make the *mechanism* new.

3. **Anchor with diff evidence.** A novelty claim must cite either (a) `git diff master --stat <files>` showing the additions are genuinely new logic, or (b) the specific master function being wrapped (proving the claim should be reframed). Unanchored novelty claims are marked `[TODO: verify novelty against master]` and treated as suspect until anchored.

Failure mode this catches: writing a doc from inside a feature branch and describing branch-local code as if master did not exist. Documented case (2026-05-24, `mattermost-pages-channel`): a doc claimed "the wiki feature introduces a notification subsystem covering three trigger sources (page edits, page comments, mentions) and two delivery channels (WebSocket, email)". Branch-vs-master investigation showed the wiki feature reuses `SendNotifications()` from `app/notification.go:54` directly — what's actually new is a TipTap mention extractor, an edit-aggregation wrapper, and a wiki-access gate. The doc had to be reframed from "introduces a subsystem" to "plugs into the existing notification pipeline with three feature-specific concerns".

This rule is automatable; the `reuse-detector` agent runs the scan mechanically.

### 9. Concern-level reuse check before proposing any mechanism

Rule 8 catches surface-verb novelty ("introduces a subsystem"). Rule 9 catches the deeper failure: proposing a *mechanism* (a new column, a new prop key, a new table, a new helper) when master already addresses the same *concern* with an existing mechanism. The two failures look different on the page but share a root cause — the author did not search master for "how is this concern handled today."

For every newly-proposed mechanism in an architecture doc / ADR / plan, the discipline has three parts:

1. **"Master today: …" inline anchor before the proposal.** Every novelty proposal must be preceded by a one-line `Master today:` anchor naming the existing master-branch mechanism that addresses the same concern, with a `file:line` proof. Example: a proposal of `Props["snapshot_kind"]` to discriminate page-version snapshots from chat edits requires a `Master today: chat-message edit history is discriminated by Posts.OriginalId + DeleteAt > 0 (no Props key); see server/channels/store/sqlstore/page_store.go:1259-1320` anchor. If the author cannot fill in the `Master today:` line, they have not searched master and the proposal is unsupported. The proposal then needs to either (a) reuse the existing mechanism, or (b) justify why the existing mechanism is insufficient *for this concern*. The justification is what earns the right to propose something new.

2. **Symmetric "Master today" / "Proposed addition" sections per concern.** Every section addressing a discrete concern (snapshot, transaction, mention parsing, permission caching, notification fan-out) gets a "Master today" paragraph BEFORE the "Proposed addition" paragraph. The asymmetry between the two paragraphs is the novelty surface — visible at-a-glance to reviewers, impossible to hide behind synthesis prose. The existing `## MM functionality reused` section at the end of a doc is too late: by the time the reviewer reaches it, the synthesis has already framed the proposal as net-new. The pairing must be inline, per-concern.

3. **Symbol-existence sweep before publishing.** Every named symbol the plan introduces (constant, table, column, permission, prop key, flag, function) must be grepped against master before the doc is published. If the symbol exists, anchor it with `file:line`. If not, mark it `[proposed]`. The sweep is mechanical and catches symbol-level hallucinations (a flag named `EnableWikis` that does not exist; a method named `App.ExecuteInTransaction` that lives at `SqlStore.ExecuteInTransaction` instead). Tooling: `grep -rn "<symbol_name>" server/ webapp/` from the repo root, repeated per symbol.

Failure mode this catches: proposing a new mechanism for a concern master already handles, because the author wrote from design intent rather than from the codebase. Documented case (2026-05-25, `mattermost-pages-channel`): a version-history section proposed `Props["snapshot_kind"] = "page_version"` as the discriminator separating page-version snapshots from chat-message edit history. Master already discriminates the two with `Type='page' AND OriginalId != '' AND DeleteAt > 0` (chat-message edit rows carry the chat post's `Type`, not `'page'`) — the proposed prop key is redundant. The same review surfaced `App.ExecuteInTransaction` as a named method; master has no such method (transactions live at `SqlStore.ExecuteInTransaction`, called through `Store().Wiki().Create(...)`). Both would have been caught by either the "Master today" anchor (9.1) or the symbol-existence sweep (9.3).

This rule is partially automatable: the symbol-existence sweep can be a script. The "Master today" anchor and the per-concern symmetric pairing are drafting discipline; they live in the author's hand, with review agents (`reuse-detector`, `plan-assertion-reviewer`) as the safety net.

### 10. "POC state: implemented" sections must anchor values to initialization code

Rule 9.3 (symbol-existence sweep) verifies that a named constant *exists* in the codebase. It does not verify that the constant is *used in this context*. These are different claims, and the gap is where fabrication hides.

When a section is marked **"POC state: implemented"**, every concrete value it states (field values, constant names used in context, type strings, configuration values) must be anchored to the code that *sets or initializes* those values — not to the file where the constant is defined.

**The distinction:**
- `PropertyFieldObjectTypePage` exists at `server/public/model/property_field.go:56` — a symbol-existence claim.
- `ObjectType` for the pages property group is `PropertyFieldObjectTypePage` — a *usage* claim that requires reading `wiki_migrations.go:52`, the setup function.

A symbol sweep passes both. Only reading the initialization code catches the second.

**Failure mode this catches.** Described `PropertyGroup('pages')` with `ObjectType = 'post', TargetType = 'channel'` in an architecture doc (2026-05-25, `mattermost-pages-channel`). Both `PropertyFieldObjectTypePost` and `PropertyValueTargetTypeChannel` exist as valid constants, so a symbol sweep would not flag them. The correct values — `ObjectType = "page"`, `TargetType = "system"` — are only visible in `wiki_migrations.go:52-53`, the setup function. The doc was written from schema knowledge ("pages are stored as posts") rather than from the initialization code.

**The rule:** For any "POC state: implemented" section, read the setup/migration/initialization function that creates or configures the described entity. Anchor every concrete value with `file:line` pointing to where it is *set*, not where it is *defined*. If you cannot find the initialization code, mark the values `[TODO: verify in setup code]` rather than inferring from schema or general knowledge.

## Anti-patterns

- **"The research subagent summary IS the source."** No — the summary is a derived artifact. Treating it as the source erases the epistemic difference and makes downstream synthesis brittle to contradictions the summary contained but did not flag.
- **"Re-reading is wasteful when I already have context."** No — re-reading is the only way to verify your context matches reality. Especially on pushback, where the reason for pushback is often that reality and your context have diverged.
- **"The doc would be too noisy with all those annotations."** Then the doc is doing too much synthesis on too thin a source base. Either thin the synthesis (less confident claims), or strengthen the source base (read more sources directly).
- **"Comparing systems at asymmetric depth is fine if the user wants a quick answer."** No — asymmetric reading produces asymmetric understanding which biases the comparison invisibly. Be explicit if the comparison is provisional.
- **"The branch is the world."** No — when writing about a feature branch, master is the surrounding context that determines what counts as net-new. A claim of "introduces X" that has not been checked against master is unsupported by definition: branch-local code can only be classified as novel after the base branch has been consulted. The new code being real does not make the *mechanism* new.
- **"Unlike [other MM feature], which [behavior] — everyone knows that."** No — comparative claims about other MM features used as justification ("unlike a Boards card, which typically has no external permalink") are factual assertions that require the same anchoring as any other claim. "Everyone knows" and "typically" are red flags: they signal the claim has not been verified against source code. The fix: grep the other feature's codebase for the asserted behavior before writing the comparison. If the search confirms it, add a `file:line` anchor. If the search returns nothing, either drop the comparison or mark it `[unverified]`. (2026-05-25, `mattermost-pages-channel`: "unlike a Boards card (which typically has no external permalink)" — verified correct only after grep; the word "typically" was hedging against an unverified claim.)
- **"I searched for the exact name and found nothing, so it doesn't exist."** No — a symbol sweep for the exact proposed name is only step one. Step two is a concern-level grep: if you're proposing `page_property_updated`, also grep `property.*updat\|updat.*property`. `property_values_updated` exists at `server/public/model/websocket_message.go:142` and covers the same concern. The names differ; the concern is identical. One search misses it; two searches catch it. Apply this two-step check to any proposed mechanism: exact-name sweep first, concern-keyword sweep second. (2026-05-25, `mattermost-pages-channel`.)
- **"The constant exists, so the value must be right."** No — a symbol sweep confirms existence, not correct usage. `PropertyFieldObjectTypePost` exists and is valid; that does not mean it is used for the pages group. For "POC state: implemented" sections, read the initialization code where the value is *set*, not the model file where it is *defined*.
- **"The mechanism is new because the concern is wiki-specific."** No — a wiki-specific concern (page version snapshots, page mentions, page draft autosave) can still be addressed by a master-branch mechanism (the `Posts.OriginalId` edit-history chain, the `MentionParser` interface, the `Drafts` table). The concern being wiki-specific does not entitle the proposal to a new mechanism. The proposal earns that entitlement only by demonstrating the existing mechanism is insufficient for the concern — which requires naming the existing mechanism first.

## When to apply

Apply when:
- Generating an architecture document, design spec, ADR, or plan.
- Writing a comparison between two systems or two approaches.
- Defending a design choice against pushback in any conversation.
- Producing any output where a future reader will treat your claims as authoritative.

Skip when:
- A short ad-hoc question where exhaustive sourcing would be overkill (e.g. "what does the `Wikis` table look like" — just read the migration file, do not assemble a discipline framework around it).
- A throwaway draft that will be reviewed before any decision rests on it.

The discipline is a load-bearing process for high-stakes outputs, not a tax on every output.
