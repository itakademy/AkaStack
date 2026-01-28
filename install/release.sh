#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "../$(dirname "$0")" && pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"

echo "======================================"
echo " Project release script"
echo "======================================"

# --------------------------------------
# Checks
# --------------------------------------
if [ ! -f "$VERSION_FILE" ]; then
  echo "❌ VERSION file not found"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ Not inside a git repository"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "❌ Working tree is not clean"
  echo "Commit or stash your changes before releasing."
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE")
echo "Current version: $CURRENT_VERSION"

# --------------------------------------
# Ask for new version
# --------------------------------------
echo
read -p "Enter new version (semver, e.g. 1.5.0): " NEW_VERSION

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Invalid version format (expected X.Y.Z)"
  exit 1
fi

# --------------------------------------
# Confirm
# --------------------------------------
echo
echo "You are about to release version: $NEW_VERSION"
read -p "Continue? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Release cancelled."
  exit 0
fi

# --------------------------------------
# Update VERSION file
# --------------------------------------
echo
echo "▶ Updating VERSION file"
echo "$NEW_VERSION" > "$VERSION_FILE"

git add $VERSION_FILE
git commit -m "chore(release): v$NEW_VERSION"

# --------------------------------------
# Create git tag
# --------------------------------------
echo "▶ Creating git tag v$NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

# --------------------------------------
# Push changes
# --------------------------------------
echo "▶ Pushing changes and tag"
git push origin master
git push origin "v$NEW_VERSION"

# --------------------------------------
# Generate CHANGELOG
# --------------------------------------
echo "▶ Generating CHANGELOG"
./generate-changelog.sh

git add CHANGELOG.md
git commit -m "docs(changelog): update for v$NEW_VERSION"

# --------------------------------------
# Done
# --------------------------------------
echo
echo "======================================"
echo " ✔ Release v$NEW_VERSION completed"
echo "======================================"
echo
echo "CI will now run for this release."
