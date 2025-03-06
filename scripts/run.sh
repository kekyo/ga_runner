#!/bin/sh
set -e

USER_NAME="$1"
REPOSITORY_NAME="$2"
RUNNER_TOKEN="$3"
CONTAINER_NAME="$4"
HTTP_PROXY="$5"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ] || [ -z "$RUNNER_TOKEN" ] || [ -z "$CONTAINER_NAME" ]; then
    echo "usage: run.sh <user_name> <repository_name> <runner_token> <container_name> [<proxy url>]"
    exit 1
fi

#-------------------------------------------------

IMAGE_NAME="github-actions-runner"
GITHUB_URL="https://github.com/${USER_NAME}/${REPOSITORY_NAME}"

#-------------------------------------------------

# Runner name (on GitHub Actions console)
if RUNNER_NAME=$(hostname -A 2>/dev/null | head -n 1); then
    if [ -z "$RUNNER_NAME" ]; then
        RUNNER_NAME=$(hostname -f 2>/dev/null || hostname)
    fi
else
    RUNNER_NAME=$(hostname -f 2>/dev/null || hostname)
fi

#-------------------------------------------------

# Preserve the cache directory
CACHE_DIR="$(dirname $0)/runner-cache"

mkdir -p "$CACHE_DIR"
chmod 770 "$CACHE_DIR"
chgrp 1001 "$CACHE_DIR"

#-------------------------------------------------

# Run the container
sudo podman run --rm --name "${CONTAINER_NAME}" \
    -e CONTAINER_NAME="$CONTAINER_NAME" \
    -e HTTP_PROXY="$HTTP_PROXY" \
    -e GITHUB_URL="$GITHUB_URL" \
    -e RUNNER_NAME="$RUNNER_NAME" \
    -e RUNNER_TOKEN="$RUNNER_TOKEN" \
    -v ${CACHE_DIR}:/runner-cache \
    $IMAGE_NAME

exit $?
