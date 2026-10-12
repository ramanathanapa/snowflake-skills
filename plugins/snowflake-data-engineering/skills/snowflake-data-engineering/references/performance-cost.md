# Performance and cost

> Read when: a query is slow, a warehouse is busy or queued, spend is rising, or you are sizing compute.

## How billing works
| Component | Charged for | Notes |
|---|---|---|
| Warehouses | Credits per second while running; 60-second minimum on each resume | Credits per hour double per size: XS 1, S 2, M 4, L 8, XL 16, 2XL 32 ... (standard warehouses; newer generations and Snowpark-optimized differ, verify) |
| Storage | Compressed TB per month | Time travel, fail-safe and diverged clones add storage |
| Serverless features | Credits or per-GB/per-token rates | Snowpipe (per GB), serverless tasks, Dynamic Table refresh compute, clustering, search optimization, Cortex AI |
| Cloud services | Metadata, compilation | Free up to a daily share of compute; floods of tiny queries can exceed it |
A suspended warehouse costs nothing. Idle running warehouses and oversized warehouses are the most common waste.

## Warehouse settings (in code)
```sql
CREATE WAREHOUSE IF NOT EXISTS transform_wh
  WAREHOUSE_SIZE = XSMALL  AUTO_SUSPEND = 60  AUTO_RESUME = TRUE  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 3600;          -- default is 2 days: always lower it
```
| Decision | Guidance |
|---|---|
| Size | Start `XSMALL`. Scale up only when one query is slow **and** the profile shows spilling or work you cannot remove |
| Scale up vs out | Up (bigger) for one heavy query; out (multi-cluster, Enterprise) for many concurrent users queuing |
| Auto-suspend | 60 s for loads, transforms and apps; longer only when cache reuse clearly pays |
| Workload isolation | Separate warehouses for load, transform, BI and apps: attributable cost, no noisy neighbours |
| Timeouts | `STATEMENT_TIMEOUT_IN_SECONDS` and `STATEMENT_QUEUED_TIMEOUT_IN_SECONDS` stop runaway or stuck queries |
| Memory-heavy Python | Snowpark-optimized warehouses (verify) |

## Spend controls
```sql
CREATE RESOURCE MONITOR transform_rm WITH CREDIT_QUOTA = 100 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 50 PERCENT DO NOTIFY  ON 80 PERCENT DO NOTIFY  ON 100 PERCENT DO SUSPEND  ON 110 PERCENT DO SUSPEND_IMMEDIATE;
ALTER WAREHOUSE transform_wh SET RESOURCE_MONITOR = transform_rm;
```
- `SUSPEND` lets running queries finish; `SUSPEND_IMMEDIATE` cancels them.
- Resource monitors cover warehouses only. Use **budgets** for serverless and account-level spend (verify).
- Confirm someone actually receives monitor notifications (users with verified email and notifications enabled).

## Where credits go
```sql
-- by warehouse, last 30 days
SELECT warehouse_name, ROUND(SUM(credits_used), 2) AS credits
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP()) GROUP BY 1 ORDER BY 2 DESC;

-- by service type (warehouses, pipes, serverless tasks, AI ...)
SELECT service_type, ROUND(SUM(credits_used), 2) AS credits
FROM snowflake.account_usage.metering_daily_history
WHERE usage_date >= DATEADD(day, -30, CURRENT_DATE()) GROUP BY 1 ORDER BY 2 DESC;

-- slowest recent queries with pruning and spilling indicators
SELECT query_id, warehouse_name, total_elapsed_time / 1000 AS seconds, partitions_scanned, partitions_total,
       bytes_spilled_to_local_storage, bytes_spilled_to_remote_storage, LEFT(query_text, 120) AS query
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD(day, -1, CURRENT_TIMESTAMP()) ORDER BY total_elapsed_time DESC LIMIT 20;
```
- `ACCOUNT_USAGE` views lag by up to a few hours; `INFORMATION_SCHEMA` table functions are near real time with shorter history.
- Per-query cost attribution exists in `QUERY_ATTRIBUTION_HISTORY` (verify).
- Set `QUERY_TAG` per job or app (`ALTER SESSION SET QUERY_TAG = 'job:orders_load'`) and group spend by it.
- Queueing: `WAREHOUSE_LOAD_HISTORY` shows running vs queued load.

## Making a query faster (in this order)
1. **Prune**: filter early on columns that align with load order or clustering; do not wrap filter columns in functions (`WHERE DATE(ts) = ...` prunes worse than a range on `ts`).
2. **Project**: select only needed columns; avoid `SELECT *` in wide intermediate steps.
3. **Join correctly**: equality joins on keys, no accidental cross joins, aggregate before joining.
4. **Read the Query Profile**: most expensive operator, partitions scanned vs total, spilling (local, then remote = undersized or bad plan), exploding joins, row counts per step.
5. **Reuse**: the result cache serves identical queries on unchanged data; avoid needless non-deterministic functions in repeated query text.
6. **Only then** consider a bigger warehouse, clustering, search optimization or materialization.

## Acceleration features
| Feature | Use when | Watch |
|---|---|---|
| Clustering key | Large tables (roughly multi-TB) filtered selectively on columns that do not follow load order | Automatic clustering costs credits; check `SYSTEM$CLUSTERING_INFORMATION` first |
| Search optimization | Selective point lookups or text/variant searches on large tables (Enterprise) | Storage and maintenance cost |
| Query acceleration service | Occasional scan-heavy outliers on a warehouse | Serverless credits |
| Materialized view / Dynamic Table | Repeated expensive aggregation over slowly changing data | Refresh cost |
Small tables rarely need any of these. Measure first.

## Data layout
- Loading in a natural order (by date) gives free pruning on date filters.
- Prefer `DATE` columns for filtering daily data over parsing timestamps in predicates.
- Batch small inserts; streams of tiny DML create many small micro-partitions.
- Transient tables for rebuildable staging data cut storage overhead.
- Drop or let expire old clones and scratch objects; shorten time travel on scratch schemas.

## Apps and BI
- Cache query results in the app (for example 5-10 minutes) so clicks do not wake the warehouse.
- Serve from small aggregates or serving views, never from raw.
- Give BI and apps their own warehouse with a monitor.

## Cost review checklist
- [ ] Every warehouse: auto-suspend 60 s, statement timeout set, monitor or budget attached.
- [ ] Sizes justified by evidence (profiles), not habit.
- [ ] Serverless spend (pipes, tasks, Dynamic Tables, clustering, search optimization, AI) reviewed monthly.
- [ ] Spend attributable by warehouse or query tag.
- [ ] Old clones, scratch tables and long time travel on scratch data cleaned up.
