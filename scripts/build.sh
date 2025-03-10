#!/bin/sh
set -e

# GitHub Actions Self-hosted immutable runner"
# Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
# License under MIT.
# https://github.com/kekyo/ga_runner/

#-------------------------------------------------

IMAGE_NAME="github-actions-runner"

#-------------------------------------------------

# Remove previous podman image
sudo podman rmi -i "localhost/${IMAGE_NAME}"

# Build podman image
sudo podman build -t "$IMAGE_NAME" .

#-------------------------------------------------

echo "Podman image is built successfully."
echo "Image name: ${IMAGE_NAME}"
