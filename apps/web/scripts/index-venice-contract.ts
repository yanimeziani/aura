import * as dotenv from 'dotenv';
import path from 'path';

// Load .env from the parent directory (apps/web/.env)
dotenv.config({ path: path.resolve(__dirname, '../.env') });

import { supabaseAdmin } from '../lib/supabase-admin';
import { generateEmbedding } from '../lib/ai-provider';
import { chunkText } from '../lib/chunking';

async function indexContract(contractId: string) {
  console.log(`🚀 Starting indexing for contract: ${contractId}`);

  // 1. Fetch raw text
  const { data: contract, error: fetchError } = await supabaseAdmin
    .from('contracts')
    .select('raw_text, merchant_id')
    .eq('id', contractId)
    .single();

  if (fetchError || !contract?.raw_text) {
    console.error('❌ Failed to fetch contract text:', fetchError);
    return;
  }

  console.log('📝 Text fetched. Chunking...');

  // 2. Chunk text
  const chunks = chunkText(contract.raw_text, 1000, 200);
  console.log(`📦 Created ${chunks.length} chunks.`);

  // 3. Clear existing embeddings for this contract (to avoid duplicates)
  await supabaseAdmin
    .from('contract_embeddings')
    .delete()
    .eq('contract_id', contractId);

  // 4. Generate embeddings and insert
  for (const [index, chunk] of chunks.entries()) {
    console.log(`[${index + 1}/${chunks.length}] Embedding chunk...`);
    const embedding = await generateEmbedding(chunk);

    if (embedding) {
      const { error: insertError } = await supabaseAdmin
        .from('contract_embeddings')
        .insert({
          contract_id: contractId,
          content: chunk,
          embedding: embedding,
          metadata: { chunk_index: index, merchant_id: contract.merchant_id }
        });

      if (insertError) {
        console.error(`❌ Failed to insert chunk ${index}:`, insertError);
      }
    } else {
      console.warn(`⚠️ Skipping chunk ${index} due to embedding failure.`);
    }
  }

  console.log('✅ Indexing complete!');
}

// Venice Gym Contract ID from mounir_onboarding.sql
const VENICE_CONTRACT_ID = '22222222-2222-2222-2222-222222222222';

indexContract(VENICE_CONTRACT_ID).catch(console.error);
