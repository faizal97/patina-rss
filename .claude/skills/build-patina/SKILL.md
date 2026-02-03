---
name: build-patina
description: Build and run the Patina RSS app (both Rust and Swift)
disable-model-invocation: true
---

Build Patina RSS Reader:

## Current State
- Rust build: !`cd patina-core && cargo check 2>&1 | tail -5`

## Build Steps
1. Build Rust library: `cd patina-core && cargo build`
2. Generate Xcode project (if needed): `cd Patina && xcodegen generate`
3. Build Swift app: `cd Patina && xcodebuild -scheme Patina -configuration Debug build 2>&1 | tail -20`
4. Launch app: `open ~/Library/Developer/Xcode/DerivedData/Patina-*/Build/Products/Debug/Patina.app`

Report any errors encountered. If the build succeeds, confirm the app launched.
