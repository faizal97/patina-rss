#!/bin/bash
set -e

# Patina Release Script
# Usage: ./release.sh [major|minor|patch]
#
# This script:
# 1. Bumps the version
# 2. Commits the version change
# 3. Creates a git tag
# 4. Builds the app in release mode
# 5. Packages it as a zip
# 6. Pushes to GitHub
# 7. Creates a GitHub release with the binary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BUILD_DIR="/tmp/patina-build"

usage() {
    echo "Usage: $0 [major|minor|patch]"
    echo ""
    echo "Creates a new release with:"
    echo "  - Version bump in Cargo.toml and project.yml"
    echo "  - Git commit and tag"
    echo "  - Release build of the app"
    echo "  - GitHub release with binary attached"
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

# Build the app
build_app() {
    echo -e "${BLUE}Building Rust library (release)...${NC}"
    cd "$PROJECT_ROOT/patina-core"
    cargo build --release

    echo -e "${BLUE}Generating Xcode project...${NC}"
    cd "$PROJECT_ROOT/Patina"
    xcodegen generate

    echo -e "${BLUE}Building Swift app (release)...${NC}"
    xcodebuild -scheme Patina -configuration Release -arch arm64 ONLY_ACTIVE_ARCH=YES SYMROOT="$BUILD_DIR" build 2>&1 | grep -E "(error:|warning:|BUILD|Compiling|Linking)" || true

    if [ ! -d "$BUILD_DIR/Release/Patina.app" ]; then
        echo -e "${RED}Error: Build failed. Patina.app not found.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Build succeeded${NC}"
}

# Package the app
package_app() {
    local version=$1
    local zip_name="Patina-v${version}-macos-arm64.zip"

    echo -e "${BLUE}Packaging app...${NC}"
    cd "$BUILD_DIR/Release"
    rm -f "$zip_name"
    zip -r "$zip_name" Patina.app

    echo -e "${GREEN}✓ Created $zip_name ($(du -h "$zip_name" | cut -f1))${NC}"
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

# Build
echo -e "${YELLOW}Building release...${NC}"
build_app
echo ""

# Package
echo -e "${YELLOW}Packaging...${NC}"
package_app "$NEW_VERSION"
echo ""

# Push to GitHub
echo -e "${YELLOW}Pushing to GitHub...${NC}"
git push origin main
git push origin "v$NEW_VERSION"
echo -e "${GREEN}✓ Pushed to GitHub${NC}"
echo ""

# Create GitHub release
echo -e "${YELLOW}Creating GitHub release...${NC}"
ZIP_PATH="$BUILD_DIR/Release/Patina-v${NEW_VERSION}-macos-arm64.zip"

gh release create "v$NEW_VERSION" \
    --title "Patina v$NEW_VERSION" \
    --notes "## Patina v$NEW_VERSION

### Downloads

- **[Patina-v${NEW_VERSION}-macos-arm64.zip](https://github.com/faizal97/patina-rss/releases/download/v${NEW_VERSION}/Patina-v${NEW_VERSION}-macos-arm64.zip)** - macOS app (Apple Silicon)

### Installation

1. Download the zip file above
2. Extract and drag Patina.app to your Applications folder
3. On first launch, right-click and select \"Open\" to bypass Gatekeeper

---

*Note: This app is signed locally and not notarized with Apple. You may need to allow it in System Preferences > Security & Privacy.*
" \
    "$ZIP_PATH"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           Release v$NEW_VERSION Complete!         ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo "Release URL: https://github.com/faizal97/patina-rss/releases/tag/v$NEW_VERSION"
echo ""
