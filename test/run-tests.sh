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
assert_not_contains "${REPO_DIR}/scripts/setup.sh" "runner_token"

assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "--pat \"\$GITHUB_PAT\""
assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "--ephemeral"
assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "Expected files: github_url, runner_name, github_pat"
assert_contains "${REPO_DIR}/scripts/entrypoint.sh" "exec ./run.sh"
assert_not_contains "${REPO_DIR}/scripts/entrypoint.sh" "exec ./run.sh --once"
assert_not_contains "${REPO_DIR}/scripts/entrypoint.sh" "find . -maxdepth 1 -type f -name '.*' -exec cp"

assert_contains "${REPO_DIR}/README.md" "fine-grained GitHub personal access token (PAT)"
assert_contains "${REPO_DIR}/README.md" "Administration: Read and write"
assert_contains "${REPO_DIR}/README_ja.md" "fine-grained GitHub personal access token (PAT)"
assert_contains "${REPO_DIR}/README_ja.md" "Administration: Read and write"

echo "All tests passed."
