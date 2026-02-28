# Running Supabase Migrations

## Migration: `20260227000003_add_data_retention.sql`

Adds `data_retention_days` column to `merchants` table.

### Option 1: Supabase Dashboard (SQL Editor)

1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/mvddmzjepcwxfkuggmzm/sql/new) → SQL Editor
2. Run:

```sql
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS data_retention_days INTEGER DEFAULT 0;
```

### Option 2: Supabase CLI (with linked project)

```bash
# Ensure you're logged in and linked
supabase login
supabase link --project-ref YOUR_PROJECT_REF

# Push migrations
supabase db push
```

### Option 3: Environment

Set `SUPABASE_ACCESS_TOKEN` (from `~/.config/meziani/mcp.env`) before running Supabase CLI commands.
