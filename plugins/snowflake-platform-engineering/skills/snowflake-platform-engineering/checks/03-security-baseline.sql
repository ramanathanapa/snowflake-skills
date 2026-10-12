-- Phase 03 (Security baseline) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '03';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-01', '2-5 ACCOUNTADMIN holders', IFF(COUNT(DISTINCT grantee_name) BETWEEN 2 AND 5, 'PASS', 'FAIL'), COUNT(DISTINCT grantee_name) || ' holders: ' || LEFT(LISTAGG(DISTINCT grantee_name, ', '), 500)
FROM snowflake.account_usage.grants_to_users WHERE role = 'ACCOUNTADMIN' AND deleted_on IS NULL;

SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-02', 'Account network policy is set', IFF(COALESCE(MAX("value"), '') = '', 'FAIL', 'PASS'), COALESCE(COALESCE(NULLIF(MAX("value"), ''), 'no account network policy'), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-03', 'PUBLIC holds no privileges granted by account roles', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' grants: ' || COALESCE(LEFT(LISTAGG(privilege || ' on ' || granted_on || ' ' || name, ', '), 500), '')
FROM snowflake.account_usage.grants_to_roles WHERE grantee_name = 'PUBLIC' AND deleted_on IS NULL AND granted_on <> 'ROLE' AND COALESCE(granted_by, 'SNOWFLAKE') <> 'SNOWFLAKE';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-04', 'Account password policy attached', IFF(COUNT(*) > 0, 'PASS', 'FAIL'), COALESCE(MAX(policy_name), 'none')
FROM snowflake.account_usage.policy_references WHERE policy_kind = 'PASSWORD_POLICY' AND ref_entity_domain = 'ACCOUNT';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-05', 'Account session policy attached', IFF(COUNT(*) > 0, 'PASS', 'FAIL'), COALESCE(MAX(policy_name), 'none')
FROM snowflake.account_usage.policy_references WHERE policy_kind = 'SESSION_POLICY' AND ref_entity_domain = 'ACCOUNT';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-06', 'Account authentication policy attached', IFF(COUNT(*) > 0, 'PASS', 'FAIL'), COALESCE(MAX(policy_name), 'none')
FROM snowflake.account_usage.policy_references WHERE policy_kind = 'AUTHENTICATION_POLICY' AND ref_entity_domain = 'ACCOUNT';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-07', 'Failed logins, last 7 days', 'INFO', COUNT(*) || ' failed logins by ' || COUNT(DISTINCT user_name) || ' users'
FROM snowflake.account_usage.login_history WHERE is_success = 'NO' AND event_timestamp >= DATEADD(day, -7, CURRENT_TIMESTAMP());

SHOW PARAMETERS LIKE 'REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-09', 'Stage creation requires a storage integration', IFF(MAX("value") = 'true', 'PASS', 'WARN'), COALESCE('value: ' || MAX("value"), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW PARAMETERS LIKE 'REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-10', 'Stage operations require a storage integration', IFF(MAX("value") = 'true', 'PASS', 'WARN'), COALESCE('value: ' || MAX("value"), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW PARAMETERS LIKE 'PREVENT_UNLOAD_TO_INLINE_URL' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-11', 'Unloads to inline URLs are prevented', IFF(MAX("value") = 'true', 'PASS', 'WARN'), COALESCE('value: ' || MAX("value"), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW PARAMETERS LIKE '%PRIVILEGED_ROLES_TO_BLOCKED_LIST' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-12', 'Admin roles are blocked for OAuth', IFF(COUNT(*) > 0 AND COUNT_IF("value" = 'true') = COUNT(*), 'PASS', 'FAIL'), COALESCE(LISTAGG("key" || ' = ' || "value", ', '), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-13', 'ACCOUNTADMIN is not granted to any role', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' roles hold ACCOUNTADMIN: ' || COALESCE(LEFT(LISTAGG(grantee_name, ', '), 500), '')
FROM snowflake.account_usage.grants_to_roles WHERE granted_on = 'ROLE' AND name = 'ACCOUNTADMIN' AND privilege = 'USAGE' AND deleted_on IS NULL;

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-14', 'No open critical or high Trust Center findings', IFF(COUNT_IF(severity IN ('CRITICAL', 'HIGH')) > 0, 'FAIL', IFF(COUNT(*) > 0, 'WARN', 'PASS')), COUNT(*) || ' open (' || COUNT_IF(severity = 'CRITICAL') || ' critical, ' || COUNT_IF(severity = 'HIGH') || ' high): ' || COALESCE(LEFT(LISTAGG(DISTINCT scanner_name || ' [' || severity || ']', ', '), 500), '')
FROM snowflake.trust_center.findings WHERE state = 'Open';

SHOW PARAMETERS LIKE 'PERIODIC_DATA_REKEYING' IN ACCOUNT;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '03', 'P03-15', 'Periodic data rekeying (regulated data)', 'INFO', COALESCE('value: ' || MAX("value") || ' (enable for regulated data; adds storage cost)', 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '03' ORDER BY check_id;
