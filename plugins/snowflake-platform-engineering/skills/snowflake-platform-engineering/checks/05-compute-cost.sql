-- Phase 05 (Compute and cost) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '05';

SHOW WAREHOUSES;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-01', 'Warehouses auto-suspend within 60 s', IFF(COUNT_IF(COALESCE("auto_suspend", 0) = 0 OR "auto_suspend" > 60) = 0, 'PASS', 'FAIL'), COALESCE(COUNT_IF(COALESCE("auto_suspend", 0) = 0 OR "auto_suspend" > 60) || ' of ' || COUNT(*) || ': ' || COALESCE(LEFT(LISTAGG(IFF(COALESCE("auto_suspend", 0) = 0 OR "auto_suspend" > 60, "name" || ' (' || COALESCE(TO_VARCHAR("auto_suspend"), 'never') || 's)', NULL), ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW WAREHOUSES;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-02', 'Every warehouse has a resource monitor', IFF(COUNT_IF(COALESCE("resource_monitor", 'null') = 'null') = 0, 'PASS', 'FAIL'), COALESCE(COUNT_IF(COALESCE("resource_monitor", 'null') = 'null') || ' of ' || COUNT(*) || ' without: ' || COALESCE(LEFT(LISTAGG(IFF(COALESCE("resource_monitor", 'null') = 'null', "name", NULL), ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" NOT LIKE 'SYSTEM$%';

SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT_IN_SECONDS' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-03', 'Account statement timeout below the 2-day default', IFF(TRY_TO_NUMBER(MAX("value")) < 172800, 'PASS', 'WARN'), COALESCE('account value: ' || MAX("value") || ' s', 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-04', 'Credits by service type, last 30 days', 'INFO', COALESCE(LEFT(LISTAGG(service_type || ' ' || TO_VARCHAR(ROUND(credits, 2)), ', '), 500), 'no usage')
FROM (SELECT service_type, SUM(credits_used) AS credits FROM snowflake.account_usage.metering_daily_history
  WHERE usage_date >= DATEADD(day, -30, CURRENT_DATE()) GROUP BY 1 HAVING SUM(credits_used) > 0);

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-05', 'At least half of recent queries carry a QUERY_TAG', IFF(COUNT_IF(COALESCE(query_tag, '') <> '') >= 0.5 * COUNT(*), 'PASS', 'WARN'), ROUND(100 * COUNT_IF(COALESCE(query_tag, '') <> '') / NULLIF(COUNT(*), 0), 1) || '% of ' || COUNT(*) || ' queries tagged (7 days)'
FROM snowflake.account_usage.query_history WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP()) AND warehouse_name IS NOT NULL;

SHOW WAREHOUSES;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-06', 'Warehouse sizes', 'INFO', COALESCE(LEFT(LISTAGG("name" || ' ' || "size", ', '), 500), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW RESOURCE MONITORS;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-08', 'An account-level resource monitor caps total spend', IFF(COUNT_IF("level" = 'ACCOUNT') > 0, 'PASS', 'WARN'), COALESCE(COUNT_IF("level" = 'ACCOUNT') || ' account-level of ' || COUNT(*) || ' monitors', 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW RESOURCE MONITORS;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '05', 'P05-09', 'Resource monitors name who is notified', IFF(COUNT_IF(COALESCE("notify_users", '') = '') = 0, 'PASS', 'WARN'), COALESCE(COUNT_IF(COALESCE("notify_users", '') = '') || ' of ' || COUNT(*) || ' monitors have no NOTIFY_USERS (only admins with notifications enabled are alerted): ' || COALESCE(LEFT(LISTAGG(IFF(COALESCE("notify_users", '') = '', "name", NULL), ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '05' ORDER BY check_id;
