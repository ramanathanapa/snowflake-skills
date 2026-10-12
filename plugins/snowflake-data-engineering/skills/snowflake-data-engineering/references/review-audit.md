# Reviewing and auditing a Snowflake project

> Read when: asked for a **full** audit or an account-wide review. For a review of one area (loading, pipelines, security ...), do not use this file: use that area's reference and its `Checklist`.

## Scoped review (the default)
1. Identify the area from the request and read only its reference file.
2. Check the code or account against that file's `Checklist`, item by item, with evidence.
3. Run only that area's probe queries (for loading: `COPY_HISTORY`, `LIST @stage`, `SYSTEM$PIPE_STATUS`, count reconciliation).
4. Report in the scoped review format (`SKILL.md`, section 7). Offer the full audit only if problems clearly spill into other areas.

## Ground rules
- **Read-only.** Gather evidence with `SELECT`, `SHOW`, `DESC`, file reads and greps. Change nothing during the audit.
- **Evidence for every finding**: a file and line, a query result, or a command output. No finding without evidence; no evidence presented as a finding without saying so.
- **Report first, fix after approval.**
- **State what you could not check** (missing privileges, unavailable views, features not present).

## Step 1: Scope
Name what is in scope: repository path(s), account, databases, environments, and the role used for evidence. Note the edition and account type (trial accounts lack some features).

## Step 2: Repository evidence
| Check | How |
|---|---|
| Version control | `git rev-parse --is-inside-work-tree`; history, branches, CI config present |
| Secrets | Search for `BEGIN PRIVATE KEY`, `password`, `token`, `.p8`, `.pem`, `.env`, connection strings; check `.gitignore` covers keys, state, tfvars, data |
| Synced folders | Is the repo inside a cloud-synced folder (OneDrive, Dropbox) that uploads state, keys or data? |
| Infrastructure as code | Terraform present? Provider pinned and lock file committed? State remote or local? Role used by the provider? |
| Migrations | Versioned files? Runner with history and checksums? Applied files edited in place? |
| SQL built from strings | f-strings or concatenation with variables in `execute`/`sql` calls |
| Duplication | Connection/key-loading code copied across files; hardcoded account, role, warehouse, database names |
| Dependencies | Pinned (`requirements.txt`, lock file); runtime versions for Snowflake-hosted code pinned |
| Tests | Data checks, regression tests, AI question battery; run in CI? |
| Documentation | README with setup, run order, limits; comments on non-obvious logic |
| Personal data | Personal emails, names, account identifiers in code or docs that should be configuration |

## Step 3: Account evidence (read-only probes)
```sql
-- context
SELECT CURRENT_ACCOUNT(), CURRENT_REGION(), CURRENT_VERSION(), CURRENT_ROLE();

-- identity and access
SHOW GRANTS OF ROLE accountadmin;
SHOW GRANTS TO ROLE public;
SHOW USERS;                                   -- default_role, has_password, has_rsa_public_key, type, disabled
DESC USER <user>;                             -- default role, key fingerprint, password set
SHOW NETWORK POLICIES;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;
SHOW MASKING POLICIES IN ACCOUNT;  SHOW ROW ACCESS POLICIES IN ACCOUNT;

-- compute and cost
SHOW WAREHOUSES;                              -- size, auto_suspend, auto_resume, resource_monitor
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT_IN_SECONDS' IN WAREHOUSE <wh>;   -- 172800 = default (2 days)
SHOW RESOURCE MONITORS;                       -- quota, used, triggers, notified users
SELECT warehouse_name, SUM(credits_used) FROM snowflake.account_usage.warehouse_metering_history
 WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP()) GROUP BY 1 ORDER BY 2 DESC;

-- pipelines and health
SHOW TASKS IN ACCOUNT;                        -- state = suspended?
SELECT name, state, error_message, scheduled_time FROM snowflake.account_usage.task_history
 WHERE state = 'FAILED' AND scheduled_time >= DATEADD(day, -7, CURRENT_TIMESTAMP());
SHOW PIPES IN ACCOUNT;                        -- then SYSTEM$PIPE_STATUS('<pipe>') for each
SHOW DYNAMIC TABLES IN ACCOUNT;               -- scheduling_state, refresh_mode
SHOW STREAMS IN ACCOUNT;                      -- stale?

-- governance and documentation
SELECT table_schema, table_name, table_type FROM <db>.information_schema.tables WHERE comment IS NULL AND table_schema NOT IN ('INFORMATION_SCHEMA');
SHOW GRANTS TO ROLE <reader_role>;            -- only serving objects?
SHOW GRANTS OF ROLE <reader_role>;            -- held by anyone? ever tested?
```
`ACCOUNT_USAGE` views need appropriate privileges and lag by hours; note it if they are unavailable.

## Step 4: Data and logic evidence
- Rerun the project's checks; record results.
- Reconcile key layers (counts, distinct keys) and run one known-value comparison.
- Run any AI question battery; run verified queries' SQL to confirm they work.
- Time the heaviest serving queries; note spilling or full scans.

## Step 5: Rate severity
| Severity | Meaning | Examples |
|---|---|---|
| Critical | Active exposure or likely data loss now | Secret in repo or history, public access to sensitive data, no backups for irreplaceable data |
| High | Serious risk with a plausible trigger | No version control; LLM or app SQL running with write privileges; `ACCOUNTADMIN` as daily or automation role; untracked migrations; local-only Terraform state |
| Medium | Weakens reliability or control | No CI; no alerts; default statement timeout; untested reader role; duplicated config; unpinned dependencies; non-atomic reloads |
| Low | Hygiene and maintainability | Missing comments; style; minor duplication; private API use in dev-only code |
Severity reflects impact times likelihood in **this** context (a public dataset needs no masking; a trial account needs fewer controls than production).

## Step 6: Report (template)
```
# Audit: <project> (<date>)
Scope: <repo, account, role used>. Method: read-only checks; no changes made.

## Passed
- <short list of things done well, with evidence>

## Findings
| # | Severity | Finding | Evidence | Fix | Effort |
|---|---|---|---|---|---|
| 1 | High | ... | file:line / query result | ... | 1 h |

## Could not verify
- <item and why>

## Suggested order
1. <highest risk per unit of effort first>

Nothing has been changed. Which items should be fixed?
```
Keep findings concrete and actionable. Prefer "the app executes generated SQL as an owner role with ALL on every schema (`app.py:147`)" over "security could be improved".

## Step 7: After approval
- Fix in the order agreed, one item per change, each with its own check.
- Re-run the relevant audit probes to confirm the fix.
- Update the report: fixed, skipped (with reason), or no change needed.
