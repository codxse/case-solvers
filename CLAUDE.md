# Case Solvers — a Claude Code plugin marketplace

This repo ships Claude Code **plugins**, not an application. The "source" is prompt files
(`SKILL.md`), so there is no unit-test suite — verifying a change usually means reading the prompt
and the `CHANGELOG.md`, then running the skill. The exception is behavioral guards that must hold
on a budget model: `plugins/case-solvers/tests/model-guard.sh` runs `/case` on Haiku headless
across multiple trials (including override-injection descriptions) and asserts the model-tier
guard stops it. It calls the real model, so it's slow and probabilistic — run it when changing the
`/case` Model Guard.

## What this is

`.claude-plugin/marketplace.json` publishes two plugins under `plugins/`:

- **case-solvers** — `/case`, `/solve`, `/evaluate`: a bd-backed, parallel-capable coding workflow.
- **writing-claude-md** — `/writing-claude-md`: authoring lean, high-signal context files.

## Philosophy (this drives how every skill is worded)

- **Three model tiers, three commands.** `/case` runs on a planning/frontier model and authors
  the **WHAT** (requirement, boundary, contract); `/solve` runs on a budget model and does the
  **HOW** (code, in an isolated worktree+branch); `/evaluate` is the human review-and-merge gate.
  A skill is expected to recognize its own tier from its system prompt.
- **bd is the engine, not the interface.** bd (Beads) is the durable issue store, but the
  plugin's end user never types a `bd` command and never sees raw bd output — skills translate
  to/from bd and render human-friendly. Keep bd hidden when editing skill prose. (This is the
  *opposite* of how you, the agent working on this repo, track your own tasks — see below.)
- **Story = WHAT, solver = HOW.** A story states a testable, unambiguous outcome — never the
  mechanism. "Specific ≠ prescriptive."

## Editing skills

- Bump the skill's frontmatter `version` and add a `CHANGELOG.md` entry in the same change. The
  marketplace/plugin `version` tracks the published plugin, not the per-skill frontmatter versions.
- `AGENTS.md` is a symlink to this file — edit `CLAUDE.md`.

> If the code contradicts anything above, the code wins — update this file in the same change.
