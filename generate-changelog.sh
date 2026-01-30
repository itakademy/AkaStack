#!/usr/bin/env bash
set -euo pipefail

VERSION_FILE="VERSION"
CHANGELOG_FILE="CHANGELOG.md"
ENTRY_FILE="$(mktemp -t changelog_entry.XXXXXX)"
TMP_CHANGELOG="$(mktemp -t changelog_new.XXXXXX)"

if [ ! -f "$VERSION_FILE" ]; then
  echo "❌ VERSION file not found"
  exit 1
fi

NEW_VERSION="$(cat "$VERSION_FILE")"
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
  rm -f "$ENTRY_FILE" "$TMP_CHANGELOG"
  exit 0
fi

cat <<EOF > "$ENTRY_FILE"
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

# Insert entry after header separator (portable for macOS/Linux)
awk -v entry_file="$ENTRY_FILE" '
BEGIN { inserted = 0 }
{
  print $0
  if (!inserted && $0 ~ /^---$/) {
    while ((getline line < entry_file) > 0) print line
    close(entry_file)
    inserted = 1
  }
}
END {
  if (!inserted) {
    while ((getline line < entry_file) > 0) print line
    close(entry_file)
  }
}
' "$CHANGELOG_FILE" > "$TMP_CHANGELOG"

mv "$TMP_CHANGELOG" "$CHANGELOG_FILE"
rm -f "$ENTRY_FILE"

echo "✔ CHANGELOG updated"
