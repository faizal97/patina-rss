#!/bin/bash

# Build script for Patina Core Rust library
# This script builds the Rust library for all required Apple architectures
# and generates Swift bindings.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUST_DIR="$PROJECT_ROOT/patina-core"
GENERATED_DIR="$PROJECT_ROOT/generated"

echo "🦀 Building Patina Core Rust Library..."
echo "Project root: $PROJECT_ROOT"

cd "$RUST_DIR"

# Determine build configuration
if [ "$CONFIGURATION" = "Release" ]; then
    BUILD_TYPE="release"
    BUILD_FLAG="--release"
else
    BUILD_TYPE="debug"
    BUILD_FLAG=""
fi

echo "Build type: $BUILD_TYPE"

# Build for Apple Silicon (arm64)
echo "Building for arm64-apple-darwin..."
cargo build $BUILD_FLAG --target aarch64-apple-darwin 2>&1 || {
    echo "Note: If aarch64-apple-darwin target is not installed, run:"
    echo "rustup target add aarch64-apple-darwin"
    # Fall back to native build
    cargo build $BUILD_FLAG
}

# Build for Intel (x86_64) if needed for universal binary
# echo "Building for x86_64-apple-darwin..."
# cargo build $BUILD_FLAG --target x86_64-apple-darwin

# Generate Swift bindings
echo "Generating Swift bindings..."
mkdir -p "$GENERATED_DIR"

LIBRARY_PATH="$RUST_DIR/target/aarch64-apple-darwin/$BUILD_TYPE/libpatina_core.a"
if [ ! -f "$LIBRARY_PATH" ]; then
    LIBRARY_PATH="$RUST_DIR/target/$BUILD_TYPE/libpatina_core.a"
fi

cargo run --bin uniffi-bindgen generate \
    --library "$LIBRARY_PATH" \
    --language swift \
    --out-dir "$GENERATED_DIR"

# Patch generated Swift for Swift 6 strict concurrency
echo "Patching generated Swift for Swift 6 concurrency..."
sed -i '' 's/^private var initializationResult/nonisolated(unsafe) private var initializationResult/' "$GENERATED_DIR/PatinaCore.swift"

echo "✅ Rust library built successfully!"
echo "Generated files in: $GENERATED_DIR"
ls -la "$GENERATED_DIR"
