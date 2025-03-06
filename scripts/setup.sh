#!/bin/sh
set -e

USER_NAME="$1"
REPOSITORY_NAME="$2"
RUNNER_TOKEN="$3"
HTTP_PROXY="$4"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "usage: setup.sh <user_name> <repository_name> <runner_token> [<proxy url>]"
    exit 1
fi

#-------------------------------------------------

IMAGE_NAME="github-actions-runner"
CONTAINER_NAME="${IMAGE_NAME}_${USER_NAME}_${REPOSITORY_NAME}"

SERVICE_TEMPLATE_FILE="systemd.service.template"
SERVICE_INSTALL_PATH="/etc/systemd/system/${CONTAINER_NAME}.service"

#-------------------------------------------------

# Remove previous service
sudo systemctl daemon-reload
if [ -f "$SERVICE_INSTALL_PATH" ]; then
    echo "Remove previous installed service: $CONTAINER_NAME"
    sudo systemctl stop "$CONTAINER_NAME" || true 2>/dev/null
    sudo systemctl disable "$CONTAINER_NAME" || true 2>/dev/null
    sudo rm -f "$SERVICE_INSTALL_PATH"
fi

#---------------------------------------------------

# Install systemd service
echo "Installing systemd service: $CONTAINER_NAME"
sudo sed -e "s|@SCRIPT_PATH@|$(pwd)|g" \
         -e "s|@USER_NAME@|$USER_NAME|g" \
         -e "s|@REPOSITORY_NAME@|$REPOSITORY_NAME|g" \
         -e "s|@RUNNER_TOKEN@|$RUNNER_TOKEN|g" \
         -e "s|@CONTAINER_NAME@|$CONTAINER_NAME|g" \
         -e "s|@HTTP_PROXY@|$HTTP_PROXY|g" \
         "$SERVICE_TEMPLATE_FILE" | sudo tee "$SERVICE_INSTALL_PATH" > /dev/null
sudo chmod 600 "$SERVICE_INSTALL_PATH"
sudo systemctl daemon-reload

# Reload systemd and enable the service
echo "Enabling and starting the service: $CONTAINER_NAME"
sudo systemctl enable "$CONTAINER_NAME"
sudo systemctl start "$CONTAINER_NAME"

#-------------------------------------------------

echo "GitHub Actions Runner service is installed and started successfully."
echo "Service name: $CONTAINER_NAME"
