#!/bin/sh
set -e

# GitHub Actions Self-hosted immutable runner"
# Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
# License under MIT.
# https://github.com/kekyo/ga_runner/

CONTAINER_NAME="$1"
INSTANCE_NAME="$2"

if [ -z "$CONTAINER_NAME" ] || [ -z "$INSTANCE_NAME" ]; then
    echo "usage: run.sh <container_name> <instance_name>"
    exit 1
fi

#-------------------------------------------------

IMAGE_NAME="github-actions-runner"

SCRIPT_DIR="$(dirname "$0")"
CONFIGURE_BASE_DIR="${SCRIPT_DIR}/config"
CACHE_BASE_DIR="${SCRIPT_DIR}/runner-cache"

#-------------------------------------------------

# Preserve the cache directory
CACHE_DIR="${CACHE_BASE_DIR}/${INSTANCE_NAME}"
APT_DIR="${CACHE_DIR}/apt"
APT_ARCHIVE_DIR="${APT_DIR}/archives"
APT_LIST_DIR="${APT_DIR}/lists"
NPM_DIR="${CACHE_DIR}/npm"
NUGET_DIR="${CACHE_DIR}/nuget"
DOTNET_DIR="${CACHE_DIR}/dotnet"
MAVEN_DIR="${CACHE_DIR}/maven"
DOT_CACHE_DIR="${CACHE_DIR}/cache"

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

mkdir -p "$MAVEN_DIR"
sudo chmod 775 "$MAVEN_DIR"
sudo chgrp 1001 "$MAVEN_DIR"

mkdir -p "$DOT_CACHE_DIR"
sudo chmod 775 "$DOT_CACHE_DIR"
sudo chgrp 1001 "$DOT_CACHE_DIR"

CONFIGURE_DIR="${CONFIGURE_BASE_DIR}/${INSTANCE_NAME}"

#-------------------------------------------------

# Run the container
sudo podman run --rm --name "${CONTAINER_NAME}" \
    -e INSTANCE_NAME="$INSTANCE_NAME" \
    --userns=keep-id \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /etc/subuid:/etc/subuid:ro \
    -v /etc/subgid:/etc/subgid:ro \
    -v /dev/fuse:/dev/fuse:rw \
    -v ${CACHE_DIR}:/runner-cache \
    -v ${CONFIGURE_DIR}:/config \
    -v ${APT_ARCHIVE_DIR}:/var/cache/apt/archives \
    -v ${APT_LIST_DIR}:/var/lib/apt/lists \
    -v ${NPM_DIR}:/home/runner/.npm \
    -v ${NUGET_DIR}:/home/runner/.nuget \
    -v ${DOTNET_DIR}:/home/runner/.dotnet \
    -v ${MAVEN_DIR}:/home/runner/.m2/repository \
    -v ${DOT_CACHE_DIR}:/home/runner/.cache \
    $IMAGE_NAME

exit $?
