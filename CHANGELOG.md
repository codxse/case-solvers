# Changelog

All notable changes to the **case-solvers** marketplace are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Versions track the published plugin/marketplace, not the skills' internal frontmatter
versions (shown in parentheses where relevant).

## [Unreleased]

## [2.19.0] - 2026-07-18

Plugin & marketplace entry `case-solvers` `2.18.0` → `2.19.0`. New skill **`/orchestrate`**
(`1.0.0`). `/evaluate` (`1.9.0` → `1.10.0`).

**Added: `/orchestrate <epic-id>` automates the story-by-story `/solve` → review → land loop for
one epic, collapsing today's manual "solve one, evaluate one, repeat" cycle into a single run with
exactly one human gate at the end.** It checks out (or resumes) an integration branch `epic/<id>` —
forked from whatever's checked out in the main worktree, never a hardcoded trunk, the same rule
`/solve`/`/evaluate` already follow — and keeps the main worktree on it for the whole run, so every
dispatched `/solve` naturally forks from it and every landed story naturally merges back onto it,
with zero changes to `/solve` or `/evaluate`'s own base-branch logic. Each cycle it reads the
epic's live readiness (`bd swarm status`) and dispatches `/solve` in parallel across every ready
story, model-pinned per story to its own `solver-<tier>` label — the first place the Complexity
Tier recommendation is actually acted on automatically, not just displayed for a human to read.
Once a story reaches `needs-review` it always goes through a mandatory, orchestrator-judgment-free
review pass at the effort its own `## Complexity` section recommends, then lands one at a time
through bd's own `merge-slot` primitive — the lock bd ships specifically to stop concurrent landers
from cascading conflicts into each other. A spec-gap or scope observation surfaced mid-run is never
acted on by `/orchestrate` itself — authoring or revising a contract stays the human's call via
`/case`/`/refine`; the run queues it for the final report instead. `/orchestrate` itself now also
requires a **planning model**, the same Model Guard `/case` and `/refine` carry — it runs
unsupervised for most of an epic (pre-flight go/no-go, stalled-story triage, the final PR's
summary), which is exactly the kind of judgment this workflow otherwise reserves for a frontier
tier. To keep the near-certain class of
conflict this repo's own history is full of (virtually every skill-editing story touches the same
four version manifests and `CHANGELOG.md`) out of the merge-slot machinery entirely,
`/orchestrate` tells every dispatched story to leave those files alone and performs the one
epic-level version bump + changelog entry itself, once, at the end. The run finishes by opening
**one PR, `epic/<id>` → the branch it was forked from** — each story already its own single commit
(`--approve`'s existing one-commit rule), so the PR reads story-by-story rather than as one
rubber-stampable diff — and that PR is the **only** real human-loop gate: everything on `epic/<id>`
before it is provisional until it merges. `/orchestrate` is slash-only (`agents/openai.yaml`,
`allow_implicit_invocation: false`), the same classification as `/solve` and `/evaluate` — it
transitively fires both, so it inherits their blast radius.

**Added: `/evaluate --review [effort] --unattended`.** The existing `--review` fast path still
hard-stops at step 4b.3 for a human "amend these into `bd/<id>`?" confirm — exactly the per-story
pause `/orchestrate` exists to remove from its own loop. Rather than fork the review-and-apply
mechanism into `/orchestrate` too, `/evaluate` gains one modifier: `--unattended` still spawns the
frontier-pinned subagent, runs `/code-review <effort> --fix`, and shows what changed — it just
replaces the human go-ahead with an automatic one. The name is deliberately explicit rather than a
terse `--auto`: this flag skips `/evaluate`'s own core safety property, so its use is meant to be
provisional (an epic integration branch, not `master`/`main`) with a real human review still coming
later, at the epic's final PR — never for a human approving straight to trunk.

This design was reviewed twice by a Fable-tier model before implementation. The first pass caught
that autonomously running `/evaluate --approve` per story contradicts the repo's own human-loop
principle unless landings happen on a reversible branch with a real gate at the end, that "judge
whether review is needed" has no rubric and is exactly the judgment `/evaluate` exists to keep
human, and that autonomous `/case` mid-loop breaks the "nothing commits to bd until the user
confirms" guard. The second pass, after the user pushed back on blanket serialization (bd already
tracks dependencies — independent stories should run in parallel), found that `/evaluate`'s own
step 4a.4 already implements the exact conflict-handling pattern the design was about to reinvent,
and proposed removing the mechanical conflict class by construction instead of auto-resolving it.
Planning research on top of both reviews then found that bd itself already ships the
`swarm`/`merge-slot` primitives this design needs, letting `/orchestrate` end up thinner than any
draft that preceded it. The Model Guard requirement was added after implementation, at the user's
own direction, for parity with `/case`/`/refine`'s existing gate.

## [2.18.0] - 2026-07-18

Plugin & marketplace entry `case-solvers` `2.17.1` → `2.18.0`. `/case` (2.8.1 → 2.9.0), `/refine`
(1.7.1 → 1.8.0), `/board` (1.0.0 → 1.1.0), `/solve` (1.4.1 → 1.5.0), `/evaluate` (1.8.0 → 1.9.0).

**Added: a `Complexity Tier` rubric judges story difficulty and recommends a solver tier.**
`Budget-Solver Fit` already gates *scope and ambiguity* — every story reaching bd fits a budget
solver's working set, or it's decomposed/settled until it does. But a story can pass that gate and
still call for more reasoning capability than raw execution — auth/crypto surfaces, concurrency,
non-obvious algorithms, subtle library semantics, a refactor across an unfamiliar pattern. The new
rubric is a separate axis, judged only after Budget-Solver Fit passes: it recommends the cheapest
tier + effort combination likely to succeed (`budget`/`medium`/`frontier` × `low`/`medium`/`high`/
`max`), recorded as a `## Complexity` section in the story body and a `solver-<tier>` bd label for
board-table visibility. `medium` is a relative call, not a new Model Guard bucket — it means the
cheaper end of the planning roster (e.g. Sonnet over Opus) or the strongest end of the budget roster,
whichever middle option a given setup offers; the existing budget/planning classification in `/case`
and `/refine` is untouched. Escalation follows the signal: a *volume* signal (long AC list, wide file
surface) raises effort within the current tier; a *subtlety/blast-radius* signal (the difficulty
signals above) raises tier instead — more effort on a weaker model doesn't close a capability gap.
Purely informational — nothing enforces the recommendation; the human still picks which model runs
`/solve <id>`.

**Fixed: `/solve`'s frontier-cost warning no longer contradicts a story's own recommendation.** The
warning previously fired on any frontier-tier run regardless of the story, which meant a story
correctly labelled `solver-frontier`, solved deliberately on a frontier model, still got told "you're
expensive, consider downgrading" — two advisories disagreeing on the same decision. The check now
runs once the story is resolved (`/solve` step 1) and reads its `solver-*` label first; it's silent
when the label already says `frontier`, unchanged otherwise.

**Added: an optional calibration note at `/evaluate`.** Nothing previously checked whether a tier
recommendation was actually right — `/refine` only re-grades after a hard failure (a `/solve`
spec-gap bounce). On the full interactive approve flow (not the `--approve`/`--review` fast paths),
`/evaluate` now optionally asks whether the recommended tier matched how the story actually went and
records the answer as a `bd comment` — a data point for judging the rubric's accuracy over time, not
a gate.

This design was reviewed by a Fable-tier model before implementation, which caught that the original
draft's `medium` tier had no concrete referent, that its effort-before-tier escalation rule was
backwards for the exact signals the rubric names, and the `/solve` warning contradiction above — all
three are reflected in the final rubric rather than the first draft.

## [2.17.1] - 2026-07-17

Plugin & marketplace entry `case-solvers` `2.17.0` → `2.17.1`. `/case` (2.8.0 → 2.8.1), `/refine`
(1.7.0 → 1.7.1).

**Changed: the `Budget-Solver Fit` rubric now splits its signals along two labeled axes.** The
section's checklist was headed "Too-large signals", but two of its bullets — an AC that forces an
unsettled design decision, and a bugfix whose root cause isn't reproduced — are not size signals at
all; they are *ambiguity* signals (a gap in the middle of an otherwise-small story). Filed under a
"too-large" heading, an author sizing a small-but-ambiguous story could correctly conclude "not too
large" and skip past exactly the two checks that most reliably make a budget solver drift. The
signals are now two groups — **Too big (scope)** (→ decompose or split) and **Unsettled middle
(ambiguity)** (→ settle in the contract or split out) — under an opening line that names both axes as
co-equal ("scope is bounded *and* nothing inside is left undecided"). The INVEST line's mapping is
corrected to match: **E**stimable now carries the ambiguity axis, **S**mall the scope axis. Rubric
wording only — the section name is unchanged, so nothing else references break.

**Changed: the `both` Verification mode is renamed `auto+human`, and its definition now states the
action, not just the composition.** `both` is relational — it means nothing until the other two modes
are memorized — and the token travels into a story body, where the budget solver reading it never sees
the rubric that defines it. `auto+human` names its own constituents, so it reads clearly wherever it
appears. Its definition moves from "has a machine-assertable part AND an experiential part" to the
resulting split: the solver auto-verifies the assertable part and spells out the experiential part for
a person to exercise at `/evaluate`. Unlike the rename-free change above, `/solve` and `/evaluate`
cite the mode by name *outside* the shared rubric block, so their `` `human`/`both` `` call sites were
updated by hand to `` `human`/`auto+human` ``.

**Docs: `CLAUDE.md` gains the caveat those hand-edits taught.** `rubrics-sync.sh --write` propagates
only the shared block, so a rubric edit that renames a token other skills cite in their own prose (the
`auto+human` rename is the worked example) needs those call sites fixed by hand — the sync still
reports green while the skills drift out of step with the rubric.

## [2.17.0] - 2026-07-17

Plugin & marketplace entry `case-solvers` `2.16.0` → `2.17.0`. `/case` (2.7.1 → 2.8.0), `/refine`
(1.6.1 → 1.7.0).

**Fixed: the shared rubrics are now inlined, not read at runtime.** `/case` and `/refine` pointed at
`shared/contract-rubrics.md` by relative path (`../../shared/...`). That path can never resolve: the
Read tool resolves a relative path against the **user's working directory**, not the SKILL.md's own
directory, so in any real project it became `<parent-of-project>/shared/contract-rubrics.md` and
errored with `File does not exist`. The skills' own fallback ladder then sent the model to a Bash
`find` across the plugin cache — which is what produced a permission prompt on every `/case`, and, on
a bad run, authoring from memory of the rubrics instead of the file.

Everything below the `BEGIN SHARED` marker in `shared/contract-rubrics.md` is now inlined verbatim
into a `Contract Rubrics` section at the end of both SKILL.md files. All path-resolution prose and the
`find` fallback are gone; there is no file to locate, so nothing can mis-resolve and nothing prompts.

The rubrics are a hard gate — every invocation loads them — so a separate file never saved context;
it only bought a fragile path. `${CLAUDE_PLUGIN_ROOT}`, which Claude Code substitutes inline in skill
content, would have fixed this on Claude Code alone, but Codex does not substitute it and the repo's
rule is one skill body per host. Inlined text needs no host contract at all.

**New: `tests/rubrics-sync.sh`** keeps the two inlined copies byte-identical to the source. No flag
verifies and exits non-zero on drift; `--write` regenerates. It never calls a model — a pure text
comparison, fast and deterministic.

**New: CI (`.github/workflows/checks.yml`)**, the repo's first. It runs `rubrics-sync.sh` on push to
`master` and on every PR. Inlining moved the failure mode from loud to silent: the old bug prompted on
every `/case`, whereas stale inlined rubrics would look completely normal while the skills authored
against out-of-date bars. Both hosts install this plugin by copying the repo — there is no build step
between a commit and a user's machine — so drift on `master` is drift that ships, and CI is the only
place a gate can stand. The model-calling tests (`model-guard.sh`, `authoring-format.sh`) stay manual:
slow, probabilistic, credentialed.

**Changed: the story line in the Output Format template is now a fenced code block.** `As a / I want /
so that` previously relied on blank lines between the three lines to keep them apart; they now sit in
a fence, the same device the `gherkin` block already uses, for the same reason — bare lines collapse
into one paragraph when rendered.

**Removed: `tests/rubric-read.sh`.** It existed solely to assert the model achieved a non-error Read
of `contract-rubrics.md` — a slow, probabilistic test of the very mechanism this release deletes.

**Docs.** `README.md` install section now covers both hosts properly: verified Codex syntax
(`codex plugin list`, `codex plugin marketplace upgrade` — not `update`), how to check the install on
each host, updating, and which commands are slash-only on Codex. Dropped the "install the plugin, not
loose skill folders" warning — with the rubrics inlined, a `skills/<name>/` copy no longer breaks
`/case` and `/refine`.

## [2.16.0] - 2026-07-17

Plugin & marketplace entry `case-solvers` `2.15.2` → `2.16.0`.

**New: session-start / pre-compact primer hook.** `plugins/case-solvers/hooks/hooks.json` now ships
with the plugin (Claude Code only — hooks aren't part of the shared `skills/` tree) and fires on
`SessionStart` and `PreCompact`, printing `hooks/session-primer.md`: a one-screen cheat sheet of
when to reach for `/case`, `/refine`, `/solve`, `/evaluate`, and `/board`. Keeps the workflow
top-of-mind across long sessions and survives context compaction, without querying live `bd` state.

## [2.15.2] - 2026-07-17

Plugin & marketplace entry `case-solvers` `2.15.1` → `2.15.2`. (`/case` `2.7.0` → `2.7.1`, `/refine`
`1.6.0` → `1.6.1`.)

**Story-line template now breaks across three lines.** The shared `Output Format` template in
`contract-rubrics.md` renders the opening `As a / I want / so that` statement as three one-line
paragraphs (blank-line separated) instead of one run-on sentence, for readability — still compliant
with the existing "no hard-wrap, one paragraph per line" rule since each clause is its own unbroken
paragraph.

## [2.15.1] - 2026-07-13

Plugin & marketplace entry `case-solvers` `2.15.0` → `2.15.1`. (`/solve` `1.4.0` → `1.4.1`.)

**Senior Solver exploration now selects for role fit, not lowest price.** The shared `/solve` prose
now tells both hosts how to keep codebase paging out of the senior solver's decision context:
Claude Code dispatches its `Explore` agent on Haiku, while Codex dispatches its built-in `explorer`
agent; a host without named roles may give the same bounded brief to a general subagent. The task is
explicitly read-only — search, inspect, and report, with no edits, implementation, or mechanism
decisions — and uses the model suited to read-heavy exploration rather than whichever model is
merely cheapest. A host with no subagents still explores inline from Files of Interest.

## [2.15.0] - 2026-07-13

Plugin & marketplace entry `case-solvers` `2.14.0` → `2.15.0`. (`/solve` `1.3.0` → `1.4.0`.)

**`/solve` now adapts to the model running it without ever growing the ticket.** The Cost Guard
becomes a **Model Check** that derives two things from the system prompt's model ID: the solver's
short class name (`haiku`, `opus`, `fable`, `gpt-5.6-sol`, …) — now used as the bd assignee at claim
time instead of the hardcoded `claude`, so the story records which model picked it up — and the
tier. A frontier tier still gets the one-time cost warning, but continuing now puts the new
**Senior Solver rules** in effect: same scope, better craft (extra capability goes into quality
*within* the AC, never into features or abstractions the contract doesn't ask for — the junior's
ticket doesn't grow for the senior); exploration is delegated to a read-only subagent on the
cheapest tier the host offers (Claude Code: `Explore` on Haiku), seeded with Files of Interest and
the concrete questions to answer, rather than paging through the codebase on frontier tokens; and
out-of-scope observations — adjacent bugs, contract ambiguities, worthwhile refactors — are
reported, never fixed. The step-6 review handoff gains an optional **Recommendations** section
(one line each, explicitly *not implemented*) so the reviewer can address each item at `/evaluate`
or file it as a separate story.

## [2.14.0] - 2026-07-13

Plugin & marketplace entry `case-solvers` `2.13.0` → `2.14.0`. (`/case` `2.6.0` → `2.7.0`,
`/refine` `1.5.0` → `1.6.0`.)

**AC steps are now declarative and third person, per Cucumber's Better Gherkin guidance.** The AC
Quality Rubric gains a **Declarative** bar: steps state business-level actions naming the story
line's actor — never "I", never UI mechanics ("clicks the button", "types into the field") — with
the litmus test *wording that must change when the implementation changes → rework*. Specific
values deliberately stay (a divergence from Cucumber's fully-declarative style, which relies on
step definitions to hold the details; these scenarios have none — a budget solver derives tests
directly from them, so hiding values would force it to invent them). The Pre-write Guard checks the
new bar. Also fixed the Codex marketplace (`.agents/plugins/marketplace.json`): its plugin entries
carried no `version` field, so Codex installs couldn't be tied to a release — both entries now
version in lockstep with the other three manifests.

## [2.13.0] - 2026-07-13

Plugin & marketplace entry `case-solvers` `2.12.0` → `2.13.0`. (`/case` `2.5.0` → `2.6.0`,
`/refine` `1.4.0` → `1.5.0`.)

**Stories now carry the Cucumber user-story Who/What/Why, and AC blocks open with a `Feature:`
title.** The shared contract rubrics gain two authoring principles: **Who, What, Why** — the Problem
Statement must open with the story line `As a <actor>, I want <what>, so that <why>` (actor by
problem type: Feature/Design — who gets the capability; Bugfix — who the failure blocks; Refactor —
who maintains the code; Investigation — who the findings inform) — and **INVEST** (Independent,
Negotiable, Valuable, Estimable, Small, Testable), each letter mapped to the rubric section that
enforces it. The AC `gherkin` block now opens with a `Feature:` line titling the behavior under
test, also named by problem type (Bugfix titles the behavior being *restored*, never the bug;
Refactor the behavior preserved; Investigation the question answered); related scenarios may group
under `Rule:` lines and repeated steps over many values become a `Scenario Outline` with an
`Examples` table. The Pre-write Guard checks both additions (missing/vague story line → name the who
and why; missing `Feature:` title → add it), and `tests/authoring-format.sh` asserts a drafted story
contains the story line and the `Feature:` title. Goal: any reader — human or budget model — parses
the same who, what, and why from every story.

## [2.12.0] - 2026-07-12

Plugin & marketplace entry `case-solvers` `2.11.0` → `2.12.0`. (`/solve` `1.2.0` → `1.3.0`,
`/evaluate` `1.7.0` → `1.8.0`.)

Fixed Codex discovery of the explicit-only `/solve` and `/evaluate` skills. Their shared
frontmatter now uses the Codex-compatible `disable-model-invocation: false`, while their
`agents/openai.yaml` files continue to enforce explicit invocation with
`policy.allow_implicit_invocation: false` and now provide the required short descriptions. The
Codex plugin manifest also includes the required long description, default prompt, and capability
metadata.

## [2.11.0] - 2026-06-26

Plugin & marketplace entry `case-solvers` `2.10.0` → `2.11.0`. (`/solve` `1.1.0` → `1.2.0`,
`/evaluate` `1.6.0` → `1.7.0`.)

**Story worktrees now live inside the repo at `.worktree/<id>`, not at the sibling
`../<repo>-worktrees/<id>`.** The sibling location put each worktree outside the project root —
often on a different filesystem or permission scope (or under `/tmp`), which is what produced the
recurring permission errors during `/evaluate`. `/solve` now creates the worktree at `.worktree/<id>`
under the repo root, so it shares the project's filesystem and permissions, and `/evaluate` reads,
reviews, amends, and cleans up at the same path. To keep the main worktree's `git status` clean,
`/solve` appends `.worktree/` to `.git/info/exclude` before creating the worktree — local and
idempotent, leaving the tracked `.gitignore` untouched (no stray uncommitted change on the base
branch). Existing sibling worktrees from older runs are unaffected; the new path applies to
worktrees created from this version on.

## [2.10.0] - 2026-06-26

Plugin & marketplace entry `case-solvers` `2.9.0` → `2.10.0`. (`/case` `2.4.0` → `2.5.0`, `/refine`
`1.3.0` → `1.4.0`.)

**The shared-rubrics read is now a fail-loud gate, not a silently-skippable hint.** `/case` and
`/refine` pointed at `shared/contract-rubrics.md` by relative path (`../../shared/...`); a planning
model would often miscount the `..` levels, Read `skills/shared/contract-rubrics.md` (which does not
exist), get *File does not exist*, and then author the contract from memory — the rubric effectively
skipped with no visible error. Both skills now spell out the path explicitly (two levels up: out of the
skill folder, out of `skills/`, into `shared/`) and make the read a **hard gate**: on a Read error the
skill must re-resolve or `find` the file and retry — never fall back to memory. New regression harness
`plugins/case-solvers/tests/rubric-read.sh` runs `/case` on a planning model and, by inspecting the
tool stream, asserts a **non-error** Read of `contract-rubrics.md` actually happened (the existing
`authoring-format.sh` only graded output shape, which a model can fake from memory).

## [2.9.0] - 2026-06-24

Plugin & marketplace entry `case-solvers` `2.8.0` → `2.9.0`.

**`/evaluate` now always runs `bd show <id>` before making any claim about a story's state.** The previous wording of step 1 let the agent substitute session context or the bd status field for an actual story read — it would see an `in_progress` bd status (which is normal for a story `/solve` has finished) and incorrectly stop with "story is not done." The fix makes `bd show <id>` mandatory with no skip condition, and explicitly separates bd status from labels: `needs-review` is a label, and `in_progress` status alongside a `needs-review` label is the expected output of a finished `/solve` run in a separate session.

### Changed
- `/evaluate` (`v1.5.0` → `v1.6.0`): step 1 rewritten — `bd show <id>` is mandatory before any verdict; `needs-review` check is now explicitly on the **labels** field, not the bd status; story with status `in_progress` + label `needs-review` is documented as normal.

## [2.8.0] - 2026-06-19

Plugin & marketplace entry `case-solvers` `2.7.0` → `2.8.0`. (`/case` `2.3.0` → `2.4.0`, `/refine`
`1.2.0` → `1.3.0`.)

**Contract prose is now written unwrapped — one line per paragraph.** Authored stories used to hard-wrap
Problem Statement / Context / Constraints prose at a column width. That reads fine in a text editor but
leaves stray line breaks when the contract is pasted into a tool that soft-wraps (Basecamp, Linear,
GitHub), forcing manual cleanup. The shared **Output Format** now requires each prose paragraph to be a
single unbroken line, and the **Pre-write Guard** flags hard-wrapped prose so the self-audit joins it
before commit. Markdown and `bd show` already soft-wrap a long line, so nothing changes on screen. The
fenced `gherkin` AC block is the sole exception — its internal line breaks are still preserved verbatim.
Affects both `/case` and `/refine`, which share `shared/contract-rubrics.md`.

## [2.7.0] - 2026-06-19

Plugin & marketplace entry `case-solvers` `2.6.0` → `2.7.0`. (`/case` `2.2.0` → `2.3.0`, `/refine`
`1.1.1` → `1.2.0`.)

**A story must now state WHY, not just WHAT.** The contract template always asked the Problem
Statement for "why it must be solved," but nothing enforced it — a story could pass the whole rubric
with only problem + outcome. The shared **Pre-write Guard** now flags a Problem Statement missing the
why and requires it added, so the authored contract matches how the workflow is described: a story is
**WHAT and WHY**, never HOW. Affects both `/case` (new stories) and `/refine` (revisions), which share
`shared/contract-rubrics.md`.

## [2.6.0] - 2026-06-18

Plugin & marketplace entry `case-solvers` `2.5.0` → `2.6.0`.

**`/case` is now model-invocable — a plain-English ask reaches it, not just the slash command.** Saying
something like "let's put our problem to a case" now routes to `/case` instead of requiring you to type
`/case`. It stays safely backstopped: the planning-tier **Model Guard** still runs first and nothing is
written to bd until you confirm, the same guards that let `/refine` be model-invocable. The
description gained trigger phrasing so the model knows when to fire. This moves `/case` out of the
slash-only group (now just `/solve` and `/evaluate`, which bake work into a branch) and the philosophy
note in CLAUDE.md was updated to match.

### Changed
- `/case` (`v2.1.1` → `v2.2.0`): dropped `disable-model-invocation` (Claude) and removed its
  `agents/openai.yaml` (`allow_implicit_invocation: false`, Codex), so it's implicitly invocable on
  both hosts; description now carries invocation triggers.
- `CLAUDE.md`: "Invocation tracks blast radius" bullet rewritten — slash-only is now `/solve` +
  `/evaluate`; `/case` joins `/board`/`/refine` as model-invocable, backstopped by Model Guard +
  confirm-before-write.

## [2.5.0] - 2026-06-18

Plugin & marketplace entry `case-solvers` `2.4.0` → `2.5.0`.

**A story now lands back on the branch it was forked from — not hardcoded `main`.** `/solve` used to
fork every worktree off `main` and `/evaluate --approve` merged it back to `main`, so work started on a
feature branch like `my-branch` still landed on the trunk. Now `/solve` forks `bd/<id>` off the repo's
**current active branch** (`<base>` — `main`, `master`, or a feature branch, whatever is checked out)
and records that base in its review handoff; `/evaluate --approve` reads `<base>`, checks the main
worktree out to it, and rebases + fast-forward-lands the story there. Older stories with no recorded
base fall back to the branch currently checked out in the main worktree. (`--note` to skip landing is
unchanged.)

### Changed
- `/solve` (`v1.0.2` → `v1.1.0`): forks the worktree off the current active branch instead of
  hardcoded `main`, and records **Base branch:** in the review handoff comment.
- `/evaluate` (`v1.4.0` → `v1.5.0`): approve path resolves the story's base branch (recorded handoff,
  or the main worktree's current branch) and lands on it; description, step 4a, and bd/git map updated.

## [2.4.0] - 2026-06-18

Plugin & marketplace entry `case-solvers` `2.3.2` → `2.4.0`.

**`/evaluate --approve` now lands the story as one linear commit — no merge commit.** Approving a
story used to run a plain `git merge bd/<id>`, which produced a second "Merge bd/<id>" commit on the
target branch whenever the branch had fallen behind. Step 4a now **rebases `bd/<id>` onto the target
and fast-forwards it in** (`git merge --ff-only`), so the story's own commit is the only thing that
lands. The conflict confidence gate now fires on *rebase* conflicts (same clear-vs-ambiguous logic),
and `--ff-only` is the guardrail against silently falling back to a merge commit.

### Changed
- `/evaluate` (`v1.3.1` → `v1.4.0`): approve path rebases then fast-forward-merges instead of a plain
  merge; bd/git map and conflict gate updated to match.

## [2.3.2] - 2026-06-17

Plugin & marketplace entry `case-solvers` `2.3.1` → `2.3.2`.

**Fix: `/case` and `/refine` now properly include the shared contract rubrics in agent context.**
The shared rubric file (`contract-rubrics.md`) was referenced in the skill instructions but without
the `@` prefix required by the plugin harness for file inclusion. Agents were instructed to read it
but the harness wasn't providing its contents, preventing them from following the rubrics.

### Changed
- `/case` (`v2.1.0` → `v2.1.1`): added `@` prefix to shared rubric reference to enable file inclusion.
- `/refine` (`v1.1.0` → `v1.1.1`): added `@` prefix to shared rubric reference to enable file inclusion.

## [2.3.1] - 2026-06-17

Plugin & marketplace entry `case-solvers` `2.3.0` → `2.3.1`.

**Fix: `/evaluate --review` now reliably dispatches the reviewer on a frontier model (Opus by
default) instead of inheriting `/evaluate`'s ambient model.** When `/evaluate` itself ran on a budget
model (e.g. Haiku), the request-changes subagent was inheriting that budget model — the `/code-review`
pass ran on Haiku despite the intent to pin it. The instruction offered a vague "`sonnet` or `opus`"
choice with no concrete spawn shape, so the model argument was often left unset.

### Changed
- `/evaluate` (`v1.3.0` → `v1.3.1`): the request-changes (and `--review [effort]`) path now makes
  frontier pinning **mandatory and concrete** — the subagent spawn must set its `model` argument
  explicitly, defaulting to **`opus`** (`Agent(subagent_type: …, model: "opus", …)` on Claude Code;
  frontier GPT-5-class on Codex), with `sonnet` only as a fallback when Opus is unavailable. Inheriting
  the ambient model or running the review inline on `/evaluate`'s own model is now explicitly
  prohibited; a budget ID is never pinned. Effort still passes through to `/code-review` (default
  `high`).

## [2.3.0] - 2026-06-16

Plugin & marketplace entry `case-solvers` `2.2.0` → `2.3.0`.

**`/evaluate` request-changes now fixes in place via a frontier-pinned `/code-review` subagent
instead of bouncing work back to `/solve`.** When the implementation needs work but the contract is
sound, `/evaluate` spawns a subagent **with its model pinned to a frontier tier** (Sonnet/Opus on
Claude, GPT-5-class on Codex — the same IDs the `/case` Model Guard treats as planning), runs
`/code-review <effort> --fix` against the story's worktree inside it, then **shows the human the
reviewer's applied diff and amends `bd/<id>` only after an explicit confirm** — and re-opens the diff
for another verdict. The story never leaves `needs-review`. The reviewer is frontier regardless of
what model `/evaluate` itself runs on; the amend is mechanical and stays in `/evaluate`, gated on the
human's go-ahead. A wrong *contract* still routes to `/refine`. This shifts review-time code
fixes onto the review tier; greenfield implementation stays `/solve`'s job (CLAUDE.md single-writer
discipline updated to match).

### Changed
- `/evaluate` (`v1.2.0` → `v1.3.0`): **replaced** the `--request-changes` /
  `--request-changes --note <text>` flags with **`--review [effort]`** — a fast-path that runs the
  `/code-review` pass straight away at `effort` (default `high`; any `/code-review` level), applies
  fixes in place, shows the applied diff, and amends the branch **only after the human confirms**.
  The review-and-apply runs in a subagent **pinned to a frontier model** (`/evaluate` has no model
  gate of its own, so the reviewer's tier is pinned explicitly, never inherited); if no frontier model
  is available to pin, it stops rather than review on a budget model. `--review` always takes the implementation path; a wrong *contract* still routes
  to `/refine` via the interactive flow. `--note <text>` now steers the reviewer (e.g. "focus on …")
  in addition to annotating the story. `--approve` / `--approve --note <text>` and the interactive
  flow are unchanged. A **Host note** documents the Codex equivalent (run that host's review-and-apply
  command in the same pinned-frontier subagent against the same worktree, then amend identically).
- `/solve` (`v1.0.1` → `v1.0.2`): the "resuming" note now covers an existing `bd/<id>` branch in
  general (a contract sent back via `/refine`, or earlier in-progress work) and clarifies that
  implementation-only review fixes no longer return here — `/evaluate` applies those in place.

## [2.2.0] - 2026-06-14

Plugin & marketplace entry `case-solvers` `2.1.0` → `2.2.0`; `writing-claude-md` `1.0.0` → `1.1.0`.

**Dual-host: the same skills now run on OpenAI Codex as well as Claude Code.** Codex's plugin layout
mirrors Claude's, so the `skills/<name>/SKILL.md` tree is shared verbatim — no duplication, no
symlinks. Support is purely additive packaging plus a Model Guard that recognizes Codex frontier IDs.

### Added
- **Codex plugin manifests** — `plugins/case-solvers/.codex-plugin/plugin.json` and
  `plugins/writing-claude-md/.codex-plugin/plugin.json`, each pointing at the shared `./skills/` tree
  alongside the existing `.claude-plugin/plugin.json`.
- **Codex marketplace** — `.agents/plugins/marketplace.json` publishing both plugins to Codex
  (`source`/`policy` schema), mirroring `.claude-plugin/marketplace.json`.
- **Codex invocation policy** — `agents/openai.yaml` (`policy.allow_implicit_invocation: false`) in
  the `case`, `solve`, and `evaluate` skills, the Codex equivalent of Claude's
  `disable-model-invocation: true`. These stay explicit-only (slash / `$skill`); `board` and `refine`
  remain implicitly invocable.

### Changed
- `/case` Model Guard (`v2.0.1` → `v2.1.0`) and `/refine` Model Guard (`v1.0.0` → `v1.1.0`): the
  planning tier now recognizes frontier GPT-5-class IDs (e.g. `gpt-5.5`, `gpt-5.5-high`) so `/case`
  and `/refine` run on a Codex frontier model. `gpt-5-mini`/`gpt-5-nano` classify as budget, and a
  budget marker now explicitly outranks a planning marker on ambiguous IDs. `/solve` is unchanged —
  it runs on any model tier, as before.

## [2.1.0] - 2026-06-14

Plugin & marketplace entry `case-solvers` `2.0.0` → `2.1.0`.

### Changed
- `/evaluate` (`v1.1.1` → `v1.2.0`): replaced `--skip-review` with three composable flags.
  `--approve` merges without opening the VSCode diff; `--request-changes` routes straight to the
  send-back path (still prompts for impl vs. contract); `--note <text>` attaches a `bd comment` to
  the story and is orthogonal — works with either flag or the full interactive flow. Removed the
  post-merge `⚠` warning: `--approve` is an affirmative signal, not negligence, so no warning is
  warranted. **Note:** `--skip-review` is removed; use `--approve` instead.
- `/case` Environment Guard (`v2.0.0` → `v2.0.1`): dropped the dangling `(see README → Requirements)`
  pointer. The skill runs from the plugin cache inside repos that don't carry the plugin README, so
  the reference was unreachable there. The guard now states the bd requirement on its own; the
  `.beads/`-absent → `bd init`-and-continue behavior and "Run Second" run-order are unchanged.

## [2.0.0] - 2026-06-14

Plugin & marketplace entry `case-solvers` `1.2.2` → `2.0.0`.

**Breaking:** `/case` is now **authoring only** and takes just `<description>`. Its other two modes
moved to dedicated commands — viewing the board / one story is **`/board`** (new), revising a story
is **`/refine`** (new). `/case` with no argument now prints a usage hint instead of the board, and
`/case --id <id>` is gone (use `/board <id>` to view, `/refine <id>` to revise). The split follows
the read/author fault line the skill already had: read-only modes ran on any tier, authoring needed
a planning model.

### Added
- New skill **`/board`** (`v1.0.0`) — read-only render of the bd backlog as a status board, or one
  story by id (`/board <id>`). Runs on **any model tier** (no planning model) and is
  **model-invocable**, so plain-language asks ("show me story 5", "list all stories") route to it.
  This is the old `/case` Board + Detail modes lifted out.
- New skill **`/refine`** (`v1.0.0`) — revise an existing story's contract on a **planning model**:
  apply a `/solve` spec-gap or `/evaluate` change-request (or a user edit), stay WHAT-only, and
  return the story to ready. Carries the same Model Guard as `/case` (untrusted-input handling
  included) and is **model-invocable** ("update story 5"). This is the old `/case` Refine mode as
  its own command.
- `plugins/case-solvers/shared/contract-rubrics.md` — the contract rubrics (Authoring principles,
  Problem Types, Budget-Solver Fit, Verification Mode, AC Quality Rubric, Pre-write Guard, Output
  Format) extracted to one file that both `/case` and `/refine` load after their Model Guard passes.
  Single source of truth, no duplication across the two authoring skills. Each skill's Model Guard
  stays inline — it must run before anything is read.

### Changed
- `/case` (`1.1.4` → `2.0.0`) — reduced to its one job: author a new story or epic. Board, Detail,
  Refine, the mode-dispatch table, and most of the bd command map are gone (moved to `/board` and
  `/refine`); the Model Guard sheds its read-only carve-outs since every `/case` run now authors.
  Stays slash-only (`disable-model-invocation`) — authoring is a deliberate act tied to a model
  switch, and a fuzzy "make a story" trigger would false-positive during ordinary design talk. The
  **Authoring: Story vs Epic** section was then compressed ~30% (the inline problem-type list and
  "both modes" restatement dropped — both already covered by the shared rubrics it points to); the
  new `authoring-format.sh` harness confirms a planning model still follows it (Story vs Epic
  branching + Output Format) across trials.
- `/solve` (`1.0.0` → `1.0.1`) and `/evaluate` (`1.1.0` → `1.1.1`) — pointers follow the new
  commands: a spec-gap / contract-wrong handoff now points at `/refine <id>`; "view the story" and
  "readable later" point at `/board` / `/board <id>`.
- Test harness grew a positive path and got more robust. `model-guard.sh` (the budget-STOP
  direction) now exercises both authoring guards — `/refine <id>` trials alongside
  `/case <description>` (`/refine`'s Model Guard runs before its environment guard, so a budget
  model must emit the planning-model stop even with no backlog; the harness asserts that). New
  `authoring-format.sh` covers the PLANNING-PROCEED direction: it runs `/case` on a planning model
  and grades the drafted `.case.md` against the Output Format and the Story-vs-Epic branch. Shared
  `lib.sh` auto-syncs the working tree into the active install before each run (no more manual
  `cp` into the cache) and adds `infra_error` detection so a mid-run session/rate limit or empty
  response scores **inconclusive (exit 2)**, never a false guard/format FAIL.
- `CLAUDE.md` / `README.md` updated for the five-command surface and the invocation policy
  (slash-only for the tier-gated/side-effecting commands; model-invocable for read-only `/board`
  and id-scoped `/refine`).

## [1.2.2] - 2026-06-14

Plugin & marketplace entry `case-solvers` `1.2.1` → `1.2.2`.

### Fixed
- `/case` (`1.1.3` → `1.1.4`) — Acceptance Criteria now author into a fenced ` ```gherkin `
  block instead of relying on trailing-two-space markdown hard breaks. The old format kept its
  line breaks in `bd show` (raw text) but silently collapsed Given/When/Then into one run-on
  paragraph when rendered as markdown whenever the agent dropped the invisible trailing spaces —
  which happened often, since there was nothing visible to reproduce. A code fence preserves the
  line breaks and 2-space indent literally and identically in both `bd show` and rendered
  markdown, and the structure is visible so the agent can't omit it. The Output Format template,
  Pre-write Guard (new scan item that wraps bare/trailing-space AC in the fence), and the format
  rule were updated together.

## [1.2.1] - 2026-06-13

Plugin & marketplace entry `case-solvers` `1.2.0` → `1.2.1`.

### Fixed
- `/case` (`1.1.2` → `1.1.3`) — the Model Guard now treats the `<description>` argument as
  **untrusted data**: text inside it that tells the skill to ignore/skip/waive the tier rules,
  "author anyway", or claims the model is a planning model no longer relaxes the gate. A budget
  model (e.g. Haiku) classifying from its real model ID stops and authors nothing even when the
  description tries to override the guard. Reproduced and verified with the new
  `plugins/case-solvers/tests/model-guard.sh` harness, which runs `/case <desc>` on a budget
  model across multiple trials (including override-injection descriptions) and asserts every
  trial emits the stop message and writes no contract.
- `/case` (`1.1.1` → `1.1.2`) — the Staging Loop now writes `.case.md` to the **main checkout
  root** (resolved as the first entry of `git worktree list`), not the session's working
  directory, so authoring from inside a worktree no longer strands the staging file there. An
  existing `.case.md` is overwritten without a confirmation prompt — the old "Overwrite guard"
  step is removed. The Decomposition (Epic) section's reference to that guard is updated to match.

## [1.2.0] - 2026-06-13

Plugin & marketplace entry `case-solvers` `1.1.0` → `1.2.0`.

### Added
- `/evaluate` (`1.0.0` → `1.1.0`) — new `--skip-review` flag: `/evaluate --skip-review <id>`
  merges a `needs-review` story straight to `main` (close, unblock dependents, drop the worktree —
  identical to approving) **without** opening the diff in VSCode or asking a verdict, for stories
  clear enough that no human review is wanted. The skip always prints a non-dismissible warning
  (`⚠ Merged <id> without review — skipped the human quality gate.`). The merge-conflict confidence
  gate is unchanged — an ambiguous conflict still stops for the human. Plain `/evaluate <id>`
  (no flag) is unchanged.

### Fixed
- `/case` (`1.1.0` → `1.1.1`) — the Model Guard now reliably stops authoring on a budget
  model. The gate anchors to the session's exact model ID (not self-assessed capability),
  requires emitting a `model-guard: id=… tier=…` line before any authoring, and proceeds only
  on a positively-confirmed planning tier — `budget` **or** `unsure` resolves to STOP. Removes
  the "any frontier/high-parameter model qualifies → proceed" wording that let a budget model
  rationalize past the guard. Read-only Board/Detail still run on any tier.

## [1.1.0] - 2026-06-13

Plugin & marketplace entry `case-solvers` `1.0.0` → `1.1.0`.

### Changed
- `/case` (`1.0.0` → `1.1.0`) — read-only modes now run on **any model tier**: Board (`/case`)
  and Detail (`/case --id`) render without requiring a planning model. Authoring (author,
  decompose, refine) still requires one; a budget `--id` on a `needs-refinement` story renders
  the detail, then stops short of refining.
- Rewrote `CLAUDE.md` (and the `AGENTS.md` symlink) as a lean, high-signal context file:
  states what the repo is (a plugin marketplace, no build/test suite), the three-tier
  `/case`/`/solve`/`/evaluate` philosophy, the "bd is the engine, not the interface" rule, and
  the skill-editing convention. Dropped the generic non-interactive-shell boilerplate.

## [1.0.0] - 2026-06-13

Breaking: the `case-solvers` plugin (`0.3.0` → `1.0.0`) is re-architected around **bd
(Beads)** for a durable, dependency-aware, parallel-capable workflow. `bd` is now required,
and the singleton dot-files are retired. `bd` stays hidden behind three commands —
`/case`, `/solve`, `/evaluate` — the user never types a `bd` command.

### Added
- New skill **`/evaluate`** (`v1.0.0`) — the human review gate (Gate N): opens a finished
  story's branch in VSCode for the human to read the diff, then enacts the verdict — approve
  (merge to `main`, close the story, unblock dependents, drop the worktree) or request changes
  (feedback as a bd comment, back to `/solve` or `/case`).
- **Stories & epics** in bd: `/case <text>` authors one story; a large goal decomposes into an
  epic — a dependency graph of stories — reviewed at **Gate 0** before any issue is created.
- **Board**: `/case` with no argument renders backlog / in-progress / review-queue / blocked,
  with epic rollups. `/case <id>` shows one story's contract + its comments.
- **Isolation**: every solve runs in its own git worktree+branch (`bd/<id>`); `/evaluate`
  reviews and merges it like a PR. Merge conflicts pass a confidence gate (clear+tests-green →
  auto-resolve; ambiguous → escalate to the human).
- **Dependency guardrail**: `/solve <id>` refuses a still-blocked story with a reason and
  offers to walk the dependency chain.

### Changed
- `/case` (`0.10.0` → `1.0.0`) authors into bd instead of writing a persistent `.case.md`;
  gains board, detail, and epic-decomposition modes. The contract template, AC Quality Rubric,
  Budget-Solver Fit, and Pre-write guard carry over.
- `/solve` (`0.12.0` → `1.0.0`) takes a story id, works in a worktree, ends at `needs-review`
  (never merges or closes). The milestone machinery is gone — epics replace it.
- Plugin & marketplace entry version `0.3.0` → `1.0.0`; descriptions/keywords mention bd,
  epics, parallel, `/evaluate`.
- All three skills are slash-only (`disable-model-invocation: true`) with lean one-line
  descriptions — no natural-language auto-trigger. Standardised argument hints: `/case
  [<description>] [--id <story-id>]`, `/solve` and `/evaluate` `[<story-id>]`. `/case`
  tells a story id from a description via an explicit `--id` flag.
- Skill bodies trimmed for token cost: dropped per-invocation `bd prime` (static command
  maps + `bd <cmd> --help` fallback), de-duplicated guidance, removed the worked example.

### Removed
- The persistent singleton dot-files. `.case.md` survives only as a transient
  epic-decomposition surface (deleted after generating bd issues); `.solve-progress.md` and
  `.handoff.md` are gone — progress is the bd graph, and handoff feedback is bd comments
  per story.

### Requires
- The `bd` (Beads) CLI installed and on `PATH` — `brew install beads`, `npm i -g @beads/bd`,
  or `go install`. Skills assume it's present (no install check) and run `bd init` on first
  use. See README → Requirements.

## [0.4.0] - 2026-06-12

### Added
- New plugin `writing-claude-md` (`v1.0.0`): skill for writing lean, high-signal
  `CLAUDE.md` and `AGENTS.md` files — includes only what can't be derived from code.
  Install: `/plugin install writing-claude-md@case-solvers`.
- Updated marketplace description to reflect multi-plugin scope.
- Expanded README: plugin table, per-plugin install instructions, `writing-claude-md`
  usage section.

## [0.3.0] - 2026-06-12

### Changed
- Model tiers are now capability-defined instead of a closed name list: a planning model
  is "any frontier-tier, high-parameter model" (Opus/Sonnet/Fable/Mythos/Gemini Pro as
  illustrative examples). Fixes frontier models outside the old list (e.g. Fable) refusing
  to run `/case` and missing the `/solve` cost warning.
- Compressed the `/case` worked example (39 lines) to a micro-fragment showing only the
  judgment parts: positive+regression AC pair, boundary-style constraint, verification line.
- Removed the redundant "What NOT to Include" section (duplicate of the Pre-write guard)
  and slimmed repeated Model Guard restatements to one-line pointers.
- Internal skill versions: case `0.9.0` → `0.10.0`, solve `0.11.0` → `0.12.0`.

## [0.2.0] - 2026-06-12

Breaking: the architect command and its output file were renamed. Existing installs
receive the change on `/plugin update` because the version is bumped.

### Changed
- Renamed the architect command `/spec` → `/case` (skill `name`, directory, and heading;
  internal skill version `0.8.0` → `0.9.0`).
- Renamed the contract artifact `.architect-plan.md` → `.case.md` across both skills,
  the README, and `.gitignore`.
- Updated plugin and marketplace `description`, `keywords` (`spec` → `case`), and the
  README install/usage examples to match.
- Bumped plugin and marketplace entry version `0.1.0` → `0.2.0`.

### Unchanged
- `/solve` and its files (`.solve-progress.md`, `.handoff.md`) are untouched.
- The "architect" role wording is kept; only the command token and artifact name changed.

## [0.1.0] - 2026-06-12

Initial release: the `/spec` + `/solve` pair, packaged from two standalone skills into a
publishable Claude Code plugin marketplace.

### Added
- `case-solvers` marketplace (`.claude-plugin/marketplace.json`) bundling a single plugin.
- `case-solvers` plugin (`.claude-plugin/plugin.json`) exposing two skills:
  - `/spec` — runs on a planning model (Opus / Sonnet / Gemini Pro); defines the problem
    and writes `.architect-plan.md`, the budget-solver contract.
  - `/solve` — runs on a budget model (Haiku / Gemini Flash / MiniMax-M3); reads the
    contract and implements it test-first, one milestone per pass, with a handoff loop
    back to `/spec` on rejection or pre-flight gaps.
- `README.md`, `LICENSE` (MIT), and `.gitignore` for the skills' runtime artifacts.

### Fixed
- Quoted the skills' `description` frontmatter so it parses under strict YAML and passes
  `claude plugin validate --strict`. The original values contained `: ` (colon-space)
  sequences that broke plain-scalar parsing and silently dropped the metadata.

[Unreleased]: https://github.com/codxse/case-solvers/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/codxse/case-solvers/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/codxse/case-solvers/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/codxse/case-solvers/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/codxse/case-solvers/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/codxse/case-solvers/releases/tag/v0.1.0
