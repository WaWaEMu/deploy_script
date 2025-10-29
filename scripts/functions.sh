#!/bin/bash
# === Common deployment functions ===

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "$SCRIPT_DIR"
source "$SCRIPT_DIR/../config/deploy.conf"

# Set the repository URL based on the selected clone mode (SSH or HTTPS)
get_repo_url() {
    if [ "$CLONE_MODE" == "SSH" ]; then
        echo "$SSH_REPO_URL"
    elif [ "$CLONE_MODE" == "HTTPS" ]; then
        echo "https://${GIT_USERNAME}:${GIT_PASSWORD}@${HTTPS_REPO_URL#https://}"
    else
        echo "Invalid CLONE_MODE: $CLONE_MODE" >&2
        exit 1
    fi
}

# Verify or clone repository
prepare_repo() {
    local REPO_URL="$1"
    local BRANCH="$2"

    if [ ! -d "$LOCAL_ROOT/.git" ]; then
        echo "Repository not found. Cloning..."
        git clone "$REPO_URL" "$LOCAL_ROOT"
    else
        cd "$LOCAL_ROOT"
        EXISTING_URL=$(git remote get-url origin)

        if [ "$EXISTING_URL" != "$REPO_URL" ]; then
            echo "Error: $LOCAL_ROOT exists but is not the target repository."
            echo "Expected: $REPO_URL"
            echo "Found:    $EXISTING_URL"
            exit 1
        else
            echo "Repository exists and matches target. Skipping clone."
        fi
    fi

    # Upadte repository
    cd "$LOCAL_ROOT"
    echo "Fetching latest changes..."
    git fetch --all

    # Checkout / reset to the desired branch
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git checkout "$BRANCH"
        git reset --hard "origin/$BRANCH"
        echo "Switched to existing branch '$BRANCH' and synced with origin."
    else
        git checkout -b "$BRANCH" "origin/$BRANCH"
        echo "Created local branch '$BRANCH' from origin/$BRANCH."
    fi
}

# Function to rollback a single backup
rollback_single_backup() {
    local TARGET_BACKUP="$1"
    local BACKUP_PATH="$BACKUP_ROOT/$TARGET_BACKUP"

    # Check that backup is not empty
    if [ -z "$(ls -A "$BACKUP_PATH")" ]; then
        echo "⚠️  Backup directory is empty: $BACKUP_PATH"
        exit 1
    fi

    # Restore old files from backup
    OLD_DIR="$BACKUP_PATH/old"
    NEW_DIR="$BACKUP_PATH/new"

    # Rollback 'old' files (restore previous versions)
    if [ -d "$OLD_DIR" ]; then
        echo "Restoring old files..."
        mapfile -t old_files < <(find "$OLD_DIR" -type f)
        for FILE in "${old_files[@]}"; do
            REL_PATH="${FILE#$OLD_DIR/}"
            PROD_FILE="$PROD_ROOT/$REL_PATH"
            PROD_DIR="$(dirname "$PROD_FILE")"

            ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "mkdir -p \"$PROD_DIR\""
            scp -P "$SSH_PORT" "$FILE" "$SSH_USER@$SSH_HOST:$PROD_FILE" &>/dev/null
        done
        echo "   Old files restored."
    else
        echo "   No old files to restore."
    fi

    echo ""

    # Rollback 'new' files (delete files that were newly added during apply)
    if [ -d "$NEW_DIR" ]; then
        echo "Removing newly added files..."
        # Read all files into an array
        mapfile -d '' NEW_FILES < <(find "$NEW_DIR" -type f -print0)

        for FILE in "${NEW_FILES[@]}"; do
            REL_PATH="${FILE#$NEW_DIR/}"
            PROD_FILE="$PROD_ROOT/$REL_PATH"

            ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "rm -f \"$PROD_FILE\""
        done

        echo "   New files removed."
    else
        echo "   No new files to delete."
    fi

    # Set path to backup version record
    BACKUP_DEPLOY_VERSION="$BACKUP_PATH/$DEPLOY_VERSION"
    LOCAL_VERSION="$LOCAL_ROOT/$DEPLOY_VERSION"

    # Copy the deploy version record back
    if [ -f "$BACKUP_DEPLOY_VERSION" ]; then
        cp "$BACKUP_DEPLOY_VERSION" "$LOCAL_VERSION"
        scp -P "$SSH_PORT" "$BACKUP_DEPLOY_VERSION" "$SSH_USER@$SSH_HOST:$PROD_ROOT/$DEPLOY_VERSION" &>/dev/null

        echo "   Deployment version updated: $DEPLOY_VERSION"
    else
        echo "   Deployment version file not found."
    fi
}
