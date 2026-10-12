# Changelog: snowflake-platform-engineering

All notable changes to this plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-10-11
### Added
- `snowflake-platform-engineering` skill: blueprint-driven bring-up and operation of a Snowflake platform, with modes for kickoff, discovery, phase builds, scoped phase reviews, a readiness scorecard and team onboarding.
- Twelve phase references (0 blueprint, 1 organization and accounts, 2 identity, 3 security baseline, 4 access model, 5 compute and cost, 6 data foundations, 7 delivery, 8 observability, 9 governance, 10 resilience, 11 golden path), each with prerequisites, build steps, a checklist with stable IDs and exit criteria.
- Blueprint template (`assets/blueprint-template.md`) recording the organization's decisions and per-phase progress.
- 60 automated readiness checks in `checks/*.sql` (read-only; results in a session temporary table) and a scorecard script, including enterprise-grade settings: MFA coverage, admin notification email, MFA bypass, exfiltration guards, OAuth admin blocking, `ACCOUNTADMIN` grants to roles, open Trust Center findings, account-level spend cap, monitor recipients, event table, access history, Cortex cross-region inference vs residency, and minimum time travel.
- Output formats for scoped phase reviews, the readiness scorecard and build plans.
- Six behavioural eval cases, including token-discipline, lockout safety and a negative triggering case.
