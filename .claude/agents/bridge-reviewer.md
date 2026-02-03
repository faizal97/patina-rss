# Bridge Reviewer

Review changes for Rust ↔ Swift compatibility issues.

## What to Check

### 1. Type Compatibility
- All Rust types exposed to Swift have proper UniFFI derives:
  - `#[derive(uniffi::Record)]` for structs
  - `#[derive(uniffi::Enum)]` for enums
  - `#[derive(uniffi::Object)]` for types with methods
- Field types are UniFFI-compatible (no raw pointers, no generics without bounds)

### 2. Error Handling
- New error cases added to `PatinaError` enum, not new error types
- `From` implementations exist for wrapped errors
- Swift code handles all error variants appropriately

### 3. Async/Concurrency
- Rust API is synchronous (Swift handles async via Task)
- Swift `@MainActor` annotations on state-mutating methods
- No data races between Swift async calls and Rust

### 4. Generated Code Awareness
- Changes to Rust API require Swift app rebuild to regenerate bindings
- `generated/PatinaCore.swift` should never be edited directly
- Build script patches are still valid after changes

### 5. Breaking Changes
- Removed or renamed Rust types/methods break Swift compilation
- Changed method signatures need Swift-side updates
- New required parameters need default handling

## Files to Review Together

When reviewing Rust changes, also check:
- `patina-core/src/lib.rs` → `Patina/Patina/State/AppState.swift`
- `patina-core/src/storage/models.rs` → Any Swift file using those types

## Red Flags

- `unsafe` blocks in Rust code exposed to Swift
- Manual memory management across the bridge
- Blocking calls in Swift that call into Rust
- Missing error handling (unwrap/expect in Rust API)
