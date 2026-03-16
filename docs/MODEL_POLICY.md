# Nexa Model Policy

## Purpose

This document defines the default model posture for Nexa as an OSS collaboration stack.

The goal is not to bind the system to one provider. The goal is to keep one canonical model policy across gateway, automation, docs, and edge deployments.

## Default Roles

### Collaborative default

- Model family: `Qwen3-Coder`
- Intended role: default shared coding and collaboration model for OSS publication, review, implementation, and agentic task execution
- Typical deployment: remote or shared control-plane inference

### Edge/mobile fallback

- Model family: `Qwen2.5-Coder-7B-Instruct`
- Intended role: phone-local and edge-local fallback for offline coding, recovery operations, and constrained agent sessions
- Typical deployment: quantized local runtime on operator devices

### Phone runtime baseline

- Runtime: `MLC Engine`
- Backend: `Vulkan`
- Device class: Android flagship phones such as Samsung Galaxy Z Fold5

## Routing Rules

- If a task is collaborative, repo-wide, or agentic and shared across operators, prefer the collaborative default.
- If a task must run on a phone, in degraded connectivity, or under strict power/memory limits, prefer the edge/mobile fallback.
- Do not spawn one heavyweight local model per agent on mobile devices. Multiplex many agent sessions through one local runtime.
- Use remote escalation for long-horizon reasoning, broad refactors, or many-file planning tasks that exceed phone thermal or memory envelopes.

## Environment Contract

- `NEXA_DEFAULT_COLLAB_MODEL`: canonical shared model
- `NEXA_DEFAULT_EDGE_MODEL`: canonical local/edge fallback
- `NEXA_PHONE_RUNTIME`: canonical mobile runtime label
- `OPENAI_MODEL_NAME`: active OpenAI-compatible provider model override when the gateway is pointed at a compatible remote provider

## Current Defaults

- `NEXA_DEFAULT_COLLAB_MODEL=Qwen/Qwen3-Coder-480B-A35B-Instruct`
- `NEXA_DEFAULT_EDGE_MODEL=qwen2.5-coder:7b-instruct`
- `NEXA_PHONE_RUNTIME=mlc-vulkan`

## Operational Guidance

- Treat the collaborative default as the public OSS baseline.
- Treat the edge model as the portable continuity layer.
- Preserve explicit routing in docs and configs so contributors understand when a phone-local session is expected to differ from the shared collaborative path.
