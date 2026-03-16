# Distributed OSS inference — offline & local-mesh coding

**Goal:** Code at high velocity on devices like Samsung Z Fold (or any phone/tablet/laptop) in two modes:

1. **No network** — Fully offline; inference runs on the device or on a local peer.
2. **WiFi, no internet** — Local network only; no cloud APIs. The **whole org’s distributed compute** runs the best OSS model for each task and routes requests across available nodes.

No dependency on online providers; the mesh *is* the provider, using open-weight models and org-owned hardware.

---

## Why it fits Aura

- **Sovereign mesh** — Data and inference stay on your devices and LAN.
- **Already mesh-first** — Gateway today prefers Ollama (local) over Groq; we extend “local” to “any node in the org mesh.”
- **One entry point** — Cursor/IDE points at the gateway; the gateway decides *where* and *which model* runs each request.

---

## Architecture (target state)

### 1. Offline on device (no WiFi)

- **Client:** PWA or native app on Z Fold (Mission Control / Cursor-like UX).
- **Inference on device:** Small OSS model (e.g. Phi-3 mini, Qwen2-0.5B, or TinyLlama) via:
  - **Ollama Android** (when available), or
  - **WebAssembly / ONNX** in the browser or a lightweight runtime (e.g. Transformers.js, llama.cpp WASM).
- **Use case:** Completions, short edits, navigation. When back on WiFi, sync and optionally offload heavier tasks to the mesh.

### 2. Local mesh (WiFi, no internet)

- **Gateway** (today’s `aura gateway`) stays the single API entry point: `/v1/chat/completions`, `/v1/models`, etc.
- **Inference nodes:** Each node is a device (laptop, workstation, NAS, or phone running a server) that:
  - Runs an **Ollama-compatible** API (Ollama, llama.cpp server, or another OpenAI-compatible endpoint).
  - **Registers** with the gateway or a local registry: reachable URL, list of models, current load/capacity.
- **Discovery:** On LAN, e.g. mDNS (“aura-inference._tcp”) or a small **node registry** (file or KV) that the gateway reads. No internet required.
- **Routing:** For each request, the gateway:
  - Classifies **task** (e.g. autocomplete vs. refactor vs. review) or uses model hint from the client.
  - Picks the **best OSS model** for that task (small/medium/large).
  - Picks a **node** that has that model and free capacity.
  - Proxies the request to that node (OpenAI-compatible POST).

So “distributing the best OSS model for current tasks dynamically” = **task → model → node** at request time, using only org devices.

### 3. Dynamic model selection

- **Task → model:** Map request context to a tier, e.g.:
  - **Tiny:** Inline completions, quick fixes → e.g. Qwen2-0.5B, Phi-3 mini.
  - **Small:** Single-file edit, explain code → e.g. Llama 3.2 3B, Smollm2.
  - **Medium:** Multi-file refactor, review → e.g. Llama 3.1 8B, Mistral 7B.
  - **Large:** Architecture, complex reasoning → e.g. Llama 3.1 70B, Qwen 72B (run on the most capable node).
- **Node capability:** Each node advertises: `models: ["qwen2:0.5b", "llama3.2:3b"]`, optional `max_concurrent`, `priority` (e.g. workstation > laptop > phone).
- **Scheduler:** Gateway (or a small scheduler service) chooses node + model; if the preferred node is busy, try next. All over local HTTP/gRPC.

### 4. Org distributed calculation power

- **Pool:** Every device that can run an inference server joins the pool (opt-in; e.g. “Share this device with the mesh”).
- **No single point of failure:** If one node is down, the gateway routes to others. For true offline-on-device, the Z Fold runs its own small model and does not depend on other nodes.
- **Best OSS model for the task:** We choose from the org’s **aggregate** model set (union of all nodes), then pick the best node that has that model and capacity. So the “best” model is both *which* model (for the task) and *where* it runs (which device).

---

## How it maps to the current codebase

| Today | Extension |
|-------|-----------|
| `OLLAMA_BASE` → single Ollama (e.g. 127.0.0.1:11434) | **Node registry:** list of `{url, models[], load?}`; gateway selects one per request. |
| `GET /v1/models` → Ollama tags + cloud | Merge models from **all registered nodes** + optional cloud; mark `mesh: true` and `node_id`. |
| `POST /v1/chat/completions` → try Ollama, then Groq | **Router:** task/model → pick node from registry → proxy to that node’s OpenAI-compatible API; fallback to next node or cloud if configured. |
| `providers` with `mesh: True` (Ollama) | **Mesh = pool of nodes**; each node is a “provider” with a URL and model list. |
| Dashboard / Mission Control | **PWA + offline:** cache UI; when offline, use on-device small model or “queue for when mesh is back.” |

So we keep the same API contract; we add a **node registry**, a **router/scheduler**, and optional **on-device inference** for offline.

---

## Practical steps (incremental)

1. **Node registry (config or API)**  
   - Allow `OLLAMA_BASE` to be a list of URLs, or a path to a JSON file / env with multiple nodes.  
   - Gateway aggregates `GET /api/tags` from each; `GET /v1/models` returns union of models with `node_id` or `url`.

2. **Router in gateway**  
   - For `/v1/chat/completions`, choose a node that has the requested (or default) model; round-robin or least-loaded if we have load info.  
   - No internet required if all nodes are on LAN.

3. **Task-aware model selection (optional)**  
   - Client sends a hint (e.g. `X-Task-Type: completion` vs `refactor`) or gateway infers from context length / model name.  
   - Map task type to preferred model; then pick a node that has that model.

4. **Discovery (optional)**  
   - mDNS advertiser on each node (“I’m an Aura inference node”); gateway discovers nodes automatically on LAN.  
   - Or a simple “Register with gateway” button in a small node app that POSTs its URL and model list.

5. **Offline-on-device**  
   - Separate track: PWA that can load a tiny model via WASM/ONNX when no network; when on WiFi, switch to gateway (mesh).  
   - Or integrate with Ollama Android / similar when available.

---

## Summary

- **Yes:** We can design for high-velocity coding on Z Fold (and similar) **without WiFi** (on-device small OSS model) and **with WiFi but no online provider** (gateway + org-wide distributed OSS inference).
- **Mechanism:** Dynamic choice of “best OSS model for current task” and “which org node runs it” via a **node registry** and **router** in the gateway, plus optional **on-device inference** for offline.
- **Current codebase:** Gateway already has mesh-first Ollama and `/v1/models`; adding a multi-node registry and a router in front of Ollama (and future nodes) is the natural next step. No need to change the external API; Cursor and Mission Control keep pointing at the gateway.

This doc is the **vision and roadmap**; implementation can proceed incrementally (registry → router → task hints → discovery → offline client).
