# Phase 9: Governance at scale

> Read when: defining tags, classifying sensitive data, applying masking or row policies across the platform, governing sharing, or producing audit evidence. Prerequisites: phases 4 and 6.

## Blueprint inputs
Compliance (1), approvers (8), Teams onboarded.

## Standards
| Item | Standard |
|---|---|
| Tags | A small central set in a `GOVERNANCE` database: `cost_center`, `owner`, `data_classification` (`public`/`internal`/`confidential`/`restricted`), `pii_type` |
| Classification | Run automated classification on new curated data and confirm results with owners (verify edition and syntax) |
| Protection | Tag-based masking: one policy per data type, attached to the tag, so new columns are protected when tagged |
| Rows | Row access policies with a mapping table for tenant or region separation |
| Sharing | Only secure views over curated data; each share approved and listed in the blueprint |
| Evidence | `ACCESS_HISTORY` and grants exports for audits (higher editions) |

## Build
```sql
CREATE DATABASE governance; CREATE SCHEMA governance.tags; CREATE SCHEMA governance.policies;
CREATE TAG governance.tags.pii_type ALLOWED_VALUES 'email', 'phone', 'name', 'address', 'national_id';
CREATE MASKING POLICY governance.policies.mask_string AS (val STRING) RETURNS STRING ->
  CASE WHEN IS_ROLE_IN_SESSION('PII_READER') THEN val ELSE '***MASKED***' END;
ALTER TAG governance.tags.pii_type SET MASKING POLICY governance.policies.mask_string;
ALTER TABLE <db>.curated.customer MODIFY COLUMN email SET TAG governance.tags.pii_type = 'email';
```
Test by switching roles; record exceptions in the blueprint.

## Checklist
- [ ] P09-01 Tags are in use on objects (automated: `checks/09-governance.sql`)
- [ ] P09-02 Masking policies and where they are applied (automated, INFO)
- [ ] P09-03 Columns with sensitive-looking names have a policy (automated, WARN lists them; a name heuristic, not classification)
- [ ] P09-04 Outbound shares are known (automated, INFO)
- [ ] P09-05 Tag standard published; classification reviewed; every share approved (manual)
- [ ] P09-06 Access history is recorded, for lineage and audit evidence (automated: `checks/09-governance.sql`)
- [ ] P09-07 Cortex cross-region inference matches the data residency decision (automated)
- [ ] P09-08 Row access policies and where they are applied (automated, INFO)

## Exit criteria
Sensitive data is identified and protected by policy, every share is approved, and audit evidence can be produced on request.
