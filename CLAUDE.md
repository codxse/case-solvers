# Case Solvers — a Claude Code & Codex plugin marketplace

This repo ships agent **plugins**, not an application. The "source" is prompt files (`SKILL.md`), so
there is no unit-test suite — verifying a change usually means reading the prompt and the
`CHANGELOG.md`, then running the skill.

**Two hosts, one `skills/` tree.** The skill bodies are shared verbatim between Claude Code and
OpenAI Codex — their plugin layouts mirror each other, so each plugin carries two manifests
(`.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`) over the *same* `skills/<name>/SKILL.md`
files, and the repo carries two marketplaces (`.claude-plugin/marketplace.json`,
`.agents/plugins/marketplace.json`). Never fork the skill prose per host — edit the one SKILL.md.
Host-specific bits live outside the prose: Claude's `disable-model-invocation` frontmatter ↔ Codex's
per-skill `agents/openai.yaml` (`policy.allow_implicit_invocation: false`). The exception is behavioral guards that must hold
on a budget model: `plugins/case-solvers/tests/model-guard.sh` runs the authoring commands (`/case`
and `/refine`) on Haiku headless across multiple trials (including override-injection descriptions)
and asserts the model-tier guard stops each. It calls the real model, so it's slow and probabilistic
— run it when changing either Model Guard.

## What this is

`.claude-plugin/marketplace.json` (Claude Code) and `.agents/plugins/marketplace.json` (Codex)
publish the same two plugins under `plugins/`:

- **case-solvers** — `/case`, `/refine`, `/board`, `/solve`, `/evaluate`: a bd-backed,
  parallel-capable coding workflow.
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
  Claude, GPT-5-class on Codex).
- **Invocation tracks blast radius, not read/write.** The high-blast-radius commands that bake work
  into a branch — `/solve` (writes code) and `/evaluate` (merges + closes) — are slash-only
  (`disable-model-invocation` on Claude / `allow_implicit_invocation: false` on Codex) so they never
  auto-fire mid-conversation. The rest are model-invocable so plain-English asks route to them:
  `/board` (read-only), `/refine` (names an id), and `/case` (authors a new story/epic — a
  plain-English ask like "let's put our problem to a case" should reach it). `/case` and `/refine`
  write to bd but are backstopped the same way: the planning-tier **Model Guard** runs first and
  **nothing is committed to bd until the user confirms**, so an implicit fire can't silently author
  on the wrong tier or without sign-off. Their model-invocable skills carry no
  `disable-model-invocation` / `allow_implicit_invocation: false` gate (and no `agents/openai.yaml`
  at all on Codex) — presence of that gate is the at-a-glance marker of a slash-only skill.
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
  (Problem Types, Budget-Solver Fit, AC Quality Rubric, Pre-write Guard, Output Format). Edit them
  there once — don't copy rubric prose back into a skill. Each skill's **Model Guard** stays inline,
  though: it's the always-loaded security gate and must run before anything is read.
  - The skills reach the rubrics by relative path (`../../shared/contract-rubrics.md`), which only
    resolves when the **whole plugin directory** is present. Both hosts' plugin installs copy the full
    dir, so this holds — but it means these skills must be distributed **as a plugin**, never as loose
    `skills/<name>/` folders dropped into `~/.agents/skills` (Codex) or anywhere the `shared/` sibling
    is left behind. Don't recommend a skills-only copy for case/refine.
- `AGENTS.md` is a symlink to this file — edit `CLAUDE.md`.

> If the code contradicts anything above, the code wins — update this file in the same change.
