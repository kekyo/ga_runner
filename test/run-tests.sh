#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

assert_contains() {
    FILE_PATH="$1"
    PATTERN="$2"

    if ! grep -F -- "$PATTERN" "$FILE_PATH" >/dev/null 2>&1; then
        echo "Expected pattern was not found."
        echo "File: $FILE_PATH"
        echo "Pattern: $PATTERN"
        exit 1
    fi
}

assert_not_contains() {
    FILE_PATH="$1"
    PATTERN="$2"

    if grep -F -- "$PATTERN" "$FILE_PATH" >/dev/null 2>&1; then
        echo "Unexpected pattern was found."
        echo "File: $FILE_PATH"
        echo "Pattern: $PATTERN"
        exit 1
    fi
}

run_run_sh_with_fake_sudo() {
    INSTANCE_NAME="$1"
    CONFIG_BODY="$2"
    OUTPUT_DIR="$3"

    TEST_ROOT=$(mktemp -d)
    mkdir -p "${TEST_ROOT}/scripts/config/${INSTANCE_NAME}"
    cp "${REPO_DIR}/scripts/run.sh" "${TEST_ROOT}/scripts/run.sh"

    if [ -n "$CONFIG_BODY" ]; then
        printf '%s\n' "$CONFIG_BODY" > "${TEST_ROOT}/scripts/config/${INSTANCE_NAME}/config.ini"
    fi

    mkdir -p "${TEST_ROOT}/bin"
    cat > "${TEST_ROOT}/bin/sudo" <<'EOF'
#!/bin/sh
set -eu

PODMAN_LOG_PATH="${PODMAN_LOG_PATH:?}"

case "$1" in
    podman)
        shift
        : > "$PODMAN_LOG_PATH"
        for ARGUMENT in "$@"; do
            printf '%s\n' "$ARGUMENT" >> "$PODMAN_LOG_PATH"
        done
        exit 0
        ;;
    chmod)
        shift
        chmod "$@"
        exit $?
        ;;
    chgrp)
        exit 0
        ;;
    rm)
        shift
        rm "$@"
        exit $?
        ;;
esac

exec "$@"
EOF
    chmod +x "${TEST_ROOT}/bin/sudo"

    PODMAN_LOG_PATH="${OUTPUT_DIR}" PATH="${TEST_ROOT}/bin:${PATH}" sh "${TEST_ROOT}/scripts/run.sh" test-container "$INSTANCE_NAME"
    rm -rf "$TEST_ROOT"
}

sh -n "${REPO_DIR}/install.sh"
sh -n "${REPO_DIR}/remove.sh"
sh -n "${REPO_DIR}/scripts/build.sh"
sh -n "${REPO_DIR}/scripts/entrypoint.sh"
sh -n "${REPO_DIR}/scripts/run.sh"
sh -n "${REPO_DIR}/scripts/setup.sh"
sh -n "${REPO_DIR}/scripts/stop.sh"

assert_contains "${REPO_DIR}/install.sh" "<github_pat>"
assert_contains "${REPO_DIR}/scripts/setup.sh" "usage: setup.sh <user_name> <repository_name> <instance_postfix> <github_pat> [<proxy url>]"
assert_contains "${REPO_DIR}/scripts/setup.sh" "actions/runners/registration-token"
assert_contains "${REPO_DIR}/scripts/setup.sh" "\"Authorization: Bearer \${GITHUB_PAT}\""
assert_contains "${REPO_DIR}/scripts/setup.sh" "\"\${CONFIGURE_DIR}/github_pat\""
assert_contains "${REPO_DIR}/scripts/setup.sh" "config.ini"
assert_contains "${REPO_DIR}/scripts/setup.sh" "runner_package = enabled"
assert_not_contains "${REPO_DIR}/scripts/setup.sh" "runner_token"

assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "--pat \"\$GITHUB_PAT\""
assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "--ephemeral"
assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "Expected files: github_url, runner_name, github_pat"
assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "exec ./run.sh"
assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "sudo mkdir -p \"\$CACHE_DIR\""
assert_not_contains "${REPO_DIR}/scripts/entrypoint.sh" "exec ./run.sh --once"
assert_not_contains "${REPO_DIR}/scripts/entrypoint.sh" "find . -maxdepth 1 -type f -name '.*' -exec cp"

assert_contains "${REPO_DIR}/README.md" "fine-grained GitHub personal access token (PAT)"
assert_contains "${REPO_DIR}/README.md" "Administration: Read and write"
assert_contains "${REPO_DIR}/README.md" "scripts/config/<instance_name>/config.ini"
assert_contains "${REPO_DIR}/README.md" "home_cache = enabled"
assert_contains "${REPO_DIR}/README_ja.md" "fine-grained GitHub personal access token (PAT)"
assert_contains "${REPO_DIR}/README_ja.md" "Administration: Read and write"
assert_contains "${REPO_DIR}/README_ja.md" "scripts/config/<instance_name>/config.ini"
assert_contains "${REPO_DIR}/README_ja.md" "home_cache = enabled"

DEFAULT_PODMAN_LOG=$(mktemp)
run_run_sh_with_fake_sudo "default_instance" "" "$DEFAULT_PODMAN_LOG"
assert_contains "$DEFAULT_PODMAN_LOG" "/runner-cache"
assert_contains "$DEFAULT_PODMAN_LOG" "/var/cache/apt/archives"
assert_contains "$DEFAULT_PODMAN_LOG" "/home/runner/.npm"
assert_contains "$DEFAULT_PODMAN_LOG" "/home/runner/.nuget"
assert_contains "$DEFAULT_PODMAN_LOG" "/home/runner/.dotnet"
assert_contains "$DEFAULT_PODMAN_LOG" "/home/runner/.m2/repository"
assert_contains "$DEFAULT_PODMAN_LOG" "/home/runner/.cache"
rm -f "$DEFAULT_PODMAN_LOG"

DISABLED_PODMAN_LOG=$(mktemp)
run_run_sh_with_fake_sudo "custom_instance" "[cache]
runner_package = disabled
apt = false
npm = no
nuget = off
dotnet = 0
maven = disabled
home_cache = disabled" "$DISABLED_PODMAN_LOG"
assert_not_contains "$DISABLED_PODMAN_LOG" "/runner-cache"
assert_not_contains "$DISABLED_PODMAN_LOG" "/var/cache/apt/archives"
assert_not_contains "$DISABLED_PODMAN_LOG" "/var/lib/apt/lists"
assert_not_contains "$DISABLED_PODMAN_LOG" "/home/runner/.npm"
assert_not_contains "$DISABLED_PODMAN_LOG" "/home/runner/.nuget"
assert_not_contains "$DISABLED_PODMAN_LOG" "/home/runner/.dotnet"
assert_not_contains "$DISABLED_PODMAN_LOG" "/home/runner/.m2/repository"
assert_not_contains "$DISABLED_PODMAN_LOG" "/home/runner/.cache"
assert_contains "$DISABLED_PODMAN_LOG" "/config"
rm -f "$DISABLED_PODMAN_LOG"

echo "All tests passed."
