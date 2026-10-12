-- Phase 09 (Governance) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '09';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '09', 'P09-01', 'Tags are in use', IFF(COUNT(*) > 0, 'PASS', 'WARN'), COUNT(*) || ' tag assignments, ' || COUNT(DISTINCT tag_name) || ' distinct tags'
FROM snowflake.account_usage.tag_references WHERE object_deleted IS NULL;

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '09', 'P09-02', 'Masking policies and assignments', 'INFO', (SELECT COUNT(*) FROM snowflake.account_usage.masking_policies WHERE deleted IS NULL) || ' masking policies, ' || COUNT(*) || ' column assignments'
FROM snowflake.account_usage.policy_references WHERE policy_kind = 'MASKING_POLICY';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '09', 'P09-03', 'Sensitive-looking columns have a policy', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' unprotected (name heuristic): ' || COALESCE(LEFT(LISTAGG(c.table_catalog || '.' || c.table_schema || '.' || c.table_name || '.' || c.column_name, ', '), 500), '')
FROM snowflake.account_usage.columns c WHERE c.deleted IS NULL AND c.table_schema <> 'INFORMATION_SCHEMA' AND c.table_catalog NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND c.table_catalog NOT LIKE 'USER$%'
  AND c.column_name ILIKE ANY ('%EMAIL%', '%PHONE%', '%SSN%', '%BIRTH%', '%PASSPORT%', '%NATIONAL_ID%', '%TAX_ID%')
  AND NOT EXISTS (SELECT 1 FROM snowflake.account_usage.policy_references p WHERE p.policy_kind = 'MASKING_POLICY' AND p.ref_database_name = c.table_catalog
    AND p.ref_schema_name = c.table_schema AND p.ref_entity_name = c.table_name AND p.ref_column_name = c.column_name);

SHOW SHARES;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '09', 'P09-04', 'Outbound shares', 'INFO', COALESCE(COUNT_IF("kind" = 'OUTBOUND') || ' outbound shares ' || COALESCE(LEFT(LISTAGG(IFF("kind" = 'OUTBOUND', "name", NULL), ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '09', 'P09-06', 'Access history is recorded (audit evidence)', IFF(COUNT(*) > 0, 'PASS', 'WARN'), COUNT(*) || ' access-history rows in the last 7 days'
FROM snowflake.account_usage.access_history WHERE query_start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP());

SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '09', 'P09-07', 'Cortex cross-region inference matches the residency decision', IFF(MAX("value") = 'DISABLED', 'PASS', 'WARN'), COALESCE('CORTEX_ENABLED_CROSS_REGION = ' || MAX("value") || IFF(MAX("value") = 'DISABLED', '', ' (AI requests may be processed outside the account region; confirm against blueprint decision 1)'), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '09', 'P09-08', 'Row access policies and assignments', 'INFO', (SELECT COUNT(*) FROM snowflake.account_usage.row_access_policies WHERE deleted IS NULL) || ' row access policies, ' || COUNT(*) || ' assignments'
FROM snowflake.account_usage.policy_references WHERE policy_kind = 'ROW_ACCESS_POLICY';

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '09' ORDER BY check_id;
