# Dragun.app 🐲

Intelligent, empathetic, and firm debt recovery powered by **Gemini 2.0 Flash**.

## 🚀 Features
- **Agentic Recovery**: AI agents that negotiate with debtors using your specific contract terms.
- **RAG-Powered**: Upload PDF contracts and the AI will cite them during disputes.
- **Stripe Integration**: Automated settlement links for instant clearance.
- **2027 Design**: Mobile-first, dark-mode, high-density bento grid interface.

## 🛠 Tech Stack
- **Frontend**: Next.js 16 (App Router), Tailwind CSS 4, DaisyUI.
- **Backend**: Supabase (PostgreSQL + pgvector).
- **AI**: Gemini 2.0 Flash (via Vercel AI SDK).
- **Payments**: Stripe.

## 🚦 Getting Started

### 1. Prerequisites
- Node.js 20+
- Supabase Project
- Google AI (Gemini) API Key
- Stripe Account

### 2. Environment Variables
Create a `.env.local` file:
```env
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
OPENROUTER_API_KEY=your-openrouter-key
GOOGLE_GENERATIVE_AI_API_KEY=your-gemini-key
STRIPE_SECRET_KEY=your-stripe-key
NEXT_PUBLIC_URL=http://localhost:3000
```

### 3. Database Setup
1. Run the contents of `schema.sql` in your Supabase SQL Editor.
2. Run `seed.sql` to create the initial merchant and debtor records.
3. Enable Storage: Create a bucket named `contracts`.

### 4. Install & Run
```bash
npm install
npm run dev
```

## 📦 Deployment (Vercel)
1. Push this repo to your GitHub: `bioyani/dragun-app`.
2. Connect the repository to Vercel.
3. Add the Environment Variables in the Vercel dashboard.
4. Deploy!

---
Built by **Yani** in the 24-Hour Sprint.
