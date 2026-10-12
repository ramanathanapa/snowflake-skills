-- Phase 11 (Golden path) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '11';

SHOW WAREHOUSES;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '11', 'P11-01', 'Every warehouse carries a tag (cost attribution)', IFF(COUNT_IF(t.object_name IS NULL) = 0, 'PASS', 'WARN'), COALESCE(COUNT_IF(t.object_name IS NULL) || ' of ' || COUNT(*) || ' untagged: ' || COALESCE(LEFT(LISTAGG(IFF(t.object_name IS NULL, w."name", NULL), ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) w
LEFT JOIN (SELECT DISTINCT object_name FROM snowflake.account_usage.tag_references WHERE domain = 'WAREHOUSE' AND object_deleted IS NULL) t
  ON t.object_name = w."name"
WHERE w."name" NOT LIKE 'SYSTEM$%';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '11', 'P11-02', 'Every database carries a tag (ownership)', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' untagged: ' || COALESCE(LEFT(LISTAGG(d.database_name, ', '), 500), '')
FROM snowflake.account_usage.databases d WHERE d.deleted IS NULL AND d.database_name NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND database_name NOT LIKE 'USER$%'
  AND NOT EXISTS (SELECT 1 FROM snowflake.account_usage.tag_references t WHERE t.domain = 'DATABASE' AND t.object_name = d.database_name AND t.object_deleted IS NULL);

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '11' ORDER BY check_id;
