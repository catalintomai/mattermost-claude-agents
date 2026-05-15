---
name: review-modes
description: Documents the default vs thorough review mode convention for agents
---

# Review Modes

Agents may support a `--thorough` mode passed via the orchestrator prompt:

- **Default mode**: Triage-first approach. Focus on MUST_FIX and high-confidence SHOULD_FIX findings. Skip low-confidence or speculative issues. Suitable for fast PR reviews.
- **Thorough mode**: Exhaustive analysis. Check all assertions, verify all claims, report all findings including low-confidence ones. Use for security audits, pre-release reviews, or complex architectural changes.

To request thorough mode, include "Use thorough mode" or `--thorough` in the agent prompt.

## How Agents Should Implement This

```markdown
<!-- In agent system prompt, check for the flag -->
If the prompt contains "--thorough" or "Use thorough mode":
  - Check every item in the checklist, including low-confidence signals
  - Report SHOULD_FIX findings even if speculative
  - Include "NOTE"-tagged informational findings
  - Verify all claims via re-read (not just MUST_FIX)

Default (no flag):
  - Focus on MUST_FIX findings with high confidence
  - Include SHOULD_FIX findings only if evidence is clear
  - Skip speculative or hard-to-verify concerns
```

## Orchestrator Usage

```
# Default mode (fast):
Task(subagent_type="permission-reviewer", prompt="Review auth.go for permission issues.")

# Thorough mode (exhaustive):
Task(subagent_type="permission-reviewer", prompt="Review auth.go for permission issues. --thorough")
```

## Phase Interaction

| Phase | Default | Thorough |
|-------|---------|----------|
| Plan review | Required findings only | All assertions verified, all trade-offs surfaced |
| Code review | MUST_FIX + clear SHOULD_FIX | All tiers including nits |
| Security audit | High-confidence vulns | Full threat surface including speculative vectors |
| CI failure | Root cause only | All contributing factors |

## Current Agents Supporting `--thorough`

The `--thorough` flag is a convention — agents that explicitly check for it in their prompt will apply exhaustive mode. The orchestrator (e.g., `/review-code --swarm --thorough`) passes the flag down to each spawned agent.

Agents that do NOT check for the flag will behave the same regardless — this is acceptable. The flag is additive, never restrictive.
