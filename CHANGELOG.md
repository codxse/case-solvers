# Changelog

All notable changes to the **case-solvers** plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Versions track the published plugin/marketplace, not the skills' internal frontmatter
versions (shown in parentheses where relevant).

## [Unreleased]

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

[Unreleased]: https://github.com/nadiar/case-solvers/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/nadiar/case-solvers/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nadiar/case-solvers/releases/tag/v0.1.0
