# Case Solvers

A two-phase coding workflow for Claude Code, packaged as a plugin. A capable
**planning model** acts as the architect and defines *what* to build; a cheap
**budget model** acts as the solver and does *how* to build it.

- **`/spec`** — runs on a planning model (Opus / Sonnet / Gemini Pro). Defines the
  problem precisely and writes `.architect-plan.md`: the requirement, boundaries, and
  acceptance criteria. It refuses to run on a budget model, and stops to rescope if the
  problem is too large for a budget solver to finish in one pass.
- **`/solve`** — designed for a budget model (Haiku / Gemini Flash / MiniMax-M3). Reads
  `.architect-plan.md`, explores the codebase, picks the mechanism, and implements
  test-first — one milestone per pass. It pauses for human verification where required.

The two are a loop: when a slice is too vague to build, or a human rejects the result,
`/solve` writes `.handoff.md` and stops; `/spec` reads it and refines the contract.

## Install

```
/plugin marketplace add nadiar/case-solvers
/plugin install case-solvers@case-solvers
```

This installs both `/spec` and `/solve` (namespaced `case-solvers:spec` /
`case-solvers:solve`).

## Usage

```
/spec <problem description>      # planning model → writes .architect-plan.md
# switch to a budget model (/model), then:
/solve                           # budget model → implements against the contract
```

Typical flow:

1. On a planning model, run `/spec` to turn a task into a precise, verifiable contract.
2. Switch to a budget model and run `/solve` to implement it test-first.
3. If `/solve` writes `.handoff.md` (pre-flight gap or human rejection), switch back to a
   planning model and run `/spec` again to refine, then resume `/solve`.

## Runtime artifacts

These files are written into your **working project** (not this repo):

| File                  | Written by | Purpose                                            |
| --------------------- | ---------- | -------------------------------------------------- |
| `.architect-plan.md`  | `/spec`    | The problem definition (the WHAT) — the contract.  |
| `.solve-progress.md`  | `/solve`   | Milestone/slice progress tracking.                 |
| `.handoff.md`         | `/solve`   | Feedback to `/spec` on rejection or pre-flight gap. |

## License

MIT © 2026 nadiar
