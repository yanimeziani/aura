# Forge

A systems programming language with first-class memory region tagging via the **Aura system**.

## Overview

Forge extends Zig's philosophy of explicit control and zero-cost abstractions with a novel approach to memory management: **Auras**. Auras are compile-time memory region tags that track allocation lifetimes, ownership semantics, and memory provenance through the type system.

## The Aura System

Auras solve a fundamental tension in systems programming: you want the performance of manual memory management, but the safety guarantees of garbage collection.

### Core Concepts

**Region Tags**: Every allocation is tagged with an Aura that describes its lifetime and ownership:

```zig
const Aura = enum {
    stack,      // Dies with current scope
    arena,      // Dies with arena allocator
    persistent, // Lives until explicit free
    borrowed,   // Reference to memory owned elsewhere
};

fn createBuffer(aura: Aura) []u8 {
    // Compiler tracks this allocation's lifetime via aura
    return allocWithAura(aura, 1024);
}
```

**Compile-Time Verification**: The compiler verifies that:
- Borrowed auras never outlive their source
- Arena-tagged memory isn't returned past arena lifetime
- Persistent allocations are eventually freed

**Zero Runtime Cost**: Auras are erased at compile time. They exist purely for static analysis — no runtime tagging, no overhead.

### Why Auras?

| Problem | Zig's Approach | Forge's Aura Approach |
|---------|---------------|----------------------|
| Use-after-free | Runtime safety checks (debug) | Compile-time rejection |
| Dangling pointers | Programmer discipline | Type-system enforcement |
| Memory leaks | Programmer discipline | Ownership tracking |
| Allocator confusion | Explicit allocator passing | Aura propagation |

## Quick Start

```bash
# Build Forge
zig build

# Run the compiler
zig build run -- input.frg

# Run tests
zig build test
```

## Project Structure

```
forge/
├── src/
│   ├── main.zig          # Entry point
│   ├── core/             # Lexer, parser, codegen
│   └── aura/             # Aura type system
├── tests/                # Test suite
├── examples/             # Example Forge programs
└── docs/                 # Documentation
```

## Examples

### Basic Aura Usage

```zig
// Forge source (.frg)
fn process(data: []u8 @aura(.borrowed)) void {
    // Compiler knows 'data' is borrowed — can't store it
    transform(data);
}

fn main() void {
    var buffer: [1024]u8 @aura(.stack) = undefined;
    process(&buffer);  // OK: borrowed from stack
}
```

### Arena Pattern

```zig
fn parseDocument(arena: *Arena) Document @aura(.arena) {
    // All allocations inherit arena's aura
    const tokens = tokenize(arena, input);
    const ast = parse(arena, tokens);
    return ast;  // Caller knows this dies with arena
}
```

## Roadmap

- [ ] Core lexer and parser
- [ ] Aura type system implementation
- [ ] Compile-time aura verification
- [ ] Code generation (LLVM/Zig backend)
- [ ] Standard library with aura-aware containers
- [ ] LSP support

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
