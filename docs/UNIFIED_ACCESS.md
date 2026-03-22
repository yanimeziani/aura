# UNIFIED_ACCESS.md

Status: Single canonical contract for **accessible**, **neurodiversity-friendly**, and **age-friendly** experiences across Nexa surfaces.

## 1) Purpose

One bar for everyone: interfaces and communications must be easy to perceive, understand, and use without assuming a single “typical” user. This document merges accessibility (disability-inclusive), cognitive and sensory diversity (neurodiversity), and life-span usability (age-friendly) so agents and builders do not chase three separate checklists.

Non-goals: motivational or emotional copywriting; those belong outside engineering specs. See [PHILOSOPHY.md](../PHILOSOPHY.md) for values; this file is **how** we build and write **product and operator** material.

## 2) Scope

Applies to:

- Operator and public UIs (`apps/*`), status pages, forms, and dashboards
- CLI output that humans read regularly (progress, errors, help text)
- User-facing documentation, onboarding, and agent-generated summaries intended for people

Does not replace `SECURITY.md`, `LEGAL.md`, or threat modeling; it sits beside them.

## 3) Unified principles

| Principle | What it means |
|-----------|----------------|
| **Plain language** | Short sentences, common words, define jargon once or link to a glossary. |
| **Predictable structure** | Same labels and order for recurring tasks; no surprise rearrangements without notice. |
| **Low cognitive load** | One primary action per screen where possible; optional detail collapsed or linked. |
| **Sensory choice** | Do not rely on color, sound, or motion alone; provide text equivalents and pause/disable for motion. |
| **Motor tolerance** | Large hit targets, forgiving timeouts, undo where safe; full keyboard path for web UIs. |
| **Time tolerance** | Save state; allow resume; avoid unnecessary real-time-only flows. |

## 4) Accessibility baseline (technical)

For web surfaces, treat the following as **default**, not stretch goals:

- Perceivable text: user-resizable type without loss of core function; minimum contrast for body text (prefer high-contrast theme or toggle).
- Keyboard: visible focus, logical tab order, no keyboard traps.
- Non-text content: alternative text for meaningful images; captions or transcripts for essential audio/video.
- Forms: labels tied to controls; errors state what happened and how to fix it.
- Motion: respect `prefers-reduced-motion`; avoid auto-playing distracting animation.

Map features to WCAG 2.2 intent where relevant; formal audit can cite specific success criteria per release.

## 5) Neurodiversity-friendly patterns

- Prefer **literal titles** over clever ones; avoid ambiguous icons without text.
- Offer **TL;DR + detail**: summary first, depth on demand.
- Use **consistent vocabulary** across the product; one term per concept.
- Avoid **walls of dense text**; break into headings, lists, and white space.
- **Announce changes**: if behavior or layout shifts, say so in release notes and in-product once.
- **Optional channels**: where helpful, offer reading vs listening (e.g. transcript), not as a replacement for accessibility requirements.

## 6) Age-friendly patterns

- **Readable defaults**: comfortable base font size, adequate line spacing, high-legibility typefaces in UI.
- **Touch and pointer**: targets large enough for tremor or lower precision; spacing to reduce mis-taps.
- **Progressive disclosure**: advanced settings tucked away; core tasks obvious.
- **Trust and safety**: clear, calm error messages; no shame-oriented wording.

## 7) Copy and agent output

- **Neutral and factual**; avoid hype, fear, or guilt.
- **Actionable**: say what the user can do next.
- **Inclusive address**: prefer second person or neutral “you” for instructions; avoid assumptions about age, ability, or identity.

## 8) Verification (lightweight)

Before shipping or merging user-facing change:

1. Can someone use the **keyboard** (web) or **screen reader** for the main path?
2. Is there a **high-contrast** or **theme** path, or sufficient default contrast?
3. Is copy **scannable** (headings, short paragraphs)?
4. Are **errors** and **empty states** clear without blame?
5. Were **motion/audio** alternatives considered?

Record gaps in `TASKS.md` if not fixed in the same change.

## 9) Related: Montessori-aligned UI

For **prepared-environment** layout, order, autonomy, and concentration-friendly interaction patterns on top of this baseline, see [MONTESSORI_FRONTEND_SKILLS.md](./MONTESSORI_FRONTEND_SKILLS.md).

## 10) Memory sync

When inclusive requirements change:

- Update this file and `docs/RAG_CORPUS_MANIFEST.md` if corpus boundaries change.
- Touch `docs/SEED.md` or `docs/MESH_WORLD_MODEL.md` only when the memory plane or system map must reflect a new invariant; update `docs/MONTESSORI_FRONTEND_SKILLS.md` in the same change if calm-workflow or autonomy patterns shift.
