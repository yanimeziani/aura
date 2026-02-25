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
export const getChatModel = () => openrouter('openrouter/free');

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
