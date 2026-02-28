import { supabaseAdmin } from './supabase-admin';
import { getChatModel } from './ai-provider';
import { getRagContext, RAG_QUERIES } from './rag';
import { streamText } from 'ai';

export async function getDebtorChatResponse(debtorId: string, message: string) {
  const { data: debtor, error: debtorError } = await supabaseAdmin
    .from('debtors')
    .select('*, merchant:merchants(*)')
    .eq('id', debtorId)
    .single();

  if (debtorError || !debtor) throw new Error('Debtor not found');

  const merchant = debtor.merchant;

  const { context } = await getRagContext(merchant.id, RAG_QUERIES.chat(message), {
    matchCount: 5,
    matchThreshold: 0.5,
  });

  // 5. Build system prompt
  const systemPrompt = `
    You are Dragun.app, an automated debt recovery agent powered by Gemini 2.0 Flash.
    Your tone is empathetic but firm.
    Merchant: ${merchant.name}
    Debtor: ${debtor.name}
    Total Debt: ${debtor.currency} ${debtor.total_debt}
    Merchant Strictness: ${merchant.strictness_level}/10 (1 is soft, 10 is firm legal notices).
    Merchant Settlement Floor: ${merchant.settlement_floor * 100}% of the total debt.

    INSTRUCTIONS:
    - You must cite the contract context if provided.
    - If the debtor makes an excuse, check the contract.
    - Offer settlement plans within the settlement floor if they seem unable to pay.
    - Keep it WhatsApp-style (short paragraphs).
    
    CONTRACT CONTEXT:
    ${context || 'No specific contract context found. Use general empathetic but firm principles.'}
  `;

  // 6. Return stream
  return streamText({
    model: getChatModel(), 
    system: systemPrompt,
    prompt: message,
    // Add history here if needed
  });
}
