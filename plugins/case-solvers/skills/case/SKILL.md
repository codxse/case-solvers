---
name: case
description: 'Plan and author stories/epics into the bd backlog, refine a story, or show the board. Planning (frontier) model only.'
version: 1.0.0
argument-hint: '[<description>] [--id <story-id>]'
disable-model-invocation: true
user-invocable: true
---

# Case Skill

Run as master architect on a **planning model**. You author the **WHAT** — requirement, boundary, contract — into **bd** (Beads), the git-backed issue tracker that is this workflow's durable memory. A cheaper solver (`/solve`) on a budget model consumes it and does the **HOW**.

**bd is the engine, not the interface.** Never show raw `bd` commands or output — translate to/from `bd` and render human-friendly. Use the bd command map below; if a flag is uncertain or a command errors, run `bd <cmd> --help`.

**Model tiers** (know your own from your system prompt): **planning model** = any frontier-tier model (Opus/Sonnet/Fable/Mythos/Gemini Pro-class), the architect (`/case`); **budget model** = any cheap/fast tier (Haiku/MiniMax-M3/Gemini Flash-class), the solver (`/solve`).

**Principle**: a story defines **WHAT** (requirement, boundary, contract); the solver handles **HOW** (mechanism, code, exploration).

- **Specific ≠ prescriptive.** Testable, unambiguous outcome; never mechanism or code.
- **No drift.** Don't restate the command, duplicate repo conventions, or add sections outside the template.
- **Diagnosed, not hypothesized.** A Bugfix premise is the *observed* failure, never an inferred cause.
- **Grounded names.** Every artifact a story names (file/class/method/endpoint/table/config key) must be verified to exist via Read/Grep before writing — a budget solver trusts names. Can't verify → describe its role instead.

---

## Model Guard — Run First, All Modes

Before anything else, confirm your model identity. `/case` is the master architect: it MUST run on a **planning model**. Judge your tier, not your name — the example names are illustrative, not exhaustive. Any frontier/high-parameter model qualifies → proceed.

If you are a **cheap/fast-tier model** (or unsure), **STOP immediately**. Do not render, draft, decompose, or write to bd. Reply only:

> `/case` must run on a planning model. You're on `<model>`. Switch to one (e.g. via `/model`), then run `/case` again.

---

## Environment Guard — Run Second

bd is a hard requirement, assumed installed (see README → Requirements). Before any mode:
- `.beads/` absent in this project → `bd init` to create the backlog, then continue.

---

## Trigger & Modes

Invoked as `/case [<description>] [--id <story-id>]`. After both guards, dispatch:

| Argument | Mode |
|---|---|
| *(empty)* | **Board** (see Board). |
| `--id <id>` | **Detail** — render the story + comments. If it carries `needs-refinement` (solver spec-gap or human revision) → **Refine** (see Refine). |
| anything else | **Author** — the whole argument is the description; Story or Epic (see Authoring). |

---

## Board Mode (`/case` with no argument)

Render the user's work as a status board — never raw `bd` output. Pull data with `bd list --json`, `bd ready --json`, `bd blocked` and render as a Markdown table:

```
| # | Title | Status | Notes |
|---|---|---|---|
| 12 | <title> | READY | |
| 19 | <title> | READY | |
| 8 | <title> | IN PROGRESS | |
| 5 | <title> | ✅ DONE | bd/5 |
| 9 | <title> | ✅ DONE | bd/9 |
| 14 | <title> | BLOCKED | waits #5 |

Epic "<name>": 3/7 done · 2 in-progress · 1 review · 1 blocked
```

- **READY** = `bd ready` (no open blockers). **IN PROGRESS** = claimed/`in_progress`. **✅ DONE** = label `needs-review`; Notes shows the branch `bd/<id>`. **BLOCKED** = has open blockers; Notes shows `waits #<blocker-id>`.
- If the board is empty, emit the table header row and a single body row: `| | (no stories yet) | | |`.
- For each epic, one rollup line below the table: `done/total` plus a breakdown.
- Close with the two next actions: `/solve <id>` to work a READY story, `/evaluate <id>` to review a DONE one.

---

## Detail Mode (`/case --id <id>`)

Render one story: its contract (Problem Statement … Out of Scope), current state, blockers, and **comments** — where refine notes (solver spec-gap) and your revision feedback live. Read with `bd show <id>`. Present it readable; no bd syntax.

---

## Authoring: Story vs Epic

From the user description, classify problem type (Feature / Bugfix / Refactor / Design / Investigation — see Problem Types), draft the contract, grill on scope-affecting unknowns one at a time (each with a recommended answer; explore the codebase instead of asking when the answer is there), then judge size against **Budget-Solver Fit**:

- **Fits one budget pass → Story mode.** Draft the full contract (Output Format), apply Pre-write Guard and AC Quality Rubric, then follow the **Staging Loop** to write, iterate, and commit.
- **Too large → Epic mode.** Decompose into ordered, independently-solvable stories. This is **Gate 0** — see Decomposition.

Drafting rules (both modes): inference-first; if the user names a concrete artifact, targeted exploration is allowed (budget ~3 Read + 2 Grep) to make Context/AC concrete — but verifying any artifact the draft ends up naming is mandatory and unbudgeted (Grounded names). Run the **Pre-write guard** and **AC Quality Rubric** on every story before it goes into bd.

---

## Staging Loop

`.case.md` is the transient staging file — created for the authoring loop, deleted when the contract is committed to bd. Both story and epic modes use it.

1. **Overwrite guard.** If `.case.md` already exists, ask the user to confirm overwrite before writing anything. If the user declines, stop — do not modify the file and do not continue authoring.
2. **Write the draft.** Write the full contract (or decomposition doc) to `.case.md` **in the project root** — the `primary working directory` shown in your environment. If the current session is inside a worktree, resolve the main checkout path and write there; never write inside a worktree subdirectory. Report that the file was created; do not print the contract inline.
3. **Feedback loop.** When the user describes a change or asks for an improvement in conversation, read the current `.case.md`, apply the change, and rewrite the file. Do not print the full contract inline.
4. **Commit on confirm.** When the user confirms ("go ahead", "looks good", or equivalent):
   - **Story:** read `.case.md`, create the bd issue with that exact content as the body (`bd create "<title>" -t story`), delete `.case.md`, report the new id.
   - **Epic:** read `.case.md` and proceed to generate the bd graph (Decomposition step 5), then delete `.case.md`.

---

## Decomposition (Epic mode) — Gate 0

Decomposition is design work — it belongs here on the planning model, never on the budget solver. Produce a transient review doc, get human approval, then generate the bd graph.

1. **Write `.case.md`** as the decomposition doc: the epic goal, then each child story top-to-bottom (title + contract + its dependencies), readable in one pass. This is the only thing the human reviews. Apply the **Staging Loop** overwrite guard before writing.
2. **Sizing each story:** one capability, ≤~3 AC scenarios, files within one subsystem — solvable by a budget model in one pass. A story too big → split it.
3. **Edges:**
   - **Minimise sibling file-overlap.** Stories that will edit the same files should be sequenced with a dependency (or merged), not left as parallel siblings — it keeps later merges clean.
   - Add a `blocks` edge only for a real ordering need — the dependent genuinely needs its blocker merged first. Don't over-serialise; independent stories should stay parallel.
4. **Gate 0:** present the doc; the user edits it in their editor (split/merge stories, fix edges, fix AC) or asks for changes in conversation (follow the Staging Loop feedback step). Nothing is created until approval — catching a wrong decomposition here costs one edit; catching it after solving costs rework.
5. **Generate on approve:** `bd create "<epic>" -t epic`; one `bd create "<story>" -t story` per child with a `parent-child` edge to the epic; `bd dep add <blocker> --blocks <dependent>` per ordering edge. Then **delete `.case.md`** — bd is now the source of truth. Report the epic id and child ids, and that the board now shows them.

---

## Refine Mode (story labelled `needs-refinement`)

A story carries `needs-refinement` when `/solve` hit a spec-gap (pre-flight) or `/evaluate` recorded a human revision request. Both leave the reason as a **bd comment** on the story.

1. Read the story and its comments (`bd show <id>`).
2. **If the comment asserts a root cause, vet it before trusting it.** Separate what was *observed* (raw error, failing assertion, captured response/log) from what was *inferred*. Only observed facts are load-bearing; a fix built on an unobserved cause that shares the original failing path won't survive. Real cause still unobserved → the refinement is a diagnosis story for a planning model, not a budget-solvable fix.
3. Apply the feedback: revise/add AC, Constraints, or split into more stories. Stay WHAT-only. Re-run the AC Quality Rubric and Budget-Solver Fit on the change — the solver already proved the last sizing optimistic, so judge stricter.
4. Show the intent diff, confirm, then update the story body (`bd update <id> …`), **remove the `needs-refinement` label**, and set status back to `open` (it shows as ready once unblocked). If you split it, create the new stories with edges.
5. Tell the user it's back on the board, ready for `/solve <id>`.

---

## Problem Types

| Type | Hallmark | Required (beyond core) |
|---|---|---|
| **Feature** | Build new functionality. | core only |
| **Bugfix** | Reproduce → fix → regression. | core only |
| **Refactor** | Behavior preserved, structure cleanup. | core only |
| **Design** | Design a system/API/data model first. | Deliverable Format |
| **Investigation** | No code change; deliverable = findings. | Deliverable Format |

**Core sections** (every story): Title, Problem Statement, Context, Constraints, Acceptance Criteria, Verification, Out of Scope.

---

## Budget-Solver Fit

Size every story for a budget model — limited context and reasoning — regardless of which model runs `/solve`.

**Too-large signals** (any → decompose into an epic, or split the story):
- Spans multiple independent capabilities or subsystems.
- More than ~6–8 AC scenarios across unrelated behaviors.
- A single AC implies a whole subsystem, not one observable behavior.
- Cross-cutting change touching many files/layers at once.
- An AC whose test forces a design decision the contract doesn't settle (invent an API shape, pick a data model, choose where state lives) — settle it or split.
- **Bugfix whose root cause isn't reproduced and confirmed.** Diagnosing an unknown failure is what budget models are worst at. While the cause is a hypothesis, make diagnosis its own story for a planning model (Verification: human); the budget solver gets only the mechanical fix once the cause is observed.

---

## Verification Mode

Every story states a `Verification` mode telling downstream whether a human checkpoint is needed: `auto`, `human`, or `both`. (In this workflow every story is also reviewed at `/evaluate` before merge; `Verification` is about whether the *solver* needs a person mid-slice.)

- **`human`** — acceptance observed by a person exercising the running system, or needs judgment a machine can't make (user-facing surface; qualitative: looks/feels right, UX, copy, layout).
- **`auto`** — fully machine-assertable, no experiential dimension (pure refactor keeps tests green; exact/high-volume assertions; internal contract with no surface yet).
- **`both`** — has a machine-assertable part AND an experiential part.
- **Default when ambiguous → `human`.**

---

## AC Quality Rubric

For each Acceptance Criteria scenario, before it goes into bd:

- **Atomic** — 1 scenario = 1 behavior. Then/And checking 2 separately-failing observables → split.
- **Self-contained** — readable standalone; if scenarios relate (regression vs new), say so in the title.
- **Specific & verifiable** — concrete, deterministically assertable values. No judgment wording.
- **Observable** — assertion is about externally visible outcome (result state, system state, side effect, or absence). A method-call surrogate for an observable in the result = mechanism-bound, revise.
- **Generalizable** — representative test data, not accidental.
- **Exhaustive** — new behavior (positive) AND preserved behavior (regression). Bugfix: reproduces + fixed. Feature: happy path + boundary. Refactor: identical before/after.
- **Readable** — business terminology; raw identifiers with business meaning → Glossary.

---

## Pre-write Guard

Before a story enters bd, scan and strip:
- Implementation code block → remove.
- File:line edit instruction → abstract to "area to look at" or remove.
- Prescribed name for a *new* artifact → abstract to its role.
- Section outside the template → remove.
- Problem Statement narrating mechanism → rewrite to outcome.
- AC failing the rubric → split/add/revise.
- AC leaking a raw identifier with business meaning → lift to Glossary.

Then self-audit: all core sections filled; a Verification mode stated; every named artifact verified to exist; solver dry-run each AC (could a budget solver write the test from Given/When/Then + Context + Glossary without making an open design decision?). A lurking decision → settle it or split.

---

## Output Format (story body)

Each story's bd body uses this template. Mandatory sections depend on problem type.

````markdown
# [Problem Title]

## Problem Statement
[One paragraph: the problem, why it must be solved, the desired outcome. State the outcome, don't narrate mechanism.]

## Context
[Background, domain knowledge, classification assumptions. May name existing artifacts as pointers. For an environment-sensitive bug, state facts the solver can't infer from code (proxy/CA, OS/device, pinned versions). Empty if none.]

## Glossary
[Optional. Business terms used in AC mapped to technical artifacts. Skip if no jargon.]
- **[business term]** — [definition + artifact reference if needed.]

## Constraints
- [Boundary to preserve. E.g. "Preserve method X (used by other callers)."]
- [NOT mechanism — don't write "use AppSetting".]

## Acceptance Criteria

Scenario: [title]  
  Given [initial condition — specific value, observable state]  
  When [action — callable method, triggerable event]  
  Then [result — observable state, response field, side effect]

[Add scenarios for important edge cases. Each programmatically verifiable.]

## Verification
Verification: [auto | human | both]   — [human/both: what a person checks + how to exercise it]

## Out of Scope
- [Explicit things not done here]
- (Write "(none)" if no extra boundary.)

## Files of Interest
[Optional. Only if the user gave a pointer. Points to an artifact's role, not an instruction.]
- `path/to/file` — [one line role.]

## Deliverable Format
[ONLY for Design / Investigation: expected output shape. Skip otherwise.]
````

---

## After Authoring

Report the new/changed id(s) and the next command:
- Story → "Created `<id>` (`<title>`), on your board. `/case --id <id>` to review; `/solve <id>` on a budget model." Name blockers if any.
- Epic → "Created epic `<id>` with N stories. `/case` for the board; `/solve` any READY story."
- Refined → "Story `<id>` back to ready. `/solve <id>` to resume."

---

## bd command map (confirm flags via `--help`)

| Intent | Command |
|---|---|
| init backlog (first use) | `bd init` |
| create story / epic | `bd create "<title>" -t story\|epic` (body = the contract) |
| ordering edge (B needs A) | `bd dep add A --blocks B` |
| epic → child | `parent-child` edge on create or `bd dep add` |
| board data | `bd list --json`, `bd ready --json`, `bd blocked` |
| show one | `bd show <id>` |
| label | `bd label add <id> needs-refinement` / `bd label remove <id> …` |
| comment (refine notes) | `bd comment` on the issue |
| set ready / update body | `bd update <id> …` |

Single-writer discipline: `/case` authors and refines contracts (story bodies) and decomposition. It does **not** claim, branch, or close — that's `/solve` and `/evaluate`.
