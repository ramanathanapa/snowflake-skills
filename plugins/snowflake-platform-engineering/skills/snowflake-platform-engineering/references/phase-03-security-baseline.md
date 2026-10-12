# Phase 3: Security baseline

> Read when: hardening an account, setting network, authentication, password or session policies, locking down `PUBLIC` and admin roles, or creating the auditor role. Prerequisites: phase 2.

## Blueprint inputs
Compliance (1), Accounts table (admins), approvers (8).

## Auditor role (create first; use it for every check)
```sql
CREATE ROLE platform_auditor COMMENT = 'Read-only platform checks';
GRANT IMPORTED PRIVILEGES ON DATABASE snowflake TO ROLE platform_auditor;   -- ACCOUNT_USAGE views
GRANT MONITOR ON WAREHOUSE <each warehouse> TO ROLE platform_auditor;      -- SHOW WAREHOUSES visibility (Terraform for_each)
GRANT USAGE ON WAREHOUSE <ops_wh> TO ROLE platform_auditor;
GRANT ROLE platform_auditor TO ROLE sysadmin;
```
Checks only see objects this role can see; report gaps under "Not checked" (verify additional grants for tasks, alerts and integrations visibility).

## Build (apply each policy to a test user first; keep break-glass excluded until verified)
1. **Admins**: 2-5 `ACCOUNTADMIN` holders, all named people with MFA, none as default role, never service users.
2. **Network**:
   ```sql
   CREATE NETWORK RULE security.rules.corp_ingress MODE = INGRESS TYPE = IPV4 VALUE_LIST = ('203.0.113.0/24');
   CREATE NETWORK POLICY corp_only ALLOWED_NETWORK_RULE_LIST = ('security.rules.corp_ingress');
   ALTER USER <test_user> SET NETWORK_POLICY = corp_only;   -- then the account, after testing
   ALTER ACCOUNT SET NETWORK_POLICY = corp_only;
   ```
   Give service users their own narrower policy (CI runner and integration IPs).
3. **Authentication policy**: allowed methods and MFA (verify options):
   ```sql
   CREATE AUTHENTICATION POLICY security.policies.people_auth
     AUTHENTICATION_METHODS = ('SAML', 'KEYPAIR') MFA_ENROLLMENT = REQUIRED;
   ALTER ACCOUNT SET AUTHENTICATION POLICY security.policies.people_auth;
   ```
4. **Password policy** (for the few password users that remain) and **session policy**:
   ```sql
   CREATE PASSWORD POLICY security.policies.pw PASSWORD_MIN_LENGTH = 14 PASSWORD_MAX_AGE_DAYS = 90 PASSWORD_MAX_RETRIES = 5;
   CREATE SESSION POLICY security.policies.sess SESSION_IDLE_TIMEOUT_MINS = 240 SESSION_UI_IDLE_TIMEOUT_MINS = 60;
   ALTER ACCOUNT SET PASSWORD POLICY security.policies.pw;
   ALTER ACCOUNT SET SESSION POLICY security.policies.sess;
   ```
5. **`PUBLIC`**: revoke everything except what Snowflake grants by default; grant to reader roles instead.
6. **Data exfiltration guards** (verify parameter names and effects): require storage integrations for stage creation and operations; prevent unloads to inline URLs.
7. **Trust Center**: enable scanners and review findings monthly (verify availability).

## Checklist
- [ ] P03-01 2-5 `ACCOUNTADMIN` holders (automated: `checks/03-security-baseline.sql`)
- [ ] P03-02 An account network policy is set (automated)
- [ ] P03-03 `PUBLIC` holds no privileges granted by account roles; Snowflake-managed defaults are ignored (automated, WARN lists grants to review)
- [ ] P03-04 A password policy is attached at account level (automated)
- [ ] P03-05 A session policy is attached at account level (automated)
- [ ] P03-06 An authentication policy is attached at account level (automated)
- [ ] P03-07 Failed logins in the last 7 days reviewed (automated, INFO)
- [ ] P03-08 Trust Center scanners enabled and reviewed monthly; checks run with the auditor role (manual)
- [ ] P03-09 Stage creation requires a storage integration (automated: `checks/03-security-baseline.sql`)
- [ ] P03-10 Stage operations require a storage integration (automated)
- [ ] P03-11 Unloads to inline URLs are prevented (automated)
- [ ] P03-12 Admin roles are blocked for OAuth and external OAuth (automated)
- [ ] P03-13 `ACCOUNTADMIN` is not granted to any other role (automated)
- [ ] P03-14 No open critical or high Trust Center findings (automated; needs Trust Center access)
- [ ] P03-15 Periodic data rekeying decided for regulated data (automated, INFO)

## Exit criteria
Only allowed networks and methods can reach the account, admins are few and protected, `PUBLIC` is empty, and checks run with the auditor role.
