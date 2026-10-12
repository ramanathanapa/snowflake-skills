# Cortex AI and Streamlit in Snowflake

> Read when: adding natural-language querying, AI SQL functions, search over documents, or building a Streamlit app on Snowflake.

These features change fast. Everything here is a starting point: probe the account and check current docs before designing around a feature.

## 1. Probe what the account allows (first, always)
```sql
SELECT CURRENT_REGION(), CURRENT_VERSION();
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;
SELECT AI_COMPLETE('<small-model>', 'Reply with the single word: ready');   -- model names and availability vary by region
```
- Availability differs by region, edition and account type. Trial accounts may block text generation while Cortex Analyst still works. Test each function you depend on.
- Cross-region inference may be required for some models; check data-residency implications before enabling it.

## 2. AI SQL functions (verify names and preview status)
| Function | Purpose | Note |
|---|---|---|
| `AI_COMPLETE` | Generate text (or answer about an image) with a chosen model | Successor to `SNOWFLAKE.CORTEX.COMPLETE` |
| `AI_CLASSIFY` | Assign one or more categories to text or images | Successor to `CLASSIFY_TEXT` |
| `AI_FILTER` | True/false judgement usable in `WHERE` or `JOIN ON` | Preview as of late 2025 |
| `AI_AGG`, `AI_SUMMARIZE_AGG` | Aggregate insight or summary across many rows | Preview as of late 2025 |
| `AI_EXTRACT`, `AI_SENTIMENT`, `AI_TRANSLATE`, `AI_EMBED`, `AI_SIMILARITY` | Extraction, sentiment, translation, embeddings, similarity | Check current list |
| `CREATE AI FUNCTION` | Wrap prompt logic as a reusable governed function | Verify |
Older `SNOWFLAKE.CORTEX.*` functions may still work; prefer the current names in new code.

Habits:
- Cost is per token: use the smallest model that passes your tests, and process only the rows you need.
- Cache AI outputs in a table keyed by input hash; do not recompute on every query.
- Evaluate on a labelled sample before trusting results; keep the sample and the scores.
- Never send data to AI functions that policy forbids; masking and row policies still apply to inputs.

## 3. Cortex Analyst (natural language -> SQL)
- Takes a question plus a **semantic layer**, returns SQL and an interpretation. The model does not read your rows; the SQL runs in your account under the caller's role.
- **Semantic views are the recommended semantic layer** for new work: schema-level objects with privileges, sharing and direct SQL querying. Create them with DDL, from YAML (`SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML`), or in Snowsight (verify current syntax).
- Legacy **YAML semantic models on a stage** still work with Cortex Analyst; migrate when you need governance, sharing or SQL access.
- REST: `POST /api/v2/cortex/analyst/message` with `messages` and a semantic view or model reference. Multi-turn: resend earlier turns, including the analyst's returned content.

### Designing the semantic layer (this decides accuracy)
- Point it at **serving views**, never raw tables. One logical table per question shape.
- For every column: clear name, description **with units**, synonyms users actually say, sample values for categorical columns.
- Separate dimensions, time dimensions, facts and metrics; define metrics once (for example "revenue = SUM(amount_usd)").
- Instructions: unit conventions, which table answers which kind of question, caveats (data age, gaps), and "always return the as-of date".
- Relationships on real keys, with the one side uniquely keyed.
- **Verified queries**: add a known-good question and SQL pair for every question answered wrongly. Run the SQL before adding it, and never invent `verified_by`/`verified_at` metadata.

### Testing it
- Keep a battery of 10-50 real business questions with expected answers or properties; run it after every change to views or the semantic layer.
- Check numbers against known values and check that the intended table was used.
- Typical failure causes: ambiguous synonyms, missing units, two tables that can both answer, misleading column names.

### Running generated SQL safely
- Execute under a **read-only role** limited to serving views.
- Guard before executing: exactly one statement, starting with `SELECT` or `WITH`, no DDL/DML keywords; enforce a row limit.
- Execute the SQL as returned. It may end with a comment, so do not wrap it in a subquery; limit rows after fetching.
- Show the SQL and the data's as-of dates with every answer.

## 4. Cortex Search (retrieval over text)
```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE app.doc_search
  ON chunk_text
  ATTRIBUTES source, doc_date
  WAREHOUSE = search_wh
  TARGET_LAG = '1 day'
AS (SELECT chunk_text, source, doc_date FROM curated.doc_chunks);
```
- Chunk long documents (a few hundred tokens with overlap) and keep metadata for filtering and citations.
- Query through the Python API or REST; test with the preview function in SQL (verify names).
- Check account availability before designing around it.
- **Cortex Agents** can orchestrate Analyst (structured) and Search (unstructured) as tools in one conversation (verify current API).

## 5. Streamlit in Snowflake
### Execution model
- Apps run with the **owner role's** privileges. Viewers need `USAGE` on the app; they need no table access. Make the owner role read-only on what the app shows.
- Streamlit **reruns the whole script** on every interaction:
  - keep conversation and selections in `st.session_state`;
  - cache data with `@st.cache_data(ttl=...)` and connections with `@st.cache_resource`;
  - code in hidden tabs still runs: keep it light or load lazily.
- `st.cache_data` is shared across viewers of the same app. Do not cache per-user data that row policies would separate.

### Portability
```python
@st.cache_resource
def get_session():
    try:
        from snowflake.snowpark.context import get_active_session
        return get_active_session()            # inside Snowflake
    except Exception:
        return build_local_session()           # local dev from config / key file
```
- The in-Snowflake runtime can be older than your local Streamlit. Pin versions (`environment.yml` or the container runtime's requirements, verify) and avoid APIs newer than the pin.
- Calling REST APIs (for example Cortex Analyst) differs inside Snowflake (platform helper such as `_snowflake.send_snow_api_request`) and locally (HTTPS with a session token). Keep one function with both paths (verify the current helper).
- Avoid private client attributes; if unavoidable, isolate them in the local-only path.

### UX for decision tools
- Show data freshness and a short disclaimer where decisions depend on the data.
- Show the SQL behind AI answers in an expander.
- Handle errors in the UI with a clear message instead of a stack trace; log the query id.
- Build SQL from user selections with binds or strict quoting; dropdown values from the database are safer than free text.

### Deploying
- Snowflake CLI `snow streamlit deploy` with `snowflake.yml`, or a script that uploads files to a stage and runs `CREATE STREAMLIT` (verify current syntax and runtime options).
- After deploy: open the app as a viewer role, run every tab once, and run the question battery.
- Headless tests locally: `streamlit.testing.v1.AppTest.from_file("app.py").run()` exposes widgets, tables and exceptions.

## 6. Checklist
- [ ] Each AI feature probed on the actual account and region.
- [ ] Semantic layer over serving views with units, synonyms, instructions and tested verified queries.
- [ ] Question battery with expected answers runs on every change.
- [ ] Generated SQL runs under a read-only role with a statement guard.
- [ ] SQL and as-of dates visible with every answer.
- [ ] App owner role is least-privilege; caches do not mix per-user data.
- [ ] AI spend bounded: small models, cached outputs, budgets or monitors.
