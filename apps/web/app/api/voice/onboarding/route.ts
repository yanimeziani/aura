import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { generateText } from 'ai';
import { getChatModel } from '@/lib/ai-provider';

export async function POST(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const merchantId = searchParams.get('merchantId') || '00000000-0000-0000-0000-000000000002';

    // 1. Fetch Merchant Info
    const { data: merchant } = await supabaseAdmin
      .from('merchants')
      .select('name')
      .eq('id', merchantId)
      .single();

    const merchantName = merchant?.name || 'Valued Partner';

    // 2. Generate VA Greeting
    const model = getChatModel();
    const { text: greeting } = await generateText({
      model,
      system: `You are a professional Virtual Assistant for Dragun.app. 
               Keep it extremely brief (2 sentences). 
               Goal: Confirm the pilot for Venice Gym is active.`,
      prompt: `Say hello to ${merchantName}. Confirm the pilot is live and their debtors are being monitored.`
    });

    // 3. Return TwiML
    const twiml = `
      <?xml version="1.0" encoding="UTF-8"?>
      <Response>
        <Say voice="Polly.Danielle" language="en-US">
          ${greeting}
        </Say>
        <Pause length="1"/>
        <Say voice="Polly.Danielle" language="en-US">
          If you have any questions, simply reply to the text message we sent earlier. Have a productive day.
        </Say>
        <Hangup/>
      </Response>
    `.trim();

    return new NextResponse(twiml, {
      headers: { 'Content-Type': 'application/xml' },
    });
  } catch (error) {
    console.error('[/api/voice/onboarding] Error:', error);
    return new NextResponse('<Response><Say>Connection error. Please try again.</Say></Response>', {
      headers: { 'Content-Type': 'application/xml' },
    });
  }
}
