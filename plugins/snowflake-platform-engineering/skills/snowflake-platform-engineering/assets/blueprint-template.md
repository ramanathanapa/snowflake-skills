# Platform blueprint: <organization>

Status: draft | approved on <date> by <name>. Changes to decisions need the approver's sign-off.

## Decisions
| # | Decision | Value | Why |
|---|---|---|---|
| 1 | Compliance and data residency | <none / regulation; allowed regions> | |
| 2 | Identity provider and provisioning | <Okta / Entra ID / other>; SCIM <yes/no> | |
| 3 | Account topology | <one account, databases per environment / account per environment / per business unit> | |
| 4 | Environments | <dev, test, prod> | |
| 5 | Edition and region per account | <account: edition, cloud, region> | |
| 6 | Budget and chargeback | <monthly credits or currency cap>; chargeback by <team tag / warehouse> | |
| 7 | Recovery objectives | RPO <hours>, RTO <hours>; replication <yes/no> | |
| 8 | Approvers | production changes: <name/role>; access requests: <name/role> | |

## Standards (defaults unless changed above)
- Naming: databases `<DOMAIN>_<ENV>`, schemas `RAW`/`CURATED`/`ANALYTICS`/`APP`, warehouses `<TEAM>_<WORKLOAD>_WH`, access roles `<DB>_<SCHEMA>_<READ|WRITE>`, functional roles `<TEAM>_<ENGINEER|ANALYST|READER>`, service users `SVC_<SYSTEM>`.
- Warehouses: `XSMALL` first, `AUTO_SUSPEND = 60`, statement timeout 3600 s, one resource monitor each, `cost_center` tag.
- Access: users get functional roles only; custom roles roll up to `SYSADMIN`; future grants; managed access schemas for curated and serving layers.
- Authentication: SSO for people with MFA; key-pair or OAuth for services; no passwords for services.
- Infrastructure as code: Terraform for account objects; SQL migrations for database objects.

## Accounts
| Account | Purpose | Edition | Cloud / region | Admins (2-5) |
|---|---|---|---|---|

## Teams onboarded
| Team | Environments | Databases | Warehouses | Monthly budget | Owner |
|---|---|---|---|---|---|

## Progress
| Phase | Status | Last check | Open items |
|---|---|---|---|
| 1 Organization and accounts | not started | | |
| 2 Identity | not started | | |
| 3 Security baseline | not started | | |
| 4 Access model | not started | | |
| 5 Compute and cost | not started | | |
| 6 Data foundations | not started | | |
| 7 Delivery | not started | | |
| 8 Observability | not started | | |
| 9 Governance | not started | | |
| 10 Resilience | not started | | |
| 11 Golden path | not started | | |

## Change log
| Date | Change | Approved by |
|---|---|---|
