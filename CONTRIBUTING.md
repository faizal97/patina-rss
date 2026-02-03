# Contributing to Patina RSS

Thank you for your interest in contributing to Patina! This document provides guidelines and instructions for contributing.

## 🌟 Ways to Contribute

- **Bug Reports** — Found a bug? Open an issue with steps to reproduce
- **Feature Requests** — Have an idea? Open an issue to discuss it
- **Code Contributions** — Submit a pull request with improvements
- **Documentation** — Help improve docs, fix typos, add examples

## 🛠️ Development Setup

### Prerequisites

1. **macOS 14.0+** (required for SwiftUI features)
2. **Xcode 15+** with Swift 6
3. **Rust 1.85+** with the ARM target:
   ```bash
   rustup target add aarch64-apple-darwin
   ```
4. **XcodeGen**:
   ```bash
   brew install xcodegen
   ```

### Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/faizal97/patina-rss.git
   cd patina-rss
   ```
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. Build and verify:
   ```bash
   cd patina-core && cargo build && cargo test
   ```

## 📐 Architecture Overview

Patina uses a **Swift + Rust** architecture:

| Layer | Technology | Purpose |
|-------|------------|---------|
| UI | SwiftUI | Native macOS interface |
| State | Swift @Observable | Reactive state management |
| Bridge | UniFFI | Swift ↔ Rust interop |
| Core | Rust | Feed parsing, storage, serendipity |
| Storage | SQLite | Local database |

### Key Directories

- `Patina/` — SwiftUI application code
- `patina-core/` — Rust library
- `generated/` — Auto-generated UniFFI bindings (don't edit manually)
- `scripts/` — Build automation

## 📝 Coding Standards

### Rust Code

- Follow standard Rust conventions (`cargo fmt`, `cargo clippy`)
- Use `#[uniffi::export]` for functions exposed to Swift
- Use `#[uniffi::Record]` for data structures crossing the bridge
- Write tests for new functionality

### Swift Code

- Follow Swift 6 strict concurrency guidelines
- Use `@MainActor` for UI-related code
- Use `@Observable` for state classes
- Keep views focused and composable

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add keyboard shortcut for article navigation
fix: resolve feed refresh race condition
docs: update build instructions for Apple Silicon
refactor: simplify navigation router logic
```

## 🔄 Pull Request Process

1. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the coding standards

3. **Test your changes**:
   ```bash
   # Rust tests
   cd patina-core && cargo test

   # Build verification
   cd Patina && xcodebuild -scheme Patina build
   ```

4. **Commit your changes** with clear messages

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request** with:
   - Clear description of changes
   - Screenshots for UI changes
   - Reference to related issues

## 🐛 Reporting Bugs

When reporting bugs, please include:

1. **macOS version** and **Xcode version**
2. **Steps to reproduce** the issue
3. **Expected behavior** vs **actual behavior**
4. **Screenshots or logs** if applicable
5. **Database file** (if relevant, found at `~/Library/Application Support/Patina/`)

## 💡 Feature Requests

When suggesting features:

1. **Check existing issues** to avoid duplicates
2. **Describe the problem** your feature would solve
3. **Propose a solution** if you have one in mind
4. **Consider alternatives** you've thought about

## 🏷️ Issue Labels

| Label | Description |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature or improvement |
| `documentation` | Documentation improvements |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention needed |
| `rust` | Related to Rust core |
| `swift` | Related to Swift/SwiftUI |

## ❓ Questions?

- Open a [GitHub Discussion](https://github.com/faizal97/patina-rss/discussions) for questions
- Check existing issues and discussions first

## 📜 Code of Conduct

Be respectful and constructive. We're all here to build something great together.

---

Thank you for contributing to Patina! 🎉
