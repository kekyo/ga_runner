#!/bin/sh
set -e

echo "GitHub Actions Self-hosted immutable runner"
echo "Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
echo "License under MIT."
echo "https://github.com/kekyo/ga_runner/"
echo ""

sudo apt-get install -y curl uidmap podman

#-------------------------------------------------

cd scripts

./build.sh
