# Pitfalls: symptom -> cause -> fix

> Read when: numbers look wrong, an error is unclear, or something that worked yesterday fails today.

## Wrong numbers
| Symptom | Likely cause | Fix |
|---|---|---|
| Totals 2x or Nx too high; shares sum to ~200% | One-to-many join (lookup table with several rows per key) | Aggregate or pick one row before joining; compare counts before and after |
| One "entity" owns thousands of unrelated items | Placeholder identifier (`N/A`, `0`, `''`, `UNKNOWN`) used as a key | Treat placeholders as `NULL`; fall back to the next identifier; add a collision test |
| Values 100x too small or large | Fraction vs percent confusion | One convention, unit in column name, range test |
| One source's values have the opposite sign | Provider sign conventions differ | Normalize explicitly and document the rule |
| Every record in a group "changed" | Group-wide scaling (for example a split, unit creation, currency rebasing) not removed | Measure each item relative to the group's median change |
| "Latest" record is not the latest | Sorting text dates | Type with `TRY_TO_DATE`/`TRY_TO_TIMESTAMP`, sort on the typed value |
| Times off by hours | Mixed `TIMESTAMP_NTZ` and `TIMESTAMP_LTZ`, or session time zone | Store UTC; convert explicitly; set `TIMEZONE` |
| `NOT IN` returns nothing | Subquery contains `NULL` | Use `NOT EXISTS` |
| Duplicates despite a `PRIMARY KEY` | Constraints are not enforced | Test uniqueness; deduplicate with `QUALIFY` |
| Sums differ in the last decimals between runs | Floating-point order of addition | Use `NUMBER` for exact values; compare with a tolerance |
| Missing periods nobody noticed | No comparison with an expected calendar | Manifest vs calendar check with an alert |
| Results look "too clean" | Aggregation hiding duplicates, or a filter dropping rows | Reconcile with the source count |
| Different results for the same query | `LIMIT` without `ORDER BY`, or window frame defaults | Add deterministic ordering; specify frames |

## Loading
| Symptom | Cause | Fix |
|---|---|---|
| `COPY` loads 0 rows on rerun | Load metadata remembers files (~64 days) | `FORCE = TRUE` after deleting old rows, or a new path |
| Snowpipe skips a file | File already loaded, or notification missed | `COPY_HISTORY`, `SYSTEM$PIPE_STATUS`, `ALTER PIPE ... REFRESH` |
| Table rows differ from file rows | Embedded newlines/delimiters, quoting, tolerated column mismatches | Check field counts per line; `VALIDATION_MODE`; reconcile counts |
| Columns all `NULL` after typing | Wrong format string | Test `TRY_TO_*` on samples; count nulls created |
| `PUT` worked, table empty | `COPY` not run, wrong path, file name missing `.gz` | `LIST @stage/path`; check `COPY_HISTORY` |
| Client runs out of memory | Whole file read at once | Stream line by line |
| Outbound HTTP fails inside Snowflake | No external access integration, or not allowed on the account | Download on a client and `PUT` |

## SQL errors
| Error | Meaning and fix |
|---|---|
| `Object does not exist or not authorized` | Wrong context or missing `USAGE` on a parent. Check `CURRENT_ROLE()`, database, schema, then `SHOW GRANTS TO ROLE` |
| `Insufficient privileges to operate on ...` | Missing privilege in the chain (database, schema, warehouse, object) |
| `Unsupported subquery type cannot be evaluated` | Correlated subquery shape not supported (often `UNION ALL` inside a lateral). Use `LATERAL FLATTEN` or join to an aggregate |
| `syntax error ... unexpected ';'` | Generated SQL ending with `;` or a comment was wrapped in a subquery. Run it as-is |
| `Numeric value '...' is not recognized` | Text with stray characters cast to a number. Use `TRY_TO_NUMBER` and inspect |
| `Duplicate row detected during DML action` | `MERGE` source has several rows per target key. Deduplicate the source |
| `No active warehouse selected` | `USE WAREHOUSE`, or set a default / app query warehouse |
| `Statement reached its statement or warehouse timeout` | Query too heavy or timeout too low. Fix the query first |
| Query suddenly slow | Data grew, pruning lost (functions on filter columns), cache cold, warehouse queued. Read the profile |

## Authentication
| Symptom | Fix |
|---|---|
| `JWT token is invalid` (390144) | Public key not registered on that user, wrong account or user, wrong key file. `DESC USER` -> `RSA_PUBLIC_KEY_FP`, re-register |
| Works for one user, not another | Role not granted, different default role or warehouse |
| Feature "not available for trial accounts" | Account limitation; design around it or upgrade |

## Pipelines
| Symptom | Fix |
|---|---|
| Task silently stopped | Suspended after failures (`SUSPEND_TASK_AFTER_NUM_FAILURES`). Alert on state; fix and resume |
| Stream is stale | Not consumed within retention. Recreate and backfill; consume regularly |
| Dynamic Table always full refresh | Query shape not incremental-eligible. Check refresh history; restructure |
| Child tasks never run | Graph not resumed correctly. `SYSTEM$TASK_DEPENDENTS_ENABLE` on the root |

## Terraform
| Symptom | Fix |
|---|---|
| Plan wants to replace many objects | Provider upgrade or resource rename. Stop, read release notes, use moved/import blocks |
| Grants vanish after a view is replaced | `CREATE OR REPLACE` dropped them. Use future grants or `COPY GRANTS` |
| State lost | `terraform import` each resource; prevent with remote state |
| Preview resource rejected | Enable it in the provider or manage it with SQL |

## Apps and AI
| Symptom | Fix |
|---|---|
| Works locally, fails in Snowflake | Older runtime, platform-only helpers, different role or warehouse |
| Slow app, warehouse always awake | Missing caching; heavy work in hidden tabs |
| AI answers wrong | Improve descriptions, units and synonyms; add a tested verified query and a battery case |
| AI answer correct but stale | Show as-of dates; refresh the underlying data |

## Process mistakes that cause most incidents
- Trusting a green run without comparing to a known value.
- Designing columns from documentation instead of real data.
- Clicking changes in the console that code owns.
- Patching a symptom in one consumer instead of the shared layer.
- Hiding data age, so stale data is read as current.
- Building the AI layer before the data layers are verified.
- Working as `ACCOUNTADMIN` "just for now".
