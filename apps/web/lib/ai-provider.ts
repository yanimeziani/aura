/**
 * AI provider layer: chat and embeddings.
 * Switch providers via env (AI_PROVIDER=groq|local, etc.) without changing call sites.
 * Local: OpenAI-compatible API on this server (Ollama, LM Studio, vLLM, etc.).
 */

import { groq } from '@ai-sdk/groq';
import { createOpenAI } from '@ai-sdk/openai';
import { embed } from 'ai';

const PROVIDER = (process.env.AI_PROVIDER ?? 'local').toLowerCase();

/** Default chat model for Groq (free tier). */
const GROQ_DEFAULT_MODEL = 'llama-3.3-70b-versatile';

/** Default chat model for OpenRouter (free models). */
const OPENROUTER_DEFAULT_MODEL = 'google/gemini-2.0-flash-exp:free';

/** Fallback chat model ids when primary hits quota/rate limit (Groq). */
export const CHAT_FALLBACK_MODELS = [
  'llama-3.1-8b-instant',
  'llama-3.1-70b-versatile',
] as const;

/** Fallback model ids for the current provider (local uses env LOCAL_FALLBACK_MODELS or none). */
export function getChatFallbackModelIds(): string[] {
  if (PROVIDER === 'local') {
    const raw = process.env.LOCAL_FALLBACK_MODELS?.trim();
    return raw ? raw.split(',').map((s) => s.trim()).filter(Boolean) : [];
  }
  return [...CHAT_FALLBACK_MODELS];
}

/** Default base URL for local provider (Aura gateway → Ollama mesh). */
const LOCAL_DEFAULT_BASE = process.env.LOCAL_API_BASE_URL?.trim() || 'http://localhost:8765/v1';

/** Default chat model for local (Ollama-style name). */
const LOCAL_DEFAULT_MODEL = 'llama3.2';

function getGroqModel(modelId?: string) {
  const id = modelId ?? process.env.GROQ_MODEL?.trim() ?? GROQ_DEFAULT_MODEL;
  if (!process.env.GROQ_API_KEY) {
    throw new Error('GROQ_API_KEY is required. Get one free at console.groq.com');
  }
  return groq(id);
}

function getOpenRouterModel(modelId?: string) {
  const id = modelId ?? process.env.OPENROUTER_MODEL?.trim() ?? OPENROUTER_DEFAULT_MODEL;
  const apiKey = process.env.OPENROUTER_API_KEY?.trim();
  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY is required for OpenRouter provider.');
  }
  const openrouter = createOpenAI({
    apiKey,
    baseURL: 'https://openrouter.ai/api/v1',
  });
  return openrouter(id);
}

function getLocalModel(modelId?: string) {
  const base = process.env.LOCAL_API_BASE_URL?.trim() || LOCAL_DEFAULT_BASE;
  const id = modelId ?? process.env.LOCAL_MODEL?.trim() ?? LOCAL_DEFAULT_MODEL;
  const apiKey = process.env.LOCAL_API_KEY?.trim() || 'ollama';
  const openai = createOpenAI({ apiKey, baseURL: base });
  return openai(id);
}

/**
 * Returns the chat model for the configured provider.
 * Override: optional model id (used for fallbacks in chat route).
 */
export function getChatModel(modelOverride?: string) {
  switch (PROVIDER) {
    case 'local':
      return getLocalModel(modelOverride);
    case 'groq':
      return getGroqModel(modelOverride);
    case 'openrouter':
      return getOpenRouterModel(modelOverride);
    default:
      return getGroqModel(modelOverride);
  }
}

/** contract_embeddings table expects VECTOR(768). */
const EMBEDDING_DIMENSIONS = 768;

/** Local embedding model (Ollama: nomic-embed-text is 768 dims, matches DB). */
const LOCAL_DEFAULT_EMBEDDING_MODEL = 'nomic-embed-text';

/**
 * Embeddings for RAG.
 */
export async function generateEmbedding(text: string): Promise<number[] | null> {
  if (PROVIDER === 'local') {
    const base = process.env.LOCAL_API_BASE_URL?.trim() || LOCAL_DEFAULT_BASE;
    const modelId = process.env.LOCAL_EMBEDDING_MODEL?.trim() || LOCAL_DEFAULT_EMBEDDING_MODEL;
    const apiKey = process.env.LOCAL_API_KEY?.trim() || 'ollama';
    try {
      const openai = createOpenAI({ apiKey, baseURL: base });
      const { embedding } = await embed({
        model: openai.embedding(modelId),
        value: text,
      });
      return embedding?.length ? embedding : null;
    } catch (e) {
      console.error('Local embedding failed:', e);
      return null;
    }
  }

  // Check OpenRouter first if using it as provider
  const orKey = process.env.OPENROUTER_API_KEY?.trim();
  if (PROVIDER === 'openrouter' && orKey) {
    try {
      const openrouter = createOpenAI({ apiKey: orKey, baseURL: 'https://openrouter.ai/api/v1' });
      const { embedding } = await embed({
        model: openrouter.embedding('google/text-embedding-004'),
        value: text,
      });
      return embedding;
    } catch (e) {
      console.error('OpenRouter embedding failed:', e);
    }
  }

  const key = process.env.OPENAI_API_KEY?.trim();
  if (!key) {
    // Mock embedding for Pilot/Demo when no key is present to prevent crashes
    console.warn('⚠️ No embedding key found. Using zero-vector mock for RAG.');
    return new Array(EMBEDDING_DIMENSIONS).fill(0);
  }

  try {
    const openai = createOpenAI({ apiKey: key });
    const modelId = process.env.OPENAI_EMBEDDING_MODEL?.trim() || 'text-embedding-3-small';
    const supportsDimensions = modelId.startsWith('text-embedding-3');
    const { embedding } = await embed({
      model: openai.embedding(modelId),
      value: text,
      ...(supportsDimensions && {
        providerOptions: { openai: { dimensions: EMBEDDING_DIMENSIONS } },
      }),
    });
    return embedding;
  } catch (e) {
    console.error('Embedding generation failed:', e);
    return null;
  }
}
