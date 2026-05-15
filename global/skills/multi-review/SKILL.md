---
name: multi-review
description: Multi-LLM review for code AND architecture decisions. Auto-detects mode. Composable Independent Work component for other skills.
version: 2.0.0
tags:
  - code-review
  - multi-llm
  - quality
---

# Multi-LLM Review

Get consensus from multiple LLMs on code quality OR architectural decisions.

**Composable role**: Other skills (`/review-plan`, `/review-code`, `/create-plan`, `/create-code`, `/create-test`, `/fix-test`) invoke multi-review as an **Independent Work component** in swarm mode. The multi-LLM output feeds into Cross-Validation alongside domain agent findings — see `~/.claude/docs/swarm-harness.md` for the pattern.

## Usage

```
/multi-review <file-path>                    # Code review (auto-detected)
/multi-review <question or decision>         # Architecture review (auto-detected)
/multi-review --arch <decision to evaluate>  # Force architecture mode
/multi-review --code <file-path>             # Force code review mode
```

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Convergence |
|------|------------------|------------------|-------------|
| Default | Parallel subagents, no shared state (all LLMs) | SKIPPED | Single-pass |

Multi-review is a **single-mode skill** — it always runs all models in parallel and synthesizes. No `--swarm` flag. When called as a component by other skills in swarm mode, it runs as a single agent within the team (see [Composable Usage](#composable-usage-called-by-other-skills)).

## Auto-Detection

| Input | Mode |
|-------|------|
| File path (`.go`, `.ts`, `.tsx`, etc.) | Code review |
| Question ("Should we...", "What's the best...") | Architecture |
| Plan or design doc | Architecture |
| `--arch` flag | Architecture (forced) |
| `--code` flag | Code review (forced) |

## Models

See `~/.claude/docs/multi-llm-review.md` for model selection, quota limits, and fallback logic.

## Workflow

### Step 1: Detect Mode & Gather Context

**Code Review Mode:**
- Read the target file(s)
- Identify the language and framework
- Note surrounding context if needed

**Architecture Mode:**
- Frame the decision clearly
- Identify options and trade-offs
- Read relevant code for context

### Step 2: Run Reviews in Parallel

Launch **all models from `~/.claude/docs/multi-llm-review.md`** simultaneously (single message, multiple tool calls). This includes Codex, Gemini, AND seq-server — do NOT skip any.

### Step 3: Synthesize Consensus

Analyze all responses and identify:
1. **Consensus** - What 2+ models agree on (high confidence)
2. **Unique findings** - Single-model insights (verify manually)
3. **Disagreements** - Where models differ (investigate)

## Composable Usage (Called by Other Skills)

When invoked as an Independent Work component by another skill, output goes to the swarm's shared findings directory:

**Output location**: `/tmp/swarm-{team}/phase1/multi-llm.md`

**Output format** (standard finding format for cross-validation):
```markdown
# Findings: multi-llm

## MUST_FIX
- **{id}**: {description} | `{file}:{line}` | Found by: {model1}, {model2}

## SHOULD_FIX
- **{id}**: {description} | `{file}:{line}` | Found by: {model}

## PASS
- {check description}
```

**Skills that call this as Independent Work**:

| Skill | Context provided | Focus |
|-------|-----------------|-------|
| `/review-plan` | Plan file + requirements | Technical feasibility, design flaws |
| `/review-code` | Changed files + diff | Code quality, bugs, security |
| `/create-plan` | Feature request + research | Approach opinions, trade-offs |
| `/create-code` | Implemented interfaces | Cross-layer contract consistency |
| `/create-test` | Code under test + plan | Coverage gaps, edge cases |
| `/fix-test` | Failing tests + errors | Root cause patterns, common fixes |

## Output Format

### Code Review Output

```markdown
## Multi-LLM Code Review: [filename]

### Consensus Issues (High Confidence)
| Issue | Found By | Severity |
|-------|----------|----------|
| [description] | gpt-5.3-codex, gemini-3-flash-preview | HIGH/MED/LOW |

### Additional Findings
- [Issue] (found by [model]) - [verify/consider]

### Recommendations
1. [Priority fix]
2. [Secondary fix]

### Confidence: HIGH/MEDIUM/LOW
```

### Architecture Review Output

```markdown
## Multi-LLM Architecture Review: [decision]

### Model Recommendations

| Model | Recommendation | Key Reasoning |
|-------|----------------|---------------|
| gpt-5.3-codex | [option] | [rationale] |
| gemini-3-flash-preview | [option] | [rationale] |
| Claude (native) | [option] | [rationale] |

### Consensus Points
- [What all models agree on]

### Disagreements
- [Where models differ and why]

### Final Recommendation
[Synthesized decision with implementation guidance]

### Risks & Mitigations
- Risk: [issue] -> Mitigation: [solution]

### Confidence: HIGH/MEDIUM/LOW
```

## Prompt Templates

### Code Review Prompt
```
Review this [language] code for:
1. Bugs and logic errors
2. Security vulnerabilities
3. Performance issues
4. Code clarity and maintainability
5. Adherence to best practices

<code>
[paste code]
</code>

Provide specific, actionable findings with line numbers.
```

### Architecture Prompt
```
Evaluate this architectural decision:

Context: [situation summary]
Options: [list options being considered]
Constraints: [requirements, limitations]

Questions:
1. Which option do you recommend and why?
2. What are the trade-offs?
3. What risks should we mitigate?

Provide a concrete recommendation with rationale.
```

## CLI Reference

See `~/.claude/docs/multi-llm-review.md` for CLI commands and quota fallback logic.

## Tips

- **Parallel execution**: Run all model calls in single message for speed
- **Large files**: Chunk files >500 lines or summarize first
- **Model details**: See `~/.claude/docs/multi-llm-review.md` for models, quotas, and fallback logic
- **As Independent Work component**: Output is automatically consumed by Cross-Validation agents in swarm mode

## Examples

```bash
# Review a Go file
/multi-review server/channels/app/page_core.go

# Review architecture decision
/multi-review Should we use Redis or PostgreSQL for caching?

# Force architecture mode on a plan doc
/multi-review --arch plans/new-feature.md

# Review with specific focus
/multi-review server/api4/page_api.go - Focus on security and input validation
```
