import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseServiceRole = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl) throw new Error('NEXT_PUBLIC_SUPABASE_URL is required');
if (!supabaseServiceRole) throw new Error('SUPABASE_SERVICE_ROLE_KEY is required — do not fall back to anon key');

export const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole);
