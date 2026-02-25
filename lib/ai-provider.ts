import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { createOpenAI } from '@ai-sdk/openai';
import { embed } from 'ai';

/**
 * OpenRouter — chat model routing using OPENROUTER_API_KEY.
 * Base URL is required for the OpenRouter API compatibility layer.
 */
const openrouter = createOpenAI({
  apiKey: process.env.OPENROUTER_API_KEY,
  baseURL: 'https://openrouter.ai/api/v1',
  headers: {
    'HTTP-Referer': process.env.OPENROUTER_SITE_URL ?? 'https://dragun.app',
    'X-Title': process.env.OPENROUTER_SITE_NAME ?? 'Dragun.app',
  },
});

/**
 * Google AI — used for embeddings (768-dim) to match existing schema.
 */
const google = createGoogleGenerativeAI({
  apiKey: process.env.GOOGLE_GENERATIVE_AI_API_KEY,
});

/**
 * OpenRouter free router model.
 */
const DEFAULT_OPENROUTER_FREE_MODEL = 'meta-llama/llama-3.1-8b-instruct:free';
const isFreeOpenRouterModel = (model: string) => model.trim().endsWith(':free');

export const getChatModel = () => {
  if (!process.env.OPENROUTER_API_KEY) {
    throw new Error('OPENROUTER_API_KEY is missing');
  }

  const requestedModel = process.env.OPENROUTER_MODEL ?? DEFAULT_OPENROUTER_FREE_MODEL;
  if (!isFreeOpenRouterModel(requestedModel)) {
    console.warn(
      `[ai-provider] Non-free OpenRouter model requested ("${requestedModel}"). Falling back to free model.`
    );
    return openrouter(DEFAULT_OPENROUTER_FREE_MODEL);
  }

  return openrouter(requestedModel);
};

/**
 * Gemini Text-Embedding-004
 * Matches the 768-dimension vector column in Supabase.
 */
export async function generateEmbedding(text: string) {
  const { embedding } = await embed({
    model: google.embedding('text-embedding-004'),
    value: text,
  });
  return embedding;
}
