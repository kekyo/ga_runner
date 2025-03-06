#!/bin/sh
set -e

CONTAINER_NAME="$1"

if [ -z "$CONTAINER_NAME" ]; then
    echo "usage: stop.sh <container_name>"
    exit 1
fi

sudo podman stop "$CONTAINER_NAME" 2>/dev/null
sudo podman rm -f "$CONTAINER_NAME" 2>/dev/null
