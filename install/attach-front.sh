#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------
# Attach an existing frontend as OrizonStack submodule
# Script location: install/
# --------------------------------------------

if [ $# -ne 1 ]; then
  echo "Usage: ./install/attach-front.sh <github-repo-url>"
  echo "Example:"
  echo "  ./install/attach-front.sh git@github.com:mygroup/acme-front.git"
  exit 1
fi

FRONT_REPO="$1"

# --------------------------------------------
# Move to OrizonStack root
# --------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$STACK_ROOT"

TARGET_DIR="front"

echo "======================================"
echo " Attaching existing frontend"
echo "======================================"
echo " Repository : $FRONT_REPO"
echo " Target     : $TARGET_DIR"
echo " Stack root : $STACK_ROOT"
echo

# --------------------------------------------
# Safety checks
# --------------------------------------------
if [ ! -d ".git" ]; then
  echo "❌ Not in OrizonStack root (no .git found)."
  exit 1
fi

if [ -d "$TARGET_DIR" ]; then
  echo "❌ Directory '$TARGET_DIR' already exists."
  echo "Remove or detach the existing frontend first."
  exit 1
fi

# --------------------------------------------
# Attach submodule
# --------------------------------------------
echo "▶ Adding Git submodule"
git submodule add "$FRONT_REPO" "$TARGET_DIR"

echo "▶ Initializing submodule"
git submodule update --init --recursive "$TARGET_DIR"

# --------------------------------------------
# Sanity check
# --------------------------------------------
if [ ! -f "$TARGET_DIR/package.json" ]; then
  echo "⚠️  Warning: package.json not found in $TARGET_DIR."
  echo "This may not be a Node / Next.js frontend."
fi

# --------------------------------------------
# Commit
# --------------------------------------------
echo "▶ Recording OrizonStack state"
git add .gitmodules "$TARGET_DIR"
git commit -m "Attach frontend submodule ($FRONT_REPO)"

echo
echo "======================================"
echo " ✔ Frontend successfully attached"
echo " Directory: $TARGET_DIR"
echo "======================================"
