import * as dotenv from 'dotenv';
import path from 'path';
import twilio from 'twilio';

// Load .env
dotenv.config({ path: path.resolve(__dirname, '../.env') });

async function triggerVaCall() {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM;
  const to = '+15551234567'; // Change to Mounir's real number for testing
  const merchantId = '00000000-0000-0000-0000-000000000002';
  
  // TwiML endpoint on your VPS/Vercel (Must be public for Twilio to reach)
  const twimlUrl = `https://your-public-url.com/api/voice/onboarding?merchantId=${merchantId}`;

  if (!accountSid || !authToken || !from) {
    console.error('❌ Twilio credentials missing in .env');
    return;
  }

  console.log(`📞 Triggering VA Onboarding Call to: ${to}`);

  try {
    const client = twilio(accountSid, authToken);
    const call = await client.calls.create({
      from,
      to,
      url: twimlUrl,
    });

    console.log(`✅ Call initiated! SID: ${call.sid}`);
  } catch (error) {
    console.error('❌ Call trigger failed:', error);
  }
}

triggerVaCall().catch(console.error);
