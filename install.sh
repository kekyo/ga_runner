#!/bin/sh
set -e

USER_NAME="$1"
REPOSITORY_NAME="$2"
INSTANCE_POSTFIX="$3"
GITHUB_PAT="$4"
HTTP_PROXY="$5"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ] || [ -z "$GITHUB_PAT" ]; then
    echo "usage: install.sh <user_name> <repository_name> <instance_postfix> <github_pat> [<proxy url>]"
    exit 1
fi

#---------------------------------------------------

echo "GitHub Actions Self-hosted immutable runner"
echo "Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
echo "License under MIT."
echo "https://github.com/kekyo/ga_runner/"
echo ""

cd scripts

./setup.sh "$USER_NAME" "$REPOSITORY_NAME" "$INSTANCE_POSTFIX" "$GITHUB_PAT" "$HTTP_PROXY"
