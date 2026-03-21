#!/usr/bin/env node
/**
 * CI script: ensure fr.json has the same leaf keys as en.json.
 * Exits 1 if FR is missing any key from EN (so EN is source of truth).
 */
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function leafKeys(obj, prefix = '') {
  const keys = [];
  for (const [k, v] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${k}` : k;
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      keys.push(...leafKeys(v, path));
    } else {
      keys.push(path);
    }
  }
  return keys;
}

const enPath = join(root, 'messages', 'en.json');
const frPath = join(root, 'messages', 'fr.json');

const en = JSON.parse(readFileSync(enPath, 'utf8'));
const fr = JSON.parse(readFileSync(frPath, 'utf8'));

const enKeys = new Set(leafKeys(en));
const frKeys = new Set(leafKeys(fr));

const missingInFr = [...enKeys].filter((k) => !frKeys.has(k));

if (missingInFr.length > 0) {
  console.error('i18n parity check failed: fr.json is missing keys from en.json:');
  missingInFr.forEach((k) => console.error('  -', k));
  process.exit(1);
}

console.log('i18n parity OK: fr.json has all', enKeys.size, 'keys from en.json');
