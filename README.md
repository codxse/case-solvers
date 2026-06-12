# Case Solvers

A Claude Code plugin marketplace by [codxse](https://github.com/codxse). Currently ships two plugins:

| Plugin | Skills | Purpose |
|--------|--------|---------|
| `case-solvers` | `/case`, `/solve`, `/evaluate` | bd-backed, parallel-capable workflow: author stories/epics → solve in worktrees → review & merge |
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
them anytime, in parallel. **bd stays hidden**: you only ever type the three commands.

**Requirements:** the `bd` (Beads) CLI must be installed and on your `PATH` — `brew install
beads` (or `npm i -g @beads/bd`, or `go install github.com/steveyegge/beads@latest`). The
skills assume it's present (they no longer check) and run `bd init` in your project on first
use.

### The three commands

- **`/case`** — planning model (any frontier model: Opus / Sonnet / Fable / Mythos / Gemini Pro).
  - `/case <description>` → authors one **story** (a precise, verifiable contract), or
    decomposes a big goal into an **epic** (a dependency graph of stories) for you to review
    *before* anything is created.
  - `/case` → the **board**: backlog, in progress, done & awaiting merge, blocked.
  - `/case --id <id>` → one story's contract + its comments.
- **`/solve <id>`** — budget model (Haiku / Gemini Flash / MiniMax-M3). Refuses with a reason
  if the story is still blocked; otherwise claims it, works in its own git **worktree+branch**
  test-first, and stops at *done · review*. Never merges.
- **`/evaluate <id>`** — opens the branch in **VSCode** so you review the diff, then enacts
  your verdict: **approve** → merge to `main`, close the story, unblock dependents;
  **request changes** → feedback goes back to `/solve` (or `/case`).

### Typical flow

1. `/case` to capture stories anytime (or decompose an epic, reviewing the graph first).
2. On a budget model, `/solve <id>` the ones you want — run several in separate sessions to
   work in parallel; each gets an isolated worktree.
3. `/evaluate <id>` to review in VSCode and merge. Approving unblocks dependent stories.

You are the scheduler: you pick what to solve and what to merge. `bd` enforces dependencies (a
blocked story is refused with a reason) and the agents stay guardrailed workers.

### Runtime artifacts

Stored in **your working project** (not this repo):

| What | Where | Purpose |
|------|-------|---------|
| Stories / epics | `.beads/` (git-committed) | The durable backlog + dependency graph. |
| Feedback / refine notes | bd comments on a story | Per-story review feedback (refine notes + your verdicts). |
| Work under review | git worktrees on `bd/<id>` | Isolated branch per story awaiting `/evaluate`. |

Read them via `/case` and `/case --id <id>` — you never need `bd` commands directly.

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
