#!/bin/bash
set -e

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$DEPLOY_DIR")"
source "$SCRIPT_DIR/functions.sh"
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

# Find all backups newer than the target and rollback sequentially
shopt -s nullglob
ALL_BACKUPS=("$BACKUP_ROOT"/*)

# Sort backup directories
SORTED_BACKUPS=($(for dir in "${ALL_BACKUPS[@]}"; do basename "$dir"; done | sort))

# Find the target index
TARGET_INDEX=-1
for i in "${!SORTED_BACKUPS[@]}"; do
    if [[ "${SORTED_BACKUPS[$i]}" == "$TARGET_BACKUP" ]]; then
        TARGET_INDEX=$i
        break
    fi
done

if [ "$TARGET_INDEX" -lt 0 ]; then
    echo "❌ Backup $TARGET_BACKUP not found in $BACKUP_ROOT"
    exit 1
fi

# Newer backups sorted newest → oldest
ROLLBACK_BACKUPS=($(for b in "${SORTED_BACKUPS[@]:$TARGET_INDEX}"; do echo "$b"; done | sort -r))

echo ""
echo "🔍 Checking deployment environment..."
echo "------------------------------------------"

# Check if config values exist
if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ]; then
    echo "❌ SSH_USER or SSH_HOST not defined in config/deploy.conf"
    exit 1
fi

# Check VPN connection
if [ -n "$VPN_CHECK_IP" ]; then
    if ! ping -c 1 -W 2 "$VPN_CHECK_IP" &>/dev/null; then
        echo "❌ Cannot reach $VPN_CHECK_IP. Please connect to VPN first."
        exit 1
    fi
fi

# Check if SSH is reachable
if ! ping -c 1 -W 2 "$SSH_HOST" &>/dev/null; then
    echo "❌ Cannot reach SSH host: $SSH_HOST"
    echo "Please check your VPN connection or SSH settings."
    exit 1
fi

# Check if SSH public key is set up
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SSH_HOST" "exit" 2>/dev/null; then
    echo "🔔 SSH public key is not configured. Please execute manually:"
    echo "ssh-copy-id -i ~/.ssh/id_ed25519.pub $SSH_USER@$SSH_HOST"
    read -p "Press Enter to continue deployment..."
fi

echo "✅ Environment check completed!"

echo ""
echo "🔁 Rolling back to backup"
echo "------------------------------------------"

# Confirm rollback
echo "⚠️  You are about to restore the following backups (newest → oldest):"
for BACKUP in "${ROLLBACK_BACKUPS[@]}"; do
    echo "   - $BACKUP"
done
echo "   to remote environment:" 
echo "   $SSH_USER@$SSH_HOST:$PROD_ROOT"

read -p "Are you sure you want to continue? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🚫 Rollback cancelled."
    exit 0
fi

echo ""
echo "Starting rollback sequence..."

# Sequential rollback
for BACKUP in "${ROLLBACK_BACKUPS[@]}"; do
    echo ""
    echo "🔁 Rolling back: $BACKUP"

    rollback_single_backup "$BACKUP"

    echo "✅ Rollback of $BACKUP completed."
done

echo "------------------------------------------"
echo "🎉 All selected backups have been rolled back successfully!"
echo ""
