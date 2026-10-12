# Phase 5: Compute and cost (FinOps)

> Read when: setting warehouse standards, monitors, budgets, chargeback, AI spend controls, or reviewing platform spend. Prerequisites: phase 4.

## Blueprint inputs
Budget and chargeback (6), Teams onboarded, warehouse standards.

## Standards
| Item | Standard |
|---|---|
| Warehouses | One per team and workload; `XSMALL` first; `AUTO_SUSPEND = 60`; `STATEMENT_TIMEOUT_IN_SECONDS = 3600`; a `cost_center` tag |
| Monitors | One resource monitor per warehouse (or per team): notify 80%, suspend 100% |
| Budgets | Account budget plus custom budgets per team for serverless and AI spend, which resource monitors do not cover (verify syntax) |
| Attribution | Warehouse per team and `cost_center` tag; `QUERY_TAG` set by every tool and service |
| AI | Approved models only; budgets and alerts on `AI_SERVICES`; cache AI outputs |

## Build
```sql
CREATE WAREHOUSE marketing_bi_wh WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 3600 COMMENT = 'Owner: marketing';
ALTER WAREHOUSE marketing_bi_wh SET TAG governance.tags.cost_center = 'marketing';
CREATE RESOURCE MONITOR marketing_rm WITH CREDIT_QUOTA = 50 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 80 PERCENT DO NOTIFY ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE marketing_bi_wh SET RESOURCE_MONITOR = marketing_rm;
ALTER ACCOUNT SET STATEMENT_TIMEOUT_IN_SECONDS = 3600;
-- budgets (verify): CREATE SNOWFLAKE.CORE.BUDGET ...; CALL <budget>!SET_SPENDING_LIMIT(...); CALL <budget>!ADD_RESOURCE(...);
```
Chargeback query (monthly):
```sql
SELECT t.tag_value AS cost_center, ROUND(SUM(m.credits_used), 2) AS credits
FROM snowflake.account_usage.warehouse_metering_history m
LEFT JOIN snowflake.account_usage.tag_references t
  ON t.domain = 'WAREHOUSE' AND t.object_name = m.warehouse_name AND t.tag_name = 'COST_CENTER'
WHERE m.start_time >= DATE_TRUNC('month', CURRENT_DATE())
GROUP BY 1 ORDER BY 2 DESC;
```

## Checklist
- [ ] P05-01 Every warehouse auto-suspends within 60 s (automated: `checks/05-compute-cost.sql`)
- [ ] P05-02 Every warehouse has a resource monitor (automated)
- [ ] P05-03 The account statement timeout is lowered from the 2-day default (automated)
- [ ] P05-04 Credits by service type for the last 30 days, including AI (automated, INFO)
- [ ] P05-05 At least half of recent queries carry a `QUERY_TAG` (automated)
- [ ] P05-06 Warehouse sizes justified (automated, INFO lists sizes)
- [ ] P05-07 Budgets cover serverless and AI spend; monthly chargeback report sent (manual)
- [ ] P05-08 An account-level resource monitor caps total warehouse spend (automated: `checks/05-compute-cost.sql`)
- [ ] P05-09 Resource monitors name who is notified (automated)

## Exit criteria
Every credit is capped or budgeted, attributable to a team, and reported monthly.
