# Model Tiers — shared by all case-solvers skills

The model-tier map for the whole plugin: which model IDs are **budget** vs **planning**, and how
each host pins a frontier reviewer. Every skill classifies its own model from its ID by the rules
below; `/evaluate` additionally uses the host map to pin its reviewer. The rules are identical
across skills, so they are written once, here.

**This file is the single source of truth, but it is not read at runtime.** Everything below
`BEGIN SHARED` is inlined verbatim into a `Model Tiers` section of each SKILL.md by
`tests/model-tiers-sync.sh`. Edit the map **here**, then run `tests/model-tiers-sync.sh --write`;
never hand-edit the generated block in a skill. Running the script with no flag verifies every copy
matches and fails on drift.

Inlining is deliberate, for the same reason as the Contract Rubrics: the tier map is a hard gate —
every invocation needs it — so a runtime read saves nothing and costs a path that cannot resolve
reliably (a relative path resolves against the user's CWD, not the plugin; `${CLAUDE_PLUGIN_ROOT}`
is substituted by Claude Code but not Codex). Inlined text needs neither.

<!-- BEGIN SHARED -->

## Tier classification

Classify the session's model **by its exact ID, never by self-assessed capability** — "I can handle
this" is not a reason to reclassify. Read the ID from the session environment / system prompt (it
states one, e.g. `The exact model ID is claude-haiku-4-5`).

- **budget** — the ID carries a cheap/fast-tier marker: contains `haiku`, `flash`, `mini`, `lite`,
  `small`, `nano`, or `luna`, or names a known budget tier (e.g. MiniMax-M-class, Gemini Flash-class,
  `gpt-5-mini`/`gpt-5-nano`/`gpt-5.6-luna`). **A budget marker outranks any planning marker below** —
  a hypothetical `qwen3.8-max-lite` is budget, not planning.
- **planning** — a known frontier tier: contains `opus`, `sonnet`, `fable`, or `mythos`, or a
  Gemini Pro-class / frontier GPT-5-class (e.g. `gpt-5.5`, `gpt-5.6-sol`, `gpt-5.6-terra`) /
  Qwen3.8-Max-class (e.g. `qwen3.8-max-preview`) / equivalent high-tier model.
- **unsure** — anything you cannot positively place in the planning list.

`planning` is the frontier tier; `budget` and `unsure` are not. A skill that gates on a planning
model (`/case`, `/refine`, `/orchestrate`) proceeds only on `planning` and stops on `budget` **or**
`unsure`; a skill that merely notes its tier (`/solve`) treats `planning` as frontier and the rest as
budget.

## Reviewer pinning by host

`/evaluate`'s request-changes path must run its review pass on a **frontier** reviewer, regardless of
what model `/evaluate` itself runs on (it carries no model gate). How the reviewer's model is pinned
depends on what the host can do. Detect the host from the session's model ID:

| Host | Session model ID | Reviewer pin |
|---|---|---|
| **Claude Code** (native) | a Claude marker (`opus`/`sonnet`/`haiku`/`fable`/`mythos`) | the shipped reviewer agents — `case-reviewer` (cheapest frontier) / `case-reviewer-strong` (strongest); the pin lives in the agent definition |
| **Codex** (native) | a GPT-5 marker (`gpt-5…`) | the shipped reviewer agents (TOMLs copied into `.codex/agents/`); same two rungs, pinned to Codex's base / strongest GPT-5-class |
| **Custom host** (e.g. a router) | neither native marker, but classifies as **planning** (e.g. `qwen3.8-max-preview`) | a general subagent pinned to the **session's own model ID** — the host accepts literal IDs; one frontier tier |
| **None of the above** | budget / `unsure`, and no usable native agents | **stop** — no frontier reviewer can be pinned |

Take the first branch that applies:

1. **Native host that lists the shipped reviewer agents** (session model carries a Claude or GPT-5
   marker, and the host lists `case-reviewer`/`case-reviewer-strong`) → use the agents; the pin lives
   in the definition and is enforced by the harness. Two-tier cost-keying and the same-class step-up
   apply (the roster offers a cheapest and a strongest rung).
2. **Else the session model classifies as planning** (a custom frontier host) → spawn a general
   subagent pinned to the **session's own model ID**. One frontier tier — cost-keying and the
   same-class step-up both point at it; the rule degrades to a single pin, it never errors.
3. **Else** → **stop** and tell the user no frontier reviewer can be pinned.

Rules that bind every branch:
- **Never pin or inherit a budget ID**, and never run the review inline on `/evaluate`'s own model
  instead of spawning a subagent. No frontier model to pin → stop; do not fall back to a budget
  reviewer.
- **Spawn anonymously — never pass a `name`**: named teammates can't be spawned from inside another
  agent, and nothing needs to address the reviewer after it reports.

<!-- END SHARED -->
