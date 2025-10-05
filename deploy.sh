#!/bin/bash
set -e

MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MAIN_DIR/scripts/functions.sh"

DEPLOY_MODE=$1

if [ -z "$DEPLOY_MODE" ]; then
    echo "Usage: ./deploy.sh <deploy-mode>"
    echo "Available modes: init | start"
    exit 1
fi

case "$DEPLOY_MODE" in
    init)
        bash "$MAIN_DIR/scripts/deploy_init.sh"
        ;;
    start)
        bash "$MAIN_DIR/scripts/deploy_start.sh"
        ;;
    *)
        echo "Invalid mode: $DEPLOY_MODE"
        exit 1
        ;;
esac
