# Case Solvers

Two agent plugins for **Claude Code** and **OpenAI Codex** — same skills, either host.

| Plugin | Skills | Purpose |
|--------|--------|---------|
| `case-solvers` | `/case`, `/refine`, `/board`, `/solve`, `/evaluate` | bd-backed, parallel coding workflow: author stories/epics → solve in worktrees → review & merge |
| `writing-claude-md` | `/writing-claude-md` | Write lean, high-signal CLAUDE.md / AGENTS.md context files |

## Why I built this

I don't trust AI to one-shot a big app. I don't think that's where it's good — and I don't think
that's the point.

What today's AI *is* good at is **following instructions**. So my job changed. It's no longer to write
the code; it's to write the **instruction the AI will follow**. The hard part moved up a level.

The unit of that instruction is a **story**: a bounded, unambiguous primitive of work. This isn't a
new idea — it's the same "story" agile has always meant: one small, testable outcome. I lean on it
here for a specific reason about how models behave.

**Cheap models follow bounded, unambiguous instructions reliably, but degrade as a task grows in
ambiguity and scope.** It isn't about context window size — many cheap models have huge ones. It's
**reasoning capacity under ambiguity**: hand a budget model a large, vague, multi-step goal and it
drifts; hand it a tight, well-bounded story and it executes. So the fix is never "use a smaller
prompt" — it's "shrink the ambiguity." A story *is* that shrinking.

But writing a good story is its own hard problem. Often **I don't actually know what I want** until
something forces me to say it precisely. That's the job of a **frontier model**: not to write code,
but to *grill me* — to understand me and turn a fuzzy intent into a clear contract. Authoring a story
is a feedback loop, human-steered. I stay in it because only I know what I actually want.

A story says **WHAT and WHY — never HOW**. It states the outcome and why it matters; it bounds the
search space (what to look at, what's out of scope). It does **not** dictate the mechanism — which
function, which pattern, which file. The frontier model isn't remote-controlling the budget model.
It's handing it a clear primitive and getting out of the way.

Because a story is a *testable* outcome, the solver proves it the way I would — **red, green,
refactor.** Write the failing test that encodes the story's acceptance criteria (red), make it pass
with the simplest thing that works (green), then clean it up (refactor). The test is the contract
made executable: it's how I know the bounded outcome was actually met, not just claimed.

When a goal is too big for one story, I break it into an **epic** — a graph of stories — the same way
agile does.

And I stay in the loop at the **end**, too. As an engineer I need to know what I shipped: to learn
from it, and to reject what isn't right or isn't to my taste. AI doesn't get to approve its own work
into `main`.

So three roles fall out, each matched to the model that's actually good at it:

- **Frontier model — the architect.** Grills me into a clear story (WHAT/WHY). `/case`, `/refine`.
- **Budget model — the solver.** Executes one bounded story (HOW). `/solve`.
- **Me — the evaluator.** Reviews and merges. `/evaluate`.

Using a frontier model for *everything* is economically silly. This split is the sweet spot: pay for
the expensive model only where judgment is needed, let the cheap model do the bounded work, and keep
the human where the human is irreplaceable.

**This is not vibe coding.** Vibe coding lets the model run and accepts output you didn't read. This
is the opposite: I follow every change. It's closer to pairing with a real engineer — except I can
run several in parallel, each on its own bounded story. The thing that scales here isn't the app or
the model's output; it's the **code I can actually keep up with**. Throughput is bounded by how many
stories I can follow and evaluate at once — and that's deliberate, not a limitation. The human stays
the bottleneck on purpose. Which means **this isn't for everyone**: if you'd rather not look at the
code, this isn't your tool.

The stories live in [**bd** (Beads)](https://github.com/steveyegge/beads) so I can record them and
solve many in parallel — but you never type a `bd` command. The skills keep it hidden.

> Why "case" and not "spec" or "problem"? Plain naming I'd have preferred wasn't invokable outside
> Claude Code. So: a **case** — something you open, work, and close.

## Install

**Claude Code**

```
/plugin marketplace add codxse/case-solvers
/plugin install case-solvers@case-solvers
/plugin install writing-claude-md@case-solvers
```

**Codex**

```
codex plugin marketplace add codxse/case-solvers
codex plugin add case-solvers@case-solvers
codex plugin add writing-claude-md@case-solvers
```

> **Install the plugin, not loose skill folders.** `/case` and `/refine` read shared rubrics at the
> plugin root (`../../shared/...`); plugin installs copy the whole directory, so this resolves.
> Copying only `skills/<name>/` leaves the rubrics behind and breaks both commands.

**Gating:** `/case` and `/refine` require a **frontier model**; `/solve` runs on any tier.

---

## `case-solvers` — bd-backed, parallel coding workflow

The [three roles](#why-i-built-this) as commands: the **architect** (`/case`, `/refine`), the
**solver** (`/solve`), and you, the **evaluator** (`/evaluate`). Work lives in
[**bd** (Beads)](https://github.com/steveyegge/beads) — a git-backed, dependency-aware issue tracker
— so you can stockpile many stories and solve any of them anytime, in parallel. **bd stays hidden**:
you only ever type the slash commands, never `bd`.

**Requirements:** the `bd` CLI on your `PATH` — `brew install beads` (or `npm i -g @beads/bd`, or
`go install github.com/steveyegge/beads@latest`). The skills assume it's present and run `bd init` on
first use.

<details>
<summary>To skip permission prompts, add this to <code>.claude/settings.json</code></summary>

```json
{
  "allowedTools": ["Bash(bd *)", "Bash(code *)"],
  "permissions": {
    "allow": [
      "Bash(cat *)", "Bash(ls)", "Bash(ls *)", "Bash(find *)", "Bash(grep *)",
      "Bash(head *)", "Bash(tail *)", "Bash(wc *)", "Bash(file *)", "Bash(stat *)",
      "Bash(pwd)", "Bash(echo *)", "Bash(which *)", "Bash(type *)",
      "Bash(git log*)", "Bash(git diff*)", "Bash(git status*)", "Bash(git show*)", "Bash(git branch*)",
      "Bash(bd show*)", "Bash(bd list*)", "Bash(bd ready*)", "Bash(bd blocked*)", "Bash(bd stats*)",
      "Read"
    ]
  }
}
```

This allows `bd`/`code` plus read-only shell (file inspection, grep, git reads, bd queries) so the
skills never prompt for codebase exploration.

</details>

### The commands

On a **frontier model** (Opus / Sonnet / Fable / Gemini Pro / GPT-5-class) — author the *what*:

- **`/case <description>`** → one **story** (a precise, verifiable contract), or a big goal decomposed
  into an **epic** (a dependency graph of stories) for you to review *before* anything is created.
- **`/refine <id>`** → revises an existing story's contract from a `/solve` spec-gap, an `/evaluate`
  change-request, or your own ask — stays WHAT-only, returns it to ready.

On a **budget model** (Haiku / Gemini Flash / MiniMax-M3) — do the *how*:

- **`/solve <id>`** → refuses if the story is blocked; otherwise claims it, works test-first in its
  own git **worktree+branch**, and stops at *done · review*. Never merges.

On **any model**:

- **`/board`** → backlog, in progress, awaiting merge, blocked. `/board <id>` shows one story.
- **`/evaluate [<id>]`** → opens the branch in **VSCode** to review the diff, then enacts your
  verdict: **approve** merges to `main`, closes the story, unblocks dependents; **request changes**
  sends feedback to `/solve` or `/refine`. Flags skip VSCode: `--approve`, `--request-changes`,
  `--note <text>` (on either path).

### Typical flow

You're the scheduler; the loop is **author → solve → evaluate**, `/board` to look any time.

```
/case add a forgot-password reset email flow
```

`/case` drafts the contract to a transient `.case.md`, asks one or two scoping questions, then waits.
On your *"looks good"* it creates the story and hands you the next step (`/solve <id>`). For a goal
too big for one pass — `/case ship SSO across the whole app` — it switches to epic mode and shows you
the full decomposition + dependency graph *before* creating anything.

Then, on a budget model, `/solve <id>` each story — run several in parallel, each in its own
worktree+branch. `/evaluate <id>` reviews and merges, unblocking dependents. If a story comes back
`needs-refinement`, `/refine <id>` rewrites the *contract* (not the code) and returns it to ready.
`bd` enforces dependencies throughout, so a blocked story is always refused with a reason.

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
