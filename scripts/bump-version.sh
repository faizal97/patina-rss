#!/bin/bash
set -e

# Patina Version Bump Script
# Usage: ./bump-version.sh [major|minor|patch]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

CARGO_TOML="$PROJECT_ROOT/patina-core/Cargo.toml"
PROJECT_YML="$PROJECT_ROOT/Patina/project.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [major|minor|patch]"
    echo ""
    echo "Bumps the version in both Cargo.toml and project.yml"
    echo ""
    echo "Examples:"
    echo "  $0 major  # 1.0.0 -> 2.0.0"
    echo "  $0 minor  # 1.0.0 -> 1.1.0"
    echo "  $0 patch  # 1.0.0 -> 1.0.1"
    exit 1
}

# Get current version from Cargo.toml
get_current_version() {
    grep '^version = ' "$CARGO_TOML" | sed 's/version = "\(.*\)"/\1/'
}

# Bump version based on type
bump_version() {
    local version=$1
    local bump_type=$2

    IFS='.' read -r major minor patch <<< "$version"

    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}Error: Invalid bump type '$bump_type'${NC}"
            usage
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Update version in Cargo.toml
update_cargo_toml() {
    local new_version=$1
    sed -i '' "s/^version = \".*\"/version = \"$new_version\"/" "$CARGO_TOML"
}

# Update version in project.yml
update_project_yml() {
    local new_version=$1
    sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$new_version\"/" "$PROJECT_YML"
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

# Check files exist
if [ ! -f "$CARGO_TOML" ]; then
    echo -e "${RED}Error: Cargo.toml not found at $CARGO_TOML${NC}"
    exit 1
fi

if [ ! -f "$PROJECT_YML" ]; then
    echo -e "${RED}Error: project.yml not found at $PROJECT_YML${NC}"
    exit 1
fi

# Get current and new versions
CURRENT_VERSION=$(get_current_version)
NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP_TYPE")

echo -e "${YELLOW}Bumping version: $CURRENT_VERSION -> $NEW_VERSION${NC}"

# Update both files
update_cargo_toml "$NEW_VERSION"
update_project_yml "$NEW_VERSION"

echo -e "${GREEN}✓ Updated Cargo.toml${NC}"
echo -e "${GREEN}✓ Updated project.yml${NC}"
echo ""
echo -e "${GREEN}Version bumped to $NEW_VERSION${NC}"
echo ""
echo "Next steps:"
echo "  git add -A"
echo "  git commit -m \"chore: bump version to v$NEW_VERSION\""
echo "  git tag v$NEW_VERSION"
echo "  git push origin main --tags"
