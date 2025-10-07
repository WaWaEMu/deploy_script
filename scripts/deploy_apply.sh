#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"
source "$SCRIPT_DIR/../config/deploy.conf"

MAIN_DIR="$1"

if [ ! -d "$PROD_ROOT" ]; then
    echo "Error: Production directory $PROD_ROOT does not exists!"
    exit 1
fi

# === Load version diff info ===
if [ ! -f "$MAIN_DIR/version_diff/diff_list.txt" ]; then
    echo "Error: version_diff/diff_list.txt not found. Please run './deploy.sh prepare' first."
    exit 1
fi

DIFF_FILES=$(cat "$MAIN_DIR/version_diff/diff_list.txt")
PREV_COMMIT=$(cat "$MAIN_DIR/version_diff/prev_commit.txt")
LATEST_COMMIT=$(cat "$MAIN_DIR/version_diff/latest_commit.txt")

echo "Applying changes from $PREV_COMMIT → $LATEST_COMMIT ..."
echo "------------------------------------------"

# === Verify production files and permissions ===
for FILE in $DIFF_FILES; do
    PROD_FILE="$PROD_ROOT/$FILE"

    # 1️⃣ Check content matches old version
    if ! diff "$PROD_FILE" "$MAIN_DIR/version_diff/$FILE.old" >/dev/null 2>&1; then
        echo "❌ $FILE does not match old version — aborting deployment"
        exit 1
    fi

    # 2️⃣ Check write permission
    if [ ! -w "$PROD_FILE" ]; then
        echo "❌ $FILE is not writable — aborting deployment"
        exit 1
    fi
done

# 3️⃣ Check deploy version file write permission (directory must be writable)
DEPLOY_FILE_PATH="$PROD_ROOT/$DEPLOY_FILE"
DEPLOY_DIR="$(dirname "$DEPLOY_FILE_PATH")"

if [ ! -d "$DEPLOY_DIR" ] || [ ! -w "$DEPLOY_DIR" ]; then
    echo "❌ Directory $DEPLOY_DIR is not writable — aborting deployment"
    exit 1
fi

echo "✅ Verification passed. All production files match old versions."

# === Apply new files ===
for FILE in $DIFF_FILES; do
    echo "🚀 Deploying: $FILE"
    mkdir -p "$(dirname "$PROD_ROOT/$FILE")"
    cp "$MAIN_DIR/version_diff/$FILE.new" "$PROD_ROOT/$FILE"
done

# === Update deploy version record ===
# -------------------------------
# Local repository (development environment)
echo "$LATEST_COMMIT" > "$LOCAL_REPO_PATH/$DEPLOY_FILE"

# Production environment
echo "$LATEST_COMMIT" > "$PROD_ROOT/$DEPLOY_FILE"

echo "✅ Deployment completed successfully!"
