# Foundations

> Read when: starting a project, naming things, choosing environments, picking data types, or debugging "object does not exist".

## Object hierarchy
```
Organization
└── Account                      users, roles, warehouses, resource monitors, integrations, network policies
    └── Database                 replicated, cloned and shared as a unit
        └── Schema               access boundary; managed-access option
            └── Objects          tables, views, Dynamic Tables, stages, file formats, pipes, streams,
                                 tasks, sequences, functions, procedures, semantic views, Streamlit apps
```
Account-level objects (warehouses, roles, users) are not inside a database. Grants on parents (`USAGE` on database and schema) are needed before grants on children work.

## Editions and feature gates (verify for your contract)
| Typically needs Enterprise or higher | Typically needs Business Critical or higher |
|---|---|
| Multi-cluster warehouses | Private connectivity (PrivateLink and similar) |
| Time travel beyond 1 day (up to 90) | Customer-managed key layering (Tri-Secret Secure) |
| Materialized views, search optimization | Account failover and client redirect |
| Masking and row access policies, object tagging | Compliance-oriented controls (for example HIPAA, PCI) |
| `ACCESS_HISTORY`, data metric functions | |
Trial accounts can lack some features entirely (for example certain AI functions or external network access). Probe early.

## Context and qualification
- Every statement runs with a current **role**, **warehouse**, **database** and **schema**. Debug with:
  ```sql
  SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_ACCOUNT(), CURRENT_REGION();
  ```
- In code, use **fully qualified names** (`db.schema.object`) or set context explicitly at the top of each script. Never rely on a user's default context.
- "Object does not exist or not authorized" usually means wrong context or a missing `USAGE` on a parent, not a missing object.

## Identifiers and case
- Unquoted identifiers are stored in UPPER case and matched case-insensitively.
- Quoted identifiers (`"MyCol"`) are case-sensitive forever; every query must quote them the same way. Avoid them.
- Python clients and pandas return column names in UPPER case. Code accordingly.
- Use `IDENTIFIER(:var)` or `IDENTIFIER($var)` for dynamic object names, never string concatenation.
- String comparisons are case-sensitive by default: use `ILIKE`, `UPPER()`, or a collation when needed.

## Naming conventions (adapt, then apply everywhere)
| Object | Pattern | Example |
|---|---|---|
| Database | `<domain>[_<env>]` | `SALES_PROD`, `SALES_DEV` |
| Schema | layer name | `RAW`, `CURATED`, `ANALYTICS`, `APP` |
| Raw table | source entity | `RAW.ORDERS` |
| Curated | `DIM_` / `FCT_` or entity name | `CURATED.DIM_CUSTOMER`, `CURATED.FCT_ORDER_LINE` |
| Serving view | question shape | `ANALYTICS.CUSTOMER_SUMMARY` |
| Warehouse | `<workload>_WH` | `LOAD_WH`, `TRANSFORM_WH`, `BI_WH` |
| Access role | `<db>_<schema>_<level>` | `SALES_ANALYTICS_READ` |
| Functional role | job | `DATA_ENGINEER`, `ANALYST` |
| Service user | `SVC_<system>` | `SVC_LOADER` |
| Resource monitor | `<scope>_RM` | `TRANSFORM_RM` |

## Environment strategy
| Option | Use when |
|---|---|
| One account, database per environment (`_DEV`, `_PROD`) | Small teams; simplest. Separate with roles |
| Separate accounts per environment | Regulatory or strong isolation needs; more admin overhead |
| Zero-copy clone for testing (`CREATE DATABASE x_ci CLONE x_prod`) | CI and migration rehearsal on real-shaped data at no copy cost |
Parameterize database, warehouse and role names in scripts. Never hardcode a production name.

## Data types
| Data | Type | Notes |
|---|---|---|
| Money, exact decimals | `NUMBER(38, s)` | Exact arithmetic |
| Measurements, ratios | `FLOAT` or `NUMBER` | `FLOAT` sums can differ in late decimals between runs |
| Integers | `NUMBER(38,0)` (`INT` is an alias) | |
| Text | `VARCHAR` | No length needed; length does not affect storage |
| True/false | `BOOLEAN` | |
| Dates | `DATE` | Prefer over timestamps for daily data and partition-friendly filters |
| Instants | `TIMESTAMP_NTZ` / `TIMESTAMP_LTZ` / `TIMESTAMP_TZ` | See below |
| Semi-structured | `VARIANT`, `OBJECT`, `ARRAY` | Cast on read: `v:a::STRING` |
| Embeddings | `VECTOR(FLOAT, n)` | For similarity search |
| Spatial | `GEOGRAPHY`, `GEOMETRY` | |

## Time and time zones
- `TIMESTAMP_NTZ`: wall-clock value, no zone. Good for UTC instants if everyone agrees they are UTC.
- `TIMESTAMP_LTZ`: stored as UTC, displayed in the session time zone. `CURRENT_TIMESTAMP()` returns this.
- `TIMESTAMP_TZ`: stores an offset per value.
- The plain `TIMESTAMP` alias follows the `TIMESTAMP_TYPE_MAPPING` parameter (default NTZ).
- Set the account or session `TIMEZONE` explicitly (UTC is a sensible default for pipelines).
- Convert explicitly: `CONVERT_TIMEZONE('UTC', 'America/New_York', ts)`.
- Mixing NTZ and LTZ in comparisons is a classic off-by-hours bug.

## Parameters
Parameters cascade: account -> user -> session, and object parameters on warehouses, databases, schemas and tables.
```sql
SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT_IN_SECONDS' IN WAREHOUSE transform_wh;
ALTER SESSION SET QUERY_TAG = 'loader:orders';
```

## Checklist
- [ ] Naming follows one documented convention across databases, schemas, warehouses, roles and users.
- [ ] Environments are separated (database or account per environment); names are parameterized in code.
- [ ] Scripts set context explicitly or use fully qualified names.
- [ ] No quoted identifiers; money uses `NUMBER`; time zone handling is explicit.
- [ ] Features the design relies on are available on this edition and account type (probed, not assumed).

## Session variables
```sql
SET target_date = '2026-01-31';
SELECT * FROM curated.fct_orders WHERE order_date = $target_date;
SELECT COUNT(*) FROM IDENTIFIER($table_name);
```
