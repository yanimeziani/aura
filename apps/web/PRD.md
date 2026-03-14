
Product Requirement Document (PRD): Dragun.app (v1.1)
Project Name	Dragun.app
Owner	Meziani AI
Stack	Next.js 16, Tailwind/DaisyUI, Supabase, Gemini 2.0 Flash
Status	CRITICAL / OVERDUE
Author	Yani (via The Butler)
1. Executive Summary (Revised)
Dragun.app is an automated debt recovery platform owned and operated by Meziani AI. Powered by Gemini 2.0 Flash, it ingests merchant contracts and communication history to function as a knowledgeable, empathetic negotiator.

2. Technical Architecture: The "Bleeding Edge" Stack
You wanted the shiny new toys? Here they are. Do not cut yourself.

2.1 Frontend: The "Face"
Framework: Next.js 16 (RC/Canary).

Usage: Heavy use of Server Actions for form submissions (payment plans) and React Server Components (RSC) for initial data load.

Styling: Tailwind CSS v4 + DaisyUI.

Why: You need mobile-first, dark-mode ready UI components fast. DaisyUI provides pre-built "Chat Bubble", "Stat", and "Card" components essential for the debtor interface.

Hosting: Vercel.

Requirement: Edge Functions for the AI streaming response to ensure low latency on mobile networks.

2.2 Backend & Data: The "Vault"
Core Backend: Supabase.

Database: PostgreSQL.

Auth: Supabase Auth (Passwordless Magic Links for Debtors).

Realtime: Subscribe to transactions table to update Mounir’s dashboard instantly when a payment clears.

Vector Store (The Knowledge Base): Supabase pgvector.

Function: Stores embeddings of the gym's contracts, terms of service, and FAQ.

2.3 AI Engine: The "Brain"
Model: Google Gemini 2.0 Flash.

Why: Sub-second latency. We need the AI to reply to a debtor’s excuse ("I cancelled last month!") instantly.

Context Window: 1M tokens allows us to feed the entire user history and contract into the prompt if needed, reducing RAG complexity.

3. The "Knowledge Base" Implementation (RAG Pipeline)
This is the core upgrade. The AI will not just "chat"; it will cite the contract.

3.1 Data Ingestion
Upload: Mounir uploads Venice_Gym_Membership_Agreement.pdf.

Chunking & Embedding:

Dragun chunks the text (e.g., "Cancellation Policy", "Late Fees").

Generates embeddings via Gemini Text-Embedding-004.

Stores in Supabase vector column.

3.2 The Retrieval Flow (RAG)
When a debtor says: "I shouldn't have to pay, I cancelled in January."

Search: Dragun queries Supabase for chunks related to "cancellation period" and "January".

Retrieve: Finds the clause: "Cancellation requires 30 days written notice."

Generate (Gemini 2.0 Flash):

Input: User query + Retrieved Clause + Tone Guidelines (Empathetic but Firm).

Output: "I understand, Yani. However, looking at the agreement, cancellation requires 30 days' notice. Since the notice wasn't received, the January payment is still valid. We can split this into two payments if that helps?"

4. Functional Requirements (Updated)
4.1 Merchant Dashboard (Next.js 16)
Upload Zone: Drag-and-drop area for PDF contracts (feeds the Knowledge Base).

Agent Configuration:

"Strictness Level" slider (Soft Nudge vs. Legal Notice).

Define "Settlement Floor" (e.g., "Accept no less than 80%").

4.2 Debtor Mobile View (DaisyUI)
Chat Interface: A WhatsApp-like view using DaisyUI chat bubbles.

Streaming: Responses stream in real-time via Vercel AI SDK.

Action Chips: One-tap replies suggested by Gemini ("I'll pay now", "Remind me Friday", "Dispute debt").

Stripe Elements: Embedded checkout sheet.

5. Development Roadmap (The "24-Hour Sprint")
Master Yani, you have no time for a roadmap. You have a checklist.


Hour 2-6: Build the "Knowledge Base" uploader. Get the PDF parsing working.

Hour 6-12: Connect Gemini 2.0 Flash API. Build the system prompt: "You are a debt recovery specialist. You must cite the retrieved context."

Hour 12-18: Stripe Connect integration. This will hurt. Do it while listening to "Pesetas".

Hour 18-24: Deploy to Vercel. Send link to Mounir.