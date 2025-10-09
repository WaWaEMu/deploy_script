#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"
source "$SCRIPT_DIR/../config/deploy.conf"

REPO_URL=$(get_repo_url)
prepare_repo "$REPO_URL" "$DEPLOY_BRANCH"

echo "=== Initialize deployment tracking ==="

if [ ! -f "$DEPLOY_VERSION" ] || [ ! -s "$DEPLOY_VERSION" ] ; then
    echo "⚠️  Deployment record file not found or empty."
    read -p "Please enter the current production commit hash to initialize tracking: " INPUT_HASH

    if [ -z "$INPUT_HASH" ]; then
        echo "Error: commit hash cannot be empty."
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
    echo "Deployment tracking initialized with commit: $COMMIT_HASH"
else
    COMMIT_HASH=$(cat "$DEPLOY_VERSION")
    echo "Found existing deployment record: $COMMIT_HASH"
fi

# Confirm commit exists
if ! git cat-file -e "${COMMIT_HASH}^{commit}" 2>/dev/null; then
    echo "Error: commit $COMMIT_HASH not found in repository."
    exit 1
fi

echo "✅ Deployment tracking successfully initialized."
echo "Next step: run './deploy.sh prepare' to generate deployment diffs."
