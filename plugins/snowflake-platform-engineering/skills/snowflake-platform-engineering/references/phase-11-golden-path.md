# Phase 11: Golden path (onboarding and offboarding teams)

> Read when: onboarding a new team, domain or data product, changing the team template, or offboarding a team. Prerequisites: phases 4, 5 and 6.

## Blueprint inputs
Naming standards, environments (4), budget and chargeback (6), Teams onboarded, IdP groups (2).

## What a team gets (one Terraform module call per team)
| Per environment | Object |
|---|---|
| Data | `<TEAM>_<ENV>` database with `RAW`, `CURATED`, `ANALYTICS` (managed access), `APP`, transient `STAGING`; retention per phase 6 |
| Access | Access roles per schema and level; functional roles `<TEAM>_ENGINEER`, `<TEAM>_ANALYST`, `<TEAM>_READER` mapped to IdP groups; rolled up to `SYSADMIN` |
| Compute | `<TEAM>_<WORKLOAD>_WH` (`XSMALL`, 60 s) with a resource monitor sized from the team's budget, tagged `cost_center` |
| Automation | `SVC_<TEAM>_CI` service user with key-pair and the team's deployment role |
| Governance | `owner` and `cost_center` tags on database and warehouse |
| Operations | Alert routing to the team; freshness objectives recorded |

```hcl
module "team_marketing" {
  source        = "./modules/team"
  team          = "MARKETING"
  environments  = ["DEV", "PROD"]
  idp_groups    = { engineer = "sf-marketing-eng", analyst = "sf-marketing-analyst" }
  monthly_credits = { DEV = 20, PROD = 50 }
  cost_center   = "marketing"
}
```

## Onboarding steps
1. Read the blueprint (standards, budget, naming); ask only for team-specific values: name, environments, IdP groups, budget share, owner.
2. Show the build plan (format in `SKILL.md`), with object counts and the budget impact on the account total.
3. After approval: apply, run phase 4, 5 and 11 checks for the new objects, add the team to the blueprint's Teams table.
4. Hand over: a short note with database names, roles, warehouse, how to request access, where alerts go.

## Offboarding
Revoke IdP groups first, suspend the warehouse, transfer or archive data per retention rules, then remove objects through Terraform. Record it in the blueprint change log.

## Checklist
- [ ] P11-01 Every warehouse carries a tag for cost attribution (automated: `checks/11-golden-path.sql`)
- [ ] P11-02 Every database carries a tag for ownership (automated)
- [ ] P11-03 Teams are created only through the module; the Teams table matches what exists; offboarding steps documented (manual)

## Exit criteria
A new team is productive within a day from one reviewed change, and the platform can account for every team's access and spend.
