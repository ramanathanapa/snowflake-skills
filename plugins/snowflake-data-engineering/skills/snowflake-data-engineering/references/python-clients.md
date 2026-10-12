# Python clients, Snowpark and Snowflake CLI

> Read when: writing loaders, scripts, tests or apps in Python, configuring connections, or moving data between Python and Snowflake.

## One connection helper, used everywhere
Duplicated connection code in every script drifts and leaks settings. Keep one helper and import it.
```python
# lib/sf.py
import os, pathlib
import snowflake.connector
from cryptography.hazmat.primitives import serialization

def connect(**overrides):
    """Key-pair connection; settings from environment, overrides per call (role, warehouse, database, schema)."""
    key_path = pathlib.Path(os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH", "~/.snowflake/rsa_key.p8")).expanduser()
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE")
    key = serialization.load_pem_private_key(key_path.read_bytes(), password=passphrase.encode() if passphrase else None)
    der = key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    params = dict(account=os.environ["SNOWFLAKE_ACCOUNT"], user=os.environ["SNOWFLAKE_USER"], private_key=der,
                  role=os.environ.get("SNOWFLAKE_ROLE"), warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE"),
                  session_parameters={"QUERY_TAG": os.environ.get("SNOWFLAKE_QUERY_TAG", "script")})
    params.update(overrides)
    return snowflake.connector.connect(**{k: v for k, v in params.items() if v is not None})
```
Alternative: named connections in `~/.snowflake/connections.toml`, shared by the connector, Snowpark and Snowflake CLI (`snowflake.connector.connect(connection_name="dev")`, verify for your version). Keep that file out of repositories.

## Python connector rules
- **Bind values, never format them into SQL**:
  ```python
  cur.execute("SELECT * FROM curated.dim_customer WHERE country = %s AND created_at >= %s", (country, since))
  # server-side binding: snowflake.connector.paramstyle = "qmark"; then use ? placeholders
  ```
- Dynamic object names: `IDENTIFIER(%s)` or a strict allow-list. Never f-strings with user input.
- Multiple statements in one call: `conn.execute_string(sql_text)` (for trusted migration files only).
- Large results: `cur.fetch_pandas_all()` / `fetch_pandas_batches()` (needs the pandas extra) instead of `fetchall()`.
- Long queries: `cur.execute_async(...)` and poll `conn.get_query_status(query_id)`.
- Timeouts: `login_timeout`, `network_timeout`, and warehouse `STATEMENT_TIMEOUT_IN_SECONDS`.
- Retry only idempotent operations; log the query id (`cur.sfqid`) for every failure.
- Close connections (`with` blocks or `finally`).

## Moving data
| Direction | Method |
|---|---|
| Local files -> table | `PUT file://... @stage` then `COPY INTO` |
| DataFrame -> table | `snowflake.connector.pandas_tools.write_pandas(conn, df, "TABLE", auto_create_table=True)` (stages Parquet and copies) |
| Table -> DataFrame | `cur.fetch_pandas_all()` or Snowpark `to_pandas()` after aggregating |
| Large exports | `COPY INTO @stage/... FROM (SELECT ...)` then `GET` |
Column names come back in UPPER case; normalize once at the boundary.

## Large source files
- Stream line by line (`io.TextIOWrapper` over the archive member); never load a multi-GB file into memory.
- Check field counts per line before trusting a delimiter split.
- Filter to what you need before uploading; write filtered files to a git-ignored folder.
- Send required headers (for example a contact `User-Agent`) from configuration, not hardcoded personal data.

## Snowpark Python
```python
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, sum as sum_

session = Session.builder.configs({"connection_name": "dev"}).create()     # or pass the same params as the connector
orders = session.table("curated.fct_orders")
daily = orders.filter(col("ORDER_DATE") >= "2026-01-01").group_by("ORDER_DATE").agg(sum_("AMOUNT_USD").alias("REVENUE_USD"))
daily.write.save_as_table("analytics.daily_revenue", mode="overwrite")   # runs in Snowflake; nothing pulled locally
```
- DataFrames are **lazy**: work happens on `collect()`, `to_pandas()`, `show()`, `count()` or writes.
- Push work to Snowflake; pull only small, aggregated results.
- UDFs: prefer vectorized (pandas) UDFs and UDTFs for batch work over row-at-a-time scalar UDFs.
- Stored procedures (`@sproc`) run Python inside Snowflake: keep them small and test the logic locally first.
- Packages come from the Snowflake Anaconda channel or an artifact repository (verify); pin versions.
- Inside Snowflake (Streamlit, notebooks, procedures) use `get_active_session()`; locally, build a session from config. Code that works in both places keeps tests simple.

## Snowflake CLI (verify current commands)
```bash
snow connection add          # interactive; writes connections.toml
snow connection test -c dev
snow sql -c dev -f sql/migrations/V001__init.sql
snow stage copy ./app @app.streamlit_stage --overwrite
snow streamlit deploy -c dev  # uses snowflake.yml
```

## Dependencies and environments
- Pin dependencies (`requirements.txt` or a lock file); record the Python version.
- Separate local tooling dependencies from what runs inside Snowflake (Streamlit and procedure runtimes may be older).
- On Windows, the Microsoft Store `python` alias can shadow a real install: call the interpreter by full path or disable the alias.

## Checklist
- [ ] One shared connection helper; no copied key-loading code.
- [ ] All values bound as parameters; object names allow-listed.
- [ ] Config from environment or connections file; no personal data or secrets in code.
- [ ] Dependencies pinned; Snowflake-side runtimes pinned separately.
- [ ] Large files streamed; results aggregated in Snowflake before download.
