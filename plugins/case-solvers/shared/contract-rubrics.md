# Contract Rubrics — shared by `/case` and `/refine`

The quality bars for authoring or revising a story contract on a **planning model**. `/case`
(new story/epic) and `/refine` (revise an existing story) both load this **after** their Model
Guard passes and **before** writing anything to bd. The flow lives in each skill; the bars below
are identical for both, so they live once, here.

> Read this file in full before drafting or revising a contract. Path: `shared/contract-rubrics.md`
> at this plugin's root (sibling of `skills/`); from a skill folder it is `../../shared/contract-rubrics.md`.

---

## Authoring principles

- **Specific ≠ prescriptive.** A story states a testable, unambiguous *outcome* — never the
  mechanism or code.
- **Who, What, Why.** A story is written for an actor. The Problem Statement opens with one story line — `As a <actor>, I want <what>, so that <why>` — before anything else. A story whose actor or benefit can't be named isn't ready to author.
- **INVEST.** Every story is **I**ndependent (schedulable alone — a hard ordering belongs in an epic's dependencies), **N**egotiable (outcome, never mechanism), **V**aluable (the `so that` names a real benefit), **E**stimable (grounded and unambiguous enough to size), **S**mall (Budget-Solver Fit), **T**estable (AC Quality Rubric).
- **No drift.** Don't restate the command, duplicate repo conventions, or add sections outside the
  template.
- **Diagnosed, not hypothesized.** A Bugfix premise is the *observed* failure, never an inferred
  cause.
- **Grounded names.** Every artifact a story names (file/class/method/endpoint/table/config key)
  must be verified to exist via Read/Grep before writing — a budget solver trusts names. Can't
  verify → describe its role instead.

---

## Problem Types

| Type | Hallmark | Required (beyond core) |
|---|---|---|
| **Feature** | Build new functionality. | core only |
| **Bugfix** | Reproduce → fix → regression. | core only |
| **Refactor** | Behavior preserved, structure cleanup. | core only |
| **Design** | Design a system/API/data model first. | Deliverable Format |
| **Investigation** | No code change; deliverable = findings. | Deliverable Format |

**Core sections** (every story): Title, Problem Statement, Context, Constraints, Acceptance
Criteria, Verification, Out of Scope.

---

## Budget-Solver Fit

Size every story for a budget model — limited context and reasoning — regardless of which model
runs `/solve`.

**Too-large signals** (any → decompose into an epic, or split the story):
- Spans multiple independent capabilities or subsystems.
- More than ~6–8 AC scenarios across unrelated behaviors.
- A single AC implies a whole subsystem, not one observable behavior.
- Cross-cutting change touching many files/layers at once.
- An AC whose test forces a design decision the contract doesn't settle (invent an API shape, pick
  a data model, choose where state lives) — settle it or split.
- **Bugfix whose root cause isn't reproduced and confirmed.** Diagnosing an unknown failure is what
  budget models are worst at. While the cause is a hypothesis, make diagnosis its own story for a
  planning model (Verification: human); the budget solver gets only the mechanical fix once the
  cause is observed.

---

## Verification Mode

Every story states a `Verification` mode telling downstream whether a human checkpoint is needed:
`auto`, `human`, or `both`. (In this workflow every story is also reviewed at `/evaluate` before
merge; `Verification` is about whether the *solver* needs a person mid-slice.)

- **`human`** — acceptance observed by a person exercising the running system, or needs judgment a
  machine can't make (user-facing surface; qualitative: looks/feels right, UX, copy, layout).
- **`auto`** — fully machine-assertable, no experiential dimension (pure refactor keeps tests green;
  exact/high-volume assertions; internal contract with no surface yet).
- **`both`** — has a machine-assertable part AND an experiential part.
- **Default when ambiguous → `human`.**

---

## AC Quality Rubric

For each Acceptance Criteria scenario, before it goes into bd:

- **Atomic** — 1 scenario = 1 behavior. Then/And checking 2 separately-failing observables → split.
- **Self-contained** — readable standalone; if scenarios relate (regression vs new), say so in the
  title or group them under a `Rule:`.
- **Specific & verifiable** — concrete, deterministically assertable values. No judgment wording.
- **Declarative** — steps state business-level actions in third person, naming the story line's actor — never "I", never UI mechanics ("clicks the button", "types into the field"). Litmus: wording that must change when the implementation changes → rework. Specific values stay (there are no step definitions to hide them in): "When Bob logs in with password `hunter2`" is declarative *and* deterministic.
- **Observable** — assertion is about externally visible outcome (result state, system state, side
  effect, or absence). A method-call surrogate for an observable in the result = mechanism-bound,
  revise.
- **Generalizable** — representative test data, not accidental.
- **Exhaustive** — new behavior (positive) AND preserved behavior (regression). Bugfix: reproduces +
  fixed. Feature: happy path + boundary. Refactor: identical before/after.
- **Readable** — business terminology; raw identifiers with business meaning → Glossary.

---

## Pre-write Guard

Before a story enters bd, scan and strip:
- Implementation code block → remove.
- File:line edit instruction → abstract to "area to look at" or remove.
- Prescribed name for a *new* artifact → abstract to its role.
- Section outside the template → remove.
- Problem Statement narrating mechanism → rewrite to outcome.
- Problem Statement not opening with the story line (`As a <actor>, I want <what>, so that <why>`), or an actor/benefit too vague to mean anything ("the user", "better quality") → name the who and the why (a story states WHO, WHAT, *and* WHY).
- AC failing the rubric → split/add/revise.
- AC leaking a raw identifier with business meaning → lift to Glossary.
- AC scenarios **not** inside a fenced ` ```gherkin ` block (bare lines, or relying on trailing-space
  breaks) → wrap them in the fence. This is what holds the Given/When/Then formatting in rendered
  markdown; bare lines collapse to one paragraph.
- AC `gherkin` block missing its opening `Feature:` title line → add it, titled by problem type (see Output Format).
- AC step written as "I" or narrating UI mechanics → rewrite declarative, third person, actor named.
- Prose paragraph hard-wrapped across lines → join to one line (see Output Format; `gherkin` block exempt).

Then self-audit: all core sections filled; a Verification mode stated; every named artifact verified
to exist; solver dry-run each AC (could a budget solver write the test from Given/When/Then +
Context + Glossary without making an open design decision?). A lurking decision → settle it or split.

---

## Output Format (story body)

Each story's bd body uses this template. Mandatory sections depend on problem type.

**No hard wrapping in prose.** Each paragraph/list-item is **one unbroken line** — never wrap at a
column width (stray breaks survive a paste into Basecamp/Linear; markdown and `bd show` soft-wrap
anyway). Blank lines between paragraphs stay. Only the fenced `gherkin` block keeps internal breaks.

````markdown
# [Problem Title]

## Problem Statement
As a [actor],

I want [what — the outcome],

so that [why — the benefit].

[Then one paragraph: the problem, why it must be solved, the desired outcome. State the outcome, don't narrate mechanism. The actor by type — Feature/Design: who gets the capability; Bugfix: who the observed failure blocks; Refactor: who maintains the code; Investigation: who the findings inform.]

## Context
[Background, domain knowledge, classification assumptions. May name existing artifacts as pointers. For an environment-sensitive bug, state facts the solver can't infer from code (proxy/CA, OS/device, pinned versions). Empty if none.]

## Glossary
[Optional. Business terms used in AC mapped to technical artifacts. Skip if no jargon.]
- **[business term]** — [definition + artifact reference if needed.]

## Constraints
- [Boundary to preserve. E.g. "Preserve method X (used by other callers)."]
- [NOT mechanism — don't write "use AppSetting".]

## Acceptance Criteria

Put **every** scenario inside one fenced `gherkin` block that opens with a `Feature:` line titling the behavior under test. Title it by problem type — **Feature/Design**: the capability delivered; **Bugfix**: the expected behavior being restored (never the bug); **Refactor**: the behavior preserved; **Investigation**: the question the findings answer. The fence preserves the line breaks and indentation literally — identical in `bd show` and rendered markdown — so the Given/When/Then never collapse into a run-on line. Never use trailing-space line breaks (invisible, silently dropped). One blank line separates scenarios.

Scenarios clustering into distinct behaviors → group each cluster under a `Rule:` line (one business rule each, its scenarios indented beneath it). The same steps repeated over many values → one `Scenario Outline` with an `Examples` table, not near-duplicate scenarios.

```gherkin
Feature: [behavior under test — titled by problem type]

  Scenario: [title]
    Given [initial condition — specific value, observable state]
    When [action — business-level, third person naming the actor; a callable method or triggerable event, never UI mechanics or "I"]
    Then [result — observable state, response field, side effect]

  Scenario: [next edge case — each programmatically verifiable]
    Given [...]
    When [...]
    Then [...]
```

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
