#!/bin/sh
set -e

sudo apt-get install -y curl podman

#-------------------------------------------------

cd scripts

./build.sh
