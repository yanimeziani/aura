#!/usr/bin/env node
/**
 * Apply data_retention migration and run Supabase backend check.
 * Requires: SUPABASE_ACCESS_TOKEN (Management API) for migration
 * Uses: .env.local for backend check (NEXT_PUBLIC_SUPABASE_URL, keys)
 */
import { readFileSync } from 'fs';
import { resolve } from 'path';

const PROJECT_REF = 'mvddmzjepcwxfkuggmzm'; // from NEXT_PUBLIC_SUPABASE_URL

async function loadEnv() {
  try {
    const envPath = resolve(process.cwd(), '.env.local');
    const content = readFileSync(envPath, 'utf8');
    for (const line of content.split('\n')) {
      const m = line.match(/^([^#=]+)=(.*)$/);
      if (m) {
        const key = m[1].trim();
        const val = m[2].trim().replace(/^["']|["']$/g, '');
        if (!process.env[key]) process.env[key] = val;
      }
    }
  } catch (_) {
    // .env.local may not exist
  }
}

async function runMigration() {
  const token = process.env.SUPABASE_ACCESS_TOKEN;
  if (!token) {
    console.log('⚠ SUPABASE_ACCESS_TOKEN not set — skipping migration via API.');
    console.log('  Run manually in Supabase Dashboard → SQL Editor:');
    console.log('  ALTER TABLE merchants ADD COLUMN IF NOT EXISTS data_retention_days INTEGER DEFAULT 0;');
    return false;
  }

  const res = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: 'ALTER TABLE merchants ADD COLUMN IF NOT EXISTS data_retention_days INTEGER DEFAULT 0;',
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Migration API ${res.status}: ${text}`);
  }
  const data = await res.json();
  if (data.error) throw new Error(data.error);
  console.log('✓ Migration applied via Management API');
  return true;
}

async function backendCheck() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    console.log('⚠ Missing NEXT_PUBLIC_SUPABASE_URL or keys — skipping backend check');
    return;
  }

  const tables = ['merchants', 'debtors', 'contracts', 'payments', 'recovery_actions', 'conversations'];
  console.log('\n--- Supabase backend check ---\n');

  for (const table of tables) {
    try {
      const res = await fetch(`${url}/rest/v1/${table}?select=*&limit=0`, {
        headers: {
          'apikey': key,
          'Authorization': `Bearer ${key}`,
          'Prefer': 'return=minimal',
        },
      });
      if (res.ok) {
        const countRes = await fetch(`${url}/rest/v1/${table}?select=count`, {
          headers: {
            'apikey': key,
            'Authorization': `Bearer ${key}`,
            'Prefer': 'count=exact',
          },
        });
        const count = countRes.headers.get('content-range')?.split('/')[1] ?? '?';
        console.log(`  ✓ ${table.padEnd(18)} reachable (count: ${count})`);
      } else {
        console.log(`  ✗ ${table.padEnd(18)} ${res.status} ${res.statusText}`);
      }
    } catch (e) {
      console.log(`  ✗ ${table.padEnd(18)} ${e.message}`);
    }
  }

  // Check merchants.data_retention_days
  try {
    const res = await fetch(`${url}/rest/v1/merchants?select=data_retention_days&limit=1`, {
      headers: {
        'apikey': key,
        'Authorization': `Bearer ${key}`,
      },
    });
    if (res.ok) {
      const rows = await res.json();
      console.log(`\n  ✓ merchants.data_retention_days column exists`);
    } else {
      const err = await res.json().catch(() => ({}));
      if (res.status === 400 && (err.message || '').includes('column')) {
        console.log(`\n  ⚠ merchants.data_retention_days missing — run migration`);
      } else {
        console.log(`\n  ? merchants schema check: ${res.status}`);
      }
    }
  } catch (e) {
    console.log(`\n  ? Schema check error: ${e.message}`);
  }

  console.log('');
}

async function main() {
  await loadEnv();
  console.log('Supabase migration + backend check\n');

  const migrated = await runMigration();
  if (!migrated) {
    console.log('(Migration may already be applied or run manually.)\n');
  }

  await backendCheck();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
