import * as dotenv from 'dotenv';
import path from 'path';

// Load .env from the parent directory
dotenv.config({ path: path.resolve(__dirname, '../.env') });

import { createOpenAI } from '@ai-sdk/openai';
import { generateText } from 'ai';

async function generateLeads() {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    console.error('❌ GROQ_API_KEY missing in .env');
    return;
  }

  const groq = createOpenAI({
    apiKey,
    baseURL: 'https://api.groq.com/openai/v1',
  });

  console.log('🔍 Generating 10 high-value Gym/Wellness leads in Quebec City via Groq...');

  try {
    const { text } = await generateText({
      model: groq.chat('llama-3.3-70b-versatile'),
      system: `You are a B2B growth agent. Search for and provide a list of 10 real, high-end gyms, wellness centers, or physical therapy clinics in Quebec City (QC, Canada).
               For each, include: Name, Website, and a one-sentence "Automation Pain Point" (e.g., manual payment recovery, high Law 25 risk).
               Format: CSV style (Name, Website, Pain Point).`,
      prompt: "Find 10 high-end wellness/gym leads in Quebec City for an AI automation audit.",
    });

    console.log('✅ Leads Generated:\n');
    console.log(text);
    
    // Write to research folder
    const researchDir = path.resolve(__dirname, '../../research');
    if (!require('fs').existsSync(researchDir)) {
      require('fs').mkdirSync(researchDir);
    }
    require('fs').writeFileSync(path.join(researchDir, 'quebec_smb_leads.csv'), text);
    console.log(`\n📁 Saved to research/quebec_smb_leads.csv`);

  } catch (error) {
    console.error('❌ Lead Generation Failed:', error);
  }
}

generateLeads().catch(console.error);
