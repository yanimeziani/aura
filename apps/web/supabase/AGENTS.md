# AGENTS.md - Supabase Directory Guide

This directory contains Supabase database configuration for the Dragun.app debt recovery platform.

## Project Overview

**Dragun.app** is an AI-powered debt recovery platform with:
- Merchant Dashboard for business operations
- Debtor Portal for payment resolution
- Google OAuth authentication via Supabase Auth
- Stripe Connect for payment processing
- Vector embeddings for contract search (pgvector)

The main Next.js application is in the parent directory (`/home/openclaw/workspace/meziani.ai/products/dragun-app`).

## Database Schema

### Core Tables

**merchants** - Business accounts
- `id` UUID PRIMARY KEY (matches `auth.users.id` - CRITICAL)
- `name`, `email`, `country`, `phone`, `currency_preference`
- `strictness_level` INT (1-10) - controls AI negotiation tone
- `settlement_floor` FLOAT (0.0-1.0) - minimum acceptable settlement ratio
- `onboarding_step`, `onboarding_completed`
- `stripe_account_id`, `stripe_onboarding_complete`
- `plan`, `stripe_customer_id`, `plan_active_until`, `debtor_limit`
- `data_retention_days` INT - data retention policy (0 = indefinite)

**contracts** - Contract documents for debt validation
- `id` UUID PRIMARY KEY
- `merchant_id` UUID REFERENCES merchants(id) ON DELETE CASCADE
- `file_name`, `file_path`, `raw_text`

**contract_embeddings** - Vector embeddings for semantic search (pgvector)
- `id` UUID PRIMARY KEY
- `contract_id` UUID REFERENCES contracts(id) ON DELETE CASCADE
- `content` TEXT
- `embedding` VECTOR(768) - Gemini Text-Embedding-004 dimensions
- `metadata` JSONB

**debtors** - Accounts receivable records
- `id` UUID PRIMARY KEY
- `merchant_id` UUID REFERENCES merchants(id) ON DELETE CASCADE
- `name`, `email`, `phone`
- `total_debt` FLOAT, `currency`, `status` (pending/settled/disputed)
- `days_overdue` INT, `updated_at`
- `last_contacted` TIMESTAMP

**conversations** - AI chat history
- `id` UUID PRIMARY KEY
- `debtor_id` UUID REFERENCES debtors(id) ON DELETE CASCADE
- `role` TEXT ('user' or 'assistant')
- `message` TEXT

**payments** - Payment transactions
- `id` UUID PRIMARY KEY
- `debtor_id` UUID REFERENCES debtors(id) ON DELETE CASCADE
- `amount` FLOAT, `status` (success/pending/failed)
- `payment_type` TEXT (default: 'full')
- `platform_fee` NUMERIC(12,2) - 5% platform fee for Stripe Connect
- `stripe_session_id` TEXT

**recovery_actions** - Manual actions by merchants
- `id` UUID PRIMARY KEY
- `debtor_id` UUID REFERENCES debtors(id) ON DELETE CASCADE
- `merchant_id` UUID REFERENCES merchants(id) ON DELETE CASCADE
- `action_type` TEXT (call/sms/schedule/status_update)
- `status_after` TEXT, `note` TEXT

### Extensions

- **pgvector** - enabled for vector similarity search
- Custom function `match_contract_embeddings()` for semantic search

### Indexes

- `idx_recovery_actions_debtor_created` ON recovery_actions(debtor_id, created_at DESC)
- `idx_debtors_merchant_status` ON debtors(merchant_id, status)

## Row Level Security (RLS) Policies

**Critical**: All tables have RLS enabled. Policies are defined in `policies.sql`.

### Key Policies

1. **Merchants table**: Only own profile (auth.uid() = id)
2. **Contracts**: Only own contracts (merchant_id = auth.uid())
3. **Contract embeddings**: Inherits access from parent contract
4. **Debtors**: Only own debtors (merchant_id = auth.uid())
5. **Payments**: Read-only access to own debtor payments
6. **Conversations**: Special case - public read access (relies on UUID secrecy for prototype)

**Storage policies** (`storage.sql`):
- Authenticated users can upload/read contracts
- Relies on application logic to enforce folder structure (merchants/ID/...)

### RLS Gotchas

- `auth.uid()` returns the Supabase Auth user ID
- For merchants table: `merchants.id` MUST equal `auth.users.id` (enforced by RLS)
- Debtors table has public read access by design (for debtor portal chat interface)
- Storage policies are permissive - application-level filtering is required

## Storage Configuration

Bucket: **contracts** (private)

Policies:
- Authenticated users can upload
- Authenticated users can read (application-level filtering required)

Files are stored with folder structure: `contracts/merchants/{merchant_id}/{file_path}`

## Migration Management

### Directory Structure

```
supabase/
├── migrations/          # Timestamped migration files
│   ├── YYYYMMDDHHMMSS_description.sql
│   └── ...
├── policies.sql         # RLS policies (initial setup)
├── storage.sql          # Storage bucket policies
└── schema.sql           # Initial database schema (parent directory)
```

### Migration Naming Convention

Format: `YYYYMMDDHHMMSS_description.sql`

Examples:
- `20240220000001_add_onboarding_flag.sql`
- `20260226000001_align_merchants_schema.sql`
- `20260227000003_add_data_retention.sql`

### Applying Migrations

**Option 1: Supabase CLI (Recommended for development)**
```bash
cd /home/openclaw/workspace/meziani.ai/products/dragun-app
supabase db push
```

**Option 2: Supabase Dashboard (Manual)**
1. Go to Supabase Dashboard → SQL Editor
2. Run migration SQL manually

**Option 3: Management API (Automated)**
- Requires `SUPABASE_ACCESS_TOKEN` environment variable
- See `scripts/supabase-migrate-and-check.mjs` for example

### Checking Migration Status

```bash
npm run db:check
```

This script:
- Checks if `data_retention_days` column exists
- Verifies all core tables are accessible
- Requires `.env.local` with Supabase credentials

### Migration Best Practices

1. **Always use `IF NOT EXISTS`** for `ADD COLUMN` operations
2. **Use transactions** for complex schema changes
3. **Backwards compatibility**: Add columns with defaults before removing old ones
4. **Test locally**: Use `supabase start` for local development (requires Docker)
5. **Document breaking changes**: Update this file when schema changes affect application code

## Application Integration

### Supabase Client Setup

**Browser client** (`lib/supabase/client.ts`):
```typescript
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
```

**Server client** (`lib/supabase/server.ts`):
- Uses Next.js cookies for SSR
- Includes middleware support for session refresh

**Admin client** (`lib/supabase-admin.ts`):
- Bypasses RLS (uses service role key)
- Used in Server Actions for admin operations
- **Critical**: Never use admin client on client side

### Environment Variables (from parent `.env.example`)

```
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...  # For admin operations
SUPABASE_ACCESS_TOKEN=...       # For Management API (optional)
```

### Supabase Client Usage Patterns

**Server Actions** (using admin client):
```typescript
import { supabaseAdmin } from '@/lib/supabase-admin';

export async function addDebtor(formData: FormData) {
  const { error } = await supabaseAdmin.from('debtors').insert({...});
  // ...
}
```

**Server Components** (using server client):
```typescript
import { createClient } from '@/lib/supabase/server';

export default async function Dashboard() {
  const supabase = await createClient();
  const { data } = await supabase.from('debtors').select('*');
  // ...
}
```

**Client Components** (using browser client):
```typescript
import { createClient } from '@/lib/supabase/client';

export default function DebtorList() {
  const supabase = createClient();
  // Realtime subscriptions work here
}
```

## Seeding Data

For local development testing, use `seed.sql` in parent directory:

```bash
# Run via Supabase Dashboard SQL Editor or CLI
psql -h localhost -U postgres -d postgres < seed.sql
```

**Critical seeding constraint**:
- `auth.users.id` MUST equal `merchants.id` (enforced by RLS)
- Seed script creates auth user first, then references the same UUID for merchant

## Vector Search (pgvector)

### Function: `match_contract_embeddings()`

```sql
SELECT * FROM match_contract_embeddings(
  query_embedding => VECTOR(768),
  match_threshold => 0.7,
  match_count => 5,
  p_contract_id => UUID
);
```

Returns: contract embeddings ordered by similarity (descending)

### Embedding Dimensions

- **Gemini Text-Embedding-004**: 768 dimensions
- Stored in `contract_embeddings.embedding` column

### Usage Pattern

1. Generate embeddings from contract text chunks (application side)
2. Store in `contract_embeddings` table
3. Query with `match_contract_embeddings()` to find relevant contract sections
4. Use results to inform AI negotiation responses

## Important Gotchas

### 1. Auth/User ID Alignment
- `merchants.id` MUST equal `auth.users.id`
- This is enforced by RLS policy: `auth.uid() = id`
- When seeding, create `auth.users` record first, then merchant with same UUID

### 2. RLS Policy Inheritance
- `contract_embeddings` inherits access from parent contract
- Pattern: Use subquery to check parent table permissions

### 3. Public Access Patterns
- Debtors table has public read access (by design for debtor portal)
- Relies on UUID secrecy - consider token-based auth for production
- Storage bucket policies are permissive - filter at application level

### 4. Transaction Safety
- Always use `ON CONFLICT (id) DO NOTHING` for idempotent inserts
- Use `IF NOT EXISTS` for `ADD COLUMN` in migrations
- Test migrations locally before applying to production

### 5. Service Role Key Security
- Never expose `SUPABASE_SERVICE_ROLE_KEY` to client side
- Only use in Server Actions or API routes
- Admin client bypasses RLS - use with extreme caution

### 6. Stripe Connect Integration
- `merchants.stripe_account_id` - linked Stripe Connect account
- `payments.platform_fee` - 5% platform fee charged on each payment
- Destination charges flow: funds go directly to merchant's Stripe account

### 7. Data Retention
- `merchants.data_retention_days` = 0 means indefinite retention
- GDPR compliance requires implementing cleanup jobs for > 0 values
- Currently no automated deletion logic implemented

## Common Operations

### Check Table Structure
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'merchants';
```

### Test RLS Policy
```sql
-- As authenticated user
SET ROLE authenticated;
SELECT * FROM merchants WHERE id = auth.uid();
```

### Verify Storage Bucket
```sql
SELECT * FROM storage.buckets WHERE id = 'contracts';
```

### Check Vector Similarity
```sql
SELECT
  1 - (embedding <=> '[0.1,0.2,...]') AS similarity
FROM contract_embeddings
ORDER BY similarity DESC
LIMIT 5;
```

## Debugging

### Connection Issues
- Check `.env.local` has correct Supabase URL and keys
- Verify `NEXT_PUBLIC_SUPABASE_URL` matches project ref: `mvddmzjepcwxfkuggmzm`
- Check `SUPABASE_ACCESS_TOKEN` if using Management API

### RLS Permission Errors
- Verify user is authenticated: `SELECT auth.uid();`
- Check policy exists: `SELECT * FROM pg_policies WHERE tablename = 'your_table';`
- Test as specific role: `SET ROLE authenticated;`

### Migration Failures
- Check for existing columns: Use `information_schema.columns`
- Use `IF NOT EXISTS` for `ADD COLUMN`
- Rollback with: `ALTER TABLE table_name DROP COLUMN IF EXISTS column_name;`

### Storage Upload Issues
- Verify bucket exists: `SELECT * FROM storage.buckets;`
- Check policy: `SELECT * FROM pg_policies WHERE schemaname = 'storage';`
- Ensure user is authenticated for storage operations

## Deployment

**Production Project Reference**: `mvddmzjepcwxfkuggmzm`

- All migrations must be tested locally first
- Use `supabase db push` to push to development environment
- For production, use Supabase Dashboard → SQL Editor for safety
- Never run `supabase db reset` on production (deletes all data)

## Testing Supabase Changes

1. **Apply migration locally** (if using Docker):
   ```bash
   supabase start
   supabase db reset
   ```

2. **Test via application**:
   - Run `npm run dev` in parent directory
   - Test affected features (e.g., add debtor, upload contract)

3. **Verify data**:
   - Check Supabase Dashboard Table Editor
   - Run `npm run db:check` to verify schema

4. **Deploy to staging/production**:
   - Document any breaking changes
   - Coordinate with frontend team if API changes

## Related Files (Parent Directory)

- `lib/supabase/client.ts` - Browser client factory
- `lib/supabase/server.ts` - Server client factory
- `lib/supabase-admin.ts` - Admin client (bypasses RLS)
- `app/actions/*.ts` - Server Actions using Supabase
- `app/api/` - API routes with Supabase integration
- `scripts/supabase-migrate-and-check.mjs` - Migration utility

## Support Resources

- Supabase Dashboard: https://supabase.com/dashboard/project/mvddmzjepcwxfkuggmzm
- Supabase CLI Docs: https://supabase.com/docs/guides/cli
- pgvector Documentation: https://github.com/pgvector/pgvector

## Commands Quick Reference

```bash
# Apply migrations
cd /home/openclaw/workspace/meziani.ai/products/dragun-app
supabase db push

# Check database status
npm run db:check

# Local development (requires Docker)
supabase start
supabase stop
supabase db reset

# Login to Supabase CLI
supabase login
supabase link --project-ref mvddmzjepcwxfkuggmzm
```
