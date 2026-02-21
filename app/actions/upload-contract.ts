'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { generateEmbedding } from '@/lib/ai-provider';
import { chunkText } from '@/lib/chunking';
import { extractText, getDocumentProxy } from 'unpdf';
import { ensureMerchant } from '@/lib/merchant';

const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB
const CONCURRENCY_LIMIT = 5;

export async function uploadContract(formData: FormData) {
  try {
    const merchantId = await ensureMerchant();
    if (!merchantId) throw new Error('Unauthorized');

    const file = formData.get('contract') as File;
    if (!file) throw new Error('No file provided');

    if (file.size > MAX_FILE_SIZE_BYTES) throw new Error('File too large (max 10 MB)');

    const arrayBuffer = await file.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const isPdf = buffer.length > 4 &&
      buffer[0] === 0x25 && buffer[1] === 0x50 &&
      buffer[2] === 0x44 && buffer[3] === 0x46; 
    if (!isPdf) throw new Error('Only PDF files are accepted');

    const safeFileName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
    const filePath = `merchants/${merchantId}/${safeFileName}`;

    // 1. Upload to Storage FIRST while the buffer is guaranteed to be intact
    const { error: storageError } = await supabaseAdmin.storage
      .from('contracts')
      .upload(filePath, buffer, { contentType: 'application/pdf', upsert: true });

    if (storageError) throw new Error(`Storage error: ${storageError.message}`);

    // 2. Perform text extraction SECOND using a copy of the buffer
    const extractionBuffer = new Uint8Array(buffer.length);
    extractionBuffer.set(buffer);
    
    const pdf = await getDocumentProxy(extractionBuffer);
    const result = await extractText(pdf, { mergePages: true });
    
    // extractText might return text as string or array depending on mergePages option and version
    // But since mergePages: true is passed, it should return a string in newer versions, 
    // or we handle the array case just to be safe.
    const rawText = Array.isArray(result.text) ? result.text.join('\n') : result.text;

    if (!rawText || rawText.trim().length === 0) {
      throw new Error('Could not extract text from PDF.');
    }

    const { data: contract, error: contractError } = await supabaseAdmin
      .from('contracts')
      .insert({
        merchant_id: merchantId,
        file_name: safeFileName,
        file_path: filePath,
        raw_text: rawText,
      })
      .select()
      .single();

    if (contractError) throw new Error(`Contract table error: ${contractError.message}`);

    const chunks = chunkText(rawText);
    
    const embeddingFunction = async (chunk: string) => {
        try {
            const embedding = await generateEmbedding(chunk);
            return {
                contract_id: contract.id,
                content: chunk,
                embedding: embedding,
            };
        } catch (err: any) {
            console.error('Embedding generation failed for chunk:', err.message);
            return null;
        }
    };

    const embeddings = [];
    for (let i = 0; i < chunks.length; i += CONCURRENCY_LIMIT) {
        const batch = chunks.slice(i, i + CONCURRENCY_LIMIT);
        const batchResults = await Promise.all(batch.map(chunk => embeddingFunction(chunk)));
        embeddings.push(...batchResults.filter(Boolean));
    }

    if (embeddings.length > 0) {
        const { error: embeddingsError } = await supabaseAdmin
          .from('contract_embeddings')
          .insert(embeddings);

        if (embeddingsError) {
            console.error('Failed to insert embeddings:', embeddingsError.message);
        }
    } else {
        console.warn('No embeddings generated. RAG will be unavailable for this contract.');
    }

    return { success: true, contractId: contract.id };
  } catch (error: unknown) {
    console.error('Upload Error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: message };
  }
}
