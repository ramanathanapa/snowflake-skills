# Snowflake Skills for Claude

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![validate](https://github.com/ramanathanapa/snowflake-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/ramanathanapa/snowflake-skills/actions/workflows/validate.yml)

Open-source Claude skills that give Claude the habits of an experienced Snowflake engineer. They inspect real data before designing, make every step re-runnable, verify against known values, keep cost and access in code, and say plainly what was and was not checked.

Two plugins. Install the one that matches your job, or both:

| Plugin | For | What it does |
|---|---|---|
| **`snowflake-data-engineering`** | Engineers building on Snowflake | Ingestion, modeling and SQL, pipelines, performance and cost, security, Terraform and CI/CD, data quality, Python, Cortex AI, Streamlit, scoped reviews |
| **`snowflake-platform-engineering`** | Teams running Snowflake for others | Brings up and runs the platform in phases from a blueprint of your decisions: accounts, identity, security baseline, access model, FinOps, observability, governance, resilience, team onboarding. Includes 60 SQL readiness checks (including enterprise-grade settings and Trust Center findings) and a scorecard |

## Quick start
**Needs:** [Claude Code](https://code.claude.com/docs/en/overview), installed and logged in (`claude`, then `/login`).

1. **Add the marketplace and install** what you need:
   ```bash
   claude plugin marketplace add ramanathanapa/snowflake-skills
   claude plugin install snowflake-data-engineering@snowflake-skills
   claude plugin install snowflake-platform-engineering@snowflake-skills
   ```
2. **Check it** (shows the skill and its projected token cost):
   ```bash
   claude plugin details snowflake-data-engineering
   ```
3. **Use it.** Start a new Claude Code session in your project and describe the work. There is no command to learn.
   > Check my stage load in `load/orders.sql` against the loading standards.

   > We're starting Snowflake across the company. Help me set up the platform.
4. **Update** when a new version is released, then restart Claude Code:
   ```bash
   claude plugin marketplace update snowflake-skills
   claude plugin update snowflake-data-engineering@snowflake-skills
   claude plugin update snowflake-platform-engineering@snowflake-skills
   ```

The skills hold no credentials and connect to nothing by themselves. If you want Claude to check your live account, give it a way to connect (for example the Snowflake CLI or the Python connector with your own key-pair). Claude asks before running each query and before anything destructive.

## Data engineering plugin
**Use it for** day-to-day building and fixing. Examples:

| Ask | What the skill brings |
|---|---|
| "My COPY INTO loaded 0 rows on rerun" | Load metadata, `FORCE`, and a duplicate-safe reload |
| "Revenue doubled after this join" | Fan-out diagnosis, fix before the join, a reconciliation check |
| "Our Snowflake bill doubled" | Measure spend first, then auto-suspend, right-size, cap and isolate workloads |
| "Is it safe to run Cortex Analyst SQL in our app?" | Owner's-rights risk, a read-only role, a statement guard |
| "Check my stage loads against the standards" | A scoped review against the loading checklist only |
| "Run a full audit of this repo and account" | A read-only evidence pass across all areas, with no changes until you approve |

**It loads only what the task needs.** About 160 tokens are always present. A Snowflake task adds `SKILL.md` (~2,500 tokens) plus the one matching reference (~1,200-2,000 tokens). Reviews are scoped by default and reply in a fixed format: evidence, a checklist table (✅ Pass / ⚠️ Partial / ❌ Fail / N/A, each with evidence and a fix), a summary, a fix order and what could not be checked. A vague "review my project" gets a question about which area, not a read of everything.

## Platform engineering plugin
**Use it to** bring up or assess a Snowflake platform. It works in phases driven by a **blueprint**, a file in your repo holding the decisions only your organization can make.

1. **Phase 0 (once):** Claude asks about 8 decisions (compliance, identity provider, account topology, environments, edition and region, budget, recovery objectives, approvers), each with a default. On an existing account it can draft the blueprint by read-only discovery instead. You approve; it writes `docs/platform-blueprint.md`.
2. **Phases 1-11:** organization and accounts, identity, security baseline, access model, compute and cost, data foundations, delivery, observability, governance, resilience, golden path. Each request reads the blueprint plus **one** phase file, then produces a build plan (with blast radius and rollback, waiting for your approval) or a scoped review.
3. **Checks as code:** `checks/*.sql` holds 60 read-only checks (PASS / FAIL / WARN / INFO) that you run in Snowsight or CI, with no model tokens. Besides the phase basics they cover enterprise-grade settings: MFA coverage, exfiltration guards, admin roles blocked for OAuth, an account-wide spend cap, open Trust Center findings, Cortex cross-region inference against your residency decision, and minimum time travel. `checks/99-scorecard.sql` turns the results into a readiness scorecard.

   To run them: use a role that can read `SNOWFLAKE.ACCOUNT_USAGE` (phase 3 describes a read-only `PLATFORM_AUDITOR` role), a warehouse, and a schema where you may create a temporary table. Results are kept in a session temporary table, so run all scripts in one session for the scorecard:
   ```bash
   cat checks/0*.sql checks/1*.sql checks/99-scorecard.sql > all-checks.sql   # then run all-checks.sql in one session
   ```

| Ask | What happens |
|---|---|
| "Set up Snowflake for our company" | Decision interview with defaults, then the blueprint |
| "We already have Snowflake, assess it" | Read-only discovery, a draft blueprint, then a scorecard |
| "Build phase 2, identity" | A plan from your blueprint (for example SSO and SCIM for your identity provider), then apply after approval |
| "Check our security baseline" | A scoped review of phase 3 using its checks |
| "How ready are we?" | A scorecard across all phases from the check results |
| "Onboard the marketing team" | The golden-path plan: databases, roles, warehouse, monitor and tags for the team |

## What's inside
```
.claude-plugin/marketplace.json            lists both plugins
plugins/
├── snowflake-data-engineering/
│   ├── skills/snowflake-data-engineering/  SKILL.md + 12 references
│   ├── evals/                              8 behavioural test cases
│   └── CHANGELOG.md
└── snowflake-platform-engineering/
    ├── skills/snowflake-platform-engineering/
    │   ├── SKILL.md                        modes, phases, rules, output formats
    │   ├── references/                     phase-00 ... phase-11
    │   ├── checks/                         01-11 + 99-scorecard SQL
    │   └── assets/blueprint-template.md
    ├── evals/                              6 behavioural test cases
    └── CHANGELOG.md
scripts/validate.py                         repository checks (CI)
```
Fast-changing facts are marked **(verify)**. The skills tell Claude to check those against current documentation, or to probe the account, before relying on them. Each `SKILL.md` carries its review date.

## Quality
```bash
python scripts/validate.py                                              # structure, routing, links, manifests, versions, check IDs, secrets
claude plugin validate . --strict                                       # Claude Code's own manifest checks
claude plugin eval plugins/snowflake-data-engineering --runs 1 --ablation none     # behavioural tests; uses your model quota
claude plugin eval plugins/snowflake-platform-engineering --runs 1 --ablation none
```
The evals include token-discipline cases (a scoped review must read only its own reference) and negative cases (each skill must not fire on the other's questions). A full run also compares each case with and without the plugin. The `evals` GitHub workflow runs both suites on demand.

**Project status (v1.0.0).** The repository checks and Claude Code's manifest validation pass. All 60 platform checks have been run against a live Enterprise account without errors. The 14 behavioural evals are defined and validated, but have not yet been run end to end, so treat their thresholds as provisional. Build snippets that change an account (SSO, SCIM, policies, budgets, replication) are marked (verify) where syntax depends on edition or release; review them before running.

## Contributing
Corrections, new pitfalls from real incidents, new checks and new Snowflake skills are welcome. Open an issue for anything bigger than a fix.

- **Keep it generic**: no company, account, person or dataset names; neutral examples (`orders`, `transform_wh`).
- **Keep it practical**: rules, decisions and checks rather than copies of the docs; one clear rule beats three hedged ones.
- **Mark fast-changing facts (verify)** and link a source in the pull request. When you re-check them, update the review date in the skill's `SKILL.md`.
- **Runnable examples only**, and never real credentials or identifiers. New platform checks must be read-only and use the phase's check ID in both the SQL and the checklist (the validator enforces this).
- **Respect the structure**: `SKILL.md` stays short; detail goes in one reference file that starts with `> Read when:` and is routed from `SKILL.md`.
- Before opening a pull request, run `python scripts/validate.py` and add a line under `Unreleased` in the plugin's `CHANGELOG.md`. If behaviour changes, add or update a case in that plugin's `evals/`.

Be respectful and constructive; this project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Report unsafe guidance or exposed data **privately** through [GitHub security advisories](https://github.com/ramanathanapa/snowflake-skills/security/advisories/new), not in a public issue.

Releases: bump `version` in the plugin's `.claude-plugin/plugin.json`, move its `Unreleased` notes under the new version in its `CHANGELOG.md` (semantic versioning), commit, then run `claude plugin tag plugins/<plugin>` to create the `<plugin>--vX.Y.Z` tag. The validator fails if the two versions differ.

## Disclaimer
This is a community project. It is not affiliated with, endorsed by or sponsored by Snowflake Inc. or Anthropic. Snowflake and related marks are trademarks of Snowflake Inc.; Claude is a trademark of Anthropic. The guidance is provided as-is (see the licence): review generated SQL and infrastructure changes before running them, and confirm (verify) items against current documentation.

## License
[MIT](LICENSE) © snowflake-skills contributors
