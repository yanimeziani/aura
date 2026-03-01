import { streamText } from 'ai';
import type { ModelMessage } from 'ai';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getChatModel, getChatFallbackModelIds } from '@/lib/ai-provider';
import { getRagContext, RAG_QUERIES } from '@/lib/rag';
import { verifyDebtorToken } from '@/lib/debtor-token';
import type { MerchantForChat } from '@/lib/merchant-types';

function isQuotaOrRateLimitError(error: unknown): boolean {
  const msg = error instanceof Error ? error.message : String(error);
  const s = msg.toLowerCase();
  if (s.includes('429') || s.includes('402')) return true;
  if (s.includes('quota') || s.includes('rate limit') || s.includes('too many requests')) return true;
  if (s.includes('insufficient credits') || s.includes('payment required')) return true;
  const status = (error as { status?: number })?.status;
  return status === 429 || status === 402;
}

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
  merchant: { name: string; strictness_level?: number | null; settlement_floor?: number | null },
  debtor: { name?: string | null; email?: string | null; currency?: string | null; total_debt?: number | null; status?: string | null; days_overdue?: number | null },
  context: string,
) {
  const floor = Math.round((Number(merchant.settlement_floor) || 0.5) * 100);
  const strictness = Number(merchant.strictness_level) || 5;
  const overdue = debtor.days_overdue ?? 0;
  const totalDebt = Number(debtor.total_debt) || 0;
  const currency = String(debtor.currency ?? '').trim() || 'USD';
  const status = String(debtor.status ?? '').trim() || 'outstanding';
  const merchantName = String(merchant.name ?? '').trim() || 'the business';

  const rawName = String(debtor.name ?? '').trim();
  const firstName = rawName ? rawName.split(/\s+/)[0]! : 'there';
  const debtorName = rawName || 'Customer';
  const settlementAmt = (totalDebt * (Number(merchant.settlement_floor) || 0.5)).toLocaleString();
  const installmentAmt = (totalDebt / 3).toLocaleString();

  const toneGuide = strictness <= 3
    ? 'warm and compassionate. You genuinely want to help. Lead with understanding, then gently guide toward resolution.'
    : strictness <= 6
    ? 'friendly but clear. Be warm in tone, straightforward about the situation, and helpful with options.'
    : 'respectful and direct. Be polite but clear about the balance and the need to resolve it.';

  return `You are a resolution assistant helping ${firstName} with an outstanding balance owed to ${merchantName}.

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
1. Full payment: ${currency} ${totalDebt.toLocaleString()}
2. 3-month plan: ${currency} ${installmentAmt}/month
3. One-time settlement: ${currency} ${settlementAmt} (saves ${100 - floor}%)

The minimum settlement is ${floor}%. Never go below this. If they ask for less: "I understand, but ${floor}% is the lowest I'm authorized to offer. It's still a significant saving."

## HOW TO RESPOND

When they first reach out:
Welcome them warmly. Briefly acknowledge the balance exists. Ask how they'd like to handle it. Example: "Hi ${firstName}, thanks for reaching out. I can see there's an open balance of ${currency} ${totalDebt.toLocaleString()} with ${merchantName}. I have a few options that might work for you -- would you like to hear them?"

When they express hardship:
"I hear you, and I appreciate you being open about that. That's actually why we have flexible options. Would a payment plan of ${currency} ${installmentAmt}/month over 3 months be more manageable?"

When they're angry or frustrated:
Don't match their energy. Stay calm and human. "I understand this isn't easy, and I'm sorry for the frustration. I'm here to help find something that works for you, not to make things harder. Would it help to look at the available options?"

When they deny the balance:
Be factual, not confrontational. "I understand your concern. The balance is on file with ${merchantName}. ${context ? 'Based on the agreement, ' : ''}If there's been an error, I can note that for review. In the meantime, would you like to see the resolution options available?"

When they say it's a scam, fake, or question legitimacy:
Stay calm and factual. "I understand the concern — there are a lot of scams out there. This is a real account resolution portal for ${merchantName}, a business you have a relationship with. Payments go through Stripe, the same secure processor used by millions of businesses. You can verify this balance by contacting ${merchantName} directly — they'll confirm the amount. I'm here to help you resolve it when you're ready."

When they're skeptical or say "I don't believe this":
"I hear you. This is the official resolution channel for ${merchantName}. You can call or email them directly to confirm the balance — they'll recognize your account. Once verified, I'm here to help with flexible options. Would you like to see what's available?"

When they agree to pay:
"Great, I'll get you a secure payment link right now. You can choose the option that works best on the payment page."

When they go off-topic:
Gently redirect. "I'd love to help with that, but I'm only able to assist with your account with ${merchantName}. Shall we look at your options?"

When they ask who you are:
"I'm an assistant helping with account resolutions for ${merchantName}. This is a legitimate portal — payments go through Stripe, and you can verify the balance by contacting ${merchantName} directly. Everything here is confidential and secure."

## ACCOUNT DETAILS
- Name: ${debtorName}
- Balance: ${currency} ${totalDebt.toLocaleString()}
- Status: ${status}
- Days since due: ${overdue}
- Business: ${merchantName}

## CONTRACT CONTEXT
${context || 'No specific contract terms available. Use the resolution options above.'}

## CRITICAL RULES
- NEVER fabricate contract terms not in the context above.
- NEVER threaten legal action, collections agencies, credit reporting, or consequences not explicitly in the contract.
- NEVER be condescending, sarcastic, or dismissive.
- If they say they've already paid, acknowledge it and suggest they check with ${merchantName} directly.
- If they ask about fees: "Payments go through Stripe, which is secure and widely used. The amount you see is the amount that resolves your balance."
- If they express scam/skepticism: Never be defensive. Acknowledge the concern, state this is real (merchant name, Stripe), offer verification path (contact merchant directly). Stay factual.
- Always end with a clear, gentle next step.`;
}

const OPENING_INSTRUCTION = `
---
## RIGHT NOW: OPEN THE CONVERSATION
The debtor has just opened the chat. They have not sent any message yet. You have all authorised data above (name, balance, currency, merchant, contract context). Your job is to send the first message to start the conversation.

- Use their first name and the balance/currency from the account details. Do not ask them for their name or the amount — you already have it.
- Briefly acknowledge the open balance and that you are here to help. Offer the resolution options (full payment, payment plan, settlement) and invite them to choose or ask questions.
- Keep it to 2–3 sentences. Sound human and warm. End with a clear next step (e.g. "Would you like to hear the options?" or "What would work best for you?").
- Do not add meta-commentary like "I am the assistant". Just write the single message the debtor will see.`;

export async function POST(req: Request) {
  try {
    let body: { messages?: unknown; debtorId?: string; token?: string; initiate?: boolean };
    try {
      body = await req.json();
    } catch {
      return Response.json({ error: 'Invalid JSON' }, { status: 400 });
    }
    const { messages: rawMessages, debtorId, token, initiate } = body ?? {};

    if (!debtorId || typeof debtorId !== 'string') {
      return Response.json({ error: 'Invalid request' }, { status: 400 });
    }

    // Require valid debtor portal token so only intended debtor can use this channel
    const verified = token ? verifyDebtorToken(String(token)) : null;
    if (!verified || verified.debtorId !== debtorId) {
      return Response.json({ error: 'Unauthorized' }, { status: 403 });
    }

    if (isRateLimited(debtorId)) {
      return Response.json(
        { error: 'Too many messages. Please wait a moment.' },
        { status: 429, headers: { 'Retry-After': '60' } },
      );
    }
    const messages = Array.isArray(rawMessages) ? rawMessages : [];
    const isInitiate = Boolean(initiate) || messages.length === 0;

    if (!isInitiate && messages.length === 0) {
      return Response.json({ error: 'Invalid messages' }, { status: 400 });
    }
    if (messages.length > 60) {
      return Response.json({ error: 'Conversation too long' }, { status: 400 });
    }

    const { data: debtor, error: debtorError } = await supabaseAdmin
      .from('debtors')
      .select('*, merchant:merchants(*)')
      .eq('id', debtorId)
      .single();

    if (debtorError || !debtor) {
      return Response.json({ error: 'Account not found' }, { status: 404 });
    }

    const merchant = (debtor?.merchant ?? null) as MerchantForChat | null;
    if (!merchant || typeof merchant !== 'object' || !merchant.id) {
      console.error('[/api/chat] Debtor has no merchant', { debtorId });
      return Response.json(
        { error: 'Account configuration missing. Contact support.' },
        { status: 503 },
      );
    }

    const merchantId = String(merchant.id);
    const safeDebtor = {
      name: debtor?.name ?? null,
      email: debtor?.email ?? null,
      currency: debtor?.currency ?? null,
      total_debt: debtor?.total_debt ?? null,
      status: debtor?.status ?? null,
      days_overdue: debtor?.days_overdue ?? null,
    };

    let systemPrompt: string;
    let modelMessages: ModelMessage[];
    let lastMessageText = '';

    if (isInitiate) {
      let context = '';
      try {
        const rag = await getRagContext(merchantId, 'payment terms settlement options balance due', {
          matchCount: 5,
          matchThreshold: 0.5,
        });
        context = rag?.context ?? '';
      } catch (ragErr) {
        console.warn('[/api/chat] RAG context failed (initiate)', ragErr);
      }
      systemPrompt = buildSystemPrompt(merchant, safeDebtor, context) + OPENING_INSTRUCTION;
      modelMessages = [{ role: 'user' as const, content: '[Open the conversation with your first message to the debtor.]' }];
    } else {
      // Normalize to { role, content } and build ModelMessage[] for streamText.
      const normalizedMessages = messages.map((m) => ({
        role: (m && typeof m === 'object' && (m as { role?: string }).role) || 'user',
        content: (m && typeof m === 'object' && (m as { content?: unknown }).content !== undefined)
          ? (m as { content: unknown }).content
          : '',
      }));

      function toMessageContent(raw: unknown): string | Array<{ type: 'text'; text: string }> {
        if (typeof raw === 'string' && raw.length > 0) return raw;
        if (Array.isArray(raw)) {
          const parts = raw
            .map((p) => {
              if (p && typeof p === 'object' && 'text' in (p as object))
                return { type: 'text' as const, text: String((p as { text?: unknown }).text ?? '') };
              if (typeof p === 'string') return { type: 'text' as const, text: p };
              return null;
            })
            .filter((p): p is { type: 'text'; text: string } => p != null && p.text.length > 0);
          if (parts.length > 0) return parts;
        }
        if (raw != null && typeof raw === 'object' && 'text' in (raw as object))
          return [{ type: 'text' as const, text: String((raw as { text?: unknown }).text ?? '') }];
        return '';
      }

      const built: ModelMessage[] = normalizedMessages
        .map((m) => {
          const role = (m.role === 'assistant' ? 'assistant' : 'user') as 'user' | 'assistant';
          const content = toMessageContent(m.content);
          const isEmpty =
            content === '' || (Array.isArray(content) && content.every((p) => !p.text?.trim()));
          return isEmpty ? null : ({ role, content } as ModelMessage);
        })
        .filter((m): m is ModelMessage => m != null);

      const lastNorm = normalizedMessages[normalizedMessages.length - 1];
      if (lastNorm?.role === 'user') {
        const c = lastNorm.content;
        if (typeof c === 'string') lastMessageText = c;
        else if (Array.isArray(c))
          lastMessageText = (c as Array<{ type?: string; text?: string }>)
            .filter((p) => p?.type === 'text')
            .map((p) => p.text ?? '')
            .join('');
      }

      if (!lastMessageText || lastMessageText.trim().length === 0) {
        return Response.json({ error: 'Empty message' }, { status: 400 });
      }
      if (built.length === 0) {
        return Response.json({ error: 'No valid messages' }, { status: 400 });
      }
      if (lastMessageText.length > 5000) {
        return Response.json({ error: 'Message too long' }, { status: 400 });
      }

      modelMessages = built;
      let context = '';
      try {
        const rag = await getRagContext(merchantId, RAG_QUERIES.chat(lastMessageText), {
          matchCount: 5,
          matchThreshold: 0.5,
        });
        context = rag?.context ?? '';
      } catch (ragErr) {
        console.warn('[/api/chat] RAG context failed', ragErr);
      }
      systemPrompt = buildSystemPrompt(merchant, safeDebtor, context);
    }

    let model;
    try {
      model = getChatModel();
    } catch {
      return Response.json(
        { error: 'AI service not configured. Contact support.' },
        { status: 503 },
      );
    }

    const fallbacks = getChatFallbackModelIds();
    const modelsToTry = [model, ...fallbacks.map((id) => getChatModel(id))];
    let lastError: unknown;

    for (let i = 0; i < modelsToTry.length; i++) {
      try {
        const result = streamText({
          model: modelsToTry[i],
          system: systemPrompt,
          messages: modelMessages,
          temperature: 0.3,
          maxOutputTokens: 400,
          onFinish: async ({ text }) => {
            const did = debtorId;
            if (!did) return;
            const assistantMessage = typeof text === 'string' ? text : '';
            if (isInitiate) {
              await Promise.allSettled([
                supabaseAdmin.from('conversations').insert([
                  { debtor_id: did, role: 'assistant', message: assistantMessage },
                ]),
                supabaseAdmin
                  .from('debtors')
                  .update({ last_contacted: new Date().toISOString() })
                  .eq('id', did),
              ]);
            } else {
              await Promise.allSettled([
                supabaseAdmin.from('conversations').insert([
                  { debtor_id: did, role: 'user', message: lastMessageText?.trim() || '' },
                  { debtor_id: did, role: 'assistant', message: assistantMessage },
                ]),
                supabaseAdmin
                  .from('debtors')
                  .update({ last_contacted: new Date().toISOString() })
                  .eq('id', did),
              ]);
            }
          },
        });

        return result.toTextStreamResponse();
      } catch (err) {
        lastError = err;
        if (isQuotaOrRateLimitError(err) && i < modelsToTry.length - 1) {
          console.warn('[/api/chat] Quota/rate limit, trying next model', { attempt: i + 1 });
          continue;
        }
        throw err;
      }
    }

    throw lastError;
  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    console.error('[/api/chat]', err.message, err.stack, { error: String(error), name: err.name });

    if (isQuotaOrRateLimitError(error)) {
      return Response.json(
        {
          error:
            'The recovery agent is at capacity right now. Please try again in a few minutes.',
        },
        { status: 503, headers: { 'Retry-After': '60' } },
      );
    }

    return Response.json({ error: 'Internal error' }, { status: 500 });
  }
}
