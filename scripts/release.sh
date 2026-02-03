#!/bin/bash
set -e

# Patina Release Script
# Usage: ./release.sh [major|minor|patch]
#
# This script:
# 1. Bumps the version
# 2. Commits the version change
# 3. Creates a git tag
# 4. Builds the app for all architectures (arm64, x86_64, universal)
# 5. Packages each as a zip
# 6. Pushes to GitHub
# 7. Creates a GitHub release with all binaries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

BUILD_DIR="/tmp/patina-build"
RUST_TARGET_DIR="$PROJECT_ROOT/patina-core/target"

usage() {
    echo "Usage: $0 [major|minor|patch]"
    echo ""
    echo "Creates a new release with builds for:"
    echo "  - Apple Silicon (arm64)"
    echo "  - Intel (x86_64)"
    echo "  - Universal (both architectures)"
    echo ""
    echo "Examples:"
    echo "  $0 patch  # 1.0.0 -> 1.0.1"
    echo "  $0 minor  # 1.0.0 -> 1.1.0"
    echo "  $0 major  # 1.0.0 -> 2.0.0"
    exit 1
}

# Get current version from Cargo.toml
get_current_version() {
    grep '^version = ' "$PROJECT_ROOT/patina-core/Cargo.toml" | sed 's/version = "\(.*\)"/\1/'
}

# Check for uncommitted changes
check_clean_working_directory() {
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}"
        exit 1
    fi
}

# Check we're on main branch
check_main_branch() {
    local current_branch
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ]; then
        echo -e "${YELLOW}Warning: You're on branch '$current_branch', not 'main'.${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check gh CLI is available
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
        echo "Install with: brew install gh"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo -e "${RED}Error: Not authenticated with GitHub CLI.${NC}"
        echo "Run: gh auth login"
        exit 1
    fi
}

# Check Rust targets are installed
check_rust_targets() {
    echo -e "${BLUE}Checking Rust targets...${NC}"

    if ! rustup target list --installed | grep -q "aarch64-apple-darwin"; then
        echo -e "${YELLOW}Installing aarch64-apple-darwin target...${NC}"
        rustup target add aarch64-apple-darwin
    fi

    if ! rustup target list --installed | grep -q "x86_64-apple-darwin"; then
        echo -e "${YELLOW}Installing x86_64-apple-darwin target...${NC}"
        rustup target add x86_64-apple-darwin
    fi

    echo -e "${GREEN}✓ Rust targets ready${NC}"
}

# Build Rust library for a specific target
build_rust() {
    local target=$1
    echo -e "${CYAN}  → Building Rust for $target...${NC}"
    cd "$PROJECT_ROOT/patina-core"
    cargo build --release --target "$target" 2>&1 | grep -E "(Compiling|Finished)" || true
}

# Create universal Rust library
create_universal_rust_lib() {
    echo -e "${CYAN}  → Creating universal Rust library...${NC}"
    mkdir -p "$RUST_TARGET_DIR/universal-apple-darwin/release"
    lipo -create \
        "$RUST_TARGET_DIR/aarch64-apple-darwin/release/libpatina_core.a" \
        "$RUST_TARGET_DIR/x86_64-apple-darwin/release/libpatina_core.a" \
        -output "$RUST_TARGET_DIR/universal-apple-darwin/release/libpatina_core.a"
}

# Build Swift app for a specific architecture
build_swift_app() {
    local arch=$1
    local rust_lib_path=$2
    local output_dir="$BUILD_DIR/$arch"

    echo -e "${CYAN}  → Building Swift app for $arch...${NC}"

    cd "$PROJECT_ROOT/Patina"

    # Build with specific library path
    xcodebuild -scheme Patina \
        -configuration Release \
        -arch "$arch" \
        ONLY_ACTIVE_ARCH=YES \
        SYMROOT="$output_dir" \
        LIBRARY_SEARCH_PATHS="$rust_lib_path" \
        build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" || true

    if [ ! -d "$output_dir/Release/Patina.app" ]; then
        echo -e "${RED}Error: Build failed for $arch. Patina.app not found.${NC}"
        return 1
    fi
}

# Build universal Swift app by combining arm64 and x86_64
build_universal_app() {
    local output_dir="$BUILD_DIR/universal"

    echo -e "${CYAN}  → Creating universal app bundle...${NC}"

    mkdir -p "$output_dir/Release"

    # Copy the arm64 app as base
    cp -R "$BUILD_DIR/arm64/Release/Patina.app" "$output_dir/Release/"

    # Create universal binary using lipo
    lipo -create \
        "$BUILD_DIR/arm64/Release/Patina.app/Contents/MacOS/Patina" \
        "$BUILD_DIR/x86_64/Release/Patina.app/Contents/MacOS/Patina" \
        -output "$output_dir/Release/Patina.app/Contents/MacOS/Patina"

    # Re-sign the universal app
    codesign --force --sign - "$output_dir/Release/Patina.app"
}

# Package app as zip
package_app() {
    local arch=$1
    local version=$2
    local zip_name="Patina-v${version}-macos-${arch}.zip"
    local app_dir="$BUILD_DIR/$arch/Release"

    echo -e "${CYAN}  → Packaging $arch...${NC}"

    # Use subshell to avoid changing the working directory
    (
        cd "$app_dir"
        rm -f "$zip_name"
        zip -r -q "$zip_name" Patina.app
    )

    local size=$(du -h "$app_dir/$zip_name" | cut -f1)
    echo -e "${GREEN}    ✓ $zip_name ($size)${NC}"
}

# Main
if [ $# -ne 1 ]; then
    usage
fi

BUMP_TYPE=$1

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo -e "${RED}Error: Invalid bump type '$BUMP_TYPE'${NC}"
    usage
fi

cd "$PROJECT_ROOT"

echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           Patina Release Script                   ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo ""

# Pre-flight checks
echo -e "${YELLOW}Running pre-flight checks...${NC}"
check_gh_cli
check_rust_targets
check_clean_working_directory
check_main_branch
echo -e "${GREEN}✓ All checks passed${NC}"
echo ""

# Get versions
CURRENT_VERSION=$(get_current_version)

# Bump version
echo -e "${YELLOW}Bumping version ($BUMP_TYPE)...${NC}"
"$SCRIPT_DIR/bump-version.sh" "$BUMP_TYPE"
NEW_VERSION=$(get_current_version)
echo ""

# Commit version bump
echo -e "${YELLOW}Committing version bump...${NC}"
git add -A
git commit -m "chore: bump version to v$NEW_VERSION"
echo -e "${GREEN}✓ Committed version bump${NC}"
echo ""

# Create tag
echo -e "${YELLOW}Creating tag v$NEW_VERSION...${NC}"
git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION"
echo -e "${GREEN}✓ Created tag v$NEW_VERSION${NC}"
echo ""

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build Rust libraries
echo -e "${YELLOW}Building Rust libraries...${NC}"
build_rust "aarch64-apple-darwin"
build_rust "x86_64-apple-darwin"
create_universal_rust_lib
echo -e "${GREEN}✓ Rust libraries built${NC}"
echo ""

# Generate Xcode project
echo -e "${YELLOW}Generating Xcode project...${NC}"
cd "$PROJECT_ROOT/Patina"
xcodegen generate
echo -e "${GREEN}✓ Xcode project generated${NC}"
echo ""

# Build Swift apps
echo -e "${YELLOW}Building Swift apps...${NC}"
build_swift_app "arm64" "$RUST_TARGET_DIR/aarch64-apple-darwin/release"
build_swift_app "x86_64" "$RUST_TARGET_DIR/x86_64-apple-darwin/release"
build_universal_app
echo -e "${GREEN}✓ All Swift apps built${NC}"
echo ""

# Package apps
echo -e "${YELLOW}Packaging apps...${NC}"
package_app "arm64" "$NEW_VERSION"
package_app "x86_64" "$NEW_VERSION"
package_app "universal" "$NEW_VERSION"
echo -e "${GREEN}✓ All apps packaged${NC}"
echo ""

# Push to GitHub
echo -e "${YELLOW}Pushing to GitHub...${NC}"
git push origin main
git push origin "v$NEW_VERSION"
echo -e "${GREEN}✓ Pushed to GitHub${NC}"
echo ""

# Create GitHub release
echo -e "${YELLOW}Creating GitHub release...${NC}"

ZIP_ARM64="$BUILD_DIR/arm64/Release/Patina-v${NEW_VERSION}-macos-arm64.zip"
ZIP_X86="$BUILD_DIR/x86_64/Release/Patina-v${NEW_VERSION}-macos-x86_64.zip"
ZIP_UNIVERSAL="$BUILD_DIR/universal/Release/Patina-v${NEW_VERSION}-macos-universal.zip"

gh release create "v$NEW_VERSION" \
    --title "Patina v$NEW_VERSION" \
    --notes "## Patina v$NEW_VERSION

### Downloads

| Platform | Download | Size |
|----------|----------|------|
| 🍎 **Universal** (Recommended) | [Patina-v${NEW_VERSION}-macos-universal.zip](https://github.com/faizal97/patina-rss/releases/download/v${NEW_VERSION}/Patina-v${NEW_VERSION}-macos-universal.zip) | Works on all Macs |
| Apple Silicon (M1/M2/M3/M4) | [Patina-v${NEW_VERSION}-macos-arm64.zip](https://github.com/faizal97/patina-rss/releases/download/v${NEW_VERSION}/Patina-v${NEW_VERSION}-macos-arm64.zip) | Optimized for Apple Silicon |
| Intel | [Patina-v${NEW_VERSION}-macos-x86_64.zip](https://github.com/faizal97/patina-rss/releases/download/v${NEW_VERSION}/Patina-v${NEW_VERSION}-macos-x86_64.zip) | For Intel-based Macs |

### Installation

1. Download the appropriate zip file for your Mac
2. Extract and drag **Patina.app** to your Applications folder
3. On first launch, right-click and select **\"Open\"** to bypass Gatekeeper

### Which version should I download?

- **Not sure?** Download the **Universal** version - it works on all Macs
- **Apple Silicon Mac** (M1, M2, M3, M4): arm64 version is slightly smaller
- **Intel Mac** (pre-2020): x86_64 version

---

*Note: This app is signed locally and not notarized with Apple. You may need to allow it in System Preferences > Privacy & Security.*
" \
    "$ZIP_UNIVERSAL" \
    "$ZIP_ARM64" \
    "$ZIP_X86"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           Release v$NEW_VERSION Complete!         ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo "Release URL: https://github.com/faizal97/patina-rss/releases/tag/v$NEW_VERSION"
echo ""
echo "Artifacts:"
echo "  - Patina-v${NEW_VERSION}-macos-universal.zip"
echo "  - Patina-v${NEW_VERSION}-macos-arm64.zip"
echo "  - Patina-v${NEW_VERSION}-macos-x86_64.zip"
echo ""
