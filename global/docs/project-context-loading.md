# Project Context Loading

Shared convention for loading project-specific agents and reference docs. All skills MUST follow this before doing their main work.

## Three-Level Agent Discovery

Agents are discovered from three levels, **merged by name** into a single set (later level overrides earlier on collision). All three levels are ALWAYS scanned — never skip a level because an earlier level "already covered" a topic.

```
Level 1 (lowest priority):  ~/.claude/agents/              (global/user)
Level 2 (parent project):   Walk up from CWD → first parent with .claude/agents/
Level 3 (highest priority): ./.claude/agents/               (current project)
```

### Algorithm

```
agents = {}

for level in [global, parent_project, current_project]:
    dir = resolve_agent_dir(level)
    if not exists(dir): continue

    # Read registry if present (catalog + routing groups for this level)
    if exists(dir/AGENT_REGISTRY.md):
        for agent in parse_agent_table(dir/AGENT_REGISTRY.md):
            agents[agent.name] = agent  # later level overrides

    # Recursively scan agent files (*.md), excluding registry, archive, and shared dirs.
    # MUST be recursive — agents are organized into subdirectories
    # (e.g., ~/.claude/agents/{core,review,security,tech,testing}/*.md, or
    # ~/mattermost/.claude/agents/mattermost/{core,features,review,...}/*.md).
    # A non-recursive `dir/*.md` glob would silently miss every nested agent.
    for file in glob(dir/**/*.md, exclude=[_archived/**, _shared/**, AGENT_REGISTRY.md]):
        agent = parse_agent_file(file)
        agents[agent.name] = agent  # later level overrides

# Filter by skill phase
return [a for a in agents.values() if a.tag in required_tags]
```

### Coverage guarantee for `--full` / `--thorough` modes

When a skill is invoked in `--full` or `--thorough` mode (e.g. `/review-code --full`), it MUST consume the **entire merged agent set from all three levels** — not just the agents named in any single registry's "Parallel Groups" table. Other modes (default, `--quick`, `--security`) may still filter to a subset, but `--full` explicitly fans out to everything that survived the phase-tag filter.

### Parent Project Detection

Walk up from CWD looking for `.claude/agents/` directory:

```
cwd = /Users/me/mattermost/mattermost-pages-channel
  → check /Users/me/mattermost/mattermost-pages-channel/.claude/agents/  (Level 3 — current)
  → check /Users/me/mattermost/.claude/agents/                           (Level 2 — parent!)
  → stop at first hit above current project
```

**Rules:**
- Level 2 is the FIRST `.claude/agents/` found above CWD that is NOT the current project's
- If CWD is already a top-level project (no parent), Level 2 is empty
- Never walk above home directory

## Agent Phase Tags

Phase tags (`[PLAN]`, `[CODE]`, `[BOTH]`) are defined in `~/.claude/agents/AGENT_REGISTRY.md` § "Phase Tags".

**Routing rule**: Skills filter agents by phase — plan skills load `[PLAN]`/`[BOTH]`, code skills load `[CODE]`/`[BOTH]`. See the registry for the canonical definitions and routing rule.

## Reference Doc Loading

All skills should load relevant reference docs before their main work. Relevance is determined by which files/layers the skill will touch.

| Layer detected | Load docs relevant to |
|----------------|----------------------|
| `.ts`, `.tsx` files | React, frontend, performance |
| `.go` files | API, backend, store |
| `.sql`, migration files | Database, migrations |
| Any / unknown | All docs without layer restriction |

```
for level in [global, parent_project, current_project]:
    registry = level/AGENT_REGISTRY.md
    if exists(registry) and has_table("Reference Docs"):
        ref_docs = parse_ref_docs_table(registry)
        for doc in ref_docs:
            if doc.relevant_to(files_being_touched):
                Read(doc.location)
```

## How to Add Project Context

Project maintainers add entries to `.claude/agents/AGENT_REGISTRY.md`:

**Agents** — "Project Agents" table:
```markdown
| `my-reviewer` | [CODE] | Reviews X for Y | opus | medium | none | yes |
```

**Docs** — "Reference Docs" table:
```markdown
| `my-guide` | Description of what it covers | `.claude/docs/my-guide.md` |
```

**Loose agent files** — any `*.md` file in `.claude/agents/` (outside `_archived/`, `_shared/`) is auto-discovered.

Skills automatically discover and load them at all three levels — no skill modifications needed.

## Project Test Infrastructure Detection

For `/create-test` and `/fix-test`, detect the project's test runner:

```
1. Check project CLAUDE.md for test commands (make test, npm test, etc.)
2. Check for test runner scripts (.claude/scripts/run_*_tests.sh, scripts/test.sh)
3. Check for standard config files (jest.config.*, pytest.ini, go.mod, etc.)
4. Check Makefile / package.json for test targets
5. Fall back to language-standard runners (go test, npx jest, npx playwright)
```

The detected test infrastructure is passed to test skills as context — they adapt their behavior accordingly.
