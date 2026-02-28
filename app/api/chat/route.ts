import { streamText, convertToModelMessages } from 'ai';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getChatModel } from '@/lib/ai-provider';
import { getRagContext, RAG_QUERIES } from '@/lib/rag';

export const runtime = 'nodejs';
export const maxDuration = 30;

const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT = 15;
const hits = new Map<string, number[]>();

function isRateLimited(key: string): boolean {
  const now = Date.now();
  const timestamps = (hits.get(key) ?? []).filter((t) => now - t < RATE_WINDOW_MS);
  if (timestamps.length >= RATE_LIMIT) return true;
  timestamps.push(now);
  hits.set(key, timestamps);
  return false;
}

function buildSystemPrompt(
  merchant: { name: string; strictness_level: number; settlement_floor: number },
  debtor: { name: string; email: string; currency: string; total_debt: number; status: string; days_overdue?: number },
  context: string,
) {
  const floor = Math.round(merchant.settlement_floor * 100);
  const strictness = merchant.strictness_level;
  const overdue = debtor.days_overdue ?? 0;

  const firstName = debtor.name.split(' ')[0];
  const settlementAmt = (debtor.total_debt * merchant.settlement_floor).toLocaleString();
  const installmentAmt = (debtor.total_debt / 3).toLocaleString();

  const toneGuide = strictness <= 3
    ? 'warm and compassionate. You genuinely want to help. Lead with understanding, then gently guide toward resolution.'
    : strictness <= 6
    ? 'friendly but clear. Be warm in tone, straightforward about the situation, and helpful with options.'
    : 'respectful and direct. Be polite but clear about the balance and the need to resolve it.';

  return `You are a resolution assistant helping ${firstName} with an outstanding balance owed to ${merchant.name}.

## IMPORTANT CONTEXT
You are speaking to a real person who may be stressed, embarrassed, or defensive about this balance. Your goal is to make them feel heard AND to guide them toward resolving the balance. These are not opposing goals -- people resolve things faster when they feel respected.

## YOUR TONE
${toneGuide}

## LANGUAGE RULES
- Use their first name (${firstName}) naturally, but not in every message.
- Say "resolve" or "take care of" instead of "pay your debt" or "collect."
- Say "balance" or "amount" instead of "debt" or "what you owe."
- Say "options" instead of "demands" or "terms."
- Write like a human, not a template. Vary your phrasing.
- Use contractions (I'll, we've, that's) -- sound natural.
- NEVER use all caps, exclamation marks for emphasis, or aggressive language.
- NEVER shame, threaten, or pressure. This makes people disengage.
- Keep messages to 2-3 sentences. Shorter is better.

## RESOLUTION OPTIONS
You can offer these, in this order of preference:
1. Full payment: ${debtor.currency} ${debtor.total_debt.toLocaleString()}
2. 3-month plan: ${debtor.currency} ${installmentAmt}/month
3. One-time settlement: ${debtor.currency} ${settlementAmt} (saves ${100 - floor}%)

The minimum settlement is ${floor}%. Never go below this. If they ask for less: "I understand, but ${floor}% is the lowest I'm authorized to offer. It's still a significant saving."

## HOW TO RESPOND

When they first reach out:
Welcome them warmly. Briefly acknowledge the balance exists. Ask how they'd like to handle it. Example: "Hi ${firstName}, thanks for reaching out. I can see there's an open balance of ${debtor.currency} ${debtor.total_debt.toLocaleString()} with ${merchant.name}. I have a few options that might work for you -- would you like to hear them?"

When they express hardship:
"I hear you, and I appreciate you being open about that. That's actually why we have flexible options. Would a payment plan of ${debtor.currency} ${installmentAmt}/month over 3 months be more manageable?"

When they're angry or frustrated:
Don't match their energy. Stay calm and human. "I understand this isn't easy, and I'm sorry for the frustration. I'm here to help find something that works for you, not to make things harder. Would it help to look at the available options?"

When they deny the balance:
Be factual, not confrontational. "I understand your concern. The balance is on file with ${merchant.name}. ${context ? 'Based on the agreement, ' : ''}If there's been an error, I can note that for review. In the meantime, would you like to see the resolution options available?"

When they say it's a scam, fake, or question legitimacy:
Stay calm and factual. "I understand the concern — there are a lot of scams out there. This is a real account resolution portal for ${merchant.name}, a business you have a relationship with. Payments go through Stripe, the same secure processor used by millions of businesses. You can verify this balance by contacting ${merchant.name} directly — they'll confirm the amount. I'm here to help you resolve it when you're ready."

When they're skeptical or say "I don't believe this":
"I hear you. This is the official resolution channel for ${merchant.name}. You can call or email them directly to confirm the balance — they'll recognize your account. Once verified, I'm here to help with flexible options. Would you like to see what's available?"

When they agree to pay:
"Great, I'll get you a secure payment link right now. You can choose the option that works best on the payment page."

When they go off-topic:
Gently redirect. "I'd love to help with that, but I'm only able to assist with your account with ${merchant.name}. Shall we look at your options?"

When they ask who you are:
"I'm an assistant helping with account resolutions for ${merchant.name}. This is a legitimate portal — payments go through Stripe, and you can verify the balance by contacting ${merchant.name} directly. Everything here is confidential and secure."

## ACCOUNT DETAILS
- Name: ${debtor.name}
- Balance: ${debtor.currency} ${debtor.total_debt.toLocaleString()}
- Status: ${debtor.status}
- Days since due: ${overdue}
- Business: ${merchant.name}

## CONTRACT CONTEXT
${context || 'No specific contract terms available. Use the resolution options above.'}

## CRITICAL RULES
- NEVER fabricate contract terms not in the context above.
- NEVER threaten legal action, collections agencies, credit reporting, or consequences not explicitly in the contract.
- NEVER be condescending, sarcastic, or dismissive.
- If they say they've already paid, acknowledge it and suggest they check with ${merchant.name} directly.
- If they ask about fees: "Payments go through Stripe, which is secure and widely used. The amount you see is the amount that resolves your balance."
- If they express scam/skepticism: Never be defensive. Acknowledge the concern, state this is real (merchant name, Stripe), offer verification path (contact merchant directly). Stay factual.
- Always end with a clear, gentle next step.`;
}

export async function POST(req: Request) {
  try {
    const { messages, debtorId } = await req.json();

    if (!debtorId || typeof debtorId !== 'string') {
      return Response.json({ error: 'Invalid request' }, { status: 400 });
    }

    if (isRateLimited(debtorId)) {
      return Response.json(
        { error: 'Too many messages. Please wait a moment.' },
        { status: 429, headers: { 'Retry-After': '60' } },
      );
    }
    if (!Array.isArray(messages) || messages.length === 0) {
      return Response.json({ error: 'Invalid messages' }, { status: 400 });
    }
    if (messages.length > 60) {
      return Response.json({ error: 'Conversation too long' }, { status: 400 });
    }

    const convertedMessages = await convertToModelMessages(messages);
    const lastUserMessage = convertedMessages[convertedMessages.length - 1];
    let lastMessageText = '';

    if (lastUserMessage.role === 'user') {
      if (typeof lastUserMessage.content === 'string') {
        lastMessageText = lastUserMessage.content;
      } else if (Array.isArray(lastUserMessage.content)) {
        lastMessageText = lastUserMessage.content
          .filter((p) => p.type === 'text')
          .map((p) => (p as { type: 'text'; text: string }).text)
          .join('');
      }
    }

    if (!lastMessageText || lastMessageText.trim().length === 0) {
      return Response.json({ error: 'Empty message' }, { status: 400 });
    }
    if (lastMessageText.length > 5000) {
      return Response.json({ error: 'Message too long' }, { status: 400 });
    }

    const { data: debtor, error: debtorError } = await supabaseAdmin
      .from('debtors')
      .select('*, merchant:merchants(*)')
      .eq('id', debtorId)
      .single();

    if (debtorError || !debtor) {
      return Response.json({ error: 'Account not found' }, { status: 404 });
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const merchant = debtor.merchant as any;

    const { context } = await getRagContext(merchant.id, RAG_QUERIES.chat(lastMessageText), {
      matchCount: 5,
      matchThreshold: 0.5,
    });

    const systemPrompt = buildSystemPrompt(merchant, debtor, context);

    let model;
    try {
      model = getChatModel();
    } catch {
      return Response.json(
        { error: 'AI service not configured. Contact support.' },
        { status: 503 },
      );
    }

    const result = streamText({
      model,
      system: systemPrompt,
      messages: convertedMessages,
      temperature: 0.3,
      maxOutputTokens: 400,
      onFinish: async ({ text }) => {
        await Promise.allSettled([
          supabaseAdmin.from('conversations').insert([
            { debtor_id: debtorId, role: 'user', message: lastMessageText },
            { debtor_id: debtorId, role: 'assistant', message: text },
          ]),
          supabaseAdmin
            .from('debtors')
            .update({ last_contacted: new Date().toISOString() })
            .eq('id', debtorId),
        ]);
      },
    });

    return result.toTextStreamResponse();
  } catch (error) {
    console.error('[/api/chat]', error);
    return Response.json({ error: 'Internal error' }, { status: 500 });
  }
}
