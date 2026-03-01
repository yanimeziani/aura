import { createOpenAI } from '@ai-sdk/openai';
import { embed } from 'ai';

const openrouter = createOpenAI({
  apiKey: process.env.OPENROUTER_API_KEY || '',
  baseURL: 'https://openrouter.ai/api/v1',
  headers: {
    'HTTP-Referer': process.env.OPENROUTER_SITE_URL ?? 'https://dragun.app',
    'X-Title': process.env.OPENROUTER_SITE_NAME ?? 'Dragun.app',
  },
});

/**
 * OpenRouter free inference.
 * - OPENROUTER_MODEL: use this model (e.g. deepseek/deepseek-chat-v3-0324:free).
 * - Unset: use openrouter/free router (OpenRouter picks a free model; no hardcoded IDs).
 */
const OPENROUTER_FREE_ROUTER = 'openrouter/free';

/** Specific free models to try as fallback when the router hits quota/rate limit. */
export const OPENROUTER_FREE_FALLBACK_MODELS = [
  'stepfun/step-3.5-flash:free',
  'meta-llama/llama-3.2-3b-instruct:free',
  'qwen/qwen-2.5-7b-instruct:free',
] as const;

export const getChatModel = (modelOverride?: string) => {
  if (!process.env.OPENROUTER_API_KEY) {
    throw new Error('OPENROUTER_API_KEY is required. Get one free at openrouter.ai');
  }

  const explicit = modelOverride ?? process.env.OPENROUTER_MODEL?.trim();
  if (explicit) {
    return openrouter(explicit);
  }

  return openrouter(OPENROUTER_FREE_ROUTER);
};

/**
 * Embeddings for RAG via OpenRouter (free nomic-embed model).
 * Returns null if no API key -- RAG simply skips context retrieval.
 */
export async function generateEmbedding(text: string) {
  if (!process.env.OPENROUTER_API_KEY) {
    return null;
  }

  try {
    const { embedding } = await embed({
      model: openrouter.embedding('nomic-ai/nomic-embed-text-v1.5'),
      value: text,
    });
    return embedding;
  } catch (e) {
    console.error('Embedding generation failed:', e);
    return null;
  }
}
