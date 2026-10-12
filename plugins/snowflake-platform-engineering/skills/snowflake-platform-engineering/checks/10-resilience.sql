-- Phase 10 (Resilience) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '10';

SHOW REPLICATION GROUPS;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '10', 'P10-01', 'Replication and failover groups', 'INFO', COALESCE(COUNT(*) || ' groups ' || COALESCE(LEFT(LISTAGG("name" || ' (' || "type" || ')', ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '10', 'P10-02', 'Time travel retention per database', 'INFO', COALESCE(LEFT(LISTAGG(database_name || ' ' || retention_time || 'd', ', '), 500), 'no databases')
FROM snowflake.account_usage.databases WHERE deleted IS NULL AND database_name NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND database_name NOT LIKE 'USER$%';

SHOW PARAMETERS LIKE 'MIN_DATA_RETENTION_TIME_IN_DAYS' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '10', 'P10-04', 'Minimum time travel enforced account-wide', IFF(TRY_TO_NUMBER(MAX("value")) >= 1, 'PASS', 'WARN'), COALESCE('MIN_DATA_RETENTION_TIME_IN_DAYS = ' || MAX("value"), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '10' ORDER BY check_id;
