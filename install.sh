#!/bin/sh
set -e

USER_NAME="$1"
REPOSITORY_NAME="$2"
RUNNER_TOKEN="$3"
HTTP_PROXY="$4"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "usage: install.sh <user_name> <repository_name> <runner_token> [<proxy url>]"
    exit 1
fi

#---------------------------------------------------

cd scripts

./setup.sh "$USER_NAME" "$REPOSITORY_NAME" "$RUNNER_TOKEN" "$HTTP_PROXY"
