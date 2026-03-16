# Legacy Policy

## Purpose

Nexa is pre-production. The repository should not carry legacy dump artifacts, giant owner-specific exports, or stale branding baggage that obscures the actual architecture.

## What Is Excluded

The main repository should not retain:

- monolithic source dumps
- one-off documentation exports
- generated launch artifacts tied to old branding
- owner-specific audit or commercial documents that no longer represent the project
- large archival bundles that are not part of the active build, deploy, or documentation flow

## Allowed Legacy Material

Legacy material is allowed only if it is:

- still required for the active build or runtime
- under explicit migration
- documented as legacy and isolated from the canonical OSS surface

## Rule

If a file makes the repository look like a private stack dump, a weekend project, or a stale personal archive, it should be removed or isolated outside the canonical repo surface.
