-- Phase 08 (Observability) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '08';

SHOW ALERTS IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '08', 'P08-01', 'At least one alert is running', IFF(COUNT_IF("state" ILIKE 'started') > 0, 'PASS', 'WARN'), COALESCE(COUNT_IF("state" ILIKE 'started') || ' running of ' || COUNT(*) || ' alerts', 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '08', 'P08-02', 'No failed tasks, last 7 days', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' failed runs ' || COALESCE(LEFT(LISTAGG(DISTINCT name, ', '), 500), '')
FROM snowflake.account_usage.task_history WHERE state = 'FAILED' AND scheduled_time >= DATEADD(day, -7, CURRENT_TIMESTAMP());

SHOW TASKS IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '08', 'P08-03', 'No unexpectedly suspended tasks', IFF(COUNT_IF("state" ILIKE 'suspended') = 0, 'PASS', 'WARN'), COALESCE(COUNT_IF("state" ILIKE 'suspended') || ' of ' || COUNT(*) || ' tasks suspended ' || COALESCE(LEFT(LISTAGG(IFF("state" ILIKE 'suspended', "name", NULL), ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW NOTIFICATION INTEGRATIONS;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '08', 'P08-04', 'A notification integration exists', IFF(COUNT(*) > 0, 'PASS', 'WARN'), COALESCE(COUNT(*) || ' notification integrations', 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW PARAMETERS LIKE 'EVENT_TABLE' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '08', 'P08-06', 'An event table is configured for logs and traces', IFF(COALESCE(MAX("value"), '') <> '', 'PASS', 'WARN'), COALESCE('EVENT_TABLE = ' || COALESCE(NULLIF(MAX("value"), ''), 'none'), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '08' ORDER BY check_id;
