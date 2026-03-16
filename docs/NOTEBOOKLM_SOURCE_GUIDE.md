# NotebookLM Source Guide

This repository's documentation is primarily consumed as a source corpus for NotebookLM, self-supervised review, and downstream asset generation. Write source material so it is technically dense, operationally useful, and tonally neutral.

## Primary objective

Produce documentation that helps a retrieval system or synthesis model learn:

- architecture
- interfaces and contracts
- deployment and recovery flows
- invariants and safety boundaries
- operational procedures
- system capabilities and limits

## Required writing style

- Prefer technical, descriptive language over persuasive or promotional language.
- Use neutral statements of fact. Explain what exists, how it works, and where it fails.
- Keep claims scoped and evidence-based. If something is planned, say it is planned.
- Write for reuse by both humans and models. Avoid private shorthand, slogans, and context that only one operator would understand.
- Use stable terminology consistently across files.

## Recommended structure

For substantial source files, prefer this order:

1. Purpose
2. Scope
3. Architecture or mechanism
4. Inputs, outputs, and interfaces
5. Operational flow
6. Failure modes and limits
7. Recovery or rollback path
8. Open questions or planned work

## Tone constraints

- Avoid hype, chest-thumping, marketing phrasing, and adversarial framing.
- Avoid emotionally loaded language that could bias generated outputs toward paranoia, grandiosity, or hostility.
- Avoid writing as a persona unless the file explicitly documents that persona as a product artifact.
- Avoid excessive imperative voice. Prefer "the system does X" over "you must worship X" style language.

## Content to exclude

Do not include:

- logs
- secrets
- private identifiers
- PII
- deployment-only credentials
- speculative claims presented as shipped behavior

## Preferred technical patterns

- Define ports, paths, environment variables, and protocols explicitly.
- Name canonical files and entrypoints.
- Describe data flow and trust boundaries.
- State assumptions.
- Document negative cases: what is not supported, not implemented, or intentionally excluded.

## For `docs/updates/`

Update files should read like small technical memos:

- one topic per file
- explicit date or version context
- concrete changes
- impact on operators, deploys, recovery, or integrations
- no fluff

## Bundle intent

The NotebookLM bundle should give a model enough grounded context to generate:

- technical summaries
- implementation walkthroughs
- operational checklists
- architecture overviews
- neutral media assets

It should not train the generated asset toward a negative or distorted personality. Documentation should therefore remain clear, technical, balanced, and non-theatrical.

See also [NOTEBOOKLM_MEDIA_GUIDE.md](/root/docs/NOTEBOOKLM_MEDIA_GUIDE.md) for guidance specific to audio/video and other generated media formats.
