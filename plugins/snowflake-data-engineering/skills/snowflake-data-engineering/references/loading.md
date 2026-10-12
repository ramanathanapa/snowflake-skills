# Loading data

> Read when: getting files, events or tables into Snowflake, or a load is failing, slow, duplicated or silently incomplete.

## Building blocks
| Object | Role |
|---|---|
| File format | How to parse: CSV/TSV, JSON, Parquet, Avro, ORC, XML |
| Stage | Where files sit: internal (user, table, named) or external (S3, Azure, GCS) |
| Storage integration | Lets an external stage reach cloud storage without keys in DDL |
| `COPY INTO <table>` | Bulk load; remembers which files it loaded |
| Pipe (Snowpipe) | A `COPY INTO` that runs automatically when files arrive |
| Directory table | A queryable file listing of a stage (useful for unstructured files) |

## Rules
1. **Raw is a faithful copy.** Columns are `STRING` (or one `VARIANT`) plus `_SOURCE_FILE` and `_LOADED_AT`. Type later, in curated.
2. **Explicit column lists** in `COPY` and in `SELECT $1, $2 ...`. Positional loads without a list break silently when the source adds a column.
3. **Idempotent reloads.** Delete the period's rows (by `_SOURCE_FILE` pattern or a period column), then reload with `FORCE = TRUE`; or `MERGE` on a natural key.
4. **Record every load** in a manifest table: source, period, file, rows, status, time. It is your audit trail and your replay list.
5. **Reconcile counts.** Rows expected (from the source or your filter) must equal rows loaded.
6. **Filter before loading** when you need a small slice of a large source; stream large files line by line, never read them whole into memory.
7. **Size files sensibly**: roughly 100-250 MB compressed for bulk loads. Many tiny files are slow and costly; split very large ones.

## Batch load from a client
```sql
CREATE FILE FORMAT IF NOT EXISTS raw.tsv_header
  TYPE = CSV  FIELD_DELIMITER = '\t'  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = NONE  NULL_IF = ('')  EMPTY_FIELD_AS_NULL = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;      -- tolerant in raw; validate counts afterwards

CREATE STAGE IF NOT EXISTS raw.land DIRECTORY = (ENABLE = TRUE);

PUT 'file:///data/orders_2026q1.tsv' @raw.land/orders/2026q1/ AUTO_COMPRESS = TRUE OVERWRITE = TRUE;

DELETE FROM raw.orders WHERE _source_file LIKE '%/2026q1/%';
COPY INTO raw.orders (order_id, customer_id, amount, _source_file)
FROM (SELECT $1, $2, $3, METADATA$FILENAME FROM @raw.land/orders/2026q1/)
FILES = ('orders_2026q1.tsv.gz')
FILE_FORMAT = (FORMAT_NAME = raw.tsv_header)
FORCE = TRUE;
```

## External stage (cloud storage)
```sql
CREATE STORAGE INTEGRATION s3_landing
  TYPE = EXTERNAL_STAGE  STORAGE_PROVIDER = 'S3'  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '<role-arn>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>/landing/');

CREATE STAGE raw.s3_landing URL = 's3://<bucket>/landing/'
  STORAGE_INTEGRATION = s3_landing  FILE_FORMAT = raw.parquet_ff;
```
Never put access keys in stage DDL. Azure and GCS have equivalent integrations.

## COPY options worth knowing
| Option | Use |
|---|---|
| `ON_ERROR = ABORT_STATEMENT` (default) | Safest for batch; fix and rerun |
| `ON_ERROR = CONTINUE` / `SKIP_FILE` | Only with a reject process and an alert |
| `VALIDATION_MODE = RETURN_ERRORS` | Dry run: see problems without loading |
| `FORCE = TRUE` | Reload files already loaded (load metadata is kept about 64 days) |
| `PURGE = TRUE` | Delete staged files after success (keep them if you may reload) |
| `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE` | Load Parquet/Avro/ORC/JSON (and CSV with headers, verify) by column name |
Investigate failures:
```sql
SELECT * FROM TABLE(information_schema.copy_history(TABLE_NAME => 'RAW.ORDERS', START_TIME => DATEADD(hour, -24, CURRENT_TIMESTAMP())));
SELECT * FROM TABLE(VALIDATE(raw.orders, JOB_ID => '_last'));
```

## Schema detection and evolution
```sql
CREATE TABLE raw.events USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(INFER_SCHEMA(LOCATION => '@raw.s3_landing/events/', FILE_FORMAT => 'raw.parquet_ff')));
ALTER TABLE raw.events SET ENABLE_SCHEMA_EVOLUTION = TRUE;   -- loads may add columns (verify format limits)
```
For raw layers, all-`STRING` or a single `VARIANT` is usually more robust than evolving typed columns.

## Semi-structured files
- Land JSON/XML/Avro as one `VARIANT` column plus metadata; project columns in curated (`v:customer.id::NUMBER`).
- `STRIP_OUTER_ARRAY = TRUE` when a JSON file is one big array of records.
- Keep the raw `VARIANT` so new fields can be extracted later without reloading.

## Text file traps
- Embedded newlines, tabs or delimiters inside values break line-based parsing. Check that every line has the header's field count before trusting a split.
- Check encoding (UTF-8 vs others) and byte-order marks.
- Quotes: decide `FIELD_OPTIONALLY_ENCLOSED_BY` from the actual file, not the spec.

## Continuous ingestion
- **Snowpipe**: a pipe with `AUTO_INGEST = TRUE` over an external stage plus cloud event notifications.
  ```sql
  CREATE PIPE raw.orders_pipe AUTO_INGEST = TRUE AS
    COPY INTO raw.orders FROM @raw.s3_landing/orders/
    FILE_FORMAT = (FORMAT_NAME = raw.parquet_ff) MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
  ```
  - Pricing is a flat rate per GB ingested (0.0037 credits per GB as of late 2025); text formats are billed on uncompressed size (verify current rate).
  - `ALTER PIPE ... REFRESH` loads recent files already in the stage (bounded look-back).
  - Monitor: `SELECT SYSTEM$PIPE_STATUS('raw.orders_pipe');`, `COPY_HISTORY`, `PIPE_USAGE_HISTORY`.
- **Snowpipe Streaming / Kafka connector**: row-level, low-latency ingestion from applications (verify current SDK).
- **Managed connectors** (for example Openflow and partner tools) for SaaS and database CDC (verify availability).

## Other ways in
| Method | When |
|---|---|
| Data sharing / Marketplace | Another Snowflake account already has the data: zero-copy, always current, read-only |
| Iceberg tables | Open table format shared with other engines (verify catalog options) |
| External tables | Query files in place, rarely; slower than native tables |
| `write_pandas` (Python) | Small to medium DataFrames from code (see `python-clients.md`) |
| External access integration + UDF | Call an HTTP API from inside Snowflake (not available on all accounts, notably trials) |

## Using public or third-party sources
- Respect rate limits and required headers (for example a contact `User-Agent`); prefer bulk files to per-item APIs.
- Cache downloads; never re-download unchanged files.
- Read licence and redistribution terms before building a product on the data.
- Keep contact details and API keys in configuration, not in code.

## After every load
```sql
SELECT COUNT(*) FROM raw.orders WHERE _source_file LIKE '%/2026q1/%';   -- equals expected rows
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS dupes FROM raw.orders;     -- zero at the declared grain?
SELECT MIN(TRY_TO_DATE(order_date)), MAX(TRY_TO_DATE(order_date)) FROM raw.orders;
```

## Checklist
- [ ] Raw tables are all `STRING` (or one `VARIANT`) plus `_SOURCE_FILE` and `_LOADED_AT`; typing happens downstream.
- [ ] `COPY INTO` uses an explicit column list (or `MATCH_BY_COLUMN_NAME`) and records `METADATA$FILENAME`.
- [ ] Reloads are idempotent: rows for the period are removed (or `MERGE`d) before `FORCE = TRUE`, ideally in one transaction.
- [ ] Every load is recorded in a manifest (source, period, file, rows, status, time).
- [ ] Loaded row counts are reconciled with the source after each load; duplicates at the grain are checked.
- [ ] Error handling is deliberate: default `ABORT_STATEMENT`, or `CONTINUE`/`SKIP_FILE` only with rejects and an alert.
- [ ] External stages use a storage integration; no keys in stage DDL or code.
- [ ] Large files are streamed and filtered before upload; file sizes are sensible (roughly 100-250 MB compressed).
- [ ] Pipes (if any) are monitored for paused, failing or stalled ingestion.
- [ ] Source etiquette: rate limits respected, downloads cached, contact headers and keys come from configuration.
