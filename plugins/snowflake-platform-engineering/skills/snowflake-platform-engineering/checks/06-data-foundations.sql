-- Phase 06 (Data foundations) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '06';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '06', 'P06-01', 'Every database has a COMMENT', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' without comment: ' || COALESCE(LEFT(LISTAGG(database_name, ', '), 500), '')
FROM snowflake.account_usage.databases WHERE deleted IS NULL AND COALESCE(comment, '') = '' AND database_name NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND database_name NOT LIKE 'USER$%';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '06', 'P06-02', 'No permanent database has time travel 0', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' databases: ' || COALESCE(LEFT(LISTAGG(database_name, ', '), 500), '')
FROM snowflake.account_usage.databases WHERE deleted IS NULL AND retention_time = 0 AND is_transient = 'NO' AND database_name NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND database_name NOT LIKE 'USER$%';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '06', 'P06-03', 'External stages', 'INFO', COUNT(*) || ' external stages ' || COALESCE(LEFT(LISTAGG(stage_catalog || '.' || stage_schema || '.' || stage_name, ', '), 500), '')
FROM snowflake.account_usage.stages WHERE deleted IS NULL AND stage_type ILIKE 'External%';

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '06' ORDER BY check_id;
