-- Phase 01 (Organization and accounts) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '01';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '01', 'P01-01', 'Account identity and region', 'INFO', CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME() || ' in ' || CURRENT_REGION();

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '01', 'P01-02', 'Databases in this account', 'INFO', COUNT(*) || ' databases: ' || LEFT(LISTAGG(database_name, ', '), 500)
FROM snowflake.account_usage.databases WHERE deleted IS NULL AND database_name NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND database_name NOT LIKE 'USER$%';

SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '01', 'P01-06', 'Account time zone set explicitly', IFF(MAX("level") = 'ACCOUNT', 'PASS', 'WARN'), COALESCE('TIMEZONE = ' || MAX("value") || IFF(MAX("level") = 'ACCOUNT', ' (set)', ' (default; set UTC or your standard)'), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '01' ORDER BY check_id;
