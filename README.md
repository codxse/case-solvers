# Case Solvers

A Claude Code plugin marketplace by [codxse](https://github.com/codxse). Currently ships two plugins:

| Plugin | Skills | Purpose |
|--------|--------|---------|
| `case-solvers` | `/case`, `/refine`, `/board`, `/solve`, `/evaluate` | bd-backed, parallel-capable workflow: author stories/epics → solve in worktrees → review & merge |
| `writing-claude-md` | `/writing-claude-md` | Write lean, high-signal CLAUDE.md / AGENTS.md context files |

## Install

```
/plugin marketplace add codxse/case-solvers
```

Then install whichever plugins you want:

```
/plugin install case-solvers@case-solvers
/plugin install writing-claude-md@case-solvers
```

---

## `case-solvers` — bd-backed, parallel-capable coding workflow

A capable **planning model** acts as the architect (`/case`) and defines *what* to build; a
cheap **budget model** acts as the solver (`/solve`) and does *how*; you review and merge
(`/evaluate`). Work lives in [**bd** (Beads)](https://github.com/steveyegge/beads) — a
git-backed, dependency-aware issue tracker — so you can stockpile many tasks and solve any of
them anytime, in parallel. **bd stays hidden**: you only ever type the slash commands, never `bd`.

**Requirements:** the `bd` (Beads) CLI must be installed and on your `PATH` — `brew install
beads` (or `npm i -g @beads/bd`, or `go install github.com/steveyegge/beads@latest`). The
skills assume it's present (they no longer check) and run `bd init` in your project on first
use.

To skip permission prompts, add this to `.claude/settings.json` in your project:

```json
{
  "allowedTools": [
    "Bash(bd *)",
    "Bash(code *)"
  ],
  "permissions": {
    "allow": [
      "Bash(cat *)",
      "Bash(ls)",
      "Bash(ls *)",
      "Bash(find *)",
      "Bash(grep *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(wc *)",
      "Bash(file *)",
      "Bash(stat *)",
      "Bash(pwd)",
      "Bash(echo *)",
      "Bash(which *)",
      "Bash(type *)",
      "Bash(git log*)",
      "Bash(git diff*)",
      "Bash(git status*)",
      "Bash(git show*)",
      "Bash(git branch*)",
      "Bash(bd show*)",
      "Bash(bd list*)",
      "Bash(bd ready*)",
      "Bash(bd blocked*)",
      "Bash(bd stats*)",
      "Read"
    ]
  }
}
```

`allowedTools` covers `bd` and `code` commands. `permissions.allow` silently allows all read-only shell operations (file inspection, grep, git reads, bd queries) and the `Read` tool so the skills never prompt for codebase exploration.

### The commands

**Planning model** (any frontier model: Opus / Sonnet / Fable / Mythos / Gemini Pro) — authors the *what*:

- **`/case <description>`** → authors one **story** (a precise, verifiable contract), or decomposes
  a big goal into an **epic** (a dependency graph of stories) for you to review *before* anything is
  created. Authoring only.
- **`/refine <id>`** → revises an existing story's contract — applies feedback from a `/solve`
  spec-gap or an `/evaluate` change-request (or a change you ask for), keeps it WHAT-only, and
  returns it to ready.

**Any model, read-only** — shows your work:

- **`/board`** → the **board**: backlog, in progress, done & awaiting merge, blocked. `/board <id>`
  shows one story's contract + its comments.

**Budget model** (Haiku / Gemini Flash / MiniMax-M3) — does the *how*:

- **`/solve <id>`** → refuses with a reason if the story is still blocked; otherwise claims it,
  works in its own git **worktree+branch** test-first, and stops at *done · review*. Never merges.

**Review & merge:**

- **`/evaluate <id>`** → opens the branch in **VSCode** so you review the diff, then enacts your
  verdict: **approve** → merge to `main`, close the story, unblock dependents; **request changes** →
  feedback goes back to `/solve` (or `/refine`).

### Typical flow — worked examples

You are the scheduler: you pick what to author, what to solve, and what to merge. The loop is
**author → solve → evaluate**, with `/board` to look at your work any time. Three concrete runs:

#### Author one story

On a planning model, capture a task as a precise contract:

```
/case add a forgot-password reset email flow
```

You see: the skill drafts the contract to a transient `.case.md` staging file, may ask one or two
scoping questions (each with a recommended answer), then waits. When you say *"looks good"*, it
creates the story and replies with the new id and the next step:

> Created story **c-fp**. Run `/solve c-fp` on a budget model to build it, or `/board c-fp` to
> re-read the contract.

At any point, `/board` shows the whole backlog; `/board c-fp` shows just this story.

#### Refine a story back to ready

A story comes back marked `needs-refinement` — a `/solve` hit a spec gap, or `/evaluate` requested a
change. Revise the *contract* (not the code) on a planning model:

```
/refine c-fp
```

You see: the skill reads the reviewer's feedback from the story's comments, rewrites the contract to
close the gap, and returns the story to ready — then it points you back to `/solve c-fp`.

#### Decompose a large goal into an epic

When a goal is too big for one budget pass, `/case` switches to epic mode and reviews the breakdown
with you *before* creating anything:

```
/case ship SSO across the whole app
```

You see: the skill drafts a decomposition doc to `.case.md` — an ordered set of stories with the
dependency graph between them (Gate 0). You edit it or approve it; only on your *"go ahead"* does it
create the stories and links in bd, then reports the new ids. `/board` now shows the epic and which
stories block which.

#### Then: solve and evaluate

On a budget model, `/solve <id>` each story you want — run several in separate sessions to work in
parallel, each in its own isolated worktree+branch. `/evaluate <id>` opens the branch in VSCode,
merges to `main` on approve, and unblocks any dependents. `bd` enforces dependencies throughout (a
blocked story is refused with a reason), so the agents stay guardrailed workers.

### Runtime artifacts

Stored in **your working project** (not this repo):

| What | Where | Purpose |
|------|-------|---------|
| Stories / epics | `.beads/` (git-committed) | The durable backlog + dependency graph. |
| Feedback / refine notes | bd comments on a story | Per-story review feedback (refine notes + your verdicts). |
| Work under review | git worktrees on `bd/<id>` | Isolated branch per story awaiting `/evaluate`. |

Read them via `/board` and `/board <id>` — you never need `bd` commands directly.

---

## `writing-claude-md` — Write lean project context

Helps you write `CLAUDE.md` and `AGENTS.md` that only include what can't be derived from the code. Teaches the litmus test: *"Can an LLM learn this by reading the code?"* — if yes, omit it.

### Usage

```
/writing-claude-md
```

---

## License

MIT © 2026 nadiar
