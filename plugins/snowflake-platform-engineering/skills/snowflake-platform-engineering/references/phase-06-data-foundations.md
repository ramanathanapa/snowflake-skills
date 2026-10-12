# Phase 6: Data foundations

> Read when: creating the database and schema layout, setting retention, storage and external-access integrations, or reviewing how data is organized. Prerequisites: phase 4.

## Blueprint inputs
Account topology (3), environments (4), naming standards, Teams onboarded.

## Standards
| Item | Standard |
|---|---|
| Databases | One per domain and environment (`<DOMAIN>_<ENV>`), with `COMMENT` and an owner tag |
| Schemas | `RAW`, `CURATED`, `ANALYTICS` (managed access), `APP`; `STAGING` as transient |
| Retention | Time travel: 1 day on raw and staging, 7+ days on curated and serving in production (higher editions, verify); never 0 on permanent production data |
| Cloud storage | Storage integrations per bucket or container; no keys in stages |
| Outbound calls | Network rules + external access integrations allowing named hosts only |
| Shared reference data | One read-only database shared to consumers (secure views), not copies |

## Build
```sql
CREATE DATABASE marketing_prod DATA_RETENTION_TIME_IN_DAYS = 7 COMMENT = 'Marketing domain, production. Owner: marketing';
CREATE SCHEMA marketing_prod.analytics WITH MANAGED ACCESS;
CREATE TRANSIENT SCHEMA marketing_prod.staging DATA_RETENTION_TIME_IN_DAYS = 1;
CREATE STORAGE INTEGRATION s3_marketing TYPE = EXTERNAL_STAGE STORAGE_PROVIDER = 'S3' ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '<role-arn>' STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>/marketing/');
```
Manage databases and schemas in Terraform; tables and views in each team's migrations.

## Checklist
- [ ] P06-01 Every database has a `COMMENT` stating purpose and owner (automated: `checks/06-data-foundations.sql`)
- [ ] P06-02 No permanent database has time travel set to 0 (automated)
- [ ] P06-03 External stages are known and use storage integrations (automated, INFO lists them)
- [ ] P06-04 Naming and layer conventions followed; staging is transient; outbound access limited to named hosts (manual)

## Exit criteria
Every domain and environment has a predictable home with the right retention, and every path to cloud storage or the internet is an integration.
