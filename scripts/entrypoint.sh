#!/bin/sh
set -e

# GitHub Actions Self-hosted immutable runner"
# Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
# License under MIT.
# https://github.com/kekyo/ga_runner/

if [ -z "$INSTANCE_NAME" ]; then
    echo "Set INSTANCE_NAME"
    exit 1
fi

#-----------------------------------------------------

# Path
CACHE_DIR="/runner-cache"
CONFIGURE_DIR="/config"
RUNNER_DIR="/home/runner/actions-runner"

#-----------------------------------------------------

if [ -d "$CONFIGURE_DIR" ]; then
    echo "Configuration directory is found: $CONFIGURE_DIR"
else
    echo "Configuration directory is not found: $CONFIGURE_DIR"
    exit 1
fi

#-----------------------------------------------------

# Apply for proxy
HTTP_PROXY_PATH="${CONFIGURE_DIR}/http_proxy"
if [ -f "$HTTP_PROXY_PATH" ]; then
    HTTP_PROXY=$(cat "$HTTP_PROXY_PATH")
    echo "Using HTTP proxy: $HTTP_PROXY"
    echo "export http_proxy=$HTTP_PROXY" | sudo tee -a /etc/profile 2>/dev/null
    echo "export https_proxy=$HTTP_PROXY" | sudo tee -a /etc/profile 2>/dev/null
    echo "Acquire::http::Proxy \"$HTTP_PROXY\";" | sudo tee /etc/apt/apt.conf.d/runproxy.conf 2>/dev/null
    echo "Acquire::https::Proxy \"$HTTP_PROXY\";" | sudo tee -a /etc/apt/apt.conf.d/runproxy.conf 2>/dev/null
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTP_PROXY"
fi

#-----------------------------------------------------

cd /home/runner

# Latest runner image version (except pre-release)
echo "Fetching GitHub Actions runner latest version..."
RUNNER_VERSION=$(curl -s https://github.com/actions/runner/releases | xmllint --html --xpath '
  //div[@class="flex-1"]
  [not(.//span[contains(text(), "Pre-release")])]
  //a[contains(@href, "/actions/runner/releases/tag/")]
' - 2>/dev/null | sed -E 's/.*\/tag\/v([0-9]+\.[0-9]+\.[0-9]+).*/\1/g' | sort -V | tail -n 1)

if [ -z "$RUNNER_VERSION" ]; then
    echo "Could not resolve GitHub Actions runner latest version."
    exit 1
fi

echo "Detected GitHub Actions runner latest version: ${RUNNER_VERSION}"

#-----------------------------------------------------

# Reuse cached runner package
RUNNER_PACKAGE_NAME="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
RUNNER_PACKAGE_PATH="${CACHE_DIR}/${RUNNER_PACKAGE_NAME}"
if [ -f "$RUNNER_PACKAGE_PATH" ]; then
    echo "Reuse cached runner package: $RUNNER_PACKAGE_NAME"
else
    echo "Downloading the runner package: $RUNNER_VERSION"
    TMPFILE=$(mktemp)
    curl -o "$TMPFILE" -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_PACKAGE_NAME}"
    mv -n "$TMPFILE" "$RUNNER_PACKAGE_PATH" || true
    chmod 644 "$RUNNER_PACKAGE_PATH"
    rm -f "$TMPFILE"
    echo "Cached the runner package: $RUNNER_VERSION"
fi

#-----------------------------------------------------

# Extract the runner package
echo "Extracting runner package..."
rm -rf "$RUNNER_DIR"
mkdir "$RUNNER_DIR"
tar -zxf "$RUNNER_PACKAGE_PATH" -C "$RUNNER_DIR"

cd "$RUNNER_DIR"

chmod +x config.sh run.sh

#-----------------------------------------------------

# Configure the runner
GITHUB_URL_PATH="${CONFIGURE_DIR}/github_url"
RUNNER_NAME_PATH="${CONFIGURE_DIR}/runner_name"
RUNNER_TOKEN_PATH="${CONFIGURE_DIR}/runner_token"
if [ -f "$GITHUB_URL_PATH" ] && [ -f "$RUNNER_NAME_PATH" ] && [ -f "$RUNNER_TOKEN_PATH" ]; then
    # Register runner
    echo "Configuring the runner..."
    GITHUB_URL=$(cat "$GITHUB_URL_PATH")
    RUNNER_NAME=$(cat "$RUNNER_NAME_PATH")
    RUNNER_TOKEN=$(cat "$RUNNER_TOKEN_PATH")
    echo "GITHUB_URL=$GITHUB_URL"
    echo "RUNNER_NAME=$RUNNER_NAME"
    echo "RUNNER_TOKEN=************"
    ./config.sh --url "$GITHUB_URL" --name "$RUNNER_NAME" --token "$RUNNER_TOKEN" --unattended --disableupdate --replace
    rm -f "$GITHUB_URL_PATH" "$RUNNER_NAME_PATH" "$RUNNER_TOKEN_PATH"
    find . -maxdepth 1 -type f -name '.*' -exec cp {} "${CONFIGURE_DIR}/" \;
else
    echo "Runner already configured: $CONFIGURE_DIR"
    find "${CONFIGURE_DIR}" -maxdepth 1 -type f -name '.*' -exec cp {} . \;
fi

#-----------------------------------------------------

# Execute runner
# The `--once` option (on `run.sh`) is supposed to be changed to the `--ephemeral` option (on `config.sh`).
# However, once a job is executed with `--ephemeral`, the credential becomes invalid and cannot be re-executed as is.
# I hope that the `--once` option will be supported as a full feature with gentle improvements.
# https://github.com/actions/runner/issues/510
# https://github.com/actions/runner/issues/1339
# https://github.com/actions/runner/blob/de51cd0ed662503274ebd06b8044e10c4d8254c1/src/Runner.Common/Constants.cs#L142
echo "Execute the runner..."
exec ./run.sh --once
