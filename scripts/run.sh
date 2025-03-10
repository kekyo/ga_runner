#!/bin/sh
set -e

CONTAINER_NAME="$1"
INSTANCE_NAME="$2"

if [ -z "$CONTAINER_NAME" ] || [ -z "$INSTANCE_NAME" ]; then
    echo "usage: run.sh <container_name> <instance_name>"
    exit 1
fi

#-------------------------------------------------

IMAGE_NAME="github-actions-runner"

#-------------------------------------------------

# Preserve the cache directory
CACHE_DIR="$(dirname $0)/runner-cache"
CONFIGURE_DIR="$(dirname $0)/config/${INSTANCE_NAME}"

#-------------------------------------------------

# Run the container
sudo podman run --rm --name "${CONTAINER_NAME}" \
    -e INSTANCE_NAME="$INSTANCE_NAME" \
    -v ${CACHE_DIR}:/runner-cache \
    -v ${CONFIGURE_DIR}:/config \
    $IMAGE_NAME

exit $?
