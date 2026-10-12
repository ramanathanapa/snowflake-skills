# Phase 7: Delivery (Terraform, CI/CD, drift)

> Read when: putting platform objects under code, setting up CI/CD, detecting drift, or reviewing how changes reach production. Prerequisites: phase 4.

## Blueprint inputs
Account topology (3), environments (4), approvers (8).

## Target state
| Item | Standard |
|---|---|
| Ownership | Terraform owns accounts, warehouses, monitors, databases, schemas, roles, grants, policies, integrations; migrations own tables and views |
| Terraform identity | A service user and a dedicated role with only the privileges it needs; `ACCOUNTADMIN` only for bootstrap |
| State | Remote backend with locking and encryption; one state per account and environment |
| Pipeline | Pull request: fmt, validate, `plan -out`, policy checks, review. Merge: `apply` the reviewed plan with approval |
| Policy as code | Rules on the plan (no `ACCOUNTADMIN` grants, every warehouse has a monitor and auto-suspend, no grants to `PUBLIC`) using a policy tool on the plan JSON (verify tool) |
| Drift | A scheduled `terraform plan`; any diff opens an issue |
| Provider | `snowflakedb/snowflake` pinned exactly; upgrades in their own pull request after reading the migration guide |

## Build
1. Split Terraform into modules: `account-baseline`, `identity`, `access-model`, `team` (phase 11), `observability`.
2. Create the Terraform service user and role (phase 2 pattern) and move the provider off `ACCOUNTADMIN`.
3. Add the pipeline with plan on pull request and apply on merge; store the key in the CI secret store.
4. Add the scheduled drift check.
5. Back-port any console changes found by drift or by check P07-01.

## Checklist
- [ ] P07-01 People rarely run DDL directly in the last 30 days; changes come from service users (automated: `checks/07-delivery.sql`, WARN lists users)
- [ ] P07-02 Service users carry out the DDL (automated, INFO)
- [ ] P07-03 Remote state with locking; pinned provider; plan on PR and apply on merge; scheduled drift check; policy checks (manual)

## Exit criteria
Every platform object is in code, every change is reviewed as a plan, and drift is detected within a day.
