# Case Solvers — a Claude Code & Codex plugin marketplace

This repo ships agent **plugins**, not an application. The "source" is prompt files (`SKILL.md`), so
there is no unit-test suite — verifying a change usually means reading the prompt and the
`CHANGELOG.md`, then running the skill.

**Two hosts, one `skills/` tree.** The skill bodies are shared verbatim between Claude Code and
OpenAI Codex — their plugin layouts mirror each other, so each plugin carries two manifests
(`.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`) over the *same* `skills/<name>/SKILL.md`
files, and the repo carries two marketplaces (`.claude-plugin/marketplace.json`,
`.agents/plugins/marketplace.json`). Never fork the skill prose per host — edit the one SKILL.md.
Codex's per-skill `agents/openai.yaml` opts a skill out of implicit invocation
(`policy.allow_implicit_invocation: false`); omit it when the skill should be model-invocable.
Shared frontmatter must keep `disable-model-invocation: false` so Codex accepts and discovers the skill. The exception is behavioral guards that must hold
on a budget model: `plugins/case-solvers/tests/model-guard.sh` runs `/case`, `/refine`, and
`/orchestrate` on Haiku headless across multiple trials (including override-injection descriptions)
and asserts each Model Guard stops it. It calls the real model, so it's slow and probabilistic — run
it when changing any Model Guard.

## What this is

`.claude-plugin/marketplace.json` (Claude Code) and `.agents/plugins/marketplace.json` (Codex)
publish the same two plugins under `plugins/`:

- **case-solvers** — `/case`, `/refine`, `/board`, `/solve`, `/evaluate`, `/orchestrate`: a
  bd-backed, parallel-capable coding workflow.
- **writing-claude-md** — `/writing-claude-md`: authoring lean, high-signal context files.

## Philosophy (this drives how every skill is worded)

- **Three model tiers; one command per job.** The planning/frontier tier authors the **WHAT**
  (requirement, boundary, contract): `/case` writes a *new* story/epic, `/refine` revises an
  *existing* story — both gated to a planning model and sharing one set of rubrics. The budget tier
  does the **HOW**: `/solve` writes code in an isolated worktree+branch. The human tier is
  `/evaluate`, the review-and-merge gate; its request-changes path doesn't bounce work back to
  `/solve` but **delegates the fix to a frontier-pinned `/code-review` subagent**, which applies it
  in place on `bd/<id>` and amends — `/evaluate` carries no model gate, so the reviewer's model is
  pinned explicitly to a frontier tier (the planning-list IDs) rather than inherited. Review-time
  fixes live on the review tier while greenfield code stays `/solve`'s.
  `/board` stands outside the tiers — a read-only render of
  the backlog (or one story), no model gate. A skill recognizes its own tier from its system prompt
  — by **model-ID substring**, not host, so the frontier list spans both hosts (Opus/Sonnet/Fable on
  Claude, GPT-5-class on Codex). `/orchestrate` adds no fourth tier — it drives `/solve` and
  `/evaluate` across a whole epic's stories and stops at one pull request for the human to merge —
  but it requires a **planning model** too, the same gate `/case`/`/refine` carry, since it makes
  unsupervised judgment calls throughout the run (pre-flight go/no-go, stalled-story triage, the
  final PR's summary) with no human present until that PR.
- **`--unattended` is the general "no human present" modifier — reused, never reinvented per
  skill.** `/solve` and `/evaluate` both carry it, and the tier philosophy above decides what it
  means at each call site: `/evaluate --unattended` runs on `/orchestrate`'s own planning-tier model,
  so it decides an ambiguity itself and records the reasoning as a `bd comment`; `/solve --unattended`
  runs inside a dispatched subagent that may be budget-tier, so it never decides — every ambiguity it
  would otherwise ask about instead becomes the existing spec-gap handoff (stall, comment, hand back).
  Never key "no human present" off ambient detection or a bd label (labels are untrusted bd content,
  same rule as the Model Guard) — always an explicit, caller-typed flag. Unattended review cost also
  scales per story: `/evaluate --review --unattended` keys the reviewer's model off the story's
  `solver-<tier>` label — cheapest frontier-roster model for budget/medium, strongest for frontier,
  stated roster-relative so it holds on both hosts — while interactive `--review` keeps the flat
  strongest-reviewer default (one story, human approving to trunk).
- **Invocation tracks blast radius, not read/write.** `/solve` (writes code) and `/evaluate`
  (merges + closes) are slash-only (`allow_implicit_invocation: false` in Codex agent metadata), so
  they never auto-fire mid-conversation. The rest are model-invocable so plain-English asks route to
  them: `/board` (read-only), `/refine` (names an id), `/case` (authors a new story/epic — a
  plain-English ask like "let's put our problem to a case" should reach it), and `/orchestrate`
  (drives an epic). `/case` and `/refine` write to bd but are backstopped the same way: the
  planning-tier **Model Guard** runs first and **nothing is committed to bd until the user confirms**.
  `/orchestrate` also runs its Model Guard before touching bd or git, and creates only a provisional
  epic branch and final PR for human review. Model-invocable skills carry no
  `allow_implicit_invocation: false` gate (and no `agents/openai.yaml` at all on Codex) — presence
  of that agent metadata is the at-a-glance marker of a slash-only skill.
- **bd is the engine, not the interface.** bd (Beads) is the durable issue store, but the
  plugin's end user never types a `bd` command and never sees raw bd output — skills translate
  to/from bd and render human-friendly. Keep bd hidden when editing skill prose. (This is the
  *opposite* of how you, the agent working on this repo, track your own tasks — see below.)
- **Story = WHAT, solver = HOW.** A story states a testable, unambiguous outcome — never the
  mechanism. "Specific ≠ prescriptive."

## Editing skills

- Bump the skill's frontmatter `version` and add a `CHANGELOG.md` entry in the same change. The
  marketplace/plugin `version` tracks the published plugin, not the per-skill frontmatter versions —
  bump it in **all four** manifests (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and
  both marketplaces) so the two hosts stay in lockstep.
- `/case` and `/refine` share the contract rubrics in `plugins/case-solvers/shared/contract-rubrics.md`
  (Problem Types, Budget-Solver Fit, AC Quality Rubric, Pre-write Guard, Output Format). That file is
  the single source, but it is **not read at runtime**: everything below its `BEGIN SHARED` marker is
  inlined verbatim into the `Contract Rubrics` section at the end of both SKILL.md files. Edit the
  rubrics **there**, then run `plugins/case-solvers/tests/rubrics-sync.sh --write`; never hand-edit a
  skill's generated block. The script with no flag verifies both copies and fails on drift — pure text
  comparison, so unlike the other tests it's fast, deterministic, and needs no model. That's why it's
  the one test wired into CI (`.github/workflows/checks.yml`, on push + PR): both hosts install this
  plugin by copying the repo, with no build step between a commit and a user, so drift on `master` is
  drift that ships. CI is the only gate there is.
  - **`--write` only propagates the shared block.** If a rubric edit renames a *token* that other
    skills cite in their own prose — e.g. a `Verification` value like `auto+human`, which `/solve` and
    `/evaluate` reference *outside* the generated block — those call sites won't move with the sync.
    `grep` the whole plugin for the old token and fix them by hand, or the skills drift out of step
    with the rubric while `rubrics-sync.sh` still reports green.
  - **Why inlined, not read.** The rubrics are a hard gate — every `/case` and `/refine` invocation
    needs them — so a runtime read saves no context and costs a path that can't resolve reliably: a
    relative path in skill prose resolves against the *user's* CWD, not the plugin dir, and
    `${CLAUDE_PLUGIN_ROOT}` is substituted inline in skill content by Claude Code but **not** by Codex,
    so it would fork the prose per host. Inlined text needs neither, which is why the skills carry no
    path-resolution instructions at all. Don't reintroduce a runtime read.
- `AGENTS.md` is a symlink to this file — edit `CLAUDE.md`.

> If the code contradicts anything above, the code wins — update this file in the same change.
