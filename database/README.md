# SkillSync Database Setup Guide

This document explains how to initialize the SkillSync PostgreSQL database using the SQL files in this folder.

## Files and Purpose

- `migrations/001_schema.sql`: Creates lookup tables, core domain tables, triggers/functions, and grants/revokes.
- `policies/001_rls.sql`: Enables and enforces Row Level Security (RLS), creates tenant-isolation policies, and exposes `resolve_tenant`.
- `seeds/001_dev_data.sql`: Inserts development seed data for organizations, users, profiles, and candidates.

Note: The filename is currently `001_schema.sql` (spelling in repo). Keep using this exact name unless you rename it intentionally everywhere.

## Prerequisites

- PostgreSQL is installed and running.
- A database named `skillsync` exists.
- Roles `skillsync_app` and `skillsync_admin` exist.
- You can connect with your local `psql` client.

## Setup Order

Run scripts in this order:

1. Schema migration
2. RLS policies
3. Seed data

This order is required because:
- Policies depend on tables created by migration.
- Seed data depends on both table definitions and constraints.

## Commands

From project root:

```bash
psql -v ON_ERROR_STOP=1 -d skillsync -f database/migrations/001_schema.sql
psql -v ON_ERROR_STOP=1 -d skillsync -f database/policies/001_rls.sql
psql -v ON_ERROR_STOP=1 -d skillsync -f database/seeds/001_dev_data.sql
```

Single-line equivalent:

```bash
psql -v ON_ERROR_STOP=1 -d skillsync -f database/migrations/001_schema.sql \
&& psql -v ON_ERROR_STOP=1 -d skillsync -f database/policies/001_rls.sql \
&& psql -v ON_ERROR_STOP=1 -d skillsync -f database/seeds/001_dev_data.sql
```

## What Was Executed in This Environment

I verified and used:

- PostgreSQL profile: `DD723899-FC18-40D4-AFC4-D872AA0FC92A`
- Connected DB: `skillsync`
- Required roles found: `skillsync_app`, `skillsync_admin`

I then ran the 3 scripts above in sequence with `ON_ERROR_STOP=1`.

## Post-Setup Validation

### 1) Seed row counts

```sql
SELECT 'organizations' AS table_name, COUNT(*) AS row_count FROM organizations
UNION ALL
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'user_profiles' AS table_name, COUNT(*) AS row_count FROM user_profiles
UNION ALL
SELECT 'candidates' AS table_name, COUNT(*) AS row_count FROM candidates
UNION ALL
SELECT 'platform_admins' AS table_name, COUNT(*) AS row_count FROM platform_admins
ORDER BY table_name;
```

Expected after first successful run:
- organizations: 3
- users: 3
- user_profiles: 3
- candidates: 3
- platform_admins: 1

### 2) RLS policies

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('organizations', 'users', 'user_profiles', 'candidates', 'audit_log')
ORDER BY tablename, policyname;
```

Expected policies:
- `tenant_isolation` on organizations, users, user_profiles, candidates, audit_log
- `root_lookup` on organizations (for role `skillsync_admin`, SELECT)

## Re-run Notes

- `migrations/001_schema.sql` is not idempotent for table creation (re-running may fail with relation already exists).
- `policies/001_rls.sql` is mostly safe to re-run due to `DROP POLICY IF EXISTS`.
- `seeds/001_dev_data.sql` is partially idempotent (`platform_admins` uses `ON CONFLICT`), but most inserts do not, so duplicates/conflicts may happen.

For repeated environment setup, consider adding guards like `CREATE TABLE IF NOT EXISTS` and `ON CONFLICT` where appropriate.
