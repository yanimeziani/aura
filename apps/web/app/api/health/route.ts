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

    const provider = (process.env.AI_PROVIDER ?? 'groq').toLowerCase();
    const aiConfigured =
      provider === 'local' ||
      (typeof process.env.GROQ_API_KEY === 'string' &&
        process.env.GROQ_API_KEY.length > 0);

    return NextResponse.json({
      status: 'operational',
      ai_configured: aiConfigured,
    });
  } catch (err) {
    console.error('[health] Error:', err);
    return NextResponse.json(
      { status: 'degraded', message: 'Service unavailable' },
      { status: 503 }
    );
  }
}
