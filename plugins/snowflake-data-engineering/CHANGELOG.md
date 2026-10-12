# Changelog: snowflake-data-engineering

All notable changes to this plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-10-11
### Added
- `snowflake-data-engineering` skill: principles, change workflow, decision guides, conventions, definition of done and assistant behaviour rules.
- Twelve reference files: foundations, loading, modeling and SQL, pipelines, performance and cost, security and governance, infrastructure as code and CI/CD, testing and quality, Python clients, Cortex AI and Streamlit, pitfalls, and review/audit.
- Claude Code plugin manifest (`snowflake-data-engineering@snowflake-skills`).
- `scripts/validate.py` structural checks and a GitHub Actions workflow.
- Scoped reviews by default: each area reference ends with a checklist; vague review requests make Claude ask which area; the full audit runs only on request.
- Defined report formats: a scoped-review template in `SKILL.md` (section 7) and the full-audit template in `references/review-audit.md`; review evals check the format.
- Eight behavioural eval cases (`evals/*/case.yaml`) for `claude plugin eval`, including a loading-only review that must not read unrelated references, a vague request that must lead to a scope question, and a negative triggering case.
- Contribution guidelines in the README and GitHub issue forms.
