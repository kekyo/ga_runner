#!/bin/sh
set -e

if [ -z "$GITHUB_URL" ] || [ -z "$RUNNER_TOKEN" ] || [ -z "$RUNNER_NAME" ] || [ -z "$CONTAINER_NAME" ]; then
    echo "Set GITHUB_URL, RUNNER_TOKEN, RUNNER_NAME and CONTAINER_NAME"
    exit 1
fi

#-----------------------------------------------------

# Cache path
CACHE_DIR="/runner-cache"
RUNNER_DIR="/home/runner/actions-runner"

#-----------------------------------------------------

# Apply for proxy
if [ -z "$HTTP_PROXY" ]; then
    echo "Not use HTTP proxy."
else
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

mkdir -p "$CACHE_DIR"

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

CONFIGURED_PATH="${CACHE_DIR}/config/${CONTAINER_NAME}"

if [ -d "$CONFIGURED_PATH" ]; then
    echo "Runner already configured: $CONFIGURED_PATH"
    find "${CONFIGURED_PATH}" -maxdepth 1 -type f -name '.*' -exec cp {} . \;
else
    # Register runner
    echo "Configuring the runner..."
    ./config.sh --url "$GITHUB_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --unattended --disableupdate --replace
    mkdir -p "${CONFIGURED_PATH}"
    find . -maxdepth 1 -type f -name '.*' -exec cp {} "${CONFIGURED_PATH}/" \;
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
