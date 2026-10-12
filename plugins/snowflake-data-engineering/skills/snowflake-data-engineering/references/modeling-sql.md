# Modeling and SQL

> Read when: designing tables or views, writing transformations, joining, deduplicating, or numbers look wrong.

## Layer contracts
| Layer | Contains | Never |
|---|---|---|
| Raw | Exact source copy, `STRING`/`VARIANT`, load metadata | Business logic, fixes, deletes of history |
| Curated | Typed, deduplicated, conformed keys; dimensions and facts at a stated grain | Report-specific shaping |
| Serving (analytics/mart) | One object per question shape, business names, units, as-of dates | Raw columns, ambiguous names |
| App | Stages, apps, semantic models | Business data |
Medallion naming maps directly: bronze = raw, silver = curated, gold = serving.

## Grain and keys
- Write the grain of every table as one sentence: "one row per order line per day".
- Prefer stable natural keys. Build composite identity keys by priority and **treat placeholders as NULL**:
  ```sql
  COALESCE(NULLIF(NULLIF(primary_id, 'N/A'), ''), secondary_id, UPPER(name) || '|' || COALESCE(subtype, '')) AS entity_key
  ```
- Surrogate keys only when natural keys are unreliable: `HASH(...)` (fast, 64-bit), `SHA2(...)`/`MD5(...)` (stable across systems), sequences or `IDENTITY`, or `UUID_STRING()`.
- **Constraints are informational.** Snowflake does not enforce `PRIMARY KEY`, `UNIQUE` or `FOREIGN KEY` on standard tables (only `NOT NULL`). Test uniqueness yourself.
- After building a key, test it: no key maps to many distinct names; counts and sums by key are plausible.

## Safe typing
```sql
TRY_TO_NUMBER(x, 38, 2)   TRY_TO_DOUBLE(x)   TRY_TO_DATE(x, 'DD-MON-YYYY')   TRY_TO_TIMESTAMP_NTZ(x)   TRY_TO_BOOLEAN(x)
```
`TRY_` returns `NULL` instead of failing the whole query. Count the `NULL`s you create and assert the count is acceptable.

## Style
- Explicit column lists; no `SELECT *` in serving objects (`SELECT * EXCLUDE (...)` is acceptable in intermediate steps).
- One CTE per step, named for what it produces.
- `JOIN ... USING (key)` for simple equality joins; qualify columns otherwise.
- `GROUP BY ALL` for readability when grouping by every non-aggregate column.
- Comments explain **why**. Put `COMMENT` on serving objects and key columns that humans or AI will read.

## Joins, duplicates and fan-out
- A one-to-many join multiplies rows and inflates sums. Aggregate the many side first or select one row.
- Reconcile every join: `COUNT(*)` and `COUNT(DISTINCT key)` before and after.
- Lookup tables often have several rows per key (identifiers, aliases, history). Collapse them before joining:
  ```sql
  LEFT JOIN (SELECT entity_id, MAX(alt_id) AS alt_id FROM ids GROUP BY entity_id) i USING (entity_id)
  ```

## Useful functions and clauses
| Need | SQL |
|---|---|
| Latest row per key | `QUALIFY ROW_NUMBER() OVER (PARTITION BY k ORDER BY updated_at DESC) = 1` |
| Value of another column at min/max | `MAX_BY(price, ts)`, `MIN_BY(...)` |
| Conditional count/sum | `COUNT_IF(cond)`, `SUM(IFF(cond, x, 0))` |
| Safe division | `DIV0(a, b)`, `a / NULLIF(b, 0)` |
| Null-safe equality | `EQUAL_NULL(a, b)` or `a IS NOT DISTINCT FROM b` |
| Previous value | `LAG(x) OVER (PARTITION BY k ORDER BY d)` |
| Share of total | `x / SUM(x) OVER (PARTITION BY grp)` |
| Point-in-time match | `ASOF JOIN q MATCH_CONDITION (t.ts >= q.ts) ON t.key = q.key` |
| Ordered string list | `LISTAGG(x, ', ') WITHIN GROUP (ORDER BY x)` |
| Pattern over rows | `MATCH_RECOGNIZE` |

## NULL semantics
- `x NOT IN (subquery)` returns no rows if the subquery contains a `NULL`. Use `NOT EXISTS`.
- `COUNT(col)` skips `NULL`s; `COUNT(*)` does not.
- `NULL = NULL` is not true; use `EQUAL_NULL`.
- Aggregates ignore `NULL`s: an average of a mostly-null column describes few rows.

## Window functions
- `ORDER BY` inside a window defaults to a frame ending at the current row; `LAST_VALUE` then returns the current row. Specify `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` when you mean the whole partition.
- `LIMIT` without `ORDER BY` is non-deterministic.
- Floating-point sums can differ in the last decimals between runs. Compare with a tolerance, or use `NUMBER`.

## MERGE
```sql
MERGE INTO curated.customer t
USING (SELECT * FROM staging.customer QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) = 1) s
ON t.customer_id = s.customer_id
WHEN MATCHED AND t.row_hash <> s.row_hash THEN UPDATE SET t.name = s.name, t.row_hash = s.row_hash, t.updated_at = s.updated_at
WHEN NOT MATCHED THEN INSERT (customer_id, name, row_hash, updated_at) VALUES (s.customer_id, s.name, s.row_hash, s.updated_at);
```
`MERGE` fails (or is non-deterministic) when one target row matches several source rows. Deduplicate the source first.

## Semi-structured
```sql
SELECT e.v:customer.id::NUMBER AS customer_id, f.value:sku::STRING AS sku, f.index AS position
FROM raw.events e, LATERAL FLATTEN(INPUT => e.v:items) f;
```
- `LATERAL FLATTEN` turns arrays into rows; `f.index` gives the position.
- Correlated `UNION ALL` subqueries inside a lateral are not supported. Unpivot with `FLATTEN(ARRAY_CONSTRUCT(a, b, c))` or `UNPIVOT`.
- Build values with `OBJECT_CONSTRUCT`, `ARRAY_AGG`, `PARSE_JSON`, `TO_VARIANT`. Always cast on read.

## Reshaping
- Pivot known, few categories with conditional aggregation: `MAX(IFF(tag = 'x', value, NULL)) AS x`.
- Unpivot repeated columns (`m1, m2, m3`) with `FLATTEN(ARRAY_CONSTRUCT(...))` and derive the period from the index.

## History and point-in-time
| Need | Pattern |
|---|---|
| Only latest matters | Overwrite or `MERGE` |
| Full history | Type 2: `valid_from`, `valid_to`, `is_current`; close the old row, insert the new |
| Snapshots | Keep each snapshot with its as-of date |
| No look-ahead in analysis | Store both the as-of date and the date the data became known; filter on the latter |

## Transactions
- Each DDL statement commits implicitly (and commits any open transaction).
- Wrap multi-statement DML in `BEGIN ... COMMIT` when partial results are not acceptable (for example delete-then-insert).
- Streams advance only when consumed by DML inside a committed transaction.

## Regex and text
- Backslashes inside single-quoted strings are escapes; prefer POSIX classes: `[[:space:]]`, `[[:digit:]]`, `[[:alpha:]]`.
- When cleaning HTML: strip tags first, then decode entities (`&amp;`, `&nbsp;`, `&lt;`, `&gt;`).
- Test cleaning on a known string and assert the result.

## Time travel, clones and table kinds
- Time travel: `SELECT ... AT(TIMESTAMP => ...)`, `BEFORE(STATEMENT => '<query_id>')`, `UNDROP TABLE`.
- Zero-copy clone a database or table before a risky change; drop it afterwards.
- Transient and temporary tables have no fail-safe: use them for rebuildable staging data.
- `CREATE OR REPLACE TABLE` replaces data and drops grants. Use `ALTER TABLE` for tables with data; use `COPY GRANTS` or future grants when replacing views.

## Checklist
- [ ] Every table states its grain; uniqueness at that grain is tested (constraints are not enforced).
- [ ] Keys treat placeholder values as `NULL`; no key maps to many distinct entities.
- [ ] Joins are reconciled (row and key counts before and after); many-side tables are collapsed first.
- [ ] Text is typed with `TRY_TO_*` and the `NULL`s created are counted.
- [ ] Serving objects use explicit columns, unit-bearing names, and carry as-of and availability dates.
- [ ] `NOT IN` with nullable subqueries, window frames and `LIMIT` without `ORDER BY` have been checked.
- [ ] `MERGE` sources are deduplicated; multi-statement DML that must be atomic runs in a transaction.
- [ ] Tables with data are changed with `ALTER`, not `CREATE OR REPLACE`.

## Metadata queries
```sql
SELECT table_schema, table_name, row_count, bytes, comment FROM <db>.information_schema.tables WHERE table_schema = 'CURATED';
SELECT GET_DDL('VIEW', '<db>.<schema>.<view>');
SHOW GRANTS ON VIEW <db>.<schema>.<view>;
```
