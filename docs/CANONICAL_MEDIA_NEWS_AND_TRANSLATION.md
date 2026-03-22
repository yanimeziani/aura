# CANONICAL: Media, News, and Translation

**Status:** Binding contract for Meziani Studio (movies, educative / Montessori-friendly work), global radio, and the news network layer.  
**Scope:** Single linguistic source of truth, quantitative spine, downstream localization only.

## 1) Core language (non-negotiable)

- All **editorial truth, numbers, methods, and caveats** are authored and frozen in **one designated core language** (current default: **English**).
- Changing the core language is an **operator-level decision**: update this section in the same change that updates glossaries and agent prompts.

## 2) Translation agent (downstream only)

- A **core translation agent** consumes **only** the frozen core artifact plus **glossary / do-not-translate / numeric integrity** rules.
- It **must not** add facts, soften uncertainty, invent sources, or rewrite the quantitative meaning.
- Locale work is **localization of wording**, not a second editorial desk. Numbers, units, dates, and legal names pass through explicit rules.

## 3) Truth only by math

- Strong claims require **quantitative backing** (data, model, or stated uncertainty) in the **core** artifact before any translation runs.
- Translations **inherit** the same figures and uncertainty; they do not “simplify” risk away.

## 4) Montessori-friendly and educative media

- Studio and news copy in core language prioritizes **clarity, concrete steps, and calm tone** per `docs/MONTESSORI_FRONTEND_SKILLS.md` and `docs/UNIFIED_ACCESS.md` where applicable.
- Translation preserves **cognitive load profile** (short sentences for radio, speakable numbers, no manipulative urgency).

## 5) Compliance hooks

- Generative and distributable media remain subject to `docs/MEZIANI_AI_AUDIT_MEDIA_GEN_AI_FORGE.md` (provenance, biological safety audit, HITL, staging under `vault/media_staging/`).

## 6) Traceability

- Pipelines should log: **core artifact id / hash → translation job id → locale outputs** so every published language traces to one core spine.
