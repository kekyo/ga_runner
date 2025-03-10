#!/bin/sh
set -e

USER_NAME="$1"
REPOSITORY_NAME="$2"
INSTANCE_POSTFIX="$3"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ]; then
    echo "usage: remove.sh <user_name> <repository_name> <instance_postfix>"
    exit 1
fi

#---------------------------------------------------

IMAGE_NAME="github-actions-runner"

if [ -z "$INSTANCE_POSTFIX" ]; then
    INSTANCE_NAME="${USER_NAME}_${REPOSITORY_NAME}"
else
    INSTANCE_NAME="${USER_NAME}_${REPOSITORY_NAME}_${INSTANCE_POSTFIX}"
fi

CONTAINER_NAME="${IMAGE_NAME}_${INSTANCE_NAME}"

CONFIGURE_BASE_DIR="$(dirname "$0")/scripts/config"
CONFIGURE_DIR="${CONFIGURE_BASE_DIR}/${INSTANCE_NAME}"

SERVICE_INSTALL_PATH="/etc/systemd/system/${CONTAINER_NAME}.service"

#-------------------------------------------------

echo "GitHub Actions Self-hosted immutable runner"
echo "Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
echo "License under MIT."
echo "https://github.com/kekyo/ga_runner/"
echo ""

# Remove previous service
if [ -f "$SERVICE_INSTALL_PATH" ]; then
    echo "Removing previous installed service: $CONTAINER_NAME"
    sudo systemctl daemon-reload
    sudo systemctl stop "$CONTAINER_NAME" || true 2>/dev/null
    sudo systemctl disable "$CONTAINER_NAME" || true 2>/dev/null
    sudo rm -f "$SERVICE_INSTALL_PATH"
    sudo systemctl daemon-reload
fi

#-------------------------------------------------

# Remove configuration

sudo rm -rf "$CONFIGURE_DIR"

#-------------------------------------------------

echo "GitHub Actions Runner service is removed successfully."
echo "Service name: ${CONTAINER_NAME}"
