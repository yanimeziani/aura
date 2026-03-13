# Contributing to Forge

Thank you for your interest in contributing to Forge!

## Code of Conduct

Be respectful. Be constructive. Focus on the code, not the person.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Build and test: `zig build test`

## Development Guidelines

### Code Style

- Follow Zig style conventions
- Use `snake_case` for functions and variables
- Use `PascalCase` for types
- Keep functions small and focused
- Write tests for new functionality

### The Aura System

When working on Aura-related code:
- Ensure compile-time verification is maintained
- Document lifetime semantics clearly
- Add test cases for edge cases in region tracking

### Commits

- Write clear, concise commit messages
- One logical change per commit
- Reference issues when applicable

### Pull Requests

1. Create a branch from `main`
2. Make your changes
3. Run `zig build test` — all tests must pass
4. Submit PR with clear description

## Reporting Issues

- Check existing issues first
- Include reproduction steps
- Specify Zig version and OS

## License

By contributing, you agree that your contributions will be licensed under Apache 2.0.
