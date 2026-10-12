# Testing, data quality and observability

> Read when: proving a pipeline is right, adding checks, setting up monitoring and alerts, or investigating silent failures.

## Principle
A pipeline that runs is not a pipeline that is right. Checks must **fail loudly** and compare against **something independently known**.

## Kinds of checks
| Kind | Example | Catches |
|---|---|---|
| Reconciliation | Curated row count equals raw; components sum to the total | Fan-out joins, dropped rows |
| Uniqueness | `COUNT(*) = COUNT(DISTINCT key)` at the declared grain | Duplicate loads, wrong keys |
| Key collision | No key maps to many distinct names | Placeholder identifiers used as keys |
| Completeness | Every expected entity and period present; required columns not null | Missing loads, failed typing |
| Range | Ratios between 0 and 1, percentages 0-100, dates within bounds | Unit mix-ups, parsing errors |
| Domain truth | Two sources that must agree do agree; a known entity has its published value | Logic errors totals cannot reveal |
| Freshness | Latest load or as-of date within the expected window | Stalled pipelines |
| Regression | A fixed bug has a test that fails if it returns | Repeat bugs |
| Behavioural (AI) | A battery of business questions with expected answers | Silent drift in AI answers |

## Plain-script tests (fast to add, easy to run in CI)
```python
# tests/check_curated.py -- exits non-zero on failure
raw, cur_rows = one("SELECT (SELECT COUNT(*) FROM raw.orders), (SELECT COUNT(*) FROM curated.fct_orders)")
assert raw == cur_rows, f"fan-out or drop: raw={raw} curated={cur_rows}"

collisions = q("SELECT entity_key FROM curated.dim_entity GROUP BY 1 HAVING COUNT(DISTINCT name) > 20")
assert not collisions, f"colliding keys: {collisions[:5]}"

lo, hi = one("SELECT MIN(margin_pct), MAX(margin_pct) FROM analytics.product_summary")
assert 0 <= lo and hi <= 100, f"margin_pct out of range: {lo}..{hi}"   # catches fraction-vs-percent bugs
```
- Every assertion message shows the values that failed.
- Explain any tolerance in a comment (for example floating-point sums).
- **Prove the test can fail**: break the logic once on purpose and watch it trip.
- Add a test with every bug fix.

## Reconciliation habits
- Count before and after every join and transformation (`COUNT(*)`, `COUNT(DISTINCT key)`, sums of key measures).
- Compare with an independent figure when one exists (a published number, a source-system report).
- Inspect extremes: top 10 by value, rows with nulls, minimum and maximum dates, the newest and oldest records.

## Native data quality: data metric functions (Enterprise, verify details)
```sql
ALTER TABLE curated.fct_orders SET DATA_METRIC_SCHEDULE = '60 MINUTE';
ALTER TABLE curated.fct_orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_id);
ALTER TABLE curated.fct_orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (order_id);
SELECT * FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS ORDER BY measurement_time DESC;
```
- System functions include `NULL_COUNT`, `DUPLICATE_COUNT`, `UNIQUE_COUNT`, `ROW_COUNT`, `FRESHNESS`; custom DMFs are SQL functions.
- Use DMFs for continuous monitoring; keep script or dbt tests as deploy gates.

## dbt tests
`unique`, `not_null`, `relationships`, `accepted_values`, plus singular SQL tests for reconciliation and domain truths. Run on a clone in CI; fail the build on errors.

## Alerts
```sql
CREATE OR REPLACE ALERT ops.failed_tasks_alert
  WAREHOUSE = ops_wh  SCHEDULE = '30 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM TABLE(information_schema.task_history(SCHEDULED_TIME_RANGE_START => DATEADD(minute, -30, CURRENT_TIMESTAMP())))
    WHERE state = 'FAILED'))
  THEN CALL SYSTEM$SEND_EMAIL('ops_email_int', 'data-team@example.com', 'Snowflake task failures', 'A task failed in the last 30 minutes.');
ALTER ALERT ops.failed_tasks_alert RESUME;
```
- Sending email needs a notification integration with allowed recipients (verify setup). Webhook and queue integrations exist too.
- Alert on: failed or suspended tasks, stale streams, Dynamic Tables behind lag or failing, paused or erroring pipes, `COPY` errors, missing periods (manifest vs expected calendar), spend spikes against a trailing average, repeated login failures.

## Observability
- **Load manifest**: one row per file or period with counts and status; compare with the expected calendar.
- **Query tags** per job make failures and cost traceable.
- **Event tables** capture logs and traces from procedures, UDFs and apps (verify setup).
- Show freshness to users: the as-of date in every app screen and AI answer.

## Checklist
- [ ] Counts and key counts reconcile across layers.
- [ ] At least one known real value matches.
- [ ] A failing check stops the pipeline or alerts a person.
- [ ] Tests live in the repo and run in CI.
- [ ] Every past bug has a regression check.
