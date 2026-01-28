#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------
# Attach an existing backend as OrizonStack submodule
# Script location: install/
# --------------------------------------------

if [ $# -ne 1 ]; then
  echo "Usage: ./install/attach-back.sh <github-repo-url>"
  echo "Example:"
  echo "  ./install/attach-back.sh git@github.com:mygroup/acme-back.git"
  exit 1
fi

BACK_REPO="$1"

# --------------------------------------------
# Move to OrizonStack root
# --------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$STACK_ROOT"

TARGET_DIR="back"

echo "======================================"
echo " Attaching existing backend"
echo "======================================"
echo " Repository : $BACK_REPO"
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
  echo "Remove or detach the existing backend first."
  exit 1
fi

# --------------------------------------------
# Attach submodule
# --------------------------------------------
echo "▶ Adding Git submodule"
git submodule add "$BACK_REPO" "$TARGET_DIR"

echo "▶ Initializing submodule"
git submodule update --init --recursive "$TARGET_DIR"

# --------------------------------------------
# Sanity check
# --------------------------------------------
if [ ! -f "$TARGET_DIR/composer.json" ]; then
  echo "⚠️  Warning: composer.json not found in $TARGET_DIR."
  echo "This may not be a Laravel backend."
fi

# --------------------------------------------
# Commit
# --------------------------------------------
echo "▶ Recording OrizonStack state"
git add .gitmodules "$TARGET_DIR"
git commit -m "Attach backend submodule ($BACK_REPO)"

echo
echo "======================================"
echo " ✔ Backend successfully attached"
echo " Directory: $TARGET_DIR"
echo "======================================"