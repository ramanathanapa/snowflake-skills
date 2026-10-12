# Phase 10: Resilience (replication, failover, recovery)

> Read when: setting recovery objectives, configuring replication or failover, planning restores, or running recovery drills. Prerequisites: phase 6.

## Blueprint inputs
Recovery objectives (7), edition and region (5), Accounts table, approvers (8).

## Choose by objective (verify edition requirements)
| Objective | Mechanism |
|---|---|
| Undo mistakes within days | Time travel (`AT`/`BEFORE`, `UNDROP`); retention per phase 6 |
| Safe risky changes | Zero-copy clone before the change, dropped after verification |
| Recover from a region or account outage, data only | Database replication to a secondary account in another region (replication groups) |
| Fail over the whole platform with low RTO | Failover groups for databases, roles, users, warehouses and integrations, plus client redirect (Business Critical, verify) |
| Data loss window (RPO) | Replication schedule (for example every 10-60 minutes); measure actual lag |

## Build (only if the blueprint asks for replication)
```sql
-- in the primary account (verify object types and syntax for your edition)
CREATE FAILOVER GROUP platform_fg
  OBJECT_TYPES = DATABASES, ROLES, USERS, WAREHOUSES, INTEGRATIONS
  ALLOWED_DATABASES = marketing_prod, finance_prod
  ALLOWED_ACCOUNTS = <org>.<dr_account>
  REPLICATION_SCHEDULE = '30 MINUTE';
-- in the secondary account
CREATE FAILOVER GROUP platform_fg AS REPLICA OF <org>.<primary_account>.platform_fg;
```
Write the runbook: who decides to fail over, steps, client redirect, and failback. Run a drill twice a year and record the measured RPO and RTO in the blueprint.

## Checklist
- [ ] P10-01 Replication and failover groups match the blueprint (automated: `checks/10-resilience.sql`, INFO)
- [ ] P10-02 Time travel retention per database fits the recovery objectives (automated, INFO lists retention)
- [ ] P10-03 Measured RPO/RTO meet the blueprint; a drill was run in the last 6 months; runbook exists (manual)
- [ ] P10-04 A minimum time travel is enforced account-wide (`MIN_DATA_RETENTION_TIME_IN_DAYS` at least 1) (automated: `checks/10-resilience.sql`)

## Exit criteria
The organization can recover within its stated objectives, and has proven it in a drill.
