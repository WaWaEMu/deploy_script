#!/bin/bash
set -e

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$DEPLOY_DIR")"
source "$SCRIPT_DIR/../config/deploy.conf"

MAIN_DIR="$1"
BACKUP_ROOT="$MAIN_DIR/backups"

if [ ! -d "$BACKUP_ROOT" ]; then
    echo "❌ No backups found. Directory $BACKUP_ROOT does not exist."
    exit 1
fi

if [ "$2" == "--list" ]; then
    echo "📦 Available backups:"
    shopt -s nullglob
    BACKUP_DIRS=("$BACKUP_ROOT"/*)
    if [ ${#BACKUP_DIRS[@]} -eq 0 ]; then
        echo "⚠️  No backup directories found in $BACKUP_ROOT."
        exit 0
    fi

    for dir in "${BACKUP_DIRS[@]}"; do
        [ -d "$dir" ] && echo " - $(basename "$dir")"
    done
    exit 0
fi

TARGET_BACKUP="$2"
if [ -z "$TARGET_BACKUP" ]; then
    echo "Usage:"
    echo "  ./deploy.sh rollback --list               # List available backups"
    echo "  ./deploy.sh rollback <backup_folder>     # Roll back to specific backup"
    exit 1
fi

BACKUP_PATH="$BACKUP_ROOT/$TARGET_BACKUP"

if [ ! -d "$BACKUP_PATH" ]; then
    echo "❌ Backup '$TARGET_BACKUP' not found in $BACKUP_ROOT"
    exit 1
fi

echo ""
echo "🔍 Checking deployment environment..."
echo "------------------------------------"

# === Check if config values exist ===
if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ]; then
    echo "❌ SSH_USER or SSH_HOST not defined in config/deploy.conf"
    exit 1
fi

# === Check VPN connection ===
if [ -n "$VPN_CHECK_IP" ]; then
    if ! ping -c 1 -W 2 "$VPN_CHECK_IP" &>/dev/null; then
        echo "❌ Cannot reach $VPN_CHECK_IP. Please connect to VPN first."
        exit 1
    fi
fi

# === Check if SSH is reachable ===
if ! ping -c 1 -W 2 "$SSH_HOST" &>/dev/null; then
    echo "❌ Cannot reach SSH host: $SSH_HOST"
    echo "Please check your VPN connection or SSH settings."
    exit 1
fi

# === Check if SSH public key is set up ===
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SSH_HOST" "exit" 2>/dev/null; then
    echo "🔔 SSH public key is not configured. Please execute manually:"
    echo "ssh-copy-id -i ~/.ssh/id_ed25519.pub $SSH_USER@$SSH_HOST"
    read -p "Press Enter to continue deployment..."
fi

echo "------------------------------------"
echo "✅ Environment check completed!"
echo ""

echo ""
echo "🔄 Rolling back to backup: $TARGET_BACKUP"
echo "------------------------------------"

# === Confirm rollback ===
echo "⚠️  You are about to restore files from:"
echo "   $BACKUP_PATH"
echo "   to remote environment:"
echo "   $SSH_USER@$SSH_HOST:$PROD_ROOT"
read -p "Are you sure you want to continue? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🚫 Rollback cancelled."
    exit 0
fi

# === Check that backup is not empty ===
if [ -z "$(ls -A "$BACKUP_PATH")" ]; then
    echo "⚠️  Backup directory is empty: $BACKUP_PATH"
    exit 1
fi

# === Restore old files from backup ===
OLD_DIR="$BACKUP_PATH/old"
NEW_DIR="$BACKUP_PATH/new"

echo ""
echo "📂 Restoring old files from: $OLD_DIR"

# === Rollback 'old' files (restore previous versions) ===
if [ -d "$OLD_DIR" ]; then
    mapfile -t old_files < <(find "$OLD_DIR" -type f)
    for FILE in "${old_files[@]}"; do
        REL_PATH="${FILE#$OLD_DIR/}"
        PROD_FILE="$PROD_ROOT/$REL_PATH"
        PROD_DIR="$(dirname "$PROD_FILE")"

        echo "⬅️ Restoring: $REL_PATH"
        ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "mkdir -p \"$PROD_DIR\""
        scp -P "$SSH_PORT" "$FILE" "$SSH_USER@$SSH_HOST:$PROD_FILE"
    done
    echo "✅ Old files restored successfully."
else
    echo "ℹ️ No old files to restore."
fi

echo ""
echo "🗑️  Removing newly added files from: $NEW_DIR"

# === Rollback 'new' files (delete files that were newly added during apply) ===
if [ -d "$NEW_DIR" ]; then
    # Read all files into an array
    mapfile -d '' NEW_FILES < <(find "$NEW_DIR" -type f -print0)

    for FILE in "${NEW_FILES[@]}"; do
        REL_PATH="${FILE#$NEW_DIR/}"
        PROD_FILE="$PROD_ROOT/$REL_PATH"

        echo "➖ Deleting: $REL_PATH"
        ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "rm -f \"$PROD_FILE\""
    done

    echo "✅ New files removed successfully."
else
    echo "ℹ️ No new files to delete."
fi

# Set path to backup version record
BACKUP_DEPLOY_VERSION="$BACKUP_PATH/$DEPLOY_VERSION"
LOCAL_VERSION="$LOCAL_ROOT/$DEPLOY_VERSION"

# Copy the deploy version record back
if [ -f "$BACKUP_DEPLOY_VERSION" ]; then
    cp "$BACKUP_DEPLOY_VERSION" "$LOCAL_VERSION"
    scp -P "$SSH_PORT" "$BACKUP_DEPLOY_VERSION" "$SSH_USER@$SSH_HOST:$PROD_ROOT/$DEPLOY_VERSION"
else
    echo "⚠️ Backup deployment version record not found: $BACKUP_DEPLOY_VERSION"
fi

echo "✅ Deployment version record restored to production: $DEPLOY_VERSION"

echo "------------------------------------"
echo "🎉 Rollback completed successfully!"
echo ""
