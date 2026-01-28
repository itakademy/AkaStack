#!/usr/bin/env bash
set -e

VERSION_FILE="VERSION"
CHANGELOG_FILE="CHANGELOG.md"

if [ ! -f "$VERSION_FILE" ]; then
  echo "❌ VERSION file not found"
  exit 1
fi

NEW_VERSION=$(cat "$VERSION_FILE")
DATE=$(date +%Y-%m-%d)

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

echo "▶ Generating changelog for version $NEW_VERSION"

if [ -z "$LAST_TAG" ]; then
  COMMITS=$(git log --pretty=format:"- %s")
else
  COMMITS=$(git log "$LAST_TAG"..HEAD --pretty=format:"- %s")
fi

if [ -z "$COMMITS" ]; then
  echo "⚠️ No commits found for changelog"
fi

cat <<EOF > /tmp/CHANGELOG_ENTRY.md
## [$NEW_VERSION] - $DATE

### Changed
$COMMITS

EOF

# Create file if not exists
if [ ! -f "$CHANGELOG_FILE" ]; then
  cat <<EOF > "$CHANGELOG_FILE"
# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project follows Semantic Versioning.

---

EOF
fi

# Insert entry after header
sed -i "/^---$/r /tmp/CHANGELOG_ENTRY.md" "$CHANGELOG_FILE"

rm /tmp/CHANGELOG_ENTRY.md

echo "✔ CHANGELOG updated"
