---
name: evaluate
description: 'Human review gate for a needs-review story by id: opens its branch diff in VSCode, then enacts the verdict — approve (merge to main, close, unblock dependents) or request changes (back to /solve or /refine). --approve merges without opening the diff; --request-changes routes straight to the send-back path; --note <text> attaches a comment to either.'
version: 1.2.0
argument-hint: '[<story-id>] [--approve] [--request-changes] [--note <text>]'
disable-model-invocation: true
user-invocable: true
---

# Evaluate Skill

The human review gate. A story finished by `/solve` sits in **`needs-review`** on branch `bd/<id>`. The **human** reviews the diff in VSCode; you open it, capture the verdict, and enact it mechanically — **you never judge the code yourself.** Never show raw `bd`/`git` output; translate and render human-friendly. Use the map below; if a flag is uncertain or a command errors, run `bd <cmd> --help`.

## Environment Guard — Run First

- `.beads/` absent → tell the user to `/case <description>` first. Stop.

## Flag dispatch — check before step 1

| Flags | Action |
|---|---|
| `--approve` | Resolve story (step 1), skip steps 2–3, go straight to 4a |
| `--request-changes` | Resolve story (step 1), skip steps 2–3, go straight to 4b (still prompts for impl vs. contract) |
| `--approve --note <text>` | Same as `--approve`; record `<text>` as a `bd comment` before merging |
| `--request-changes --note <text>` | Same as `--request-changes`; `<text>` pre-fills the feedback — record it as a `bd comment` and skip the "what's the feedback?" prompt, but still ask impl vs. contract |
| neither | Full interactive flow: steps 1 → 2 → 3 → 4a or 4b |

`--note` is orthogonal: it attaches text to the story regardless of which path is taken. 4a's merge-conflict confidence gate applies in all paths — fast-pathing the review does not bypass conflict resolution.

Story id: use the argument if supplied. If omitted but a story was mentioned earlier in this session, use that. If still unknown, go to step 1.

### 1. Resolve the story
- No id → show the review & merge queue (`bd list` filtered to `needs-review`) and ask which. Stop.
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
1. If `--note <text>` was supplied, record it as a `bd comment` on the story first.
2. Merge `bd/<id>` into `main`.
3. **Merge conflict?** Apply the confidence gate:
   - **Clear & safe** — purely additive/textual, both sides' intent preserved, AND the branch's tests stay green after resolving → auto-resolve. The resolution is part of the merge the user just approved; show it.
   - **Ambiguous** — both sides changed the same logic/value differently, or resolving means one story's AC must lose, or tests go red → **do not guess.** Present it decision-ready: the conflict, the two intents, the options, your recommendation. Let the human decide, then apply. (A semantic conflict often means the decomposition let two stories collide — worth flagging for `/refine`.)
4. After a clean merge: `bd close <id>` (this unblocks any dependents — recompute and report which stories are now READY), remove the `needs-review` label, and remove the worktree + delete branch `bd/<id>`.
5. Report: merged, closed, and the newly-unblocked stories (`/solve <id>` to pick one).

### 4b. Request changes → back to the right owner
If `--note <text>` was supplied, record it as a `bd comment` now (before asking anything else).

Ask which kind of change, because they route differently:

- **Implementation is wrong (most common)** → the contract is fine, the code isn't. Record the feedback as a `bd comment` (if not already recorded via `--note`), remove `needs-review`, set the story back to `in_progress`, and **keep** the branch + worktree so `/solve` resumes on it. Tell the user: `/solve <id>` to redo with your feedback.
- **The contract itself is wrong** → the spec needs rethinking. `bd label add <id> needs-refinement` + a `bd comment` with the feedback (if not already recorded via `--note`), remove `needs-review`. Tell the user: `/refine <id>` to refine the contract first, then `/solve <id>`.

Either way the feedback lives as a durable per-story comment, readable later via `/board <id>`.

## bd / git map (confirm flags via `--help`)

| Intent | Command |
|---|---|
| read story + review comment | `bd show <id>` |
| review queue / recompute ready | `bd list` (filter `needs-review`) / `bd ready` |
| open diff for human | `code ../<repo>-worktrees/<id>` (or `git diff main...bd/<id>`) |
| merge | `git -C <main-worktree> merge bd/<id>` |
| record note / feedback | `bd comment <id> "<text>"` |
| approve | `bd close <id>` + `bd label remove <id> needs-review` |
| clean up | `git worktree remove …` + `git branch -d bd/<id>` |
| request impl change | `bd comment` + `bd update <id> --status in_progress` + `bd label remove <id> needs-review` (keep branch) |
| contract wrong | `bd label add <id> needs-refinement` + `bd comment` + `bd label remove <id> needs-review` |

Single-writer discipline: `/evaluate` is the only skill that merges to `main` and closes a story. It never edits the contract body (`/case` / `/refine`) and never writes implementation code (`/solve`).
