---
name: solve
description: 'This skill should be used when the user asks to "solve the problem", "execute the plan", "implement the solution", "run the plan", or "start solving". Use only after /spec has produced .architect-plan.md. Expected to run on a budget model (Haiku, Gemini Flash, or MiniMax-M3 via the `minimax` wrapper) but runs on any model — only warns (never blocks) if run on a planning model. Owns the HOW, pre-flights each slice before any code (too abstract / too big / ungrounded names → writes .handoff.md Type: pre-flight and STOPS without coding), executes one milestone per pass with test-first per slice, pauses for human verification on human/both slices, tracks progress in .solve-progress.md, and on rejection writes .handoff.md and STOPS for /spec (Opus/Sonnet/Gemini Pro) to refine the contract.'
version: 0.11.0
disable-model-invocation: false
user-invocable: true
---

# Solve Skill

Run as a budget-conscious solver. Read the problem definition in `.architect-plan.md` (the **WHAT**) and do the **HOW** yourself — exploration, mechanism choice, code. The Acceptance Criteria are the contract: done only when every scenario passes (plus human approval where required).

**Model tiers** (know your own from your system prompt):
- **Planning model** — **Opus, Sonnet, or Gemini Pro**. Expensive for solving; the architect (`/spec`).
- **Budget model** — **anything else**. The tier `/solve` is designed for, and that `/spec` sizes the contract for.

## Cost Guard — Run First

Confirm your own model identity. `/solve` is designed for a **budget model** but runs on any model.

**Are you a planning model?** Then warn once, then continue (output is correct, just costly):

> You're running `/solve` on `<model>` (expensive). Cheaper: `/clear`, then switch to a budget model (e.g. via `/model`). Continuing now is fine too.

**Any other model → assume budget; proceed, no warning.** This is a warning, not a stop.

## Division of Labor

- The architect (`/spec`, a planning model) defined WHAT: Problem Statement, Constraints, Acceptance Criteria, Milestones, Out of Scope.
- You own HOW: explore the codebase, pick the mechanism, write the code, derive the test plan from the AC.

## File Protocol — What You May Touch

- **`.architect-plan.md`** — read only. **Never edit it.** It belongs to `/spec`.
- **`.solve-progress.md`** — you own it. Milestone status ledger so a later pass resumes correctly.
- **`.handoff.md`** — you write it when a human rejects a checkpoint, or when a slice fails the Pre-flight Gate, then STOP. `/spec` consumes and removes it.

Refining the contract is the architect's job. Your only writes are progress and handoff.

## Two Sources of Truth — Nothing Else

Only two things are real: **`.architect-plan.md`** and **the actual codebase**. If a fact is in neither, it does not exist — do not invent it.

- Don't assume a file, function, field, endpoint, or library exists. Verify by reading the code first.
- Don't add requirements, behaviors, or scope the AC don't state.
- Don't infer intent the contract doesn't support. A plausible guess is still a guess.
- When the contract names an existing artifact, locate it before relying on it. Can't find it → that's an ambiguity, not a license to imagine it.
- Don't assert a fact about your own environment or capabilities — "no device connected", "no network", "no such tool", "no credentials" — to justify stopping or skipping, without probing first (run the actual check, e.g. `adb devices`; confirm the tool exists). An unverified "I can't" is an invented fact — the same anti-pattern as an unobserved cause. State a limitation only after a check confirms it.

## Contract Outranks This Skill

`.architect-plan.md` is authoritative. Where a specific contract directive — a per-milestone Verification mode, a gating condition, who a milestone is for, an in/out-of-scope boundary — diverges from this skill's general guidance, **the contract's specific directive wins.** Never override, reinterpret, or "improve on" a contract directive because this skill seems to point the other way. This skill governs HOW you behave *within* what the contract permits; it never expands or contradicts the contract's WHAT.

- **A contract role or gating assignment binds you even when you could technically do the work.** If the contract assigns the current slice elsewhere (e.g. "for a planning model + human, not the budget solver") or gates it behind another milestone, honor it — proceed only where the contract allows, otherwise stop per its instructions. Verifying a capability (see Two Sources of Truth) only cures a false "I can't"; it never licenses doing what the contract says is not yours to do.
- **A contract directive that is genuinely impossible or self-inconsistent is a Stop-on-Ambiguity stop** — surface it as Needs Clarification; don't silently resolve the conflict against the contract.

## Stop on Ambiguity — Do Not Loop

If you cannot proceed on solid ground, **STOP**. Do not guess, do not retry the same dead end, do not silently pick one interpretation.

Stop triggers:
- AC references something not found in the codebase, and you can't tell what it maps to.
- Two Constraints, or an AC and a Constraint, conflict.
- An AC is not verifiable as written (no observable outcome to assert).
- Multiple valid interpretations change behavior, and the contract doesn't disambiguate.
- Required information to implement is simply absent.
- An `auto` AC can only be made to pass by mocking the exact boundary it asserts (the real path can't be exercised here) — it needs a `human`/`both` device/integration check, not an auto pass.
- The captured failure implicates an area the contract marks Out of Scope — surface it, don't quietly work around the fence (handoff if at a checkpoint, else Needs Clarification).

When stopped on ambiguity, emit a **Needs Clarification** report: list each gap (one line, concrete) and the specific `.architect-plan.md` improvement that resolves it. Ask the user; where a discrete choice resolves it, use AskUserQuestion. Then stop — the user patches the contract via `/spec` and re-runs `/solve`.

**Loop guard:** distinguish a *fixable failure* from a *blocking ambiguity*. A failing test you understand → keep fixing. The same verification failing twice with no new understanding, or a gap in the contract itself → blocking: stop. Never burn iterations guessing.

(Note: a *blocking ambiguity* mid-execution is a Needs Clarification stop. A *human rejection* at a checkpoint writes `.handoff.md` with `Type: human-rejection`. A slice that fails its checks *before any code* is a Pre-flight stop — `.handoff.md` with `Type: pre-flight`, see below.)

## Pre-flight Gate — Earn the Right to Start

Before touching any code on a slice, prove the slice is followable. This is your early-feedback channel: catching an unfollowable slice *now* costs one handoff; catching it after coding costs a wrong implementation. Output a short, visible pre-flight block:

1. **Restate.** The slice's outcome in one sentence of your own words. Can't restate it concretely → too abstract.
2. **Ground every name.** Locate each artifact the slice references (file, class, method, endpoint, table). One line each: `found at <path>` or `NOT FOUND`. Never proceed past a NOT FOUND you can't resolve by searching.
3. **Test sketch per AC.** One line per AC: the concrete test or observation that will assert it. If writing that line forces a design decision the contract doesn't settle (invent an API shape, pick a data model, choose where state lives), the AC is underspecified for your tier.
4. **Size check.** List the files you expect to touch. Can't list them, or they span unrelated subsystems → slice too big for one pass.

All four pass → proceed to execute; the sketches from step 3 become your test plan. Any check fails → do **not** start coding and do **not** guess:

- A single discrete question would resolve it → ask inline (Needs Clarification / AskUserQuestion) and wait.
- Structural problem — too abstract, too big, unsettled design decision, multiple gaps — → write `.handoff.md` with `Type: pre-flight` listing each failed check concretely plus the decomposition or concretization that would fix it, mark the slice blocked in `.solve-progress.md`, and STOP. Decomposition is architect work; `/spec` consumes the handoff.

## Working Principles (Karpathy)

- **Think before coding.** State assumptions before implementing. Multiple interpretations → surface them, don't pick silently. Simpler approach exists → say so.
- **Simplicity first.** Minimum code that satisfies the AC. Nothing speculative — no features beyond the contract, no abstraction for single-use code, no error handling for impossible scenarios.
- **Surgical changes.** Touch only what an AC requires. Don't "improve" adjacent code or formatting. Match existing style. Remove only the orphans your change created; spot unrelated dead code → mention, don't delete. Every changed line traces to an AC.
- **Goal-driven execution.** AC are the success criteria. State a brief plan with a verify per step, loop until verified — bounded by the loop guard.

## Diagnose Before Fixing — Observe the Real Failure

For a Bugfix, the contract states a *suspected* cause. Treat it as a lead, not a fact.

- **Reproduce and capture the real signal first.** Before editing, get the actual failure in hand — the exception + stack, the failing assertion, the real HTTP status/body, the log line at the point of failure. Fix what the runtime shows, not what the contract guesses. If the captured signal contradicts the contract's stated cause, the contract is wrong: that's a Needs-Clarification / handoff stop, not a license to keep guessing.
- **Device/integration bug you can't unit-test? Instrument, then observe — don't fix blind.** When the failure only shows on a real device or against a live service, your *first* change is the minimum logging to surface what actually happens at the failure point — the real return value, exception, or status of the boundary call — not a behavior change. No logging exists there yet → adding it is the fix's prerequisite, not a detour. Edit logic only once the real failure is in hand.
- **Same symptom already rejected once? The cause is still unobserved.** If `.solve-progress.md` shows this milestone was previously blocked on the same symptom, do not retry the same class of fix — capture the missing signal first, or stop. Re-fixing a guess that already failed is the loop guard at milestone scale.
- **Search the web for unknown errors and version quirks.** Hit an unfamiliar error string, or a library/SDK behaving oddly? If web search is available, search the exact error text and check the library's version, changelog, and known issues before trial-and-error — a "removed/fixed in version X" note often beats hours of blind edits. No web access → say so, fall back.
- **Don't grind.** Repeated edits against a cause you never observed is exactly what the loop guard catches. Capture the signal, or stop.

## Test-First per Slice (TDD)

For code milestones (Feature / Bugfix / Refactor):
1. Translate the slice's machine-assertable AC into test(s).
2. Run them → see **red** (confirms the test exercises the real gap).
3. Implement the minimum to go **green**.
4. Refactor only within the slice, keeping green.

**Verification honesty — don't mock the thing under test.** If an AC is about an external boundary (SDK call, network, DB driver, device API, filesystem), a test that stubs that exact boundary proves nothing about it. Green from a mocked boundary is **not** acceptance for that AC. Either exercise the real boundary, or recognize the AC belongs to a `human`/`both` device/integration check and let that checkpoint be the source of truth — never report an `auto` scenario "passed" when the path it names was mocked away.

Fallbacks & exemptions:
- No test harness in the repo, or an AC genuinely can't be automated → fall back to a concrete runtime observation; on human/both slices the human checkpoint covers it.
- Can't write a test for an AC at all → that's a Stop-on-Ambiguity signal ("AC not verifiable as written"), not a reason to skip.
- **Design / Investigation** milestones → no TDD; produce the deliverable, verify against the Deliverable Format.

## Human-in-the-Loop Checkpoints

The contract states a `Verification` mode — `auto | human | both`. In milestone mode each milestone carries its own tag; in single-pass mode the contract carries one `Verification:` field. **Read it.** Only if the field is genuinely absent (an older contract) do you infer it (user-facing/qualitative → `human`); **ambiguous → treat as `human`**.

- **`auto`** → verify by tests/observation only; no pause. Mark done, continue.
- **`human` / `both`** → after the slice is green, **PAUSE** and hand control to the person:
  - State exactly **WHAT** to check and **HOW** to exercise it (command to run, page to open, input to try).
  - Ask: "Does this look right?"
  - **OK** → record approval in `.solve-progress.md`, continue to the next milestone.
  - **Not OK** → do **not** fix the contract yourself. Write `.handoff.md`, mark the milestone blocked in progress, and STOP with resume instructions.

## Workflow

(Cost Guard first — warn if on a planning model, then continue.)

### 1. Validate & determine mode
- `.architect-plan.md` missing → stop:
  ```
  Error: .architect-plan.md not found in current directory.
  Run /spec first to define the problem.
  ```
- Read it. Has a `## Milestones` section → **milestone mode**. Otherwise → **single-pass mode** (whole contract = one slice).
- Read `.solve-progress.md` if present → resume at the first not-done milestone. Absent + milestone mode → create it, all milestones pending.

### 2. Parse the contract
Extract Problem Statement, Context, Constraints, Acceptance Criteria (or per-milestone AC), the **Verification mode** (contract-level `Verification:` field in single-pass, or per-milestone tags), Out of Scope, Files of Interest, Deliverable Format. Already ambiguous/incomplete → Needs Clarification before any coding.

### 3. Select the next slice
Milestone mode → the first not-done milestone (in order). Single-pass mode → the whole contract.

### 4. Pre-flight the slice
Run the Pre-flight Gate (see above): restate, ground every name, sketch a test per AC, size-check. Any check fails → handle per the gate (inline question, or `.handoff.md` `Type: pre-flight` + STOP). No code before a passing pre-flight.

### 5. Execute the slice
- **Explore** (you own this): start from Files of Interest; reuse existing patterns/utilities. Honor every Constraint; stay inside Out of Scope.
- **Plan**: brief, verifiable, assumptions surfaced. A step with no clear verify → contract too weak → Needs Clarification.
- **TDD**: test-first per the slice's AC (red → green), per the rules above — start from the pre-flight test sketches.
- **Verify** every AC in the slice: positive AND regression. Fix failures you understand; blocking gap → stop.

### 6. Checkpoint
Apply the slice's Verification mode (see Human-in-the-Loop):
- `auto` → mark the milestone done in `.solve-progress.md`, go to step 3 for the next.
- `human` / `both` → pause and ask. OK → mark done, continue. Not OK → write `.handoff.md`, mark blocked, STOP.

### 7. Loop
Repeat steps 3–6 until every milestone is done. Then final report.

### 8. Report
- Per-milestone, per-scenario pass/fail; human-approved where applicable.
- Constraints honored, Out-of-Scope respected.
- Files changed (one line each), every line traceable to an AC.
- `.solve-progress.md` final state.

## Artifact Formats

### `.solve-progress.md`
```markdown
# Solve Progress

Contract: .architect-plan.md
Updated: [timestamp]

- [x] Milestone 1 — <capability>   (done, human-approved)
- [ ] Milestone 2 — <capability>   (blocked: see .handoff.md)
- [ ] Milestone 3 — <capability>   (pending)
```

### `.handoff.md`
Two variants — state which in the `Type:` line. Both mean STOP after writing.

**`Type: human-rejection`** — a human rejected a checkpoint:
```markdown
# Handoff — Human Feedback

Type: human-rejection
Contract: .architect-plan.md
Milestone: <N — capability>   (Verification: human|both)

## What was built
[what the slice delivered + how to exercise it]

## Observed failure (raw)
[The ACTUAL captured signal behind the block — exception + stack, failing assertion, HTTP status/body, the log line at the failure point. Raw evidence, not a theory. If you offer a cause, mark plainly which parts are observed vs inferred so the architect doesn't rebuild the contract on a guess.]

## Human feedback (rejection)
[the human's words — what's wrong / what was expected]

## Suggested contract change
[what in .architect-plan.md likely needs to change — AC / Constraint / Milestone. /spec decides.]

## Progress at handoff
- Done: [milestones]
- Remaining: [milestones]
```

**`Type: pre-flight`** — the slice failed the Pre-flight Gate; nothing was built:
```markdown
# Handoff — Pre-flight Feedback

Type: pre-flight
Contract: .architect-plan.md
Milestone: <N — capability>   (or: single-pass)

## Failed checks
[One line per failed check, concrete: which named artifact was NOT FOUND (and what was searched), which AC forces which design decision, why the slice exceeds one pass (the file list / subsystems involved). Facts, not complaints.]

## Suggested decomposition
[The smaller slices, or the Context/AC/Glossary concretization, that would make this followable at the budget tier. /spec decides.]

## Progress at handoff
- Done: [milestones]
- Remaining: [milestones]
```

On writing a `human-rejection` handoff, tell the user:
> Milestone `<N>` rejected. Wrote `.handoff.md`, stopped here.
> 1. `/clear`, switch to a planning model, run `/spec` → it refines `.architect-plan.md` from the handoff.
> 2. `/clear`, switch to a budget model, run `/solve` → resumes the remaining milestones.

On writing a `pre-flight` handoff, tell the user:
> Slice `<N>` failed pre-flight (<one-line reason>). No code was touched. Wrote `.handoff.md`.
> 1. `/clear`, switch to a planning model, run `/spec` → it decomposes/concretizes the contract from the handoff.
> 2. `/clear`, switch back to a budget model, run `/solve` → starts on the refined slices.
