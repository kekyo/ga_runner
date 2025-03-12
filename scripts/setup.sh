#!/bin/sh
set -e

# GitHub Actions Self-hosted immutable runner"
# Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
# License under MIT.
# https://github.com/kekyo/ga_runner/

USER_NAME="$1"
REPOSITORY_NAME="$2"
INSTANCE_POSTFIX="$3"
RUNNER_TOKEN="$4"
HTTP_PROXY="$5"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "usage: setup.sh <user_name> <repository_name> <instance_postfix> <runner_token> [<proxy url>]"
    exit 1
fi

#-------------------------------------------------

IMAGE_NAME="github-actions-runner"

if [ -z "$INSTANCE_POSTFIX" ]; then
    INSTANCE_NAME="${USER_NAME}_${REPOSITORY_NAME}"
else
    INSTANCE_NAME="${USER_NAME}_${REPOSITORY_NAME}_${INSTANCE_POSTFIX}"
fi

CONTAINER_NAME="${IMAGE_NAME}_${INSTANCE_NAME}"
GITHUB_URL="https://github.com/${USER_NAME}/${REPOSITORY_NAME}"

SERVICE_TEMPLATE_FILE="systemd.service.template"
SERVICE_INSTALL_PATH="/etc/systemd/system/${CONTAINER_NAME}.service"

SCRIPT_DIR="$(dirname "$0")"
CONFIGURE_BASE_DIR="${SCRIPT_DIR}/config"
CACHE_BASE_DIR="${SCRIPT_DIR}/runner-cache"

#-------------------------------------------------

# Preserve the cache and configuration directory
CACHE_DIR="${CACHE_BASE_DIR}/${INSTANCE_NAME}"
APT_DIR="${CACHE_DIR}/apt"
APT_ARCHIVE_DIR="${APT_DIR}/archives"
APT_LIST_DIR="${APT_DIR}/lists"
NPM_DIR="${CACHE_DIR}/npm"
NUGET_DIR="${CACHE_DIR}/nuget"
DOTNET_DIR="${CACHE_DIR}/dotnet"
PIP_DIR="${CACHE_DIR}/pip"
MAVEN_DIR="${CACHE_DIR}/maven"

mkdir -p "$CACHE_DIR"
sudo chmod 770 "$CACHE_DIR"
sudo chgrp 1001 "$CACHE_DIR"

mkdir -p "$APT_DIR"
sudo chmod 775 "$APT_DIR"
sudo chgrp 1001 "$APT_DIR"

mkdir -p "$APT_ARCHIVE_DIR"
sudo chmod 775 "$APT_ARCHIVE_DIR"
sudo chgrp 1001 "$APT_ARCHIVE_DIR"

mkdir -p "$APT_LIST_DIR"
sudo chmod 775 "$APT_LIST_DIR"
sudo chgrp 1001 "$APT_LIST_DIR"

mkdir -p "$NPM_DIR"
sudo chmod 775 "$NPM_DIR"
sudo chgrp 1001 "$NPM_DIR"

mkdir -p "$NUGET_DIR"
sudo chmod 775 "$NUGET_DIR"
sudo chgrp 1001 "$NUGET_DIR"

mkdir -p "$DOTNET_DIR"
sudo chmod 775 "$DOTNET_DIR"
sudo chgrp 1001 "$DOTNET_DIR"

mkdir -p "$PIP_DIR"
sudo chmod 775 "$PIP_DIR"
sudo chgrp 1001 "$PIP_DIR"

mkdir -p "$MAVEN_DIR"
sudo chmod 775 "$MAVEN_DIR"
sudo chgrp 1001 "$MAVEN_DIR"

mkdir -p "$CONFIGURE_BASE_DIR"
sudo chmod 770 "$CONFIGURE_BASE_DIR"
sudo chgrp 1001 "$CONFIGURE_BASE_DIR"

CONFIGURE_DIR="${CONFIGURE_BASE_DIR}/${INSTANCE_NAME}"

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

# Runner name (on GitHub Actions console)
if RUNNER_BASE_NAME=$(hostname -A 2>/dev/null | head -n 1 | awk '{$1=$1; print}'); then
    if [ -z "$RUNNER_BASE_NAME" ]; then
        RUNNER_BASE_NAME=$(hostname -f 2>/dev/null || hostname)
    fi
else
    RUNNER_BASE_NAME=$(hostname -f 2>/dev/null || hostname)
fi

if [ -z "$INSTANCE_POSTFIX" ]; then
    RUNNER_NAME="$RUNNER_BASE_NAME"
else
    RUNNER_NAME="${RUNNER_BASE_NAME}_${INSTANCE_POSTFIX}"
fi

#---------------------------------------------------

# Clean and save configuration
sudo rm -rf "$CONFIGURE_DIR"
mkdir -p "$CONFIGURE_DIR"
sudo chmod 770 "$CONFIGURE_DIR"
sudo chgrp 1001 "$CONFIGURE_DIR"

echo "$GITHUB_URL" | tee "${CONFIGURE_DIR}/github_url" 2>/dev/null
echo "$RUNNER_NAME" | tee "${CONFIGURE_DIR}/runner_name" 2>/dev/null
echo "$RUNNER_TOKEN" | tee "${CONFIGURE_DIR}/runner_token" 2>/dev/null

if [ ! -z "$HTTP_PROXY" ]; then
    echo "$HTTP_PROXY" | tee "${CONFIGURE_DIR}/http_proxy" 2>/dev/null
fi

#---------------------------------------------------

# Install systemd service
echo "Installing systemd service: $CONTAINER_NAME"
sudo sed -e "s|@SCRIPT_PATH@|$(pwd)|g" \
         -e "s|@CONTAINER_NAME@|$CONTAINER_NAME|g" \
         -e "s|@INSTANCE_NAME@|$INSTANCE_NAME|g" \
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
