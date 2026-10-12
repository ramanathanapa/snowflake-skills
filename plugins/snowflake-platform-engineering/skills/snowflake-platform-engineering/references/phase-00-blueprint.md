# Phase 0: Blueprint (decisions, defaults, discovery)

> Read when: starting a platform (kickoff), assessing an existing account (discovery), or changing a recorded decision. Prerequisites: none.

The blueprint is the organization's memory. Every later phase reads it. Write it to `docs/platform-blueprint.md` in the user's repository using `assets/blueprint-template.md`, and get the user's approval before treating it as final.

## Kickoff (greenfield): the decisions only the organization can make
Ask these in one message, each with the default, so the user only answers where they differ.

| # | Decision | Default | Choose otherwise when |
|---|---|---|---|
| 1 | Compliance and data residency | No special regulation; one region close to users | Regulated data (health, payments, public sector) or residency rules: choose regions and edition accordingly |
| 2 | Identity provider and provisioning | The company's existing IdP with SAML SSO and SCIM | No IdP: start with key-pair for services and MFA passwords for a few people, plan SSO |
| 3 | Account topology | One account; databases per environment | Hard isolation is required (regulators, security, separate billing): one account per environment or business unit |
| 4 | Environments | dev and prod | Formal release testing needs a test environment |
| 5 | Edition and region | Enterprise in the chosen region | Business Critical for failover, private connectivity or stricter compliance (verify current edition features) |
| 6 | Budget and chargeback | A monthly credit cap; chargeback by team tag | Central funding with showback only |
| 7 | Recovery objectives | RPO 24 h and RTO 1 day using time travel and clones; no replication | Lower RPO/RTO: replication or failover groups (phase 10) |
| 8 | Approvers | Platform lead approves production and access changes | Separate security approver for access, change board for production |

After answers: fill the template, list the standards that apply by default, show the file, ask for approval, then record "approved on <date> by <name>".

## Discovery (brownfield): draft the blueprint from what exists
Run read-only probes, map the results to the decisions, and present the draft with every inferred value marked "inferred, please confirm".

| Decision | Probe |
|---|---|
| Accounts, edition, region | `SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT_NAME(), CURRENT_REGION();` and, with `ORGADMIN`, `SHOW ORGANIZATION ACCOUNTS;` |
| Identity provider | `SHOW SECURITY INTEGRATIONS;` (SAML2, SCIM, OAuth types) |
| Environments and naming | `SHOW DATABASES;` and `SHOW WAREHOUSES;` name patterns |
| Budget posture | `SHOW RESOURCE MONITORS;` and `SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY` for the last 30 days |
| Recovery | `SHOW REPLICATION GROUPS;` and database `retention_time` |
| Access model | `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES` (role hierarchy), `GRANTS_TO_USERS` |
Then run all `checks/*.sql` scripts and fill the Progress table from the results (a phase with no FAIL is at least `built`; mark `verified` only after the user confirms the manual items).

## Changing a decision
Propose the change with its consequences (which phases and objects it affects), get the approver's sign-off, update the decision and add a Change log row. Never edit decisions silently.

## Checklist
- [ ] P00-01 All 8 decisions have a value and a reason (manual)
- [ ] P00-02 The blueprint is approved, with date and approver recorded (manual)
- [ ] P00-03 Standards section reviewed; deviations from defaults are written down (manual)
- [ ] P00-04 Accounts table lists every account with 2-5 admins named (manual)
- [ ] P00-05 Progress table reflects the latest check results (manual)

## Exit criteria
An approved `docs/platform-blueprint.md` exists. Every later phase can read its inputs from it without asking again.
