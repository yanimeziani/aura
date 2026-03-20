import * as dotenv from 'dotenv';
import path from 'path';

// Load .env
dotenv.config({ path: path.resolve(__dirname, '../.env') });

import { createOpenAI } from '@ai-sdk/openai';
import { generateText } from 'ai';

async function researchTreevans() {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    console.error('❌ GROQ_API_KEY missing in .env');
    return;
  }

  const groq = createOpenAI({
    apiKey,
    baseURL: 'https://api.groq.com/openai/v1',
  });

  console.log('🔍 Researching "Treevans" in Quebec City...');

  try {
    const { text } = await generateText({
      model: groq.chat('llama-3.3-70b-versatile'),
      system: `You are a B2B research agent. Find information about "Treevans" (or similar names like "Treevan") in Quebec City. 
               Identify: 
               1. Their business model (e.g., van conversion, tree care, etc.).
               2. Their likely "Automation Pain Points" (e.g., complex custom orders, inventory management, Law 25 privacy).
               3. How the Dragun AI or Aura Skill Mesh could integrate with them.`,
      prompt: 'Research Treevans Quebec City for a $1,000 AI automation audit.',
    });

    console.log('✅ Research Complete:\n');
    console.log(text);
    
    // Save to research folder
    const researchDir = path.resolve(__dirname, '../../research');
    require('fs').writeFileSync(path.join(researchDir, 'treevans_research.md'), text);
    console.log(`\n📁 Saved to research/treevans_research.md`);

  } catch (error) {
    console.error('❌ Research Failed:', error);
  }
}

researchTreevans().catch(console.error);
