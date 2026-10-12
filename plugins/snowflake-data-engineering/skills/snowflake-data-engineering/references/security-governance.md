# Security, roles and governance

> Read when: designing roles, granting access, setting up authentication, protecting sensitive data, sharing data, or fixing permission errors.

## System roles
| Role | Use |
|---|---|
| `ORGADMIN` | Organization: accounts, org-level usage |
| `ACCOUNTADMIN` | Break-glass and bootstrap only. Few holders, MFA required, never a default role, never for automation |
| `SECURITYADMIN` | Manage grants (`MANAGE GRANTS`) and roles |
| `USERADMIN` | Create users and roles |
| `SYSADMIN` | Conventional owner of databases and warehouses; custom roles should roll up to it |
| `PUBLIC` | Granted to everyone. Never grant anything sensitive to it |

## Role design
1. **Access roles** hold privileges on objects, one per scope and level: `SALES_RAW_WRITE`, `SALES_ANALYTICS_READ`.
2. **Functional roles** represent jobs (`DATA_ENGINEER`, `ANALYST`, `APP_SERVICE`) and are granted access roles.
3. **Users** receive functional roles, never direct object privileges.
4. Grant functional roles to `SYSADMIN` so administrators can manage what they own.
5. **Database roles** package privileges inside a database and can be granted to account roles or shares (verify specifics).
Small projects can start with two roles: an engineer role that owns objects and a reader role that reads only the serving layer.

## Granting
```sql
GRANT USAGE ON DATABASE sales TO ROLE sales_analytics_read;
GRANT USAGE ON SCHEMA sales.analytics TO ROLE sales_analytics_read;
GRANT SELECT ON ALL VIEWS    IN SCHEMA sales.analytics TO ROLE sales_analytics_read;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA sales.analytics TO ROLE sales_analytics_read;
GRANT USAGE ON WAREHOUSE bi_wh TO ROLE sales_analytics_read;
```
- Access requires the whole chain: `USAGE` on database, schema and warehouse, plus the object privilege.
- **Future grants** keep new and replaced objects accessible; `CREATE OR REPLACE` drops an object's grants otherwise (or use `COPY GRANTS`).
- **Managed access schemas** (`CREATE SCHEMA ... WITH MANAGED ACCESS`) let only the schema owner or `MANAGE GRANTS` holders grant on objects.
- **Ownership transfer**: `GRANT OWNERSHIP ON ... TO ROLE x COPY CURRENT GRANTS;`
- **Owner's rights**: views, secure views, procedures (by default) and Streamlit apps run with the owner role's privileges. Expose a curated surface through them instead of granting base tables.
- `USE SECONDARY ROLES ALL` lets a session use privileges from all granted roles; know it is on when debugging access.

## Authentication
| Who | Method |
|---|---|
| People | SSO (SAML/OAuth) or password with MFA. Snowflake is phasing out single-factor password sign-in (verify timeline) |
| Services, pipelines, CI | Key-pair (`TYPE = SERVICE` users), OAuth, or programmatic access tokens (verify) |
- Create automation users as service users with a key and one least-privilege default role:
  ```sql
  CREATE USER svc_loader TYPE = SERVICE DEFAULT_ROLE = loader DEFAULT_WAREHOUSE = load_wh RSA_PUBLIC_KEY = '<public key body>';
  ```
- Rotate keys with the second slot: set `RSA_PUBLIC_KEY_2`, switch clients, then unset the old key.
- Encrypt private keys with a passphrase; keep them out of repositories, chat, tickets and CI logs.
- Authentication, password and session policies enforce MFA, allowed methods and session timeouts (verify options).

## Network
- **Network policies / rules** restrict client IPs for the account or specific users. Apply at least to service users.
- Private connectivity for regulated workloads (Business Critical, verify).
- Outbound access from Snowflake requires network rules plus an external access integration; allow only the hosts needed.

## Sensitive data
| Control | Purpose |
|---|---|
| Masking policy | Return a masked value unless the role is allowed |
| Row access policy | Filter rows per role or attribute |
| Tags + tag-based masking | Classify once (`PII = 'email'`), protect everywhere the tag is applied |
| Classification | Detect likely sensitive columns automatically (verify edition) |
| Aggregation / projection policies | Limit how data can be queried (verify) |
| Secure views | Hide definitions and prevent optimizer-based inference; required for sharing views |
| Exclusion | Simplest control: do not expose the column in the serving layer |
```sql
CREATE MASKING POLICY gov.mask_email AS (val STRING) RETURNS STRING ->
  CASE WHEN IS_ROLE_IN_SESSION('PII_READER') THEN val ELSE REGEXP_REPLACE(val, '.+@', '***@') END;
ALTER TABLE curated.dim_customer MODIFY COLUMN email SET MASKING POLICY gov.mask_email;
```
Test policies by switching roles (`USE ROLE ...`) and comparing results.

## Sharing and Marketplace
- Shares are zero-copy and read-only for consumers. Share secure views over curated data, never raw tables.
- Consumers of shared or Marketplace data build views on top; they cannot change the source.
- Read the provider's terms: free datasets often restrict commercial or derivative use.

## Audit
```sql
SHOW GRANTS OF ROLE accountadmin;                          -- who holds it
SHOW GRANTS TO ROLE public;                                -- should be close to empty
SELECT name, default_role, has_password, has_rsa_public_key, type, disabled, last_success_login
FROM snowflake.account_usage.users WHERE deleted_on IS NULL; -- column set varies by release (verify)
SELECT user_name, is_success, error_message, event_timestamp
FROM snowflake.account_usage.login_history WHERE event_timestamp >= DATEADD(day, -7, CURRENT_TIMESTAMP()) AND is_success = 'NO';
```
- `ACCESS_HISTORY` (Enterprise) records which columns each query read and wrote: use it for lineage and investigations.
- The Trust Center scans the account against security benchmarks (verify availability).

## Application security
- Never build SQL by concatenating untrusted input. Use bind variables, `IDENTIFIER(?)`, or strict allow-lists.
- Apps run as their owner: give the owner role only what the app needs, ideally read-only on serving views.
- **LLM-generated SQL** (for example from Cortex Analyst) must run under a read-only role and pass a guard: a single `SELECT`/`WITH` statement, no DDL/DML, row limit.

## Governance habits
- `COMMENT` on serving objects and important columns; record owners with tags.
- Document lineage (source -> layers -> consumers) and freshness semantics in the README.
- Set `DATA_RETENTION_TIME_IN_DAYS` deliberately: longer on curated data, short on scratch.

## Security checklist
- [ ] No secrets in code, history or logs; `.gitignore` covers keys, state, `.env`, local data.
- [ ] Automation uses service users with key-pair or OAuth and a least-privilege role.
- [ ] Few `ACCOUNTADMIN` holders, all with MFA; it is nobody's default role.
- [ ] Readers see only the serving layer; `PUBLIC` holds nothing sensitive.
- [ ] Sensitive columns masked, row-filtered, excluded or classified.
- [ ] Network policy on service users; outbound access limited to named hosts.
- [ ] All grants defined in code, with future grants.
