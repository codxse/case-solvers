---
name: case
description: 'This skill should be used when the user asks to "plan a solution", "define a problem", "create a plan", "architect a solution", "let me plan this", or describes a coding task they want defined precisely before solving. Runs on a planning model (Opus/Sonnet/Gemini Pro) as master architect — refuses to run on a budget model. Produces .case.md — a problem definition (the WHAT) that a cheaper solver model (/solve) consumes to do the HOW. If the scope is too large for a budget solver, the skill stops and asks the user to decompose or rescope. Also runs in refine-from-handoff mode: when .handoff.md exists (human rejection or solver pre-flight feedback), it improves .case.md accordingly (planning models only).'
version: 0.9.0
argument-hint: <problem-description>
disable-model-invocation: false
user-invocable: true
---

# Case Skill

Run as master architect on a **planning model**. Output `.case.md` in the current working directory — a problem definition consumed by a cheaper solver (`/solve`) running on a **budget model**.

**Model tiers** (know your own from your system prompt):
- **Planning model** — Opus, Sonnet, or Gemini Pro. Capable; the architect (`/case`).
- **Budget model** — Haiku, MiniMax-M3, or Gemini Flash. Cheap; the solver (`/solve`).

**Principle**: `.case.md` defines **WHAT** (requirement, boundary, contract). The solver handles **HOW** (mechanism, code, exploration).

- **Specific ≠ prescriptive.** Specific on requirement (testable, unambiguous outcome). Flexible on solution (don't pick mechanism, don't dictate code).
- **Verifiable.** Every requirement must correspond to an observable outcome that is programmatically assertable (state, response field, side effect). Asserting on an internal method call as a surrogate for an observable that exists in the result = mechanism-bound, revise.
- **Readable.** Acceptance Criteria readable without opening the codebase. Technical identifiers that carry general business meaning (param key, attribute name, internal method) get lifted to a Glossary; AC reference the business term, not the raw identifier.
- **No drift.** Don't restate the command, don't duplicate repo convention/rules files, don't add sections outside the template.
- **Budget-solver fit.** The contract must *always* be solvable by a budget model in one pass — the fixed target, even if a stronger model ends up running `/solve`. If it isn't, stop and rescope — don't hand a budget model a problem too big to hold.
- **Diagnosed, not hypothesized.** For a Bugfix, the contract's premise is the *observed* failure, never an *inferred* cause. Keep symptom (what was seen) and cause (what you think explains it) distinct; don't encode an unverified cause as the requirement. An un-root-caused bug is a diagnosis task, not a budget-solver fix — see Budget-Solver Fit.
- **Grounded names.** Every concrete artifact the contract names (file, class, method, endpoint, table, config key) must be verified to exist via Read/Grep before the contract is written. A budget solver trusts names in the contract; one hallucinated name there becomes hallucinated code. Can't verify it → don't name it; describe its role and let the solver find it.

---

## Model Guard — Run First, All Modes

Before anything else (both fresh-define and refine-from-handoff), confirm your own model identity. `/case` is the master architect: it MUST run on a **planning model**.

If you are a **budget model** (or anything that isn't a planning model), **STOP immediately**. Do not classify, draft, grill, read `.handoff.md`, or write any file. Reply only:

> `/case` must run on a planning model. You're on `<model>`. Switch to one of those (e.g. via `/model`), then run `/case` again.

Only when you are on a planning model, proceed past this guard.

---

## Trigger

Invoked with `/case [description]`.

- **Model Guard first** — confirm you are on a planning model (see Model Guard). Not a planning model → refuse and stop.
- **If `.handoff.md` exists** → enter Refine-from-Handoff Mode (see that section), skip the fresh-define workflow.
- If `description` is empty, ask one question: "What do you want to solve?".
- Otherwise infer from the user description, and grill on scope-affecting unknowns one at a time (see Workflow).

---

## Workflow

When invoked:

0. **Model Guard.** Confirm you are on a planning model (see Model Guard). If not → refuse and stop here; do nothing else.
1. **Parse args.** If empty, ask: "What do you want to solve?".
2. **Classify problem type.** See Problem Types. If ambiguous between 2 types, pick the more specific — don't ask.
3. **Draft all sections.** Inference-first from the user description. If the user names a concrete artifact (service/class/file), targeted exploration allowed: Read the file + Grep the artifact name, budget max 3 Read + 2 Grep, to surface relevant method/attribute/caller so Context and AC can be concrete. Without an artifact hint, skip exploration — let the solver explore. The budget applies to *discovery* only; verifying artifacts the draft ends up naming is mandatory and unbudgeted (see Grounded names).
4. **Grill on scope-affecting unknowns.** For each unknown that changes behavior or scope and cannot be inferred:
   - If answerable from the codebase, explore instead of asking.
   - Otherwise ask **one question at a time**, each with your recommended answer. Resolve dependencies between decisions one-by-one — walk the decision tree.
   - Continue until no scope-affecting unknown remains. Cosmetic details: don't ask, infer.
5. **Budget-solver fit gate.** Judge whether the drafted contract fits one budget-solver pass (see Budget-Solver Fit). If too large → STOP before writing and ask the user (one question, recommended answer) which path: decompose into Milestones, narrow now, or accept a bigger solver. Never emit an oversized single-pass contract silently.
6. **Pre-write guard.** Before writing, scan the draft and strip violations:
   - Code block with implementation → remove.
   - File:line edit instruction ("change line 32 to X") → abstract to "area to look at" or remove.
   - Prescribed name for a new artifact (forced new key/constant/method) → abstract to its role or remove.
   - Section outside the template (Solution Specification, Code Change, Definition of Done) → remove.
   - Problem Statement that narrates mechanism → rewrite to contract/outcome.
   - AC scenario that fails the AC Quality Rubric (e.g. merges 2 independent assertions, or only a negative assertion with no positive counterpart) → split, add, or revise.
   - AC narrative leaking a raw tech identifier with general business meaning → lift the definition to Glossary, AC references the business term.
7. **Self-audit.** Before writing, confirm — and fix any gap before proceeding:
   - All core sections for the problem type are present and filled (no placeholder text left).
   - A `Verification` mode is stated (contract-level for single-pass, or per-milestone).
   - Every AC passes the AC Quality Rubric; the Pre-write guard and Budget-Solver Fit gate actually ran.
   - Every concrete artifact named anywhere in the contract was verified to exist (Grounded names). Unverified → verify now, or rephrase to the artifact's role.
   - **Solver dry-run.** Simulate the budget solver for each AC: could it write the test directly from the Given/When/Then, with the Context and Glossary at hand, without making a design decision the contract leaves open (inventing an API shape, picking a data model, choosing where state lives)? A lurking decision → settle it in Context/Constraints, or split the scope.
8. **Check existing `.case.md`.** If present, show the intent diff and ask for overwrite confirmation. Default non-destructive — if user declines, cancel.
9. **Write file.** Show the path + a one-line summary of each filled section.
10. **Instruct handoff.** Tell the user: review the file, then `/clear`, then `/solve`. If the contract has Milestones, note `/solve` runs one milestone per pass.

---

## Problem Types

5 types for classification. Each type sets the **mandatory sections** in `.case.md`.

| Type              | Hallmark                                                      | Required (beyond core) |
|-------------------|---------------------------------------------------------------|------------------------|
| **Feature**       | Build new functionality (endpoint, job, model, UI component). | (core only).           |
| **Bugfix**        | Bug exists, reproduce → fix → regression.                     | (core only).           |
| **Refactor**      | Behavior preserved, structure cleanup.                        | (core only).           |
| **Design**        | Design a system/API/data model before implementing.          | Deliverable Format.    |
| **Investigation** | No code change, deliverable = findings document.             | Deliverable Format.    |

**Core sections** (all types): Title, Problem Statement, Context, Constraints, Acceptance Criteria, Verification, Out of Scope. (In milestone mode, Verification is stated per-milestone instead of as a top-level field.)

---

## Budget-Solver Fit

Always size the contract for a budget model — limited context and reasoning — regardless of which model actually runs `/solve`. Before writing, judge whether the contract fits one budget-solver pass.

**Too-large signals** (any of these → stop and rescope):
- Spans multiple independent capabilities or subsystems.
- More than ~6–8 AC scenarios across unrelated behaviors.
- A single AC implies building a whole subsystem, not one observable behavior.
- Cross-cutting change touching many files/layers at once.
- Verification needs long, multi-part setup no budget model can hold in context.
- An AC whose test forces the solver into a design decision the contract doesn't settle (invent an API shape, pick a data model, choose where state lives) — settle it in the contract or split the scope.
- **Bugfix whose root cause isn't reproduced and confirmed.** Diagnosing an unknown failure — reading runtime errors, bisecting, device-only repro — is what budget models are worst at. While the cause is still a hypothesis, make the diagnosis its own milestone for a planning model (Verification: human, with device/log access); the budget solver gets only the mechanical fix once the cause is observed. Never hand a budget model "figure out why X happens."

When too large, **STOP and ask the user** (one question, recommended answer). Say plainly: "This is too large for a budget model to solve in one pass." Offer:

1. **Decompose (recommended).** Use the grilling approach to split the scope into ordered **Milestones** — each an independently verifiable slice small enough for a budget model (rule of thumb: one capability, ≤3 scenarios, files within one subsystem). Fill the Milestones section; `/solve` executes one milestone per pass, checkpointing at each boundary.
2. **Narrow now.** Cut to the first valuable slice; move the rest to Out of Scope or a later `/case`.
3. **Accept a bigger solver.** Keep it as one contract, acknowledging it exceeds a budget model; the user solves on a planning model.

Never silently emit an oversized single-pass contract. Decomposition is design work — it belongs here on the planning model, not the budget solver.

---

## Verification Mode

Every contract states a `Verification` mode telling `/solve` whether a human checkpoint is needed: `auto`, `human`, or `both`. State it **once at contract level** for a single-pass contract, or **per-milestone** when decomposed. Assigning it is judgment work — do it here, not in the budget solver.

**`human`** (pause for a person) — acceptance is observed by a person exercising the running system, or needs judgment a machine can't make:
- User-facing surface: UI/page, CLI output, rendered artifact, an endpoint a human can hit.
- Qualitative acceptance: looks/feels right, UX flow, copy/tone, layout, output quality.

**`auto`** (no pause, TDD only) — acceptance is fully machine-assertable with no experiential dimension:
- No observable surface change (pure refactor) → existing tests stay green.
- Exact/high-volume assertions: parsing, algorithms, math, invariants (no N+1, perf, concurrency).
- Internal component contract with no user-facing surface yet.

**`both`** — has a machine-assertable part AND an experiential part. `/solve` TDDs the former, then pauses for the latter.

**Default when ambiguous → `human`.** Safer to interrupt than to let an experiential slice pass unchecked.

---

## Refine-from-Handoff Mode

Entered when `.handoff.md` exists in the current directory (written by `/solve` on a rejected human checkpoint, or as pre-flight feedback before any code was touched). This improves the contract from that feedback.

**Model guard applies** (see Model Guard) — refinement is architect work, planning models only.

Steps:
1. Read `.handoff.md` and the current `.case.md`. The handoff carries a `Type:` line that sets how to treat it:
   - **`pre-flight`** — the solver refused to start the slice: too abstract, too big, an unsettled design decision, or names it couldn't ground in the codebase. Nothing was run, so skip step 2 (there is no diagnosis to vet). The handoff's failed checks are your grilling agenda: resolve each from the codebase where possible, otherwise ask the user one question at a time with a recommended answer. The fix is usually decomposing the slice into smaller milestones or concretizing AC/Context/Glossary — then re-run the Budget-Solver Fit gate with stricter eyes; the solver has already proven your last sizing judgment optimistic.
   - **`human-rejection`** (or no `Type:` line, older handoff) — a human rejected a checkpoint; proceed with step 2.
2. **Vet the diagnosis before trusting it** (human-rejection only). A handoff often asserts a root cause, sometimes in confident detail. Separate what was *observed* (the raw error, the failing assertion, the captured response/log) from what was *inferred* (the story explaining it). Only observed facts are load-bearing. If the asserted cause was never actually captured — no exception/log proving it — treat it as a hypothesis, not a premise; don't rebuild the contract around it. Before committing a fix direction, sanity-check: *does it still work if the hypothesis is wrong?* A fix that shares the same failing path as the original (same network/IO/library call) won't survive a cause that lives in that path. If the real cause is still unobserved, the right refinement is a diagnosis milestone for a planning model — not a budget-solvable fix built on a guess.
3. Apply the feedback to the contract: revise/add AC, Constraints, or Milestones as required. Stay WHAT-only — no mechanism, no code. Re-run the AC Quality Rubric and the Budget-Solver Fit gate on the change.
4. Show the intent diff (what changes in `.case.md`) and confirm with the user.
5. Write the updated `.case.md`. Preserve milestone order and already-done status.
6. Remove `.handoff.md` (it's consumed). Leave `.solve-progress.md` untouched — `/solve` owns it.
7. Instruct: `/clear`, switch to a budget model, run `/solve` to continue the remaining milestones.

---

## AC Quality Rubric

7 criteria for each Acceptance Criteria scenario. Before writing, scan AC and revise any that fail.

- **Atomic** — 1 scenario = 1 behavior. If Then/And checks 2 observables that can fail separately → split into 2 scenarios.
- **Self-contained** — readable standalone. If scenarios relate (e.g. regression vs new behavior), state it explicitly in the title.
- **Specific & verifiable** — Given/When/Then use concrete, deterministically assertable values. Avoid judgment wording ("should be reasonable", "should look nice").
- **Observable** — assertion is about an externally visible outcome: result state (response field, output), system state (DB row, cache entry), external side effect (notification sent, API call made), or absence of operation. A method-call assertion as a surrogate for an observable that actually exists in the result = mechanism-bound, revise.
- **Generalizable** — test data representative of the behavior class, not accidental. A specific value (e.g. `'female'`) is fine if it's an instance of a relevant broader case.
- **Exhaustive** — cover new behavior (positive) AND preserved behavior (regression). Bugfix: "bug reproduces" + "fix applied". Feature: happy path + boundary. Refactor: behavior identical before/after.
- **Readable** — business terminology. Raw tech identifiers with business meaning → Glossary, referenced via the business term. Self-explanatory public API may be inline.

---

## What NOT to Include

The Pre-write guard (Workflow step 6) is the canonical list of what to strip: implementation code, file:line edits, prescribed names for new artifacts, sections outside the template (Solution Specification, Definition of Done…), mechanism narrative in the Problem Statement, and AC that merge independent assertions. The throughline: if you're tempted to write any of these, you're writing a *plan*, not a *problem* — stop and return to contract/outcome.

---

## Output Format

Write `.case.md` with the template below. Mandatory sections depend on problem type.

````markdown
# [Problem Title]

## Problem Statement
[One paragraph: what the problem is, why it must be solved, the desired outcome. State the outcome, don't narrate mechanism.]

## Context
[Background, domain knowledge, assumptions made during classification. May name existing artifacts (file/class/method) as pointers for the solver. For an environment-sensitive bug, state the facts the solver can't infer from code — intercepting proxy / custom CA, OS-device specifics, pinned SDK/library versions. Leave empty if no extra context.]

## Glossary
[Optional. Define business terms used in AC, mapped to technical artifacts so AC reads without codebase context. Skip if AC has no jargon.]
- **[business term]** — [short definition, with reference to the technical artifact if needed.]

## Constraints
- [Boundary to preserve. E.g. "Preserve method X (used by other callers).", "Don't change signature Y."]
- [NOT mechanism — don't write "use AppSetting".]

## Acceptance Criteria

Scenario: [scenario title]
  Given [initial condition — specific value, observable state]
  When [action — callable method, triggerable event]
  Then [result — observable state, method call/non-call, response field]

[Add scenarios for important edge cases. Each must be programmatically verifiable. If decomposed into Milestones, AC live under each milestone instead — write "See Milestones" here.]

## Verification
[Single-pass only (no Milestones). State the mode. For human/both, add one line: what the person checks and how to exercise it (command, screen, input). When Milestones are used, omit this section — each milestone carries its own Verification tag.]
Verification: [auto | human | both]   — [human/both: what to check + how to exercise it]

## Milestones
[Optional — only when Budget-Solver Fit triggered decomposition. Ordered slices, each independently verifiable and small enough for a budget model. /solve executes one milestone per pass, checkpointing at each boundary.]

### Milestone 1 — [capability]
Verification: [auto | human | both]
[One line: the observable capability this slice delivers.]
  Scenario: [title]
    Given / When / Then
[Done when: all scenarios in this milestone pass (+ human approval if human/both).]

### Milestone 2 — [capability]
Verification: [auto | human | both]
[...]

## Out of Scope
- [Explicit things not done in this scope]
- (Write "(none)" if no extra boundary.)

## Files of Interest
[Optional. Only if the user gave a pointer hint. Points to an artifact (its role), not an instruction.]
- `path/to/file` — [one line role. NOT "change line 32".]

## Deliverable Format
[ONLY for Design / Investigation: expected output shape — markdown file, folder structure, etc. Skip otherwise.]
````

---

## Filled Example (Bugfix)

Note: no code block, no file:line edit, no prescribed mechanism, no section outside the template.

````markdown
# Bug: Engagement Campaign Doesn't Expire After end_at Passes

## Problem Statement
An engagement campaign whose `end_at` has passed still returns as `active` from `GET /api/shopping_pages`. Expected: a campaign past its `end_at` must not appear in active campaign results.

## Context
`EngagementCampaign` has `start_at` and `end_at` columns (timestamp). The bug appeared after the `end_at` column was added but the active scope query wasn't updated.

## Constraints
- Don't change the signature of scope `active` (used by 3 other callers).
- Don't add a new migration index.

## Acceptance Criteria

Scenario: Expired campaign not in active
  Given an EngagementCampaign with start_at 1 day ago, end_at 1 hour ago
  When calling `EngagementCampaign.active`
  Then that campaign is not in the result

Scenario: Non-expired campaign stays in active
  Given an EngagementCampaign with start_at 1 day ago, end_at 1 day from now
  When calling `EngagementCampaign.active`
  Then that campaign is in the result

## Verification
Verification: auto   — scope behavior is asserted by a unit test on `EngagementCampaign.active`; no human checkpoint needed.

## Out of Scope
- Don't refactor `shopping_pages_controller`.
- Don't change the serializer response.

## Files of Interest
- `app/models/engagement_campaign.rb` — model with scope `active`.
````

---

## After Saving

Guide the user:

> Saved to `.case.md`. Review the contract & Acceptance Criteria. When ready:
>
> 1. `/clear` — reset context (saves tokens)
> 2. `/solve` on a budget model — Haiku or Gemini Flash, or a `minimax` session for MiniMax-M3 (run M3 with thinking enabled; this is agentic work)
>
> The solver owns the HOW and self-verifies against your Acceptance Criteria. It pre-flights each slice before coding — if a slice is too abstract or too big for its tier, it writes `.handoff.md` and stops *without touching code*, so you re-run `/case` to decompose. For milestone contracts it runs one slice per pass and pauses at `human`/`both` checkpoints; if you reject one it likewise writes `.handoff.md` and stops, so you re-run `/case` on a planning model to refine, then `/solve` to resume.

---

## File Protocol

Single writer per file — keep these roles clean:
- `.case.md` — written only here (`/case`, planning model). The contract.
- `.solve-progress.md` — written only by `/solve` (budget). Milestone status ledger for resume. Never edited here.
- `.handoff.md` — written by `/solve` (rejected human checkpoint, or pre-flight refusal before any code); consumed and removed here. Never written here.
