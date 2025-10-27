#!/bin/bash
set -e

MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MAIN_DIR/scripts/functions.sh"

DEPLOY_MODE=$1

if [ -z "$DEPLOY_MODE" ]; then
    echo "Usage: ./deploy.sh <deploy-mode>"
    echo "Available modes: init | prepare"
    exit 1
fi

case "$DEPLOY_MODE" in
    init)
        bash "$MAIN_DIR/scripts/deploy_init.sh"
        ;;
    prepare)
        export MAIN_DIR
        bash "$MAIN_DIR/scripts/deploy_prepare.sh" "$MAIN_DIR"
        ;;
    apply)
        export MAIN_DIR
        bash "$MAIN_DIR/scripts/deploy_apply.sh" "$MAIN_DIR"
        ;;
    rollback)
        export MAIN_DIR
        bash "$MAIN_DIR/scripts/deploy/rollback.sh" "$MAIN_DIR" "$2"
        ;;
    *)
        echo "Invalid mode: $DEPLOY_MODE"
        exit 1
        ;;
esac
