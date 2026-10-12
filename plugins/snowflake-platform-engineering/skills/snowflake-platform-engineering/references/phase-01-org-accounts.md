# Phase 1: Organization and accounts

> Read when: creating or reviewing accounts, account topology, account naming, or organization-level usage. Prerequisites: phase 0.

## Blueprint inputs
Compliance and residency (1), account topology (3), environments (4), edition and region (5), Accounts table.

## Concepts
- An **organization** groups accounts for billing and management. `ORGADMIN` manages accounts and sees organization-wide usage (`SNOWFLAKE.ORGANIZATION_USAGE`).
- Accounts are isolated security boundaries: users, roles, warehouses and policies are per account. Data moves between accounts by sharing or replication.
- Edition and region are per account and drive which features exist (phase 10, private connectivity, some governance features).

## Build
1. Enable `ORGADMIN` in exactly one administrative account; grant it to 2-3 named people only.
2. Create accounts from the blueprint (verify current syntax and parameters):
   ```sql
   USE ROLE ORGADMIN;
   CREATE ACCOUNT acme_prod
     ADMIN_NAME = platform_admin
     ADMIN_RSA_PUBLIC_KEY = '<public key body>'   -- no admin password
     EMAIL = 'platform-team@example.com'
     EDITION = ENTERPRISE
     REGION = <region_id>
     COMMENT = 'Production. Owner: platform team';
   SHOW ORGANIZATION ACCOUNTS;
   ```
3. Name accounts by purpose and environment (`<ORG>_<ENV>` or `<BU>_<ENV>`); record them in the blueprint Accounts table.
4. In each new account, create a second named admin immediately (phase 3 requires 2-5 `ACCOUNTADMIN` holders) and continue with phase 2.
5. Give finance and the platform team organization-level usage views for cross-account spend (phase 5).

## Checklist
- [ ] P01-01 Account identity and region match the blueprint (automated: `checks/01-org-accounts.sql`, INFO)
- [ ] P01-02 Databases in the account reflect the environment strategy (automated: `checks/01-org-accounts.sql`, INFO)
- [ ] P01-03 The account list matches the blueprint topology; no unexplained accounts (manual, needs `ORGADMIN`)
- [ ] P01-04 `ORGADMIN` is enabled in one account and held by 2-3 people (manual)
- [ ] P01-05 Account names, comments and owners follow the convention (manual)
- [ ] P01-06 The account time zone is set explicitly (UTC or the organization standard) (automated: `checks/01-org-accounts.sql`)

## Exit criteria
Every account in the blueprint exists in the right edition and region, with named admins, and nothing outside the blueprint exists.
