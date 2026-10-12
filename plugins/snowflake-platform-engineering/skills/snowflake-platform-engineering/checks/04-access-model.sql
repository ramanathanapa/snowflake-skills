-- Phase 04 (Access model) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '04';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '04', 'P04-01', 'No database owned by ACCOUNTADMIN', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' databases: ' || COALESCE(LEFT(LISTAGG(database_name, ', '), 500), '')
FROM snowflake.account_usage.databases WHERE deleted IS NULL AND database_owner = 'ACCOUNTADMIN' AND database_name NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND database_name NOT LIKE 'USER$%';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '04', 'P04-02', 'No orphan custom roles', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' roles not granted to any role: ' || COALESCE(LEFT(LISTAGG(r.name, ', '), 500), '')
FROM snowflake.account_usage.roles r WHERE r.deleted_on IS NULL AND r.role_type = 'ROLE' AND r.name NOT IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'USERADMIN', 'SYSADMIN', 'ORGADMIN', 'PUBLIC')
  AND NOT EXISTS (SELECT 1 FROM snowflake.account_usage.grants_to_roles g WHERE g.granted_on = 'ROLE' AND g.privilege = 'USAGE' AND g.name = r.name AND g.deleted_on IS NULL);

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '04', 'P04-03', 'No admin role granted to a service user', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' grants: ' || COALESCE(LEFT(LISTAGG(gu.grantee_name || ' -> ' || gu.role, ', '), 500), '')
FROM snowflake.account_usage.grants_to_users gu JOIN snowflake.account_usage.users u ON u.name = gu.grantee_name AND u.deleted_on IS NULL
  WHERE gu.deleted_on IS NULL AND gu.role IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'ORGADMIN') AND u.type IN ('SERVICE', 'LEGACY_SERVICE');

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '04', 'P04-04', 'Schemas with managed access', 'INFO', COUNT_IF(is_managed_access = 'YES') || ' of ' || COUNT(*) || ' schemas use managed access'
FROM snowflake.account_usage.schemata WHERE deleted IS NULL AND schema_name <> 'INFORMATION_SCHEMA' AND catalog_name NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA') AND catalog_name NOT LIKE 'USER$%';

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '04' ORDER BY check_id;
