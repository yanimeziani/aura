# Forge Roadmap: Phase G20 to G100

This document outlines the strategic progression for the Aura Stack from G20 to G100, focusing on completing the sovereign network (aura-tailscale), the Ziggy compiler, the operational webhook engine (aura-flow), and the core API layer (aura-api), ultimately converging into a fully self-hosted, sovereign infrastructure.

## Phase 1: Mesh Transport & Data Plane (G20–G29)
**Focus:** Elevating `aura-tailscale` from handshake skeleton to a functioning VPN data plane.
* **G20** - `aura-tailscale`: UDP socket wrapper (bind, sendTo, recvFrom).
* **G21** - `aura-tailscale`: Main event loop (poll/epoll for UDP and TUN sockets).
* **G22** - `aura-tailscale`: WireGuard cookie generation and MAC2 validation.
* **G23** - `aura-tailscale`: Handshake timer state machine (retransmissions, timeouts).
* **G24** - `aura-tailscale`: Session key ratcheting and nonce tracking.
* **G25** - `aura-tailscale`: Data packet encryption (ChaCha20Poly1305).
* **G26** - `aura-tailscale`: Data packet decryption and authentication.
* **G27** - `aura-tailscale`: TUN to UDP routing (IP packet inspection -> peer lookup).
* **G28** - `aura-tailscale`: UDP to TUN routing (decrypt -> write to TUN).
* **G29** - `aura-tailscale`: Ping/Keepalive mechanism between peers.

## Phase 2: Control Plane & Edge Proxy (G30–G39)
**Focus:** Connecting the mesh to a control plane and exposing services via `aura-edge`.
* **G30** - `aura-tailscale`: Control plane client (HTTP long-polling/websocket).
* **G31** - `aura-tailscale`: Dynamic peer table synchronization.
* **G32** - `aura-tailscale`: Key rotation and re-keying logic.
* **G33** - `aura-edge`: TCP reverse proxy skeleton over mesh.
* **G34** - `aura-edge`: HTTP/1.1 parsing and forwarding.
* **G35** - `aura-edge`: Let's Encrypt / ACME client stub for edge TLS.
* **G36** - `aura-edge`: SNI routing and certificate management.
* **G37** - `aura-edge`: Rate limiting and connection bounding.
* **G38** - `aura-api`: Integration of edge status into `/status` endpoint.
* **G39** - `tui`: Real-time traffic and mesh routing dashboard.

## Phase 3: Compiler Frontend & Expressions (G40–G49)
**Focus:** Advancing `ziggy-compiler` past top-level decls into full expression parsing.
* **G40** - `ziggy-compiler`: Binary expression parsing (Pratt parser / precedence).
* **G41** - `ziggy-compiler`: Unary and postfix operators.
* **G42** - `ziggy-compiler`: Block parsing and scoping `{ ... }`.
* **G43** - `ziggy-compiler`: Control flow parsing (`if`, `while`, `for`).
* **G44** - `ziggy-compiler`: Function call parsing and argument lists.
* **G45** - `ziggy-compiler`: Struct and Enum declaration parsing.
* **G46** - `ziggy-compiler`: Symbol table data structure (StringMap).
* **G47** - `ziggy-compiler`: Variable resolution and scope tracking.
* **G48** - `ziggy-compiler`: Type checker skeleton for expressions.
* **G49** - `ziggy-compiler`: Error recovery and advanced linting reports.

## Phase 4: Workflow Engine & Automation (G50–G59)
**Focus:** Evolving `aura-flow` from simple spooling to a full DAG execution engine.
* **G50** - `aura-flow`: DAG (Directed Acyclic Graph) representation in Zig.
* **G51** - `aura-flow`: Workflow definition parser (JSON/YAML).
* **G52** - `aura-flow`: Execution context and state threading between nodes.
* **G53** - `aura-flow`: HTTP Request node implementation.
* **G54** - `aura-flow`: Subprocess Execution node implementation.
* **G55** - `aura-flow`: Condition/Branching node implementation.
* **G56** - `aura-flow`: Worker pool management and job queues.
* **G57** - `aura-flow`: Dead-letter queue and retry policies.
* **G58** - `aura-flow`: Stripe webhook deep-parsing and normalization.
* **G59** - `aura-flow`: Payment-to-fulfillment pipeline template.

## Phase 5: AI Proxy & Core API (G60–G69)
**Focus:** Retiring the legacy Python gateway and making `aura-api` the LLM gateway.
* **G60** - `aura-api`: Groq/Gemini HTTP streaming client integration.
* **G61** - `aura-api`: Server-Sent Events (SSE) streaming response handler.
* **G62** - `aura-api`: OpenAI-compatible API wrapper for Groq/Gemini.
* **G63** - `aura-api`: SQLite C-API binding / database layer stub.
* **G64** - `aura-api`: Persistence of chat sessions and logs to SQLite.
* **G65** - `aura-api`: API Key authentication middleware.
* **G66** - `aura-api`: Rate limiting per workspace/key.
* **G67** - `aura-api`: Payload validation and JSON schema checking.
* **G68** - `aura-mcp`: MCP tool execution through the new API layer.
* **G69** - `gateway`: Deprecation script and traffic cutover documentation.

## Phase 6: Compiler Backend & IR (G70–G79)
**Focus:** Taking `ziggy-compiler` from checked AST to executable output.
* **G70** - `ziggy-compiler`: Intermediate Representation (IR) design.
* **G71** - `ziggy-compiler`: AST to IR lowering (basic blocks).
* **G72** - `ziggy-compiler`: IR control flow graph (CFG) generation.
* **G73** - `ziggy-compiler`: Liveness analysis and basic optimizations.
* **G74** - `ziggy-compiler`: C backend code generator (Transpilation).
* **G75** - `ziggy-compiler`: x86_64 machine code generation stub (ELF writer).
* **G76** - `ziggy-compiler`: String and data section emission.
* **G77** - `ziggy-compiler`: Function prologue/epilogue generation.
* **G78** - `ziggy-compiler`: Integration with system linker (lld/gcc).
* **G79** - `ziggy-compiler`: Standard library linking support.

## Phase 7: Sovereign Stack Integration (G80–G89)
**Focus:** Gluing the components together for automated, zero-trust deployments.
* **G80** - `aura-tailscale`: Integration with `aura-api` for identity validation.
* **G81** - `aura-flow`: Triggering workflows via mesh packets.
* **G82** - `aura-edge`: Dynamic routing updates from `aura-flow`.
* **G83** - `tui`: Comprehensive log viewing across all packages.
* **G84** - `tui`: Interactive mesh configuration interface.
* **G85** - `aura-mcp`: Agentic mesh topology adjustments.
* **G86** - `aura-api`: Telemetry and metrics aggregation endpoint.
* **G87** - `sovereign-stack`: VPS bootstrapping script (deploy from zero).
* **G88** - `sovereign-stack`: Systemd service generation and management.
* **G89** - `sovereign-stack`: Automated backup system (Vault -> S3/Encrypted).

## Phase 8: Production Polish & F-Series Culmination (G90–G100)
**Focus:** Stability, security audits, and finalising the G-series epoch.
* **G90** - `aura-tailscale`: Fuzz testing UDP packet handler.
* **G91** - `ziggy-compiler`: End-to-end compilation of a complex binary.
* **G92** - `aura-flow`: Load testing (10,000 requests/sec spool test).
* **G93** - `aura-api`: Memory leak profiling and optimization.
* **G94** - `aura-edge`: Zero-downtime reload and configuration hot-swapping.
* **G95** - `tui`: Resource monitoring (CPU/Memory per service).
* **G96** - `aura-mcp`: Self-healing prompts (Agent detects and fixes crashes).
* **G97** - `gateway`: Final removal of all Python dependencies.
* **G98** - `docs`: Generation of the Aura Stack Architectural Guide.
* **G99** - `vault`: Secret rotation automation.
* **G100** - `system`: Full workspace compilation, test, and sovereign deploy (The Aura Benchmark).