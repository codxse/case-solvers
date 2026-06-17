---
name: evaluate
description: 'Human review gate for a needs-review story by id: opens its branch diff in VSCode, then enacts the verdict — approve (merge to main, close, unblock dependents) or request changes. Request changes spawns a frontier-pinned subagent (Opus by default, never the ambient model) that runs /code-review and applies the fixes in place, shows you the applied diff, and amends bd/<id> only after you confirm; a wrong contract instead routes to /refine. --approve merges without opening the diff; --review [effort] runs the code-review pass straight away (default high); --note <text> steers the review and/or annotates the story.'
version: 1.3.1
argument-hint: '[<story-id>] [--approve] [--review [effort]] [--note <text>]'
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
| `--approve` | Resolve story (step 1), skip steps 2–3, go straight to 4a (merge) |
| `--review [effort]` | Resolve story (step 1), skip steps 2–3, go straight to **4b implementation path** — run the `/code-review` pass at `effort` (default `high`) |
| `--approve --note <text>` | Same as `--approve`; record `<text>` as a `bd comment` before merging |
| `--review [effort] --note <text>` | Same as `--review`; pass `<text>` to the reviewer as steering ("focus on …") **and** record it as a `bd comment` |
| neither | Full interactive flow: steps 1 → 2 → 3 → 4a or 4b |

`effort` is any `/code-review` level (`low`/`medium`/`high`/`max`); omit it for `high`. `--review` always takes the *implementation* path — `/code-review` can't fix a wrong contract, so for that, use the interactive flow (which asks impl vs. contract) or go straight to `/refine`. `--note` is orthogonal: it annotates the story on any path, and additionally steers the reviewer on `--review`. 4a's merge-conflict confidence gate applies in all paths — fast-pathing the verdict does not bypass conflict resolution.

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

### 4b. Request changes → fix in place via /code-review
If `--note <text>` was supplied, record it as a `bd comment` now (before asking anything else).

Ask which kind of change, because they route differently:

- **Implementation needs work (most common)** → the contract is fine, the code isn't. Don't bounce the story back to `/solve`; fix it in place by delegating the review to a **frontier model**:
  1. **Spawn the review-and-apply as a subagent and pin its model to a frontier tier explicitly — never inherit the ambient model.** `/evaluate` carries no model gate, so if you don't set the model the subagent inherits whatever `/evaluate` is running on — often a budget model like `haiku` — which is exactly the failure this step exists to prevent. Pinning is **mandatory**, not best-effort: spawn via the subagent tool with its `model` parameter set, defaulting to **`opus`** (the preferred frontier reviewer). Concretely on Claude Code, the spawn must carry `model: "opus"` (e.g. `Agent(subagent_type: "general-purpose", model: "opus", prompt: …)`) — the `model` argument is required here, not optional. `sonnet` is an acceptable frontier fallback only when `opus` is unavailable; on Codex, pin its frontier GPT-5-class equivalent. **Never** pin or inherit a budget ID (`haiku`/`flash`/`mini`/`lite`/`nano`/…), and never run the review inline on `/evaluate`'s own model instead of spawning. If no frontier model can be pinned, **stop** and tell the user — do not fall back to a budget reviewer.
  2. Inside that subagent, run `/code-review <effort> --fix` scoped to the story's worktree (`../<repo>-worktrees/<id>`), handing it the contract as context — the **WHAT** + Acceptance Criteria from `bd show <id>` — as what the diff must satisfy, plus any `--note <text>` as steering ("focus on …"). `<effort>` is the level passed on `--review` (default `high`; in the interactive flow, confirm it, defaulting to `high`). It reviews the `bd/<id>` diff and applies its findings to the worktree in place — **leaving them unstaged/uncommitted.**
  3. **Confirm before amend — the human reviews the reviewer's work first.** Surface what the subagent changed: its findings and the **applied diff** (the worktree changes it just made, e.g. `git -C ../<repo>-worktrees/<id> diff`), and re-open the worktree in VSCode if the user wants. Then ask plainly: **amend these into `bd/<id>`?** Do not amend until the human says so. If they decline → don't amend; let them edit the worktree themselves, discard, or request another `--review` pass. Nothing is baked into the branch without this go-ahead.
  4. On the go-ahead, back in `/evaluate` (any model — this step is mechanical), **amend** the branch commit on `bd/<id>` with the applied fixes. The story stays on its branch and in `needs-review`; nothing changes status and the worktree is kept.
  5. Re-open the diff and return to **step 3** so the human approves the amended branch or asks for another pass. Loop until they approve (4a) — each pass is another pinned-frontier `/code-review`, a confirm-before-amend, and the amend.
  - **Host note:** `/code-review` is the review-and-apply mechanism on Claude Code. On Codex, run that host's equivalent review-and-apply command in the same pinned-frontier subagent against the same worktree, then amend identically — the behavior (frontier reviewer, apply fixes in place, amend `bd/<id>`) is what matters, not the command name.
- **The contract itself is wrong** → `/code-review` can't fix a wrong spec. `bd label add <id> needs-refinement` + a `bd comment` with the reason (if not already recorded via `--note`), remove `needs-review`. Tell the user: `/refine <id>` to fix the contract first, then `/solve <id>`.

Either way the reason lives as a durable per-story comment, readable later via `/board <id>`.

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
| request impl change | spawn subagent **pinned to a frontier model (`model: "opus"`, never inherited)** → `/code-review <effort> --fix` in `../<repo>-worktrees/<id>` (effort from `--review`, default `high`) → show applied diff + **confirm before amend** → amend `bd/<id>` (keep branch + `needs-review`) |
| show reviewer's applied diff | `git -C ../<repo>-worktrees/<id> diff` (before staging/amend) |
| contract wrong | `bd label add <id> needs-refinement` + `bd comment` + `bd label remove <id> needs-review` |

Single-writer discipline: `/evaluate` is the only skill that merges to `main` and closes a story, and it never edits the contract body (`/case` / `/refine`). It does not hand-write implementation code, but its request-changes path **delegates** the fix to a frontier-pinned `/code-review` subagent, which applies it in place on `bd/<id>` — review-time fixes live on the review tier (and always on a frontier model, regardless of what model `/evaluate` runs on); greenfield implementation stays `/solve`'s job.
