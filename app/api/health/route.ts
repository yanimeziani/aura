import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const { error } = await supabaseAdmin
      .from('merchants')
      .select('id')
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error('[health] DB check failed:', error.message);
      return NextResponse.json(
        { status: 'degraded', message: 'Database unreachable' },
        { status: 503 }
      );
    }

    return NextResponse.json({ status: 'operational' });
  } catch (err) {
    console.error('[health] Error:', err);
    return NextResponse.json(
      { status: 'degraded', message: 'Service unavailable' },
      { status: 503 }
    );
  }
}
