---
name: agent-registry-pages
description: Registry of wiki/pages project-specific agents
---

<!-- Swarm metadata for each agent:
  model: opus|sonnet|haiku — cost/speed tradeoff
  prerequisites: agents that must run first
  speed: fast (<30s) | medium (30-90s) | slow (>90s)
  parallel-safe: can run alongside other agents without conflicts
-->

# Agent Registry - Wiki/Pages Project

**Project-specific agents only.** For general agents, see `~/.claude/agents/AGENT_REGISTRY.md`.

Phase tags (`[PLAN]`, `[CODE]`, `[BOTH]`) defined in `~/.claude/agents/AGENT_REGISTRY.md` § "Phase Tags".

---

## Project Agents

| Agent | Phase | Purpose | Model | Speed | Prerequisites | Parallel-safe |
|-------|-------|---------|-------|-------|---------------|---------------|
| `boards-alignment-reviewer` | [BOTH] | Validate alignment with Integrated Boards architecture | sonnet | slow | none | yes |
| `confluence-alignment-reviewer` | [BOTH] | Compare wiki features against Confluence patterns (CODE-level: Go/TS files vs Confluence patterns) | sonnet | slow | none | yes |
| `confluence-parity-doc-validator` | [PLAN] | Validate Confluence-parity claims in plans/docs against the canonical Confluence Feature Inventory (DOC-level) | sonnet | medium | `plans/confluence-clone-strategy/confluence-feature-inventory.md` exists | yes |
| `pages-isolation-reviewer` | [CODE] | Ensure pages don't affect posts and vice versa | sonnet | medium | none | yes |
| `pages-e2e-test-reviewer` | [CODE] | Enforce test_helpers.ts usage | haiku | fast | `playwright-test-reviewer` | yes |
| `tiptap-reviewer` | [CODE] | TipTap extensions, Suggestion plugin patterns | sonnet | medium | none | yes |
| `voice-reviewer` | [BOTH] | Catch AI-slop tells in drafted markdown docs against a style fingerprint | sonnet | medium | none | yes |
| `mm-doc-voice-reviewer` | [BOTH] | MM-specific terminology + prose-pattern layer on top of voice-reviewer; canonical-term aliases, jargon whitelist, MM anti-patterns | sonnet | medium | `voice-reviewer` (recommended) | yes |
| `poc-status-verifier` | [PLAN] | Verify every implementation-status claim against the codebase, both directions — the parity POC-state column, `[existing in the POC]` / `[new, proposed]` tags, POC-state callouts, and mermaid diagram node labels; multi-scope + sibling-repo grep. MUST_FIX on a mismatch. | sonnet | slow | none | yes |
| `scenario-validator` | [PLAN] | Validate worked scenarios / end-to-end walkthroughs in arch docs before publish: parse each numbered scenario into steps, classify every step BUILT / PROPOSED / EXTERNAL-CONFLUENCE, route to code-grep / design-consistency / Confluence-inventory, and run cross-scenario contradiction checks (subject & state carry-over, resolution order, outcome-without-mechanism, undefined-mechanism reference). | sonnet | slow | none | yes |
| `doc-duplication-reviewer` | [PLAN] | Find prose REDUNDANCY in a multi-page arch-doc run — the same mechanism / list / steelman re-derived in full across pages or across a page's own subsections, where one canonical home + a pointer would do. Separates intentional duplication (Summary-decision recaps, parity roll-up, POC-state callouts, template headers) from excess via a deletion test; MUST_FIX only when copies have diverged. Distinct from `doc-consistency-reviewer` (which owns contradictions/drift and passes identical repeated passages). | sonnet | slow | none | yes |
| `doc-concision-reviewer` | [PLAN] | Find prose BLOAT in a SINGLE, unique passage — a claim stated in far more words than it carries (padded wording, hedge stacks, throat-clearing preamble, re-explaining what a senior MM engineer knows); gives the concrete cut + word delta via a reduction test. The verbosity complement to `doc-opacity-reviewer`. SHOULD_FIX-capped (never blocks a publish). Distinct from `doc-duplication-reviewer` (needs the same claim in 2+ places — this flags one over-long statement) and `slop-detector` (which ADDS anchors/words — this CUTS, never dropping a load-bearing anchor). READ-ONLY. | sonnet | slow | none | yes |
| `summary-sync-reviewer` | [PLAN] | Check a per-area wiki/pages SUMMARY still reflects its DETAIL after the detail changed (or `build-wiki-arch-pages.py`'s summary-freshness gate flags it): runs BOTH a contradiction lens AND an omission lens (a summary can contradict nothing yet omit a whole component the detail added, e.g. `page_folder`, page-ownership, `/links`); flags cross-cutting ripple to sibling summaries; READ-ONLY. | sonnet | slow | `summaries/` + `page-registry.json` exist | yes |
| `deferred-parity-auditor` | [PLAN] | Audit parity DEFERRALS (V1/V2/post-MVP/accepted-gap/substitute) for under-use: could an existing MASTER platform mechanism deliver the deferred Confluence behavior in the MVP with bounded glue? The mirror of `reuse-detector` (which catches over-build); concern-greps `server/`+`webapp/`, master-verified; returns OVERSTATED_GAP (MUST_FIX) / REUSABLE_IN_MVP (SHOULD_FIX) / JUSTIFIED. READ-ONLY. | sonnet | slow | none | yes |
| `presentation-slide-builder` | [PLAN] | Generate slide-style Confluence presentation pages from the wiki/pages arch summaries: one "How Confluence does it" and one "Mattermost approach" section per topic, terse bullets, design-only, grounded in summaries (never invented). NOT a prose-doc author, NOT the publisher (main session handles page-create + build + publish). | sonnet | medium | arch summaries exist | yes |
| `presentation-speaker-notes` | [PLAN] | Generate/refresh spoken SPEAKER NOTES for the wiki/pages deck — ~60s flowing narration per slide into one file (`presentation/speaker-notes.md`: main deck 00–16 + a backup section for alternatives), for a mixed eng + product/leadership audience. Reads each slide + its arch summary, grounds every claim, flags off-slide specifics `[confirm: …]`. The prose-narration counterpart to `presentation-slide-builder` (which writes the terse on-screen bullets). | sonnet | medium | slides + summaries exist | yes |
| `presentation-slide-reviewer` | [PLAN] | READ-ONLY review of wiki/pages presentation slides for SENTENCE-LEVEL terseness — prose where slide notation says it shorter: a definitional copula / "analogue of" that should be `=`, an enumeration or connective "and" that should be a comma/dash, an un-telegraphic article, a multi-sentence bullet, filler nouns/intensifiers, a placement-metaphor verb (rides/sits in), a tautological `=`. Quotes the line + gives the terse rewrite. SHOULD_FIX-capped (never blocks a publish). The review counterpart to `presentation-slide-builder` (does NOT generate/write). Distinct from `mm-doc-voice-reviewer` (voice gates) and `doc-concision-reviewer` (arch-doc prose bloat where depth is PREFERRED — slides want the opposite). | sonnet | medium | slides exist | yes |

## General Agents

See `~/.claude/agents/AGENT_REGISTRY.md` for all general-purpose agents.

### Reference Skills (not agents)

| Skill | Recommending agents | When to recommend |
|-------|-------------------|-------------------|
| `/create-code --tdd` | any agent noting test gaps | Missing coverage, tests after code, implementation-coupled tests |

### Reference Docs (not agents)

| Doc | Purpose | Used by |
|-----|---------|---------|
| `wiki-api-reference` | Wiki API endpoint reference and request/response formats | `pages-isolation-reviewer` |
| `boards-alignment-reference` | Boards spec quotes, schema details, 11 dimension descriptions | `boards-alignment-reviewer` |
| `confluence-pattern-reference` | Confluence permission model, feature comparison, known deviations | `confluence-alignment-reviewer` |
| `confluence-migration-reference` | Confluence export format, JSONL structure, pipeline details | `confluence-migration-expert` (L2 — mattermost suite) |
| `pages-isolation-reference` | Isolation architecture, filter patterns, common bug examples | `pages-isolation-reviewer` |
| `tiptap-reference` | Full TipTap review checklist, extension patterns | `tiptap-reviewer` |
| `pages-e2e-helpers-reference` | E2E helper catalog, timeout constants, anti-patterns | `pages-e2e-test-reviewer` |

All docs located in `.claude/docs/`.

---

## Parallel Groups

Base groups defined in `~/.claude/agents/AGENT_REGISTRY.md` § "Parallel Groups for Code Review". This project adds agents to existing groups and defines new groups:

**Additions to global groups:**

| Global Group | Additional Agents |
|---|---|
| Frontend | `tiptap-reviewer`, `boards-alignment-reviewer` (when boards-related code changed) |
| Testing | `pages-e2e-test-reviewer` (runs after `playwright-test-reviewer`) |

**Project routing groups** (may reference global agents for routing):

| Group | Agents | When |
|---|---|---|
| Wiki/Pages | `pages-isolation-reviewer` (specialist — wins over generalist), `confluence-alignment-reviewer`, `confluence-migration-expert` (L2 — mattermost suite) | Go or TS wiki files changed |
| Boards Alignment | `boards-alignment-reviewer` | When reviewing wiki/pages features for boards integration readiness |
| Confluence Parity (doc) | `confluence-parity-doc-validator` | Plans/docs that make Confluence-parity claims changed (MW matrix, PRD, Master Feature Table, architecture parity summary) |
| Summary sync (doc) | `summary-sync-reviewer` | A wiki/pages detail page changed, or `build-wiki-arch-pages.py` summary-freshness gate flags an area summary as stale vs its detail |
| Design | `design-flaw-reviewer`, `architecture-assertion-auditor`, `doc-consistency-reviewer` | Plan scope |

### Domain-Specific Result Extensions

Appended after canonical finding format (`~/.claude/agents/_shared/finding-format.md`):
- `pages-isolation-reviewer`: Isolation checklist table (PASS/FAIL per area)
- `confluence-alignment-reviewer`: Comparison format (Confluence Behavior / MM Current / Alignment Status)
- `confluence-migration-expert`: Migration format (Issue Type / Impact / Test)
