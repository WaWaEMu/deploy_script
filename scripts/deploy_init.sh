#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"
source "$SCRIPT_DIR/../config/deploy.conf"

echo ""
echo "🌐 Repository Connection Mode"
echo "------------------------------------------"

REPO_URL=$(get_repo_url)

echo "------------------------------------------"


echo ""
echo "📦 Repository Setup"
echo "------------------------------------------"

prepare_repo "$REPO_URL" "$DEPLOY_BRANCH"

echo "------------------------------------------"

echo ""
echo "🚀 Initialize deployment tracking"
echo "------------------------------------------"

# Clean up old version_diff directory if exists
VERSION_DIFF_DIR="$MAIN_DIR/version_diff"
if [ -d "$VERSION_DIFF_DIR" ]; then
    echo "🧹 Cleaning up previous version_diff directory..."
    rm -rf "$VERSION_DIFF_DIR"
fi

if [ ! -f "$DEPLOY_VERSION" ] || [ ! -s "$DEPLOY_VERSION" ] ; then
    echo "⚠️  Deployment record file not found or empty."
    echo "Please enter the current production commit hash to initialize tracking:"
    read -p "> " INPUT_HASH

    if [ -z "$INPUT_HASH" ]; then
        echo "❌ Error: commit hash cannot be empty."
        exit 1
    fi

    # Try to expand short commit hash to full hash
    FULL_HASH=$(git rev-parse "$INPUT_HASH" 2>/dev/null)
    if [ -z "$FULL_HASH" ]; then
        echo "❌ Error: commit $INPUT_HASH not found in repository."
        exit 1
    fi

    COMMIT_HASH=$FULL_HASH
    echo "$COMMIT_HASH" > "$DEPLOY_VERSION"
    echo "→ Deployment tracking initialized with commit:"
    echo "  $COMMIT_HASH"
else
    COMMIT_HASH=$(cat "$DEPLOY_VERSION")
    echo "→ Found existing deployment record:"
    echo "  $COMMIT_HASH"
fi

# Confirm commit exists
if ! git cat-file -e "${COMMIT_HASH}^{commit}" 2>/dev/null; then
    echo "Error: commit $COMMIT_HASH not found in repository."
    exit 1
fi

echo ""
echo "✅ Deployment tracking successfully initialized."
echo "------------------------------------------"
echo ""
echo "👉 Next step:"
echo "   Run './deploy.sh prepare'"
echo "   to generate deployment diffs."
