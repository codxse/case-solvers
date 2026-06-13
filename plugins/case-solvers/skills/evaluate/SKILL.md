---
name: evaluate
description: 'Human review gate for a needs-review story by id: opens its branch diff in VSCode, then enacts the verdict — approve (merge to main, close, unblock dependents) or request changes (back to /solve or /case). --skip-review merges without opening the diff or asking a verdict.'
version: 1.1.0
argument-hint: '[--skip-review] [<story-id>]'
disable-model-invocation: true
user-invocable: true
---

# Evaluate Skill

The human review gate. A story finished by `/solve` sits in **`needs-review`** on branch `bd/<id>`. The **human** reviews the diff in VSCode; you open it, capture the verdict, and enact it mechanically — **you never judge the code yourself.** Never show raw `bd`/`git` output; translate and render human-friendly. Use the map below; if a flag is uncertain or a command errors, run `bd <cmd> --help`.

## Environment Guard — Run First

- `.beads/` absent → tell the user to `/case <description>` first. Stop.

## Workflow

**`--skip-review` present?** This is a *merge without review*, user-initiated by the flag. Resolve the story (step 1), then go straight to **4a (merge, close, unblock)** — skip the diff (step 2) and the verdict (step 3) entirely. 4a's merge-conflict confidence gate still applies: skipping *review* is not skipping *conflict resolution*, so an ambiguous conflict still stops for the human. After a clean merge and close, end with the skip warning (step 4c) in place of the normal approve report. Without the flag, run the full gate below in order.

### 1. Resolve the story
- No id → show the DONE · review & merge queue (`bd list` filtered to `needs-review`) and ask which. Stop.
- `bd show <id>`. Confirm it is `needs-review`. If not (still in progress, blocked, or already closed) → say its actual state and stop; nothing to evaluate.

### 2. Open the diff for the human (no terminal diff)
- Surface the solver's review comment: **what was built, how to exercise it, files changed**, and any AC that fell back to a runtime observation or needs a `human`/`both` check.
- Open the branch in VSCode for review:
  - `code ../<repo>-worktrees/<id>` (the story's worktree on branch `bd/<id>`).
  - `code` not on PATH → print the worktree path and branch name and the command `git diff main...bd/<id>`, and let the user review in their own tool.
- For a `human`/`both` Verification story, remind the user to actually exercise the running system per the solver's instructions, not just read the diff.

### 3. Ask the verdict
Ask plainly: **approve & merge**, or **request changes**? Do not push an opinion on the code.

### 4a. Approve → merge, close, unblock
1. Merge `bd/<id>` into `main`.
2. **Merge conflict?** Apply the confidence gate:
   - **Clear & safe** — purely additive/textual, both sides' intent preserved, AND the branch's tests stay green after resolving → auto-resolve. The resolution is part of the merge the user just approved; show it.
   - **Ambiguous** — both sides changed the same logic/value differently, or resolving means one story's AC must lose, or tests go red → **do not guess.** Present it decision-ready: the conflict, the two intents, the options, your recommendation. Let the human decide, then apply. (A semantic conflict often means the decomposition let two stories collide — worth flagging for `/case`.)
3. After a clean merge: `bd close <id>` (this unblocks any dependents — recompute and report which stories are now READY), remove the `needs-review` label, and remove the worktree + delete branch `bd/<id>`.
4. Report: merged, closed, and the newly-unblocked stories (`/solve <id>` to pick one).

### 4b. Request changes → back to the right owner
Ask which kind of change, because they route differently:

- **Implementation is wrong (most common)** → the contract is fine, the code isn't. Record the feedback as a `bd comment`, remove `needs-review`, set the story back to `in_progress`, and **keep** the branch + worktree so `/solve` resumes on it. Tell the user: `/solve <id>` to redo with your feedback.
- **The contract itself is wrong** → the spec needs rethinking. `bd label add <id> needs-refinement` + a `bd comment` with the feedback, remove `needs-review`. Tell the user: `/case --id <id>` to refine the contract first, then `/solve <id>`.

Either way the feedback lives as a durable per-story comment, readable later via `/case --id <id>`.

### 4c. Skip-review warning (only when `--skip-review` was used)
The merge happened without a human reading the diff. After 4a's merge/close/unblock, the report's headline is a clear warning — always shown, not a prompt, nothing to dismiss:

> ⚠ Merged `<id>` without review — skipped the human quality gate.

Then still report the newly-unblocked stories (`/solve <id>` to pick one), as 4a does. Do **not** tell the user to run `/evaluate <id>` afterward: the story is closed and branch `bd/<id>` is deleted, so there is nothing left to review.

## bd / git map (confirm flags via `--help`)

| Intent | Command |
|---|---|
| read story + review comment | `bd show <id>` |
| review queue / recompute ready | `bd list` (filter `needs-review`) / `bd ready` |
| open diff for human | `code ../<repo>-worktrees/<id>` (or `git diff main...bd/<id>`) |
| merge | `git -C <main-worktree> merge bd/<id>` |
| approve | `bd close <id>` + `bd label remove <id> needs-review` |
| clean up | `git worktree remove …` + `git branch -d bd/<id>` |
| request impl change | `bd comment` + `bd update <id> --status in_progress` + `bd label remove <id> needs-review` (keep branch) |
| contract wrong | `bd label add <id> needs-refinement` + `bd comment` + `bd label remove <id> needs-review` |

Single-writer discipline: `/evaluate` is the only skill that merges to `main` and closes a story. It never edits the contract body (`/case`) and never writes implementation code (`/solve`).
