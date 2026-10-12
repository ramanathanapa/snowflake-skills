-- Phase 07 (Delivery) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '07';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '07', 'P07-01', 'DDL mostly by service users, not people (30 days)', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COALESCE(SUM(n), 0) || ' DDL statements by people: ' || COALESCE(LEFT(LISTAGG(user_name || ' ' || n, ', '), 500), '')
FROM (SELECT q.user_name, COUNT(*) AS n FROM snowflake.account_usage.query_history q JOIN snowflake.account_usage.users u ON u.name = q.user_name AND u.deleted_on IS NULL
  WHERE q.start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP()) AND q.execution_status = 'SUCCESS' AND COALESCE(u.type, 'PERSON') = 'PERSON'
  AND (q.query_type LIKE 'CREATE%' OR q.query_type LIKE 'ALTER%' OR q.query_type LIKE 'DROP%' OR q.query_type IN ('GRANT', 'REVOKE'))
  GROUP BY 1);

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '07', 'P07-02', 'DDL by service users (30 days)', 'INFO', COUNT(*) || ' DDL statements by service users'
FROM snowflake.account_usage.query_history q JOIN snowflake.account_usage.users u ON u.name = q.user_name AND u.deleted_on IS NULL
  WHERE q.start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP()) AND q.execution_status = 'SUCCESS' AND u.type IN ('SERVICE', 'LEGACY_SERVICE')
  AND (q.query_type LIKE 'CREATE%' OR q.query_type LIKE 'ALTER%' OR q.query_type LIKE 'DROP%' OR q.query_type IN ('GRANT', 'REVOKE'));

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '07' ORDER BY check_id;
