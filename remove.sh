#!/bin/sh
set -e

USER_NAME="$1"
REPOSITORY_NAME="$2"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ]; then
    echo "usage: remove.sh <user_name> <repository_name>"
    exit 1
fi

#---------------------------------------------------

IMAGE_NAME="github-actions-runner"
CONTAINER_NAME="${IMAGE_NAME}_${USER_NAME}_${REPOSITORY_NAME}"

SERVICE_INSTALL_PATH="/etc/systemd/system/${CONTAINER_NAME}.service"

#-------------------------------------------------

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

echo "GitHub Actions Runner service is removed successfully."
echo "Service name: ${CONTAINER_NAME}"
