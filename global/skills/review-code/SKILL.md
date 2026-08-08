---
name: review-code
description: Comprehensive code review via specialized agents + multi-LLM review with cross-validation. Works on local changes or GitHub PRs.
version: 2.0.0
tags:
  - code-review
  - quality
  - analysis
---

# Review Code

Comprehensive code review using **specialized agents** AND **multi-LLM review** with Independent Work → Cross-Validation → Synthesis. Catches bugs, security issues, and pattern violations.

Works on: **Local changes** (uncommitted+staged vs HEAD, default) or **GitHub PRs** (`--pr` flag). Pass `--scope=branch` to review the entire branch vs base instead.

**Inline PR comments are opt-in via `--comment`.** By default, PR reviews print findings to chat only — exactly as before. Pass `--comment` to additionally prepare each MUST_FIX / SHOULD_FIX as a GitHub review comment anchored to the affected line. Even with `--comment`, comments are *prepared and shown to you first* and posted ONLY after your explicit yes — no flag authorizes the post, and nothing is ever committed or pushed. See `## Inline PR Comments`.

> `/create-plan` -> `/create-code` (includes auto-review) -> `/create-test` -> `/fix-test`

**Note**: `/create-code` now auto-runs `/review-code` as its final step. Use this skill standalone for: reviewing code not written via `/create-code`, re-reviewing after manual edits, reviewing PRs, or when you want swarm/full mode.

**Run `/lint` after** -- this skill finds semantic issues; lint cleans formatting.

**Related**: `/review-plan` (plans), `/create-code` (implement + auto-review), `/lint` (formatting)

## Three-Phase Review

| Phase | Participants | Purpose |
|-------|-------------|---------|
| **Independent Work** | Agents + multi-LLM (independent, parallel) | Diverse perspectives without anchoring bias |
| **Cross-Validation** | Agents see all Independent Work findings | Validate, dispute, go deeper with full context |
| **Synthesis** | Leader merges all findings | Final report with 80/20 filter |

## Usage

```
/review-code                              # Uncommitted+staged vs HEAD (default)
/review-code --scope=branch               # Whole branch vs base (auto-detect, fallback master)
/review-code <file-or-directory>          # Review specific path
/review-code backend                      # Go files only
/review-code frontend                     # TypeScript/React files only
/review-code --pr 123                     # Review GitHub PR #123 (chat output only)
/review-code --pr 123 --comment           # Review PR + prepare inline comments (asks before posting)
/review-code --comment                    # Prepare inline comments for the PR on the current branch (asks before posting)
/review-code --quick                      # Tier 1 agents only (no multi-LLM)
/review-code --full                       # All tiers + multi-LLM (most thorough)
/review-code --agents-only                # Skip multi-LLM review
/review-code --llm-only                   # Skip agents, multi-LLM only
/review-code --swarm                      # Parallel agents via teams + convergence loop
/review-code --swarm --sequential         # Groups run serially, agents parallel within group
/review-code --base feature-branch        # Implies --scope=branch with this base
/review-code --plan path/to/plan.md       # Review against implementation plan
```

## Mode Behavior

| Mode | Independent Work | Cross-Validation | Leader Dedup | Convergence |
|------|------------------|------------------|--------------|-------------|
| Default (no flags) | Parallel subagents, no shared state (agents + multi-LLM) | SKIPPED | **MANDATORY** | Single-pass |
| `--swarm` | Background agents with shared findings dir (agents + multi-LLM) | Fresh agents cross-validate | **MANDATORY** | Canonical convergence (swarm-harness.md) |
| `--sequential` | Serial Task() calls | SKIPPED | **MANDATORY** | Single-pass |
| `--quick` | Tier 1 agents only, no multi-LLM | SKIPPED | **MANDATORY** | Single-pass |
| `--security` | Tier 1 + Tier 2 (Security) agents + security-focused multi-LLM | SKIPPED | **MANDATORY** | Single-pass |
| `--agents-only` | Parallel subagents, no shared state (agents only) | SKIPPED | **MANDATORY** | Single-pass |
| `--llm-only` | Parallel subagents, no shared state (multi-LLM only) | SKIPPED | **MANDATORY** | Single-pass |

## Project Context Loading

See `~/.claude/docs/project-context-loading.md` -- three-level agent discovery + reference docs before review.

## Workflow

### Step 0: Read Agent Registry (MANDATORY — before any other step)

Read `~/.claude/agents/AGENT_REGISTRY.md` **in full, no line limit**. The Parallel Groups table is near the top of the file. Apply the trigger table to determine which groups run:

| Changed files | Groups to add |
|--------------|---------------|
| Always | Cross-cutting |
| `*.go` | Backend |
| `*.ts` / `*.tsx` | Frontend |
| New files or dirs added | Compatibility |
| Test files | Testing |
| CI/CD, `*.sh`, `*.yml` or `--ci` flag | Infrastructure |
| `--thorough` / `--full` | Security |

Triggers add groups; they never subtract files. A changed file matching no row still needs an owner — Step 5.5 enforces that.

**Do not select any agents until this read is complete. Never select agents from memory.**

1. **Identify changes** -- determine the comparison base from scope:
   - Default (no `--scope`, no `--base`, no `--pr`): `git diff HEAD` (uncommitted+staged work).
   - `--scope=branch` or `--base <branch>`: `git diff <base>` (whole branch vs base; base auto-detects, fallback `master`).
   - `--pr <n>`: `gh pr diff <n>`.

   **Print the active scope as the first line of output**, e.g. `Reviewing 5 uncommitted file(s) (vs HEAD). Use --scope=branch for full branch review.` This prevents users from shipping a PR thinking they got a full review when they only got the unstaged slice. Detect languages and domains from the resulting file set.
2. **Load implementation plan** (if `--plan` provided) -- Read the plan file. Extract: phased delivery scope, intentional design decisions, accepted trade-offs, and deferred items. This context is included in every agent prompt.
3. **Gather full context** -- BEFORE spawning any review agents:
   - **Identify changed-file paths**: Run `git diff --name-only` against the active scope's base to get the path list.
   - **Identify sibling/parent components**: Scan the diff for `import`, `styled(...)`, `extends`, prop types, and interface references. Add their paths to the codebase-paths list.
   - **Identify pattern exemplars**: For each changed construct (styled component, API handler, store method, etc.), identify 2-3 existing sibling paths that establish the convention (e.g., for a new `MemberButton`, identify the `DotMenuButton` and `TitleButton` paths from the same file/package).
   - **Resolve external-package symbols to their real source (MANDATORY when the diff depends on them)**: When the diff uses a symbol, type, prop, or allowed-value set from a package **outside the repo's own tree** (`@mattermost/*`, `mattermost-redux`, a sibling plugin, any third-party lib), locate the actual definition — first in sibling checkouts under the workspace (e.g. `%%MM_ROOT_DIR%%/mattermost/webapp/platform/shared/...`), then in `node_modules`, then in the package's published `.d.ts`. Bundle the verified definition (the union/interface/signature, quoted from source) into the agent context as **VERIFIED ground truth**, labeled with its file path. If the definition cannot be located, instruct agents to mark any claim about that symbol `UNVERIFIED` and to **NOT** infer the API from a web search, the symbol's name, or memory. *Why this exists*: on PR #2295 an external reviewer flagged `size='xs'`, `emphasis='quaternary'`, and a `typeof Button` union as invalid — all three were correct code; the reviewer couldn't find `@mattermost/shared`'s types, fell back to a web search, and hallucinated the allowed values. Our agents were right only because the orchestrator had bundled `button_classes.ts`'s real unions. Make that resolution a step, not luck.
   - **Pass paths, not bundled content (default for local scopes)**: Include the codebase-paths list inline in each agent prompt. Agents Read on demand from the working tree. Bundling full file contents inline duplicated ~50 KB × N across the swarm; passing paths lets each agent fetch only what it needs and keeps prompts lean.
   - **Exception — `--pr` mode**: When reviewing a PR with no local checkout, fetch each path's content via `gh` and bundle inline — agents have no working tree to Read from.
   - **Why include codebase context at all**: Diff-only review produces false positives — agents flag "issues" that are actually established codebase conventions (e.g., color opacity values, touch target sizes, missing focus styles that no sibling component has either). The diff alone doesn't show convention.
   - **CRITICAL — Annotate diff scope in agent prompts**: ALWAYS include the raw `git diff` output (with `+`/`-` line markers) as a separate clearly-labeled section. Label it: `## Diff (YOUR REVIEW SCOPE — only flag issues in these changed lines)`. Pass codebase paths in a `## Codebase Paths (Read these for context — do NOT flag issues in unchanged code)` section. Under `--pr` mode where contents are bundled, label them `## Full File Context (for understanding only — do NOT flag issues in unchanged code)` instead. The visual separation prevents agents from treating codebase context as review scope.
4. **Load agents** -- three-level discovery from `~/.claude/docs/project-context-loading.md`, tagged `[CODE]` or `[BOTH]`
5. **Emit Selection Rationale (MANDATORY — before spawning anything)** -- Print a `## Selection Rationale` block per `~/.claude/docs/selection-rationale.md`. List every candidate agent under either SELECTED (with trigger reason) or SKIPPED (with specific reason). The block is user-visible output, printed after the scope line from Step 1 and before any agent spawns. In `--swarm` mode, also write `selection-rationale.md` to the synthesis dir so it survives `/clear`.

5.5. **File-coverage gate (MANDATORY — before spawning anything)** -- Slice construction, not agent capability, is the most common reason a real defect is never seen. Specialists get narrow hand-picked slices centred on the feature's core; peripheral files land only in the monolithic full diff, which is exactly the input the multi-LLM legs truncate or refuse on token limits. The file is then "reviewed" by nobody, and nothing in the output says so.

   Before Step 6, assert **every** path in the Step 1 changed-file set appears in at least one agent's review scope:

   ```bash
   # every changed path
   git diff <base> --name-only | sort > /tmp/rc-changed.txt
   # every path across all constructed slices (adjust glob to the slice dir in use)
   cat <slice-dir>/*.diff | grep -oE '^\+\+\+ b/\S+' | sed 's|^+++ b/||' | sort -u > /tmp/rc-covered.txt
   comm -23 /tmp/rc-changed.txt /tmp/rc-covered.txt        # orphans
   ```

   - **A slice containing every file does not count as coverage.** Exclude the full/branch diff from `rc-covered.txt` — only *targeted* slices handed to a named specialist count. A 52-file monolith is the failure being detected, not the remedy.
   - **Every orphan is either assigned or explicitly waived, in user-visible output.** Print a `## File Coverage` block listing each orphan with the agent it was assigned to, or `WAIVED: <specific reason>`. "Peripheral to the feature" is not a reason — generated artifacts and vendored trees are.
   - **Orphans get an agent before Step 6 runs**, not a note in the final report. If no specialist fits, assign `code-reviewer` (general-purpose, any language) rather than leaving the file unread.
   - **Why this exists:** on PR mattermost-plugin-docs#10 CodeRabbit returned 9 findings the swarm missed. `changed-files.txt` had listed all 52 changed files correctly, but every targeted slice — `api.diff` (3 files), `core.diff` (5), `store.diff` (8), `tests.diff` (3), `concurrent.diff` (6) — excluded `ci.yml`, `build/build-core-image.sh`, `server/e2e/README.md`, `container_test.go`, and `helpers_test.go`. Those five files existed only in the 665KB `full.diff`. Five of the nine findings sat in files no specialist ever received. A slice named `tests.diff` excluded the test files carrying four findings; `code-slop-reviewer` — which explicitly owns unused params — was pointed at a 5-file `slop-target.diff` that omitted the file with the unused param. The agents were not blind; they were never shown the code.

6. **Independent Work** -- agents + multi-LLM run in parallel, write COMPLETE findings to files, neither sees the other's output
7. **Cross-Validation** -- agents READ each other's findings files directly (leader provides file paths + brief themes, not a condensed summary)
8. **Synthesis** -- fresh synthesis agent reads ALL findings files, merges with 80/20 filter, 2+ source agreement = MUST FIX. Leader reads only the summary.
9. **Leader Dedup Gate (MANDATORY — all modes)** -- Before the diff-scope gate, the leader (you) MUST deduplicate and merge findings from all agents. This step runs in ALL modes, not just `--swarm`. Agents work independently and frequently report the same root-cause pattern as separate findings with different severities.
   - **Group by root pattern**: For each finding, ask "what is the anti-pattern?" (e.g., "uses `HandleError` instead of `HandleAppError`", "missing `classifyAppError` wrapper"). Two findings with the same anti-pattern are ONE finding.
   - **Merge across agents**: If error-handling-reviewer and api-reviewer both flag the same function call, merge into one finding citing both sources.
   - **Merge across severities**: If the same pattern appears as MUST_FIX in one agent and SHOULD_FIX in another, use the HIGHER severity and list ALL instances.
   - **Count ALL in-scope instances**: For merged pattern findings, grep for the pattern across ALL changed files to find every instance — not just the ones agents reported. Report the total count.
   - **One finding, one fix**: The merged finding gets a single fix description that addresses all instances (e.g., "Replace `HandleError` with `HandleAppError` at 4 call sites in changed code").
   - **Why this exists**: Without this gate, the same bug reported by N agents appears as N separate findings, creating noise and hiding the systemic nature of the issue. The user sees "4 separate problems" when there is actually "1 pattern, 4 instances."
9.5. **Runtime-claim verification gate (MANDATORY before any behavioral MUST_FIX)** -- For every finding whose claim is *behavioral* ("breaks / 404s / never found / returns wrong value / spams / silently fails / data loss"), the leader MUST verify the **terminal end** of the execution path before assigning MUST_FIX — not the changed line alone.
   - **Read the callee, not just the caller.** The diff usually shows the *caller*; the failure claim lives at the *callee*. "Calls endpoint E / store method M / consumer C" → read E's handler / M's body / C before labeling. Reading the caller only confirms the call *happens*, never that it *fails*. (This is source-reading-discipline rule 3 — symmetric reading — applied to severity assignment.)
   - **Reconcile against the test suite.** Grep for a test covering that exact path. A green test on the path is disconfirming evidence — demote and re-read. Treat "tests pass but I claim it's broken" as a contradiction to resolve, never a footnote.
   - **Severity is capped by what you read.** Full-path read (caller→callee) OR a red test/repro → MUST_FIX permitted. Same-layer-as-diff read only → SHOULD_FIX (unverified runtime claim) maximum.
   - **Scope:** applies to runtime/behavioral findings only. Pattern/style/structural findings (dead code, naming, layer violations) do NOT need a full-path trace. This is a leader gate, not an agent constraint — agents should keep surfacing cross-layer hypotheses cheaply; the leader does not promote them without reading the far end.
   - **Why this exists:** caught a false "page version restore is broken" MUST_FIX — the frontend called the posts restore endpoint, but the server handler (`RestorePostVersion`) had a `Pages`-table fallback the caller-side read never saw. The leader had "verified" only the frontend wiring (the premise), not the server handler (the conclusion).
9.6. **Normative-claim gate (MANDATORY before DOWNGRADING any MUST_FIX)** -- Step 9.5 caps severity on *behavioral* claims. This gate governs the opposite failure: a **normative** claim — "path A enforces control C, path B doesn't, therefore B is wrong" — where every cited fact verifies but the *premise* (that B is in scope for C) never gets tested. Verifying the `is` and assuming the `ought` feels like complete verification and is not.
   - **Search for the stronger reason BEFORE downgrading.** A thin agent rationale is not evidence the finding is wrong — agents routinely reach the right answer via the weakest available argument. When an agent's reasoning is the bare parity form, go look for the decisive fact yourself (read the method signature, the accepted input range, the enforcement sites). Downgrade ONLY after that search comes up empty, and say that it did.
   - **The decisive question is capability surface, not path parity.** "B doesn't do what A does" is waveable. "B exposes the entire controlled capability, unrestricted" is not. For any bypass/parity finding, establish which one it is by reading what B actually accepts — an unrestricted parameter (arbitrary `Scope`, arbitrary role name, arbitrary path) usually makes the finding unconditional, holding regardless of intent questions you cannot resolve.
   - **Name the scope artifact, or say none exists.** For a MUST_FIX, cite what puts B in scope for C: a spec, a code comment, a test, or an existing enforcement site covering this path (e.g. `checkLDAPLicense` applied at 16 sites in `plugin_api.go` establishes that MM gates licensed capabilities on the plugin path). "The analogous path does it" is an analogy, not an artifact.
   - **Split compound findings before rating them.** One finding carrying two independent claims gets one severity, and the strong half drags the weak half — or the weak half sinks the strong one. Rate each half separately.
   - **Intent-dependent findings are questions, not verdicts.** If resolving it genuinely requires product/licensing/roadmap intent the repo cannot answer AND the capability-surface check above did not make it unconditional, present it as an open question with both branches, not as a suppressed finding.
   - **Why this exists:** on MM-69269 `license-reviewer` correctly flagged MUST_FIX that `PluginAPI.CreateScheme`/`DeleteScheme` bypass the `CustomPermissionsSchemes` gate `api4/scheme.go` enforces. The leader downgraded it twice — first to "open question", then further — because the agent's rationale was bare parity and the leader substituted "plugins are trusted" for evidence. The decisive fact was one `sed` away: `CreateScheme` accepts an arbitrary `*model.Scheme` with caller-chosen `Scope`, so it exposes general scheme creation, making the gate required no matter how the diff's own feature is licensed. The agent was right; the synthesis layer was wrong; the user had to push three times.
9.7. **Cost-of-acting gate (MANDATORY for EVERY finding you relay, at every severity)** -- Gates 9.5 and 9.6 both key off severity. This one deliberately does not, because the failure they miss is relaying a *low*-severity finding unverified: rigor gets scaled to how alarming a finding sounds rather than to what acting on it costs.
   - **Any finding that recommends an edit gets verified before you relay it — CONSIDER and SHOULD_FIX included.** A CONSIDER that says "restore these lines" produces exactly as real an edit as a MUST_FIX does. Severity ranks *importance*; it does not license a lower evidentiary standard.
   - **Verify the finding's own premise, not just its cited facts.** The cheapest decisive check is usually one command — is this file generated? does a sibling in the same state exist and get treated the same way? does the callee actually do what the caller assumes? If you cannot name the check you ran, you have not verified it: relay it as `[UNVERIFIED]` naming the check still needed, or drop it.
   - **An edit to a generated artifact is never the fix.** If the recommended action is to hand-edit a build output, the finding is wrong by construction — see `~/.claude/agents/_shared/false-positive-prevention.md` §8.
   - **Why this exists:** on MM-69269 the leader refuted three MUST_FIXes by reading source, and injected a mutant to prove a new test actually failed — then relayed a CONSIDER about three removed i18n keys with none of that scrutiny, and acted on it twice. `webapp/i18n/en.json` is the `--out-file` of `formatjs extract`; one grep of `webapp/package.json` would have voided the finding before it was raised. The alarming findings were held to a far higher standard than the one that actually produced wrong edits.
9.8. **Load-bearing PASS gate (MANDATORY before presenting the report)** -- Gates 9.5-9.7 pressure findings; this gate pressures the PASS claims nothing else re-checks. A PASS is a negative claim ("no defect exists here"), and per `~/.claude/docs/search-first-workflow.md` § "Negative Claims" a negative claim needs MORE verification than a positive one — yet a PASS from a partial trace reads identically to one from a complete trace.
   - **Select, don't sweep.** Identify PASS claims that are BOTH (a) from a sole-owner seam agent — the only agent covering that boundary (client↔server wire contract, WS event wiring, i18n key sync, migration↔model constants) — AND (b) universally quantified ("matches", "all", "every", "none", "never"). Cap the set at 6. Verifying every PASS is explicitly rejected: it roughly doubles review cost for a near-zero hit rate and buries signal.
   - **Verify each with one named decisive check** — a branch-complete read of the writer/serializer the claim quantifies over, or a diff of both sides' test fixtures for the same endpoint. If you cannot name the check you ran, the PASS is unverified: mark it so in the report instead of presenting it as covered.
   - **Why this exists:** on MM-69269, `client-server-alignment-reviewer` PASSed "RestError parsing matches the AppError shape written by writeAppError" after tracing only the general branch — `writeAppError` special-cases every 409 into a `{error, current_page}` envelope three lines above the code it verified, so every conflict reached users as "Received status code 409". That same run refuted three MUST_FIXes by reading source; no PASS received the same skepticism. The asymmetry, not agent quality, was the gap.

10. **Diff-scope gate (MANDATORY)** -- Before presenting ANY finding to the user, verify it is on a changed line. The gate **MUST use the same comparison base as Step 1** — never widen the gate beyond the chosen scope:
   - Default scope: `git diff HEAD --name-only` and `git diff HEAD -- <file>`.
   - `--scope=branch` / `--base`: `git diff <base> --name-only` and `git diff <base> -- <file>`.
   - `--pr <n>`: use the PR diff.

   For each MUST_FIX or SHOULD_FIX finding, check: is the cited file in the changed-files set?
   - If YES: verify the cited line/function appears in a `+` hunk (added/modified code).
   - If NO (file not changed, or cited line is in unchanged code): **DROP the finding**. Pre-existing issues in unchanged code — including code committed earlier in the branch when scope is `uncommitted` — are out of scope.

   This step is a HARD GATE. No finding passes to the user without diff verification. Catches agents that read full files for context and then flagged pre-existing issues.
11. **Present results** -- the user-visible output is structured as: (1) Selection Rationale block from Step 5 already printed at the top, (2) MUST_FIX and SHOULD_FIX findings that passed both gates (dedup + diff-scope), (3) verdict. If not READY, ask user: "N MUST_FIX found. Fix and run another round?"
12. **Post inline PR comments (opt-in via `--comment`, and ALWAYS confirm first)** -- Only when `--comment` is passed AND a PR is in scope (`--pr <n>`, or `--comment` resolves an open PR for the current branch), prepare the same findings as inline review comments anchored to their lines. Without `--comment`, skip this step entirely — chat output only.
    - **Posting to a PR is an outward-facing write and ALWAYS requires explicit confirmation — no flag authorizes it.** `--comment` only selects inline-comment output; it does NOT pre-authorize the post. First print the chat summary, then print the target and count (`Ready to post N inline comments to <owner>/<repo>#<n>`) and the exact comment list, and STOP for a yes/no. Post only after the user says yes.
    - Never `git commit`, push, or otherwise write to the repo as part of this step — inline comments are GitHub PR review comments only.
    - Skip silently for local scopes (no PR to comment on). See `## Inline PR Comments` for the mechanism.

## Prompts & Output Format

See `~/.claude/docs/review-prompts.md` for: code review prompt template, output format, and agent prompt rules (neutral framing to avoid confirmation bias).

## Inline PR Comments

Findings already carry everything an inline GitHub review comment needs — the canonical finding format (`~/.claude/agents/_shared/finding-format.md`) requires `file:line` plus a verbatim `Diff evidence:` `+` line. **No agent changes are needed**; this is purely an orchestrator output step. Each finding that passed the dedup + diff-scope gates maps to one comment anchored on the new-version (RIGHT) side at its cited line.

**Authorization (non-negotiable):** posting is an outward-facing write. ALWAYS print the chat summary and the full prepared comment list, then ask for a yes/no before sending anything. No flag (`--comment`, `--pr`) authorizes the post on its own. Never `git commit`, push, or write to the repo — these are PR review comments only.

**Comment body** — keep it the same content the user sees in chat, one finding per comment:

```
**[severity] [agent:TAG]** — [one-line description]

[Evidence / why it matters]

**Fix:** [concrete fix]

<sub>via /review-code</sub>
```

**Posting mechanism** — batch all comments into a SINGLE PR review (one notification, one reviewable thread), prefer the GitHub MCP tools per project policy (`mcp__github__pull_request_review_write` to create + submit a review with a `comments` array; `mcp__github__add_comment_to_pending_review` for incremental). Equivalent `gh` fallback:

```bash
gh api -X POST /repos/<owner>/<repo>/pulls/<n>/reviews \
  -f commit_id='<head sha from gh pr view --json headRefOid>' \
  -f event='COMMENT' \
  -f body='Automated review summary — N MUST_FIX, M SHOULD_FIX. See inline comments.' \
  -f 'comments[][path]=<file>' -F 'comments[][line]=<line>' \
     -f 'comments[][side]=RIGHT' -f 'comments[][body]=<comment body>'
```

(Build the `comments` array programmatically — one entry per finding. For multi-line findings add `start_line` + `start_side`.)

**Line anchoring** — the diff-scope gate (Step 10) already guarantees every finding sits on a `+` line in the PR diff, so each comment line is valid for the GitHub API. If a `COMMENT`-event review is rejected (422 — line not in diff for a borderline finding), retry that single comment as a general (non-inline) review comment rather than failing the whole batch, and report which findings fell back.

**Findings with no resolvable line** (whole-file or cross-file pattern findings) go in the review `body` summary, not as inline comments.

## Pattern Completeness — Single Source of Truth

The Pattern Completeness rule lives in `~/.claude/agents/_shared/grounding-rules.md` § "Pattern Completeness (Mandatory)". Every review agent reads `grounding-rules.md` as its FIRST ACTION, so the rule is automatically enforced without prompt injection. Do NOT duplicate it here or in agent prompts.

## Agent Tiers & Selection

Read `~/.claude/agents/AGENT_REGISTRY.md` **in full, no line limit** for agent lists per tier.

**Selection logic** -- pick agents based on changed file types (tier numbers match `~/.claude/agents/AGENT_REGISTRY.md`):
- **Tier 1 (Cross-cutting)**: Always run all agents
- **Tier 3 (Backend)**: If `*.go` files changed
- **Tier 4 (Frontend)**: If `*.ts`/`*.tsx` changed, OR API/schema changes (bridge trigger)
- **Tier 5 (Testing)**: If test files changed; E2E agents if `e2e-tests/playwright/` changed. Test files need **assertion-validity** review, not only coverage review — `test-coverage-reviewer` asks whether a test exists, `mutation-test-reviewer` asks whether it would fail if the code were wrong. Include `mutation-test-reviewer` whenever `*_test.go` / `*.test.ts` files are in the diff, and route test *harness* code (fixtures, container bootstrap, request helpers) to `code-reviewer` as well — a helper that silently returns a wrong answer is production logic wearing a test filename.
- **Tier 6 (Compatibility)**: If `model/` files changed, fields removed/renamed, API surface changes, or new files/dirs added — `backwards-compatibility-reviewer`, `batch-operations-reviewer`, `null-safety-reviewer`, `deprecation-reviewer`, `license-reviewer`, `file-structure-reviewer`
- **Tier 7 (Infrastructure)**: If CI/CD, build, or ops files changed — `.github/`, `Makefile`, `Dockerfile`, `.gitlab-ci.yml`, **any `*.sh`**, **any `*.yml`/`*.yaml`** — or `--ci` flag. Use `ci-design-reviewer` to review workflow and script *correctness* (this is the reviewing agent); `ci-failure-reviewer` is for diagnosing an already-failing pipeline, not for reviewing a diff. Shell scripts and workflow `run:` blocks are code: a guard's regex, a fallback default, and an early `exit 0` all carry the same defect risk as Go, and a broken guard fails silently by passing.
- **Docs that describe behavior** (`README.md`, `CONTRIBUTING.md`, `docs/**`): if the diff changes a `Makefile` target, script, or workflow that a tracked doc describes, assign that doc to `code-reviewer` for a code↔doc drift check. No agent owns cross-artifact drift by default, so a README that contradicts the target it documents passes review unremarked.
- **Tier 2 (Security)**: With `--security`, `--thorough`, or `--full` flag
- **`comment-reviewer`**: Always included with `--full`/`--thorough`, independent of file-type triggers (it already runs whenever Tier 3/Backend triggers on `*.go` changes; this guarantees it also runs on `--full` reviews of non-Go changes).
- **Contract-contradiction sweep**: With `--full`/`--thorough`, additionally spawn ONE general-purpose agent that reads ONLY test artifacts on both sides of every changed cross-boundary contract — server handler tests' asserted wire shapes (status codes, body envelopes) vs client tests' mocked responses for the same endpoints, and WS payload tests vs client handler expectations. Two suites asserting different shapes for one endpoint means one of them is wrong; the sweeper flags the contradiction and does NOT re-review production code. Why: on MM-69269 the server test asserted the nested 409 `{error, current_page}` envelope while the client test mocked a flat AppError for the same endpoint — a mechanically findable contradiction sitting in two test files no single agent compared.
- **Project group**: If changed files match project-specific patterns — agents from **project** registry (`<project>/.claude/agents/AGENT_REGISTRY.md`, "Parallel Groups" table). Discovered automatically via three-level agent discovery; no hardcoded agent names here.

**Routing rule**: Only spawn `[CODE]` or `[BOTH]` agents. NEVER spawn `[PLAN]`-only agents.

## Convergence Tracking

Uses canonical pattern from `~/.claude/docs/swarm-harness.md#convergence-pattern`. Track MUST FIX count trend across rounds.

## Flags

| Flag | Effect |
|------|--------|
| `--pr <number>` | Review GitHub PR instead of local changes (chat output only unless `--comment` is also passed) |
| `--comment` | Opt in to inline-comment output for the PR in scope (or the open PR on the current branch). Does NOT authorize posting — you are always asked before anything is sent to GitHub |
| `--quick` | Tier 1 agents only, no multi-LLM (fastest) |
| `--security` | Tier 1 + Tier 2 (Security) agents + security-focused multi-LLM. Narrower than `--full` |
| `--full` / `--thorough` | All tiers + multi-LLM (most thorough); always includes `comment-reviewer` regardless of file type |
| `--agents-only` | Skip multi-LLM review |
| `--llm-only` | Skip agents, multi-LLM only |
| `--swarm` | Parallel agents via teams + auto-fix convergence (env var guard — see swarm-harness.md) |
| `--sequential` | With `--swarm`: groups run serially |
| `--ci` | Include Tier 7 (Infrastructure) agents for CI/CD review |
| `--scope=uncommitted` | (default) Review only uncommitted+staged changes (`git diff HEAD`) |
| `--scope=branch` | Review the entire branch vs base (`git diff <base>`); base defaults to auto-detect, fallback `master` |
| `--base <branch>` | Implies `--scope=branch` and overrides the base branch |
| `--plan <path>` | Load implementation plan as context — agents distinguish intentional-per-plan from genuine issues |

## Examples

```bash
/review-code                           # Full review of local changes
/review-code backend                   # Go files only
/review-code --pr 123                  # Review a PR
/review-code --quick                   # Fast check (Tier 1 only)
/review-code --full                    # Thorough (all tiers + LLM)
/review-code --swarm                   # Parallel swarm review
/review-code --swarm --sequential      # Sequential swarm
/review-code --plan impl-plan.md       # Review with plan context (reduces false positives)
/review-code --plan impl-plan.md --full # Thorough + plan-aware
```

## Swarm Mode (`--swarm`)

> **Swarm protocol**: See `~/.claude/docs/swarm-harness.md`
>
> **Persistence**: Set `PERSIST_DIR = "{repo}/plans/.review-history/code-{branch-name}"`
> before invoking the harness. Each round's synthesis files are mirrored there
> so they survive `/clear` and reboots. See harness "Persistent Archive" section.

| Task | Agent Type | Role | Phase | Depends On |
|------|-----------|------|-------|------------|
| T1a-n: Code agents (by tier) | (from AGENT_REGISTRY.md) | Domain reviewers | Independent Work | -- |
| T2: Multi-LLM review | general-purpose | LLM reviewers | Independent Work | -- |
| T3: Cross-validation | 3-5 Phase 1 types covering major domains (see swarm-harness.md) | Validate/dispute/go deeper + contradiction check | Cross-Validation | T1*, T2 |
| T4: Synthesize | general-purpose (fresh) | Merge all findings | Synthesis | T3 |

### Parallel Groups (Independent Work)

Groups and agent assignments are defined in `~/.claude/agents/AGENT_REGISTRY.md` SS "Parallel Groups for Code Review". The table below mirrors those groups exactly — see the registry for agent lists.

| Group | When |
|-------|------|
| Cross-cutting | Always |
| Backend | Go changes |
| Frontend | TS/React changes |
| Compatibility | `model/` changes, API surface changes, new files/dirs |
| Infrastructure | CI/CD file changes or `--ci` |
| Security | `--thorough` or `--full` |
| Project | Project-specific file patterns (from project registry) |
| Testing | E2E changes |

## Plan-Aware Review (`--plan`)

When `--plan <path>` is provided, include the full plan content in every agent prompt with these instructions:

> **Implementation Plan Context**: The code under review implements this plan. Before flagging any finding:
> 1. Check if the behavior is **explicitly prescribed by the plan** (e.g., phased delivery, accepted trade-offs, intentional scaffolding). If so, classify as INFO with note "intentional per plan."
> 2. Check if the finding **contradicts the plan** (code does X but plan says Y). Flag as MUST_FIX with note "deviates from plan."
> 3. If the plan **doesn't mention** the concern, evaluate it on its own merits as normal.
> 4. Check if code is **scaffolded for a later phase** (field exists but has no migration/handler yet). If the plan says it ships in a later phase, classify as INFO.

This eliminates false positives from phased delivery, intentional design trade-offs (e.g., "gaps on failure are acceptable"), and deferred features.

## Fix Prompts — Pattern Completeness Rule

When spawning coder agents to fix findings, **always include** the Pattern Completeness instruction from `~/.claude/docs/pattern-completeness-rule.md` in the agent prompt.

## Fix Prompts — Precedent Gate (MANDATORY, applies to the leader too)

Precedent-hunting is a **write-time** rule, not a review-time one. The failure mode is doing it rigorously while reviewing and dropping it the moment you switch to fixing — review mode has evidence discipline on, fix mode slides into solution-design with it off. `pattern-alignment.md` already requires finding 3-5 similar implementations **before writing any code**; this gate makes it non-skippable for fixes.

Before writing any fix larger than a trivial edit:

1. **Grep the primitive's existing callers.** About to call a store/service method? `grep -rn "MethodName(" --include="*.go"` first and read how core already calls it. One command, and it frequently answers the whole question.
2. **"No sibling anywhere" is a stop signal, not a design opportunity.** If the fix introduces a magic constant, a paging loop, a threshold, or a fallback path with no counterpart in the surrounding code, stop and re-check the finding. Do not engineer around the absence.
3. **Size the fix to the finding's CONFIDENCE, not its plausibility.** A SHOULD_FIX whose trigger you could not verify (behaviour in an out-of-repo consumer, unconfirmed actor privilege) caps at the smallest possible change — or none. Never grow a one-line call into a subsystem for an unconfirmed premise.
4. **Precedent for the EXISTING code refutes the finding.** If core already does what the diff does, in an equivalent situation, the trade-off was made deliberately upstream. That is evidence the finding is wrong — re-examine it instead of fixing it.

**Why this exists:** on MM-69269 a SHOULD_FIX claimed a cluster-wide `ClearMembersForUserCache()` purge on a space scheme switch was DoS-amplifiable by an unprivileged user. The leader replaced the one-line purge with ~45 lines: a member-paging loop, a magic `500` threshold, and a fallback-on-error path. One grep would have shown `ClearMembersForUserCache` has exactly **one** other caller — `app/team.go:261`, `UpdateTeamScheme` — doing the identical purge for the identical reason, and that `InvalidateAllChannelMembersForUser` is only ever called for a single already-known user, never in a loop. The existing code matched core's only precedent; the "fix" invented three constructs with no convention behind them, for a trigger that could not be verified because it lives in the out-of-repo plugin. Reverted in full.

## Tips

- **Run before every commit** -- catch issues early
- **Use `--quick` for WIP** -- full review before PR
- **Fix MUST FIX immediately** -- they're blockers for a reason
- **Trust multi-source consensus** -- 2+ sources (agent + LLM, agent + agent) agreeing = real issue
- **Use `--agents-only` for speed** -- when external LLMs are slow
- **Cross-Validation catches false positives** -- validates/disputes Independent Work findings

## Anti-patterns
- Running full swarm review on a 5-line change — `--quick` exists for a reason.
- Treating every finding as a blocker — severity tiers (MUST_FIX / SHOULD_FIX / CONSIDER) exist to separate signal from noise.
- Spawning review agents without telling them the diff scope — agents flag pre-existing issues as new findings.
- Acting on a single-source finding without cross-validation — one agent's opinion is a hypothesis, not a verdict.
- Skipping `--quick` pre-commit and doing full review only at PR time — late reviews cost more to fix.
- **Skipping the Selection Rationale block (Step 5)** — silently selecting agents hides drift. See `~/.claude/docs/selection-rationale.md` for the full anti-pattern list.
- **Building slices around the feature's core and letting the rest fall into the full diff (Step 5.5)** — the orphaned files read as reviewed in the final report and were seen by nobody. Coverage is what a *targeted* slice contained, never what the monolith contained.
- **Treating `_test.go`, `*.sh`, `*.yml`, and `*.md` as second-class review targets** — a broken CI guard passes silently, a tautological assertion can never fail, and a stale README misroutes the next reader. These files carry defects at the same rate as production code and get a fraction of the scrutiny.

## Self-rewrite hook
After every 15 review runs, or after any run where the review produced more noise than signal (most findings were false positives or pre-existing issues):
1. Re-read the last 5 sets of findings — which finding types consistently turned out to be false positives?
2. If a recurring false-positive category appears, add a note to the relevant agent's prompt or the shared false-positive-prevention rule.
3. If cross-validation consistently reverses a specific agent's findings, flag that agent for tuning.
4. Commit: `skill-update: review-code, <one-line reason>`.
