# UX Distill: Laws of UX + Vercel Frontend Cloud

**Status:** Condensed operator memory (not a substitute for originals).  
**Sources:** [Laws of UX](https://lawsofux.com/) (Jon Yablonski); Vercel [Customer-first, experience-first, AI-first: The Frontend Cloud](https://vercel.com/resources/customer-first-experience-first-ai-first-the-frontend-cloud) (Oct 2023) and [The foundations of the Frontend Cloud](https://vercel.com/blog/the-foundations-of-the-frontend-cloud) (Nov 2023).

## 1) Laws of UX — grouped for design decisions

**Speed and control**  
- **Doherty threshold:** Keep interactive loops under ~**400ms** so neither human nor machine is waiting unnecessarily.  
- **Fitts’s Law:** Larger, closer targets are faster to hit—prioritize primary actions.  
- **Hick’s Law:** More (and harder) choices slow decisions—**reduce and sequence** options.

**Memory and perception**  
- **Miller’s Law / working memory:** People hold only a handful of items in play (~**7±2** is the rule of thumb); **chunk** information.  
- **Serial position effect:** First and last items in a list are remembered best—put anchors there.  
- **Peak–end rule:** Judgment is shaped by **peaks** and **how it ends**—design onboarding and exits deliberately.  
- **Von Restorff (isolation) effect:** What differs gets remembered—use contrast sparingly for **true** priorities.  
- **Law of Prägnanz:** People resolve ambiguity toward the **simplest** interpretation—favor clear, minimal forms.  
- **Aesthetic–usability effect:** Polished visuals read as **more usable**—aesthetics are not vanity.

**Grouping and layout (Gestalt)**  
- **Proximity, similarity, common region, uniform connectedness:** Group related controls and content **visually** so structure matches meaning.

**Expectations and standards**  
- **Jakob’s Law:** Users expect your product to behave like **what they already know**—leverage familiar patterns.  
- **Postel’s Law:** Be **liberal in what you accept** from users (inputs, formats) and **conservative in what you emit** (stable, predictable outputs).

**Complexity and honesty**  
- **Tesler’s Law (conservation of complexity):** Some complexity **cannot** vanish—**decide who carries it** (user vs. system vs. operator), don’t pretend it’s gone.  
- **Cognitive load:** Every novel element taxes attention—**cut noise**, defer depth.  
- **Chunking:** Break long information into meaningful groups.

**Motivation and flow**  
- **Goal-gradient:** Progress accelerates near the goal—show **clear progress**.  
- **Zeigarnik effect:** Incomplete tasks stick in memory—use for **honest** continuity (save state), not manipulation.  
- **Flow:** Uninterrupted, well-matched challenge supports deep work—protect focus states in tools.  
- **Selective attention:** People filter to goals—**signal hierarchy** must match user intent.

**Product realism**  
- **Paradox of the active user:** People **skip manuals**—the UI must be self-explanatory.  
- **Choice overload:** Too many options **paralyze**—defaults and curation matter.  
- **Occam’s Razor / Pareto / Parkinson:** Prefer simpler explanations, focus on the **vital few**, and bound time so work **does not expand** without limit.

## 2) Vercel “Frontend Cloud” distill (vendor-agnostic takeaways)

**Strategic framing**  
- **Customer-first, experience-first, AI-first:** The **experience layer** is the main lever for retention and differentiation; treat it as a first-class engineering concern, not paint on top of backend.  
- **UX ∩ DX:** Velocity and quality are **one system**—slow, fragile deploys show up as stale UX.

**What “frontend” means in this model**  
- **Frontend = everything that serves external clients:** UI, code on device, **edge-facing** APIs, SSR/asset paths, CDNs, ingress—**not** only CSS pixels.

**Architecture**  
- **Decouple** frontend from monolithic backend where iteration speed and blast radius differ; **reconnect** through a clear API or framework-level data access so boundaries stay controlled.  
- **Framework-defined infrastructure (FdI):** Predictable build outputs let platforms **map code → infra** (routing, functions, assets) with less bespoke ops.  
- **Serverless pattern (conceptual):** Stateless, isolated, event-driven units that **scale with demand** and reduce always-on waste—good fit for bursty, global traffic.

**Operational pillars (extract the pattern, not the vendor)**  
- **Global delivery:** Edge caching and low-latency paths as defaults.  
- **Workflow:** Integrated **preview**, test, and deploy tied to **immutable** revisions.  
- **Observability:** Performance and errors visible to the team building the experience.  
- **Security/compliance:** Auditability and data controls as part of the delivery surface, not an afterthought.  
- **AI-facing web:** Streaming and dynamic composition benefit from **fast edge paths** and composable stacks—design for **change**, not one-off hacks.

**Mindset**  
- **Backend cloud as cost center / frontend as profit center** is rhetoric—but the underlying point stands: **under-investing in the client layer** creates churn, support load, and trust debt.

## 3) Synthesis for Nexa / mesh surfaces

- **Mesh Kotlin portal** and any interim UI should **obey** Laws of UX on **load, grouping, conventions, and feedback latency**; cross-check with `docs/UNIFIED_ACCESS.md` and `docs/MONTESSORI_FRONTEND_SKILLS.md`.  
- **Tesler + cognitive load** reinforce **honest** complexity placement—aligned with “truth only by math” and calm, educative tone.  
- **Frontend Cloud** lessons justify **decoupled** client evolution against **stable** gateway/protocol contracts—without requiring any particular commercial host or framework.  
- **Vendor content** here is **reference only**; stack and dependency rules in `docs/AGENTS.md` still win on implementation choices.
