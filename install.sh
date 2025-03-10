#!/bin/sh
set -e

USER_NAME="$1"
REPOSITORY_NAME="$2"
INSTANCE_POSTFIX="$3"
RUNNER_TOKEN="$4"
HTTP_PROXY="$5"

if [ -z "$USER_NAME" ] || [ -z "$REPOSITORY_NAME" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "usage: install.sh <user_name> <repository_name> <instance_postfix> <runner_token> [<proxy url>]"
    exit 1
fi

#---------------------------------------------------

cd scripts

./setup.sh "$USER_NAME" "$REPOSITORY_NAME" "$INSTANCE_POSTFIX" "$RUNNER_TOKEN" "$HTTP_PROXY"
