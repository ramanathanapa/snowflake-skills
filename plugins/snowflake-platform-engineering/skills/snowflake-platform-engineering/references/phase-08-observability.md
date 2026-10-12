# Phase 8: Observability and operations

> Read when: setting up alerts, notifications, logging, freshness objectives, runbooks or on-call for the platform. Prerequisites: phase 5.

## Blueprint inputs
Approvers and owners (8), Teams onboarded, budget (6).

## What to watch
| Signal | Source | Alert when |
|---|---|---|
| Failed or suspended tasks | `TASK_HISTORY`, `SHOW TASKS` | Any failure; any unexpected suspension |
| Ingestion | `COPY_HISTORY`, `SYSTEM$PIPE_STATUS` | Errors, paused pipes, missing expected files |
| Freshness | Max load or as-of date per serving table | Older than the objective agreed with the team |
| Spend | `METERING_DAILY_HISTORY`, monitors, budgets | Day above trailing average x 1.5; 80% of budget |
| Security | `LOGIN_HISTORY`, grants changes | Repeated failures; new `ACCOUNTADMIN` grant |

## Build
```sql
CREATE NOTIFICATION INTEGRATION ops_email TYPE = EMAIL ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('platform-oncall@example.com');
CREATE OR REPLACE ALERT ops.alerts.failed_tasks WAREHOUSE = ops_wh SCHEDULE = '30 MINUTE'
  IF (EXISTS (SELECT 1 FROM TABLE(information_schema.task_history(
        SCHEDULED_TIME_RANGE_START => DATEADD(minute, -30, CURRENT_TIMESTAMP()))) WHERE state = 'FAILED'))
  THEN CALL SYSTEM$SEND_EMAIL('ops_email', 'platform-oncall@example.com', 'Snowflake task failures', 'See TASK_HISTORY.');
ALTER ALERT ops.alerts.failed_tasks RESUME;
```
- Event tables capture logs and traces from procedures, functions and apps (verify setup).
- Write a runbook per alert: what it means, first checks, who owns it, how to escalate.
- Agree freshness objectives with each team when they onboard (phase 11).

## Checklist
- [ ] P08-01 At least one alert exists and is resumed (automated: `checks/08-observability.sql`)
- [ ] P08-02 No task failed in the last 7 days (automated)
- [ ] P08-03 No unexpectedly suspended tasks (automated, WARN lists them)
- [ ] P08-04 A notification integration exists (automated)
- [ ] P08-05 Freshness objectives, runbooks and an on-call rota exist (manual)
- [ ] P08-06 An event table is configured for logs and traces (automated: `checks/08-observability.sql`)

## Exit criteria
Failures, staleness, spend spikes and security events reach a person within an hour, and each has a runbook.
