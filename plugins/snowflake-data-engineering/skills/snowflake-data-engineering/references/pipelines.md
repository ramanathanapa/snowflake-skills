# Pipelines and orchestration

> Read when: choosing how transformations run and refresh, scheduling work, handling change data, or planning backfills.

## Choose the simplest option that meets the freshness need
| Option | Good for | Costs and risks |
|---|---|---|
| View | Small/medium data; logic always current | Recomputed on every query |
| Dynamic Table | Declarative SQL with a freshness target | Credits per refresh; some queries cannot refresh incrementally |
| Stream + Task | Custom CDC, procedural logic, event-driven steps | More code to own; failures, retries and idempotency are yours |
| dbt | Many models, tests, docs, team workflow | Another tool and runtime |
| Stored procedure (SQL, Python) | Logic that must run next to the data | Keep small and testable |
Default: views for small serving layers, **Dynamic Tables** for new transformation pipelines, Streams and Tasks only for behaviour a Dynamic Table cannot express.

## Dynamic Tables
```sql
CREATE OR REPLACE DYNAMIC TABLE curated.fct_orders
  TARGET_LAG   = '1 hour'          -- freshness goal, not a schedule; 'DOWNSTREAM' follows consumers
  WAREHOUSE    = transform_wh
  REFRESH_MODE = AUTO              -- AUTO | INCREMENTAL | FULL
AS
SELECT order_id, customer_id, TRY_TO_NUMBER(amount, 38, 2) AS amount_usd, TRY_TO_DATE(order_date) AS order_date
FROM raw.orders;
```
- Set `DOWNSTREAM` lag on intermediate tables so only the final table drives refresh frequency and cost.
- Shorter lag costs more. Pick the slowest lag consumers accept.
- Check what actually happens:
  ```sql
  SELECT name, refresh_action, state, state_message, refresh_start_time
  FROM TABLE(information_schema.dynamic_table_refresh_history()) ORDER BY refresh_start_time DESC LIMIT 20;
  SHOW DYNAMIC TABLES;      -- scheduling state and refresh mode chosen
  ```
- Some constructs force full refresh (verify the current incremental-refresh support list). If refreshes are always full and slow, restructure.
- Manual control: `ALTER DYNAMIC TABLE x REFRESH;`, `... SUSPEND;`, `... RESUME;`.

## Streams
```sql
CREATE STREAM raw.orders_changes ON TABLE raw.orders;                 -- inserts, updates, deletes
CREATE STREAM raw.events_new ON TABLE raw.events APPEND_ONLY = TRUE;   -- inserts only, cheaper
```
- A stream returns changed rows with `METADATA$ACTION`, `METADATA$ISUPDATE`, `METADATA$ROW_ID`.
- The offset advances only when the stream is read by DML in a committed transaction. Plain `SELECT` does not consume it.
- A stream becomes stale if not consumed within the source table's retention window. Monitor `STALE` in `SHOW STREAMS` and consume regularly.

## Tasks
```sql
CREATE OR REPLACE TASK curated.load_orders
  WAREHOUSE = transform_wh                      -- omit for a serverless task (optionally set USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE)
  SCHEDULE  = 'USING CRON 0 * * * * UTC'
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
  WHEN SYSTEM$STREAM_HAS_DATA('raw.orders_changes')
AS
MERGE INTO curated.fct_orders t USING raw.orders_changes s ON t.order_id = s.order_id
WHEN MATCHED THEN UPDATE SET t.amount_usd = TRY_TO_NUMBER(s.amount, 38, 2)
WHEN NOT MATCHED THEN INSERT (order_id, amount_usd) VALUES (s.order_id, TRY_TO_NUMBER(s.amount, 38, 2));

ALTER TASK curated.load_orders RESUME;          -- tasks are created suspended
EXECUTE TASK curated.load_orders;               -- run once now (testing, backfill)
```
- **Task graphs**: child tasks declare `AFTER parent`; only the root has a schedule. Resume with `SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('db.schema.root_task');`.
- A task without `SCHEDULE` but with a stream condition can run when data arrives (triggered tasks, verify).
- Finalizer tasks can run clean-up after a graph completes (verify).
- Every task must be idempotent; tasks retry and humans rerun them.
- A task suspended after repeated failures is a common silent outage: alert on it.
- Inspect: `SELECT * FROM TABLE(information_schema.task_history()) WHERE state = 'FAILED' ORDER BY scheduled_time DESC;`

## dbt on Snowflake
- Materializations: `view`, `table`, `incremental`, `ephemeral`, `dynamic_table` (verify adapter version).
- Incremental models need a reliable `unique_key` and an `is_incremental()` filter; test them on a backfill and a rerun.
- Tests (`unique`, `not_null`, `relationships`, `accepted_values`, custom SQL) run in CI against a clone.
- One target per environment pointing at different databases; key-pair auth; profiles out of git.
- dbt can also run natively inside Snowflake (verify current "dbt Projects on Snowflake" support).

## Scheduling from outside
Use an external orchestrator (Airflow, Dagster, GitHub Actions, cron) when work spans systems. Keep each Snowflake step idempotent so the orchestrator can retry. Tag queries (`QUERY_TAG`) with the job name for cost attribution.

## Backfills and late data
- Parameterize by period; delete-then-reload one period at a time inside a transaction.
- Commit backfill scripts; never patch production by hand.
- Keep the availability date so late corrections do not silently rewrite history.
- Compare the manifest with an expected calendar to find missing periods.

## Failure handling
- Fail loudly: non-zero exit codes, task failures, alerts.
- Quarantine rows that cannot be typed into a reject table with the reason, and alert on volume.
- Alert on: failed or suspended tasks, stale streams, Dynamic Tables behind their lag, paused or backed-up pipes, missing periods.

## Idempotency checklist
- [ ] Rerunning a period leaves identical rows (no duplicates, no gaps).
- [ ] A run killed halfway can be rerun safely.
- [ ] Inputs are identified explicitly (file, period, offset), not "whatever is new".
- [ ] Assertions run after each run and stop the pipeline on failure.
