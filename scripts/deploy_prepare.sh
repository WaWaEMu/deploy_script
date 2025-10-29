#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/deploy.conf"

MAIN_DIR="$1"

echo ""
echo "🚀 Prepare Deployment"
echo "------------------------------------------"

# Ensure local repo exists and is valid
if [ ! -d "$LOCAL_ROOT/.git" ]; then
    echo "❌ Error: LOCAL_ROOT '$LOCAL_ROOT' does not exist."
    echo "   Please run './deploy.sh init' first or reinitialize."
    exit 1
fi

cd "$LOCAL_ROOT"

if [ ! -d ".git" ]; then
    echo "❌ Error: $LOCAL_ROOT is not a valid Git repository."
    exit 1
fi

# Ensure deployment tracking file exists and not empty
if [ ! -f "$DEPLOY_VERSION" ] || [ ! -s "$DEPLOY_VERSION" ] ; then
    echo "❌ Error: $DEPLOY_VERSION not found. Please run './deploy.sh init' first."
    exit 1
fi

PREV_COMMIT=$(cat "$DEPLOY_VERSION")
LATEST_COMMIT=$(git rev-parse origin/$DEPLOY_BRANCH)

if [ "$PREV_COMMIT" == "$LATEST_COMMIT" ]; then
    echo "ℹ️  No new commits since last deployment!"
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
    echo "ℹ️  No file changes detected!"
    exit 0
fi

echo "✅ Diff calculation completed."
echo ""
echo "📄 Changed files since last deployment:"
for FILE in $DIFF_FILES; do
    echo "   - $FILE"
done

# Create old and new version files under version_diff directory
for FILE in $DIFF_FILES; do
    OLD_FILE="$MAIN_DIR/version_diff/$FILE.old"
    NEW_FILE="$MAIN_DIR/version_diff/$FILE.new"

    # Make sure for directory exists
    mkdir -p "$(dirname "$OLD_FILE")"

    # Create OLD_FILE; empty if missing in previous commit (new file)
    if git cat-file -e "$PREV_COMMIT:$FILE" 2>/dev/null; then
        git show "$PREV_COMMIT:$FILE" > "$OLD_FILE"
    else
        touch "$OLD_FILE"
    fi

    # Create NEW_FILE; empty if missing in latest commit (deleted file)
    if git cat-file -e "$LATEST_COMMIT:$FILE" 2>/dev/null; then
        git show "$LATEST_COMMIT:$FILE" > "$NEW_FILE"
    else
        touch "$NEW_FILE"
    fi
done

# ✅ Save diff list and version metadata for the apply phase
echo "$DIFF_FILES" > "$MAIN_DIR/version_diff/diff_list.txt"
echo "$PREV_COMMIT" > "$MAIN_DIR/version_diff/prev_commit.txt"
echo "$LATEST_COMMIT" > "$MAIN_DIR/version_diff/latest_commit.txt"

echo ""
echo "✅ Deployment preparation completed."
echo "------------------------------------------"
echo ""
echo "🔌 Please connect to VPN manually before running './deploy.sh apply'."
echo ""
echo "👉 Next step:"
echo "   Run './deploy.sh apply'"
echo "   to deploy changes to production."
