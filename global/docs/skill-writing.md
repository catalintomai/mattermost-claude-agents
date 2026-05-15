# Skill Writing Principles

Rules for writing skills that compound rather than rot.

## Anatomy of a skill

```
~/.claude/skills/<name>/
└── SKILL.md         # frontmatter + body + self-rewrite hook
```

Frontmatter fields:
```yaml
---
name: <name>
description: <one-line — what it does and when>
version: YYYY-MM-DD
tags: [<domain>]
---
```

## Destinations and fences — not driving directions

The single most important rule.

**Bad (driving directions — rots when tooling changes):**
> 1. Run `npm test`.
> 2. Grep for "passed".
> 3. Run `git add -A`.
> 4. Run `git commit -m "fix"`.

**Good (destination + fence):**
> Verify tests pass before committing. Stage specific files (never `-A`).
> Write commit messages that explain the *why*, not the *what*.

Driving directions couple the skill to today's exact tooling. A destination survives refactors, model upgrades, and tool renames.

## Include failure examples, not just success

Every skill should include at least one anti-pattern or known failure mode.
If a skill has never been wrong, it hasn't been used enough to generalize.

Example:
```markdown
## Anti-patterns
- Adding `try/except` to silence an error without understanding it.
- Changing five things at once and claiming one of them fixed it.
```

## Self-rewrite hook

Every skill ends with this section. It makes the skill self-improving.

```markdown
## Self-rewrite hook
After every N uses OR on any failure:
1. Re-read recent feedback or episodic notes about this skill.
2. If a new failure mode has appeared, add it to Anti-patterns.
3. If a constraint was violated, tighten the constraint language.
4. Commit: `skill-update: <name>, <one-line reason>`.
```

Calibrate N per skill: 5 for frequently-used skills, 10 for rarely-used ones.

## Size
Keep each skill under 150 lines. If it needs more, split into sub-skills or
move reference material to a separate doc linked from the skill.

## Anti-patterns
- Skills that duplicate each other's triggers — causes ambiguous invocation.
- Procedural step-by-step command sequences — use destination language instead.
- Skills without failure examples — they read like marketing, not engineering.
- Skills without a self-rewrite hook — they're frozen at the moment of writing.
- Vague success criteria ("make it work") — the model can't loop independently on vague.
