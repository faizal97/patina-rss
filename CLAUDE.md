# Patina RSS Reader

## Prerequisites
- Rust 1.85+ with `aarch64-apple-darwin` target
- XcodeGen (`brew install xcodegen`)
- Xcode 15+ with Swift 6
- Node.js (for context7 MCP server)

## Architecture
- SwiftUI macOS app (Patina/) with Rust core library (patina-core/) via UniFFI
- Uses XcodeGen (project.yml) - regenerate Xcode project with `xcodegen generate`
- Rust builds via pre-build script: `scripts/build-rust.sh`

## Build Commands
- `cd patina-core && cargo build` - Build Rust library
- `cd patina-core && cargo test` - Run Rust tests
- `cd Patina && xcodebuild -scheme Patina -configuration Debug build` - Build Swift app
- `xcodegen generate` - Regenerate Xcode project from project.yml
- `open ~/Library/Developer/Xcode/DerivedData/Patina-*/Build/Products/Debug/Patina.app` - Run the app

## Release Commands
- `./scripts/release.sh [major|minor|patch]` - Full release: bump version, build all archs, push, create GitHub release with binaries
- `./scripts/bump-version.sh [major|minor|patch]` - Just bump version in Cargo.toml and project.yml

## Key Files
| Purpose | Path |
|---------|------|
| Rust API (UniFFI exports) | `patina-core/src/lib.rs` |
| Shared types | `patina-core/src/storage/models.rs` |
| Database operations | `patina-core/src/storage/db.rs` |
| Swift state management | `Patina/Patina/State/AppState.swift` |
| Generated bindings | `generated/PatinaCore.swift` (auto-patched) |
| XcodeGen config | `Patina/project.yml` |

## Key Patterns
- UniFFI: Pure proc-macro approach with minimal UDL file (`namespace patina_core {};`)
- State management: Swift `@Observable` macro with `@MainActor` for concurrency
- Generated Swift bindings: `generated/PatinaCore.swift` (auto-patched by build script)

## Swift 6 Workarounds
- UniFFI generates `private var initializationResult` - must patch to `nonisolated(unsafe) private var initializationResult` in build-rust.sh
- WKNavigationDelegate closures need `@MainActor @Sendable` annotation
- AppState class requires `@MainActor` annotation for strict concurrency
- UniFFI types need `@unchecked Sendable` extension for use with `Task.detached`
- Blocking FFI calls (network I/O) must use `Task.detached` to avoid freezing UI

## XcodeGen (project.yml)
- System frameworks: Use `sdk: Framework.framework` (not `framework: X implicit: true`)
- Sources exclude generated files, include via separate path entry

## Database
- SQLite at `~/Library/Application Support/Patina/patina.db`
- Schema managed by Rust migrations in `storage/db.rs`

## Claude Automations
- `/build-patina` - Build & run the full app
- Hooks: auto-format Rust on edit, block Cargo.lock edits
- Skills: UniFFI conventions applied automatically
- MCP: context7 for Rust crate documentation
