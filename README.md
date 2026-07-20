# Case Solvers

Two agent plugins for **Claude Code** and **OpenAI Codex** — same skills, either host.

| Plugin | Skills | Purpose |
|--------|--------|---------|
| `case-solvers` | `/case`, `/refine`, `/board`, `/solve`, `/evaluate`, `/orchestrate` | bd-backed, parallel coding workflow: author stories/epics → solve in worktrees → review & merge, or automate a whole epic behind one PR |
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

Same two plugins on either host. Add the marketplace once, then install what you want.

**Claude Code**

```
/plugin marketplace add codxse/case-solvers
/plugin install case-solvers@case-solvers
/plugin install writing-claude-md@case-solvers
```

Type the commands in a Claude Code session (not your shell). `/plugin` on its own opens the plugin
browser if you'd rather click. Verify with `/help` — the new commands appear in the list.

**Codex**

```
codex plugin marketplace add codxse/case-solvers
codex plugin add case-solvers@case-solvers
codex plugin add writing-claude-md@case-solvers
```

These run in your shell, not in a Codex session, and need a Codex CLI new enough to have the plugin
subcommand — check with `codex plugin --help`. Verify the install with `codex plugin list`.

On Codex, `/solve` and `/evaluate` are **slash-only** — they bake work into a branch, so they never
auto-fire mid-conversation. `/case`, `/refine`, `/board`, and `/orchestrate` also answer plain
English (for example, "run the epic" or "show the board"). Invoke any plugin skill explicitly with
its qualified name, such as `$case-solvers:orchestrate <epic-id>`.

**Requirements:** the `bd` CLI on your `PATH` for `case-solvers` — see
[the command reference below](#case-solvers--bd-backed-parallel-coding-workflow). `/orchestrate`
additionally needs the `gh` CLI, authenticated, for opening its final PR. `writing-claude-md` has no
dependencies.

**Reviewer agents (recommended):** the plugin ships two review-and-apply agent definitions —
`case-reviewer` (cheapest frontier tier) and `case-reviewer-strong` (strongest) — that `/evaluate`
prefers when spawning its review pass, so the reviewer's model pin is enforced by the agent
definition instead of prose. On **Claude Code** they load automatically with the plugin. On
**Codex**, plugins don't auto-load agents yet — copy the TOML templates into your project once:

```sh
cp ~/.codex/plugins/cache/case-solvers/case-solvers/<version>/agents/*.toml .codex/agents/
```

Without them, `/evaluate` falls back to pinning the model explicitly on a general subagent — same
behavior, just enforced by prose rather than the harness.

**Custom models (a router / custom host):** the plugin also runs on Claude Code pointed at a
non-Anthropic model — a router or gateway. The tier map (`shared/model-tiers.md`) classifies such a
model as **planning** when its ID matches a frontier marker (e.g. `qwen3.8-max-preview`), so `/case`,
`/refine`, and `/orchestrate` work on it. For `/evaluate`'s reviewer pin, set
**`CLAUDE_CODE_SUBAGENT_MODEL`** to your frontier model's ID — Claude Code applies it to every
subagent and it **overrides** the reviewer agents' `model:` frontmatter, so the review pass runs on
the model you name:

```sh
export CLAUDE_CODE_SUBAGENT_MODEL=qwen3.8-max-preview
```

⚠️ This variable is **global and single-valued**: it sets the model for *all* subagents (solvers and
reviewers alike) and overrides every per-agent pin. Set it to a **frontier** model — point it at a
budget model to save on `/solve` and the reviewer runs on that budget model too, which is exactly the
failure the frontier pin exists to prevent. Leave it unset and `/evaluate` falls back to pinning the
reviewer to the session's own model ID (the custom-host branch of the Reviewer-pinning map).

**Gating:** `/case`, `/refine`, and `/orchestrate` require a **frontier model**; `/solve` runs on any
tier. Each checks its own model ID and stops with a message telling you to switch, so a wrong tier
costs you a line of output, never a bad story.

### Updating

**Claude Code**

```
/plugin update case-solvers
```

**Codex** — refresh the Git marketplace snapshot, then install the new plugin version:

```sh
codex plugin marketplace upgrade case-solvers
codex plugin add case-solvers@case-solvers
```

For the context-writing plugin, substitute its name in the second command:

```sh
codex plugin add writing-claude-md@case-solvers
```

These run in your shell. Confirm the installed version with `codex plugin list`, then start a new
Codex session so it reloads the updated skills. Both hosts key updates off the plugin's `version`
and install each version into its own directory.

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

On a **frontier model** (Opus / Sonnet / Fable / Gemini Pro / GPT-5-class / Qwen3.8-Max-class) —
author the *what*:

- **`/case <description>`** → one **story** (a precise, verifiable contract), or a big goal decomposed
  into an **epic** (a dependency graph of stories) for you to review *before* anything is created. Each
  story also gets a **Complexity** call — the cheapest solver tier (budget/medium/frontier) and effort
  likely to succeed — so you know which model to run `/solve` on.
- **`/refine <id>`** → revises an existing story's contract from a `/solve` spec-gap, an `/evaluate`
  change-request, or your own ask — stays WHAT-only, returns it to ready.
- **`/orchestrate <epic-id>`** → automates the `/solve` → review → land loop across a whole epic's
  stories, landing each on an integration branch instead of one at a time by hand, and stops at a
  single pull request for you to review and merge — the one human gate for the epic. Stories run one
  at a time by default (a `--parallel` flag opts into dispatching a ready wave concurrently, at the
  cost of cross-story merge conflicts on epics whose stories touch the same files). It runs
  unsupervised for most of the epic, which is why it needs the same tier as `/case`/`/refine`.

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

For an epic, `/orchestrate <epic-id>` automates that whole solve-review-land cycle instead of you
running it story by story — it works on an integration branch, reviews every story itself at the
effort its Complexity call recommends, and only asks for you once, at the end, on the one PR that
merges the epic.

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
