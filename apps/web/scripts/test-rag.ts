import * as dotenv from 'dotenv';
import path from 'path';

// Load .env
dotenv.config({ path: path.resolve(__dirname, '../.env') });

import { getRagContext } from '../lib/rag';

async function testRag() {
  const merchantId = '00000000-0000-0000-0000-000000000002'; // Venice Gym
  const query = 'I want to cancel my membership immediately';

  console.log(`🔍 Testing RAG with query: "${query}"`);

  try {
    const { context, chunks } = await getRagContext(merchantId, query);

    console.log(`✅ Retrieved ${chunks.length} chunks.`);
    console.log('--- Context Snippet ---');
    console.log(context.slice(0, 500) + '...');
    console.log('-----------------------');

    if (context.includes('30 days written notice')) {
      console.log('✨ SUCCESS: Correct cancellation terms retrieved!');
    } else {
      console.warn('⚠️ WARNING: Expected cancellation terms not found in context.');
    }
  } catch (error) {
    console.error('❌ RAG Test Failed:', error);
  }
}

testRag().catch(console.error);
