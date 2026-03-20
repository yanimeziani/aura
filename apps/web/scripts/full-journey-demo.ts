import * as dotenv from 'dotenv';
import path from 'path';

// Load .env
dotenv.config({ path: path.resolve(__dirname, '../.env') });

import { getRagContext } from '../lib/rag';
import { getChatModel } from '../lib/ai-provider';
import { generateText } from 'ai';

async function simulateDebtorJourney() {
  const merchant = { name: 'Venice Luxury Gym', strictness_level: 7, settlement_floor: 0.70 };
  const debtor = { name: 'Jean-Claude Van Damme', total_debt: 1250, currency: 'CAD', days_overdue: 32 };
  
  console.log('--- PHASE 1: INITIAL OUTREACH ---');
  console.log('Debtor: "I cancelled in January, why am I still being charged?"\n');

  // 1. Get Context
  const { context } = await getRagContext('00000000-0000-0000-0000-000000000002', 'cancellation policy notice period');

  // 2. Generate AI Response
  const model = getChatModel();
  const { text: response1 } = await generateText({
    model,
    system: `You are a resolution assistant for ${merchant.name}. Tone: Polite but firm. Cite context precisely.`,
    prompt: `Debtor Info: ${JSON.stringify(debtor)}. 
             Contract Context: ${context}.
             Debtor says: "I cancelled in January, why am I still being charged?"`
  });

  console.log(`Dragun AI: "${response1}"\n`);

  console.log('--- PHASE 2: NEGOTIATION & SETTLEMENT ---');
  console.log('Debtor: "Fine, but $1,250 is too much right now. Can you do better?"\n');

  const { text: response2 } = await generateText({
    model,
    system: `You are a resolution assistant for ${merchant.name}. You can offer a 30% discount (settlement floor is 0.70).`,
    prompt: `Debtor Info: ${JSON.stringify(debtor)}.
             Debtor says: "Fine, but $1,250 is too much right now. Can you do better?"`
  });

  console.log(`Dragun AI: "${response2}"\n`);

  console.log('--- PHASE 3: PAYMENT HANDOFF ---');
  console.log('Action: System generates a secure Stripe Connect checkout link for $875 (30% off).');
}

simulateDebtorJourney().catch(console.error);
