/**
 * AI provider layer: chat and embeddings.
 * Switch providers via env (AI_PROVIDER=groq|local, etc.) without changing call sites.
 * Local: OpenAI-compatible API on this server (Ollama, LM Studio, vLLM, etc.).
 */

import { groq } from '@ai-sdk/groq';
import { createOpenAI } from '@ai-sdk/openai';
import { embed } from 'ai';

const PROVIDER = (process.env.AI_PROVIDER ?? 'groq').toLowerCase();

/** Default chat model for Groq (free tier). */
const GROQ_DEFAULT_MODEL = 'llama-3.3-70b-versatile';

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

/** Default base URL for local provider (Ollama). */
const LOCAL_DEFAULT_BASE = 'http://127.0.0.1:11434/v1';

/** Default chat model for local (Ollama-style name). */
const LOCAL_DEFAULT_MODEL = 'llama3.2';

function getGroqModel(modelId?: string) {
  const id = modelId ?? process.env.GROQ_MODEL?.trim() ?? GROQ_DEFAULT_MODEL;
  if (!process.env.GROQ_API_KEY) {
    throw new Error('GROQ_API_KEY is required. Get one free at console.groq.com');
  }
  return groq(id);
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
 * - local: uses LOCAL_API_BASE_URL + LOCAL_EMBEDDING_MODEL if set (e.g. nomic-embed-text, 768 dims).
 * - groq: no embeddings; when OPENAI_API_KEY is set uses OpenAI with 768 dimensions.
 * Otherwise returns null (RAG skips vector context).
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

  const key = process.env.OPENAI_API_KEY?.trim();
  if (!key) return null;

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
