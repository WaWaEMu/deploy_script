#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/deploy.conf"

echo "=== Start deployment ==="

# Ensure local repo exists and is valid
if [ ! -d "$LOCAL_REPO_PATH/.git" ]; then
    echo "Error: LOCAL_REPO_PATH '$LOCAL_REPO_PATH' does not exist. Please run './deploy.sh prepare' or reinitialize."
    exit 1
fi

cd "$LOCAL_REPO_PATH"

if [ ! -d ".git" ]; then
    echo "Error: $LOCAL_REPO_PATH is not a valid Git repository."
    exit 1
fi

# Ensure deployment tracking file exists and not empty
if [ ! -f "$DEPLOY_FILE" ] || [ ! -s "$DEPLOY_FILE" ] ; then
    echo "Error: $DEPLOY_FILE not found. Please run './deploy.sh init' first."
    exit 1
fi

PREV_COMMIT=$(cat "$DEPLOY_FILE")
LATEST_COMMIT=$(git rev-parse origin/$DEPLOY_BRANCH)

if [ "$PREV_COMMIT" == "$LATEST_COMMIT" ]; then
    echo "No new commits since last deployment!"
    exit 0;
fi

echo "Generating file diff between commits..."
if ! DIFF_FILES=$(git diff --name-only "$PREV_COMMIT" "$LATEST_COMMIT" 2>/dev/null); then
    echo "❌ Error: one of the commit hashes is invalid or not found in the repository."
    echo "   Please check your deployment record file: $DEPLOY_FILE"
    echo "   Current value: $PREV_COMMIT"
    exit 1
fi

if [ -z "$DIFF_FILES" ]; then
    echo "No file changes detected!"
    exit 0
fi

echo "✅ Deployment preparation completed."
echo "Changed files since last deployment:"
echo "$DIFF_FILES"
