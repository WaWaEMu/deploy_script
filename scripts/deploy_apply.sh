#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"
source "$SCRIPT_DIR/../config/deploy.conf"

MAIN_DIR="$1"

if [ -n "$VPN_CHECK_IP" ]; then
    if ! ping -c 1 -W 2 "$VPN_CHECK_IP" &>/dev/null; then
        echo "❌ Cannot reach $VPN_CHECK_IP. Please connect to VPN first."
        exit 1
    fi
fi

# === Check if SSH public key is set up ===
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SSH_HOST" "exit" 2>/dev/null; then
    echo "🔔 SSH public key is not configured. Please execute manually:"
    echo "ssh-copy-id -i ~/.ssh/id_ed25519.pub $SSH_USER@$SSH_HOST"
    read -p "Press Enter to continue deployment..."
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

# === Verify local diff files exist ===
for FILE in $DIFF_FILES; do
    if [ ! -f "$MAIN_DIR/version_diff/$FILE.new" ]; then
        echo "❌ $FILE.new not found in version_diff — aborting deployment"
        exit 1
    fi
done

# === Verify remote files match old versions ===
for FILE in $DIFF_FILES; do
    REMOTE_FILE=$PROD_ROOT/$FILE
    LOCAL_OLD="$MAIN_DIR/version_diff/$FILE.old"

    if [ ! -s "$LOCAL_OLD" ]; then
        # File did not exist before, skip comparison
        echo "ℹ️ $FILE is new, no need to compare old version."
        continue
    fi

    if ! ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cmp -s '$REMOTE_FILE' - " < "$LOCAL_OLD"; then
        echo "❌ $FILE on remote does not match old version — aborting deployment"
        exit 1
    fi
done

# === Deploy files to production via SSH/SCP ===
for FILE in $DIFF_FILES; do
    REMOTE_FILE="$PROD_ROOT/$FILE"
    REMOTE_DIR="$(dirname "$REMOTE_FILE")"
    LOCAL_NEW="$MAIN_DIR/version_diff/$FILE.new"

    echo "🚀 Processing: $FILE"

    if [ -s "$LOCAL_NEW" ]; then
        echo "📤 Uploading to $SSH_HOST:$REMOTE_FILE"
        ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "mkdir -p \"$REMOTE_DIR\""
        scp -P "$SSH_PORT" "$LOCAL_NEW" "$SSH_USER@$SSH_HOST:$REMOTE_FILE"
    else
        echo "🗑️ Removing $REMOTE_FILE from remote (file deleted)"
        ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "rm -f \"$REMOTE_FILE\""
    fi
done

# === Update deploy version on remote server ===
ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "echo '$LATEST_COMMIT' > '$PROD_ROOT/$DEPLOY_VERSION'"

# === Update local deploy version record ===
echo "$LATEST_COMMIT" > "$LOCAL_ROOT/$DEPLOY_VERSION"

echo "✅ Deployment completed successfully!"
