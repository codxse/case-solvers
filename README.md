# Case Solvers

A Claude Code plugin marketplace by [codxse](https://github.com/codxse). Currently ships two plugins:

| Plugin | Skills | Purpose |
|--------|--------|---------|
| `case-solvers` | `/case`, `/solve` | Two-phase coding workflow: architect contract → budget-solver execution |
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

## `case-solvers` — Two-phase coding workflow

A capable **planning model** acts as the architect and defines *what* to build; a cheap
**budget model** acts as the solver and does *how* to build it.

- **`/case`** — runs on a planning model — any frontier model (e.g. Opus / Sonnet / Fable / Mythos / Gemini Pro). Defines the problem precisely and writes `.case.md`: the requirement, boundaries, and acceptance criteria. Refuses to run on a budget model.
- **`/solve`** — designed for a budget model (Haiku / Gemini Flash / MiniMax-M3). Reads `.case.md`, explores the codebase, picks the mechanism, and implements test-first — one milestone per pass.

The two are a loop: when a slice is too vague or a human rejects the result, `/solve` writes `.handoff.md` and stops; `/case` reads it and refines the contract.

### Usage

```
/case <problem description>      # planning model → writes .case.md
# switch to a budget model (/model), then:
/solve                           # budget model → implements against the contract
```

Typical flow:

1. On a planning model, run `/case` to turn a task into a precise, verifiable contract.
2. Switch to a budget model and run `/solve` to implement it test-first.
3. If `/solve` writes `.handoff.md` (pre-flight gap or human rejection), switch back to a planning model and run `/case` again to refine, then resume `/solve`.

### Runtime artifacts

These files are written into your **working project** (not this repo):

| File | Written by | Purpose |
|------|------------|---------|
| `.case.md` | `/case` | The problem definition (the WHAT) — the contract. |
| `.solve-progress.md` | `/solve` | Milestone/slice progress tracking. |
| `.handoff.md` | `/solve` | Feedback to `/case` on rejection or pre-flight gap. |

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
