# Phase 4: Access model

> Read when: designing roles, granting access, mapping IdP groups, fixing ownership, or running access reviews. Prerequisites: phase 2.

## Blueprint inputs
Naming standards, environments (4), Teams onboarded, approvers (8).

## Role framework
```
IdP group --SCIM--> functional role (MARKETING_ENGINEER) --granted--> access roles (MARKETING_PROD_ANALYTICS_READ, ...)
                                                                  --> warehouse usage role
Functional and access roles roll up to SYSADMIN (custom role tree), SECURITYADMIN manages grants.
```
- **Access roles** (or database roles) hold object privileges: `<DB>_<SCHEMA>_READ`, `_WRITE`, `_OWNER`.
- **Functional roles** represent jobs and are the only roles granted to users.
- **Ownership**: objects are owned by an owner access role or the Terraform/migration role, never by `ACCOUNTADMIN` or a person.
- **Managed access schemas** for curated and serving layers so only owners grant.
- **Future grants** on each schema so new objects inherit access.

## Build
1. Generate roles per database and schema from the blueprint with a Terraform module (one `for_each` over databases x schemas x levels).
2. Grant access roles to functional roles; grant functional roles to `SYSADMIN` and to IdP-mapped groups (SCIM).
3. Transfer ownership away from `ACCOUNTADMIN`: `GRANT OWNERSHIP ON DATABASE x TO ROLE x_owner COPY CURRENT GRANTS;`
4. Schedule an access review per quarter: export `GRANTS_TO_USERS` and functional-role membership to owners for confirmation.

## Checklist
- [ ] P04-01 No database is owned by `ACCOUNTADMIN` (automated: `checks/04-access-model.sql`)
- [ ] P04-02 Every custom account role is granted to another role (no orphans outside the tree; application and instance roles are ignored) (automated)
- [ ] P04-03 No admin role is granted to a service user (automated)
- [ ] P04-04 Share of schemas with managed access (automated, INFO)
- [ ] P04-05 Users hold functional roles only; future grants exist; quarterly access review done (manual)

## Exit criteria
Every grant can be explained by the framework, ownership sits with owner roles, and access is reviewed on a schedule.
