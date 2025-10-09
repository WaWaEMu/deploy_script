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
