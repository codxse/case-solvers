# Case Solvers — a Claude Code plugin marketplace

This repo ships Claude Code **plugins**, not an application. The "source" is prompt files
(`SKILL.md`), so there is no unit-test suite — verifying a change usually means reading the prompt
and the `CHANGELOG.md`, then running the skill. The exception is behavioral guards that must hold
on a budget model: `plugins/case-solvers/tests/model-guard.sh` runs the authoring commands (`/case`
and `/refine`) on Haiku headless across multiple trials (including override-injection descriptions)
and asserts the model-tier guard stops each. It calls the real model, so it's slow and probabilistic
— run it when changing either Model Guard.

## What this is

`.claude-plugin/marketplace.json` publishes two plugins under `plugins/`:

- **case-solvers** — `/case`, `/refine`, `/board`, `/solve`, `/evaluate`: a bd-backed,
  parallel-capable coding workflow.
- **writing-claude-md** — `/writing-claude-md`: authoring lean, high-signal context files.

## Philosophy (this drives how every skill is worded)

- **Three model tiers; one command per job.** The planning/frontier tier authors the **WHAT**
  (requirement, boundary, contract): `/case` writes a *new* story/epic, `/refine` revises an
  *existing* story — both gated to a planning model and sharing one set of rubrics. The budget tier
  does the **HOW**: `/solve` writes code in an isolated worktree+branch. The human tier is
  `/evaluate`, the review-and-merge gate. `/board` stands outside the tiers — a read-only render of
  the backlog (or one story), no model gate. A skill recognizes its own tier from its system prompt.
- **Invocation tracks blast radius, not read/write.** The tier-gated/side-effecting commands
  (`/case`, `/solve`, `/evaluate`) are slash-only (`disable-model-invocation`) so they never
  auto-fire mid-conversation. The low-risk ones are model-invocable: `/board` (read-only) and
  `/refine` (names an id, confirm + tier guard backstop it), so plain-English asks like "show
  story 5" or "update story 5" route to them.
- **bd is the engine, not the interface.** bd (Beads) is the durable issue store, but the
  plugin's end user never types a `bd` command and never sees raw bd output — skills translate
  to/from bd and render human-friendly. Keep bd hidden when editing skill prose. (This is the
  *opposite* of how you, the agent working on this repo, track your own tasks — see below.)
- **Story = WHAT, solver = HOW.** A story states a testable, unambiguous outcome — never the
  mechanism. "Specific ≠ prescriptive."

## Editing skills

- Bump the skill's frontmatter `version` and add a `CHANGELOG.md` entry in the same change. The
  marketplace/plugin `version` tracks the published plugin, not the per-skill frontmatter versions.
- `/case` and `/refine` share the contract rubrics in `plugins/case-solvers/shared/contract-rubrics.md`
  (Problem Types, Budget-Solver Fit, AC Quality Rubric, Pre-write Guard, Output Format). Edit them
  there once — don't copy rubric prose back into a skill. Each skill's **Model Guard** stays inline,
  though: it's the always-loaded security gate and must run before anything is read.
- `AGENTS.md` is a symlink to this file — edit `CLAUDE.md`.

> If the code contradicts anything above, the code wins — update this file in the same change.
