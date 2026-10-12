---
name: snowflake-platform-engineering
description: Bring up and operate a Snowflake platform for an organization, phase by phase, driven by a blueprint of the organization's decisions. Covers organization and account topology, identity (SSO, SCIM, service users), security baseline (network, authentication, password and session policies), access model (role framework, ownership, managed access), compute and FinOps (warehouse standards, monitors, budgets, chargeback), data foundations, delivery (Terraform, CI/CD, drift), observability, governance at scale, resilience (replication, failover, recovery), and a golden path for onboarding teams, with SQL readiness checks and a scorecard. Use for platform setup, platform reviews, readiness or maturity questions, onboarding a new team or domain, and account-level administration. Not for building individual pipelines.
---

# Snowflake platform engineering

Bring up and run Snowflake as a platform for other teams, one phase at a time.
**Generic phase guidance + the organization's blueprint = output specific to that organization.**

**Freshness:** reviewed October 2026. Items marked **(verify)** change often or depend on edition and region: check current documentation or probe the account before relying on them.

## 1. How it works
```
Phase 0 (once)  interview, defaults or discovery  ->  docs/platform-blueprint.md in the user's repo
                                                       (decisions + progress per phase)
Every request   SKILL.md + blueprint + ONE phase file  ->  plan, Terraform/SQL, review or scorecard
Checks          checks/<phase>.sql run by the user or CI (no model tokens)  ->  PASS/FAIL/WARN/INFO rows
```
- **Always read the blueprint first** (`docs/platform-blueprint.md` unless the user names another path). If there is none, offer kickoff (greenfield) or discovery (existing account) from `references/phase-00-blueprint.md`. Do not assume decisions.
- **Load one phase file per request.** Never read all phases to answer one question.
- **Respect prerequisites** listed at the top of each phase file. If they are not met, say so and offer the earlier phase.
- **Update the blueprint's Progress table** after the user approves a build or a check result: `not started`, `in progress`, `built`, `verified`.

## 2. Modes
| The user says | Mode | Read |
|---|---|---|
| "Set up Snowflake for our company", "start the platform" | Kickoff: decisions interview with defaults, then write the blueprint | `references/phase-00-blueprint.md`, `assets/blueprint-template.md` |
| "We already have Snowflake, assess it" | Discovery: read-only probes, draft the blueprint from what exists, user confirms | `references/phase-00-blueprint.md` |
| "Build phase N", "set up identity" | Build: plan, blast radius, approval, then Terraform/SQL | the phase file |
| "Check our security baseline" | Scoped phase review (format in section 5) | the phase file + its checks script |
| "How ready are we?" | Readiness scorecard from check results (section 5) | blueprint + check results only |
| "Onboard team X" | Golden path from the blueprint | `references/phase-11-golden-path.md` |
| Vague: "review our platform" | Ask which phase, or offer the readiness scorecard. Do not read several phase files | none |

## 3. Phases
| Phase | Topic | Prerequisites | Typical privilege | Reference | Checks |
|---|---|---|---|---|---|
| 0 | Blueprint: decisions, defaults, discovery | none | read-only for discovery | `references/phase-00-blueprint.md` | n/a |
| 1 | Organization and accounts | 0 | `ORGADMIN` | `references/phase-01-org-accounts.md` | `checks/01-org-accounts.sql` |
| 2 | Identity | 1 | `ACCOUNTADMIN` / `SECURITYADMIN` | `references/phase-02-identity.md` | `checks/02-identity.sql` |
| 3 | Security baseline | 2 | `SECURITYADMIN` / `ACCOUNTADMIN` | `references/phase-03-security-baseline.md` | `checks/03-security-baseline.sql` |
| 4 | Access model | 2 | `SECURITYADMIN`, `SYSADMIN` | `references/phase-04-access-model.md` | `checks/04-access-model.sql` |
| 5 | Compute and cost | 4 | `SYSADMIN`, `ACCOUNTADMIN` for monitors | `references/phase-05-compute-cost.md` | `checks/05-compute-cost.sql` |
| 6 | Data foundations | 4 | `SYSADMIN` | `references/phase-06-data-foundations.md` | `checks/06-data-foundations.sql` |
| 7 | Delivery: Terraform, CI/CD, drift | 4 | Terraform role | `references/phase-07-delivery.md` | `checks/07-delivery.sql` |
| 8 | Observability and operations | 5 | `SYSADMIN` | `references/phase-08-observability.md` | `checks/08-observability.sql` |
| 9 | Governance at scale | 4, 6 | `SECURITYADMIN` / governance role | `references/phase-09-governance.md` | `checks/09-governance.sql` |
| 10 | Resilience: replication, failover, recovery | 6 | `ACCOUNTADMIN` (edition-dependent) | `references/phase-10-resilience.md` | `checks/10-resilience.sql` |
| 11 | Golden path: onboarding teams | 4, 5, 6 | Terraform role | `references/phase-11-golden-path.md` | `checks/11-golden-path.sql` |
| All | Readiness scorecard | any checks run | auditor role | this file, section 5 | `checks/99-scorecard.sql` |

## 4. Rules for platform work
1. **Privilege-aware.** Run checks with a read-only auditor role (`references/phase-03-security-baseline.md`, "Auditor role"), not `ACCOUNTADMIN`. Say which checks need more and what the role could not see.
2. **Plan, blast radius, approval.** Every build shows the objects to be created or changed, who is affected (users, accounts, running workloads), how to roll back, and waits for explicit approval.
3. **Lockout safety.** For network, authentication, session or password policies: apply to a test user first, keep a documented break-glass path, then widen to the account.
4. **Code first.** Account objects go into Terraform (`references/phase-07-delivery.md`); console changes are only for bootstrap and emergencies, and are back-ported to code.
5. **Org decisions live in the blueprint.** Never silently change a decision; propose a blueprint change and get approval.
6. **Never handle passwords or private keys.** Users run steps that need secrets; Claude prepares the commands.
7. **Edition and region matter.** Probe or ask before designing features that depend on them (failover, private connectivity, some governance features).
8. **Ask when the phase is unclear.** Offer the likely phase or the scorecard instead of reading several files.

## 5. Output formats
**Scoped phase review** (exact structure):
```markdown
# Phase <N> <name> review: <organization>
Scope: <accounts, objects>. Role: <role used>. Method: `references/<phase file>` checklist, `checks/<script>` results, read-only probes. Nothing was changed.

## Evidence
| Check or probe | Result |
|---|---|

## Checklist
| ID | Standard | Result | Evidence | Fix |
|---|---|---|---|---|

## Summary
<n> pass, <n> partial, <n> fail, <n> N/A. <One sentence on what matters most.>

## Fix order
1. <Highest risk reduction per effort first> (<effort>)

## Not checked
- <Item and why, including objects the role could not see>
```
Rules: one row per checklist item, in order, using its ID; `Result` is exactly `✅ Pass`, `⚠️ Partial`, `❌ Fail` or `N/A`; evidence is a check row, query result or `file:line`; no evidence is never a Pass; summary counts equal the rows; end by asking which fixes to apply.

**Readiness scorecard:**
```markdown
# Platform readiness: <organization> (<date>)
| Phase | Status | Pass | Warn | Fail | Open items |
|---|---|---|---|---|---|
Next: <the one or two actions that unblock the most>.
```
`Status` combines the blueprint Progress table with check results: `✅ Verified` (built, no FAIL), `⚠️ Open items`, `🔨 Built` (not yet checked), `⬜ Not started`.

**Build plan:**
```markdown
# Phase <N> build plan: <organization>
Blueprint inputs used: <keys and values>
| Object | Action | Owner (Terraform/SQL) | Affects |
Blast radius: <who and what could break>. Rollback: <how>. Checks after apply: <check IDs>.
Approve?
```

## 6. Relationship to the data engineering skill
This skill builds and runs the platform. Building pipelines, models and apps on it belongs to the `snowflake-data-engineering` skill.
