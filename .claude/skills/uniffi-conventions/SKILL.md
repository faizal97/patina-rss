---
name: uniffi-conventions
description: Patterns for working with UniFFI Swift/Rust bridge. Apply when modifying Rust core or Swift bindings.
user-invocable: false
---

## UniFFI Patterns for Patina

### Adding New Types

**Structs** (data transfer):
```rust
#[derive(uniffi::Record)]
pub struct MyStruct {
    pub field: String,
}
```

**Enums**:
```rust
#[derive(uniffi::Enum)]
pub enum MyEnum {
    VariantA,
    VariantB(String),
}
```

**Objects** (types with methods):
```rust
#[derive(uniffi::Object)]
pub struct MyService { ... }

#[uniffi::export]
impl MyService {
    #[uniffi::constructor]
    pub fn new() -> Self { ... }

    pub fn method(&self) -> Result<(), PatinaError> { ... }
}
```

### Error Handling

- Use `PatinaError` enum for ALL fallible operations
- Add new variants to `PatinaError` in `lib.rs`, not new error types
- Implement `From<X> for PatinaError` for automatic conversion

```rust
#[derive(Error, Debug, uniffi::Error)]
#[uniffi(flat_error)]
pub enum PatinaError {
    #[error("New error: {0}")]
    NewErrorType(String),
    // ... existing variants
}
```

### Swift 6 Strict Concurrency

The build script patches generated code, but you may need:

- `@MainActor` on classes that hold state
- `@MainActor @Sendable` on closure parameters in delegates
- `nonisolated(unsafe)` for global variables (handled by build script)

### File Locations

| What | Where |
|------|-------|
| Rust types | `patina-core/src/storage/models.rs` |
| Rust API | `patina-core/src/lib.rs` |
| Database ops | `patina-core/src/storage/db.rs` |
| Generated Swift | `generated/PatinaCore.swift` (auto-patched, don't edit) |
| Swift state | `Patina/Patina/State/AppState.swift` |

### Workflow for API Changes

1. Modify Rust code in `patina-core/src/`
2. Run `cargo build` to verify Rust compiles
3. Build Swift app (triggers `build-rust.sh` which regenerates bindings)
4. Update `AppState.swift` to use new API
5. Test the full flow
