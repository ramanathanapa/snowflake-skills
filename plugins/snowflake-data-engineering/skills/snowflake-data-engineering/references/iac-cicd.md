# Infrastructure as code, migrations and CI/CD

> Read when: setting up Terraform, organizing migrations, creating environments, building a CI/CD pipeline, or recovering from a bad deploy.

## Division of labour
| Tool | Owns |
|---|---|
| Terraform (`snowflakedb/snowflake` provider) | What exists and who can touch it: warehouses, resource monitors, databases, schemas, roles, users, grants, network policies, integrations |
| SQL migrations (schemachange, Snowflake CLI, dbt, or a runner with history) | What is inside: tables, views, stages, file formats, pipes, tasks, Dynamic Tables, semantic views |
| Deploy script / Snowflake CLI | Apps (Streamlit), uploaded files, semantic model files |
Rule: anything owned by code is never changed in the console. Drift is a bug.

## Terraform
```hcl
terraform {
  required_providers {
    snowflake = { source = "snowflakedb/snowflake", version = "2.x.y" }   # pin exactly once it works
  }
}
provider "snowflake" {
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.user
  role              = var.role                # a dedicated Terraform role, not ACCOUNTADMIN after bootstrap
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.private_key_path)
}
```
- **Pin the provider** and commit `.terraform.lock.hcl`. Major versions of the Snowflake provider have renamed and removed resources; read the migration guide before upgrading.
- Some resources are **preview** and must be enabled explicitly in the provider (verify the current mechanism). Prefer stable resources; manage the rest with SQL migrations.
- **Plan, read, apply**: in CI use `terraform plan -out=tfplan` on the pull request and `terraform apply tfplan` after approval, so what is applied is what was reviewed.
- Anything marked `destroy` or `must be replaced` needs explicit human approval.
- **State** maps code to real objects and can contain sensitive values. Use a remote backend with locking (S3 + lock, Azure Storage, GCS, Terraform Cloud). If local, back it up and never commit it.
- Existing objects: bring them under management with `import` blocks or `terraform import` rather than recreating them.
- Bootstrap with an admin role once; then create a Terraform role with only the privileges it needs (for example `CREATE DATABASE`, `CREATE WAREHOUSE`, `CREATE ROLE`, `MANAGE GRANTS`) and switch to it.
- Use `for_each` for repeated objects (schemas, grants per role) and keep variables few.

## Migrations
- Versioned files: `V001__create_raw.sql`, `V002__curated_views.sql`. Repeatable files (`R__views.sql`) for objects safe to recreate on every change.
- Use a runner that records **change history with checksums** (schemachange, dbt, Snowflake CLI with a history table, or similar). A script that reruns everything is acceptable only for objects that are all idempotent, and it gives no history.
- Idempotent DDL: `CREATE ... IF NOT EXISTS`, `CREATE OR REPLACE VIEW`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
- Never `CREATE OR REPLACE` a table that holds data in a migration. Never edit an applied versioned migration that changed data; add a new one.
- Template environment names (`{{ database }}`) instead of hardcoding them.
- Generate wide raw DDL from real source headers rather than typing it.

## Snowflake CLI and Git integration (verify current commands)
- Snowflake CLI (`snow`) shares connection definitions (`~/.snowflake/connections.toml`) with the Python connector: `snow connection test`, `snow sql -f file.sql`, `snow stage copy`, `snow streamlit deploy`.
- A Git repository object in Snowflake can mirror a repo; `EXECUTE IMMEDIATE FROM @repo/branches/main/path/script.sql` runs files from it.

## Environments
| Pattern | Notes |
|---|---|
| Database per environment in one account | Simple; separate with roles; easy cloning |
| Account per environment | Strong isolation; more administration |
| Zero-copy clone per pull request | Test migrations and transformations on real-shaped data, drop afterwards |
Parameterize database, warehouse and role names; promote the same code through environments.

## CI/CD pipeline
**On pull request**
1. Format and validate: `terraform fmt -check`, `terraform validate`, SQL lint (for example sqlfluff), Python lint and unit tests.
2. `terraform plan -out=tfplan` with read-only credentials; publish the plan for review.
3. Clone the target database, run migrations on the clone, run data tests, drop the clone.
4. Secret scanning and dependency checks.

**On merge to main**
1. `terraform apply tfplan` (approval gate for anything beyond additions).
2. Apply migrations through the runner.
3. Post-deploy checks: counts, smoke queries, an AI question battery if there is an AI layer.
4. Deploy apps; open them as a reader role.

**Credentials in CI**: store the private key and passphrase in the CI secret store, write them to a temp file at runtime, never echo them. Prefer short-lived credentials or workload identity federation where supported (verify).

## Reusable repository layout
```
infra/terraform/      providers, roles, warehouses, monitors, grants
sql/migrations/       V###__*.sql, R__*.sql
sql/explore/          read-only learning and investigation queries
ingest/               loaders and connector configs
app/                  Streamlit apps, semantic models
lib/                  shared helpers (one connect(), config loading)
scripts/              bootstrap, migrate, deploy
tests/                data and app checks
docs/                 guides, runbooks
requirements.txt      pinned Python dependencies
.github/workflows/    or another CI system
```

## Rollback and recovery
- Infrastructure: revert the commit, plan, apply; destructive steps need approval.
- Data: time travel (`AT`/`BEFORE`), `UNDROP`, and a clone taken before risky changes.
- Runbook: where state lives, how to restore, who approves, how to rotate keys.

## Checklist
- [ ] All infrastructure in Terraform; no console drift; provider pinned; lock file committed.
- [ ] State remote with locking, or backed up and git-ignored.
- [ ] Terraform runs as a dedicated least-privilege role.
- [ ] Migrations tracked with history and checksums.
- [ ] CI: plan on PR, migrations and tests on a clone, apply after approval.
- [ ] Secrets only in a secret store; dependencies pinned.
- [ ] Rollback path documented.
