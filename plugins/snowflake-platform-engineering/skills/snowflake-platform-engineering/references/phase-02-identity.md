# Phase 2: Identity

> Read when: setting up SSO, SCIM provisioning, MFA, service users, key rotation or break-glass access, or reviewing who can log in and how. Prerequisites: phase 1.

## Blueprint inputs
Identity provider and provisioning (2), Accounts table, approvers (8).

## Target state
| Who | How they authenticate | How they are created |
|---|---|---|
| People | SSO through the IdP (SAML2), MFA enforced by the IdP or Snowflake | SCIM from IdP groups; no manual users |
| Services (pipelines, CI, apps) | Key-pair or OAuth; `TYPE = SERVICE`; no password | Terraform |
| Break-glass | A local admin with MFA, stored credentials under dual control | Documented, tested twice a year |

## Build
1. **SSO** (verify parameters for your IdP):
   ```sql
   CREATE SECURITY INTEGRATION idp_sso TYPE = SAML2 ENABLED = TRUE
     SAML2_ISSUER = '<issuer>' SAML2_SSO_URL = '<sso url>' SAML2_PROVIDER = '<OKTA|ADFS|CUSTOM>'
     SAML2_X509_CERT = '<certificate>' SAML2_SNOWFLAKE_ACS_URL = '<account url>/fed/login';
   ```
2. **SCIM provisioning** (Okta shown; Entra ID uses `SCIM_CLIENT = 'AZURE'`; verify):
   ```sql
   CREATE ROLE okta_provisioner;
   GRANT CREATE USER ON ACCOUNT TO ROLE okta_provisioner;
   GRANT CREATE ROLE ON ACCOUNT TO ROLE okta_provisioner;
   GRANT ROLE okta_provisioner TO ROLE accountadmin;
   CREATE SECURITY INTEGRATION okta_scim TYPE = SCIM SCIM_CLIENT = 'OKTA' RUN_AS_ROLE = 'OKTA_PROVISIONER';
   SELECT SYSTEM$GENERATE_SCIM_ACCESS_TOKEN('OKTA_SCIM');   -- the user pastes this into the IdP; never into chat
   ```
   Map IdP groups to functional roles (phase 4), not to admin roles.
3. **Service users**, one per system, in Terraform:
   ```sql
   CREATE USER svc_loader TYPE = SERVICE DEFAULT_ROLE = loader DEFAULT_WAREHOUSE = load_wh
     RSA_PUBLIC_KEY = '<public key body>' COMMENT = 'Owner: data platform';
   ```
   Rotate keys with `RSA_PUBLIC_KEY_2`: add the new key, switch the client, remove the old key.
4. **MFA and allowed methods**: enforce through the IdP and an authentication policy (phase 3).
5. **Defaults**: no user has `ACCOUNTADMIN`, `SECURITYADMIN` or `ORGADMIN` as default role.
6. **Lifecycle**: disable users who have not logged in for 90 days unless they are service users with documented use.

## Checklist
- [ ] P02-01 No service user has a password (automated: `checks/02-identity.sql`)
- [ ] P02-02 Every service user has a key-pair (or uses OAuth) (automated)
- [ ] P02-03 People authenticate through SSO, not passwords (automated, WARN lists password users)
- [ ] P02-04 No user has an admin role as default role (automated)
- [ ] P02-05 No dormant users (no login in 90 days) remain enabled (automated)
- [ ] P02-06 An SSO integration exists and is enabled (automated)
- [ ] P02-07 SCIM provisioning maps IdP groups to functional roles; MFA enforced for people; break-glass documented and tested (manual)
- [ ] P02-08 Every person who still has a password has MFA (automated: `checks/02-identity.sql`)
- [ ] P02-09 Every `ACCOUNTADMIN` holder has a verified email, so monitor and alert notifications reach them (automated)
- [ ] P02-10 No user has an active MFA bypass (automated)

## Exit criteria
People log in through SSO with MFA, are created by SCIM, services use keys, and break-glass is documented and tested.
