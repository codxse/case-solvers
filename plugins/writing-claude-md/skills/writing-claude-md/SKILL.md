---
name: writing-claude-md
description: Use when creating or updating CLAUDE.md, AGENTS.md, or project context files for LLMs. Use when the user asks to document their project, improve project context, or reduce re-explanation across sessions.
---

# Writing CLAUDE.md

## Overview

CLAUDE.md is project context for an LLM that already knows every framework, language, and tool. Its only job: teach what the code CAN'T.

## The Litmus Test

For every line, ask: **"Can an LLM learn this by reading the code?"**

- The router file already documents every route → omit route listings
- The schema or model already documents every field → omit field lists
- The dependency manifest already documents every library → omit dependency explanations
- The test config already documents test setup → omit test tool descriptions
- `npm run dev`, `rails server`, `go run .` are universal → omit "how to run"

If yes → delete it. The LLM reads files. You're wasting tokens and creating maintenance debt.

## What belongs

Only things invisible from the code:

| Category | Example (language-agnostic) |
|----------|------------------------------|
| **Gotchas** | "Admin panel uses its own JS bundle — framework components won't mount there" |
| **Non-obvious defaults** | "Auth middleware skips verification in test — all requests pass as admin" |
| **Hidden coupling** | "Config reads from env var `SECRET` which is set by the CI, not the code" |
| **Custom conventions** | "Local fork of upstream lib at `../upstream`, revert before release" |
| **Derivation gaps** | "The router macro silently overrides handler methods — inline your logic" |
| **Non-standard setup** | "Two separate build configs: one for the app, one for the admin dashboard" |

## What to omit

- Route listings (read the router file)
- Model/schema fields (read the schema or model)
- Dependency purposes (read the manifest)
- How to start the dev server, run tests, open a REPL
- Framework feature explanations (the LLM knows what an ORM, router, or auth library does)
- File trees (use `ls` or `find`)
- Anything in `README.md`

## Structure

```markdown
# One-line summary

## Stack highlights
Only non-standard choices. Not every dependency — just the ones with gotchas.

## Gotchas & conventions
Grouped by subsystem. Each entry: what it is + WHY it matters to working here.

## Key files (optional)
Only files where PURPOSE isn't obvious from the path. Don't list every file.
```

Aim for under 60 lines. More than that and you're documenting what the code already says.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Listing routes | Read the router file instead |
| Documenting model fields | Read the schema/model instead |
| Explaining what libraries do | LLM knows. Only note non-default config. |
| "How to run" section | LLM knows the platform's dev command |
| Test tool listing | Only note project-specific conventions (e.g. "Chrome required for E2E") |
| Too many key files | If the path is self-explanatory, skip it |

## Before/After

### Before (noise — all derivable from code)
```markdown
## Stack
- **React 18**, **TypeScript 5**, **Vite**
- **Vitest** — test runner
- **Playwright** — E2E tests
- **Prisma** — ORM

## Routes
/           → HomePage
/settings   → SettingsPage
...

## Development
- `npm run dev` starts the dev server
- `npm test` runs tests
```

### After (only what the code doesn't say)
```markdown
## Stack highlights
- **Prisma** — migrations are manually written SQL, not generated

## Gotchas
- Admin panel is a separate Vite build — shared components need explicit exports
- Auth middleware returns 200 (not 401) for unauthenticated API calls (legacy clients)
- Local instance of `shared-ui` at `../shared-ui` via `file:` protocol
```
