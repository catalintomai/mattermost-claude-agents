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
| `confluence-alignment-reviewer` | [BOTH] | Compare wiki features against Confluence patterns | sonnet | slow | none | yes |
| `pages-isolation-reviewer` | [CODE] | Ensure pages don't affect posts and vice versa | sonnet | medium | none | yes |
| `pages-e2e-test-reviewer` | [CODE] | Enforce test_helpers.ts usage | haiku | fast | `playwright-test-reviewer` | yes |
| `tiptap-reviewer` | [CODE] | TipTap extensions, Suggestion plugin patterns | sonnet | medium | none | yes |

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
| Design | `design-flaw-reviewer`, `architecture-assertion-auditor`, `doc-consistency-reviewer` | Plan scope |

### Domain-Specific Result Extensions

Appended after canonical finding format (`~/.claude/agents/_shared/finding-format.md`):
- `pages-isolation-reviewer`: Isolation checklist table (PASS/FAIL per area)
- `confluence-alignment-reviewer`: Comparison format (Confluence Behavior / MM Current / Alignment Status)
- `confluence-migration-expert`: Migration format (Issue Type / Impact / Test)
