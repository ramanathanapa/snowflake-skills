-- Phase 02 (Identity) readiness checks: snowflake-platform-engineering skill.
-- Read-only on account objects; writes only to a session TEMPORARY table (platform_checks).
-- Run as a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example PLATFORM_AUDITOR, see phase 3),
-- with a running warehouse and a current schema where you may create a temporary table:
--   USE ROLE platform_auditor; USE WAREHOUSE <wh>; USE SCHEMA <db>.<schema>;
-- Results cover only objects the role can see. ACCOUNT_USAGE views can lag by up to ~2 hours.
-- Status: PASS | FAIL | WARN | INFO. Check IDs match the phase reference checklist.
CREATE TEMPORARY TABLE IF NOT EXISTS platform_checks (phase STRING, check_id STRING, check_name STRING, status STRING, detail STRING, checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
DELETE FROM platform_checks WHERE phase = '02';

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-01', 'No service user has a password', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' service users with a password ' || COALESCE(LEFT(LISTAGG(name, ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND type IN ('SERVICE', 'LEGACY_SERVICE') AND has_password;

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-02', 'Every service user has a key-pair', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' service users without a key (OAuth-only users also appear) ' || COALESCE(LEFT(LISTAGG(name, ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND type IN ('SERVICE', 'LEGACY_SERVICE') AND NOT has_rsa_public_key AND COALESCE(TRY_TO_BOOLEAN(TO_VARCHAR(disabled)), FALSE) = FALSE;

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-03', 'People use SSO, not passwords', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' enabled people with a password ' || COALESCE(LEFT(LISTAGG(name, ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND COALESCE(type, 'PERSON') = 'PERSON' AND has_password AND COALESCE(TRY_TO_BOOLEAN(TO_VARCHAR(disabled)), FALSE) = FALSE;

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-04', 'No admin role as default role', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' users ' || COALESCE(LEFT(LISTAGG(name || ' (' || default_role || ')', ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND COALESCE(TRY_TO_BOOLEAN(TO_VARCHAR(disabled)), FALSE) = FALSE AND UPPER(default_role) IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'ORGADMIN');

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-05', 'No dormant enabled people (90 days)', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' dormant ' || COALESCE(LEFT(LISTAGG(name, ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND COALESCE(TRY_TO_BOOLEAN(TO_VARCHAR(disabled)), FALSE) = FALSE AND COALESCE(type, 'PERSON') = 'PERSON'
  AND (last_success_login < DATEADD(day, -90, CURRENT_TIMESTAMP()) OR (last_success_login IS NULL AND created_on < DATEADD(day, -30, CURRENT_TIMESTAMP())));

SHOW SECURITY INTEGRATIONS;
INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-06', 'An enabled SSO integration exists', IFF(COUNT_IF("type" ILIKE 'SAML2%' AND TO_VARCHAR("enabled") ILIKE 'true') > 0, 'PASS', 'WARN'), COALESCE(COUNT(*) || ' security integrations ' || COALESCE(LEFT(LISTAGG("name" || ' (' || "type" || ')', ', '), 500), ''), 'none visible to this role')
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-08', 'People with a password have MFA', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' without MFA: ' || COALESCE(LEFT(LISTAGG(name, ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND COALESCE(TRY_TO_BOOLEAN(TO_VARCHAR(disabled)), FALSE) = FALSE AND COALESCE(type, 'PERSON') = 'PERSON' AND has_password AND NOT COALESCE(has_mfa, FALSE);

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-09', 'ACCOUNTADMIN holders have a verified email', IFF(COUNT(*) = 0, 'PASS', 'WARN'), COUNT(*) || ' admins cannot receive notifications: ' || COALESCE(LEFT(LISTAGG(name, ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND name IN (SELECT grantee_name FROM snowflake.account_usage.grants_to_users WHERE role = 'ACCOUNTADMIN' AND deleted_on IS NULL) AND NOT COALESCE(is_email_verified, FALSE);

INSERT INTO platform_checks (phase, check_id, check_name, status, detail)
SELECT '02', 'P02-10', 'No user has an active MFA bypass', IFF(COUNT(*) = 0, 'PASS', 'FAIL'), COUNT(*) || ' bypassing MFA: ' || COALESCE(LEFT(LISTAGG(name, ', '), 500), '')
FROM snowflake.account_usage.users WHERE deleted_on IS NULL AND bypass_mfa_until > CURRENT_TIMESTAMP();

SELECT check_id, check_name, status, detail FROM platform_checks WHERE phase = '02' ORDER BY check_id;
