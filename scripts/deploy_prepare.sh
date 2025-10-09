#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/deploy.conf"

MAIN_DIR="$1"

echo "=== Prepare deployment ==="

# Ensure local repo exists and is valid
if [ ! -d "$LOCAL_ROOT/.git" ]; then
    echo "Error: LOCAL_ROOT '$LOCAL_ROOT' does not exist. Please run './deploy.sh prepare' or reinitialize."
    exit 1
fi

cd "$LOCAL_ROOT"

if [ ! -d ".git" ]; then
    echo "Error: $LOCAL_ROOT is not a valid Git repository."
    exit 1
fi

# Ensure deployment tracking file exists and not empty
if [ ! -f "$DEPLOY_VERSION" ] || [ ! -s "$DEPLOY_VERSION" ] ; then
    echo "Error: $DEPLOY_VERSION not found. Please run './deploy.sh init' first."
    exit 1
fi

PREV_COMMIT=$(cat "$DEPLOY_VERSION")
LATEST_COMMIT=$(git rev-parse origin/$DEPLOY_BRANCH)

if [ "$PREV_COMMIT" == "$LATEST_COMMIT" ]; then
    echo "No new commits since last deployment!"
    exit 0;
fi

echo "Generating file diff between commits..."
if ! DIFF_FILES=$(git diff --name-only "$PREV_COMMIT" "$LATEST_COMMIT" 2>/dev/null); then
    echo "❌ Error: one of the commit hashes is invalid or not found in the repository."
    echo "   Please check your deployment record file: $DEPLOY_VERSION"
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
echo "-----------------------------"

# Create old and new version files under version_diff directory
for FILE in $DIFF_FILES; do
    OLD_FILE="$MAIN_DIR/version_diff/$FILE.old"
    NEW_FILE="$MAIN_DIR/version_diff/$FILE.new"

    # Make sure for directory exists
    mkdir -p "$(dirname "$OLD_FILE")"

    echo "⏳ Preparing diff for: $FILE"

    # Create OLD_FILE; empty if missing in previous commit
    if git cat-file -e "$PREV_COMMIT:$FILE" 2>/dev/null; then
        git show "$PREV_COMMIT:$FILE" > "$OLD_FILE"
    else
        touch "$OLD_FILE"
    fi

    git show "$LATEST_COMMIT:$FILE" > "$NEW_FILE"

    echo "✅ Prepared diff for: $FILE"
done

# ✅ Save diff list and version metadata for the apply phase
echo "$DIFF_FILES" > "$MAIN_DIR/version_diff/diff_list.txt"
echo "$PREV_COMMIT" > "$MAIN_DIR/version_diff/prev_commit.txt"
echo "$LATEST_COMMIT" > "$MAIN_DIR/version_diff/latest_commit.txt"

echo "✅ Deployment preparation completed"
echo "🔌 Please connect to VPN manually before running './deploy.sh apply'."
echo "Next step: run './deploy.sh apply' to deploy changes to production."
