#!/bin/sh
set -e

# GitHub Actions Self-hosted immutable runner"
# Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
# License under MIT.
# https://github.com/kekyo/ga_runner/

CONTAINER_NAME="$1"
INSTANCE_NAME="$2"

if [ -z "$CONTAINER_NAME" ] || [ -z "$INSTANCE_NAME" ]; then
    echo "usage: run.sh <container_name> <instance_name>"
    exit 1
fi

#-------------------------------------------------

IMAGE_NAME="github-actions-runner"

SCRIPT_DIR="$(dirname "$0")"
CONFIGURE_BASE_DIR="${SCRIPT_DIR}/config"
CACHE_BASE_DIR="${SCRIPT_DIR}/runner-cache"

prepare_cache_dir() {
    TARGET_DIR="$1"
    TARGET_MODE="$2"

    mkdir -p "$TARGET_DIR"
    sudo chmod "$TARGET_MODE" "$TARGET_DIR"
    sudo chgrp 1001 "$TARGET_DIR"
}

read_ini_value() {
    FILE_PATH="$1"
    SECTION_NAME="$2"
    KEY_NAME="$3"

    if [ ! -f "$FILE_PATH" ]; then
        return 0
    fi

    awk -F '=' -v target_section="$SECTION_NAME" -v target_key="$KEY_NAME" '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        {
            line=$0
            sub(/[[:space:]]*[#;].*$/, "", line)
            line=trim(line)

            if (line == "") {
                next
            }

            if (line ~ /^\[[^][]+\]$/) {
                current_section=tolower(substr(line, 2, length(line) - 2))
                next
            }

            if (tolower(current_section) != tolower(target_section)) {
                next
            }

            separator=index(line, "=")
            if (separator == 0) {
                next
            }

            current_key=tolower(trim(substr(line, 1, separator - 1)))
            if (current_key != tolower(target_key)) {
                next
            }

            print trim(substr(line, separator + 1))
            exit
        }
    ' "$FILE_PATH"
}

resolve_cache_setting() {
    KEY_NAME="$1"
    CONFIGURE_FILE_PATH="$2"

    RAW_VALUE=$(read_ini_value "$CONFIGURE_FILE_PATH" "cache" "$KEY_NAME")
    if [ -z "$RAW_VALUE" ]; then
        printf '%s\n' "true"
        return 0
    fi

    NORMALIZED_VALUE=$(printf '%s' "$RAW_VALUE" | tr '[:upper:]' '[:lower:]')
    case "$NORMALIZED_VALUE" in
        enabled|true|yes|on|1)
            printf '%s\n' "true"
            ;;
        disabled|false|no|off|0)
            printf '%s\n' "false"
            ;;
        *)
            echo "Invalid cache setting in ${CONFIGURE_FILE_PATH}: ${KEY_NAME}=${RAW_VALUE}" >&2
            echo "Use enabled/disabled (or true/false, yes/no, on/off, 1/0)." >&2
            return 1
            ;;
    esac
}

#-------------------------------------------------

# Preserve the cache directory
CACHE_DIR="${CACHE_BASE_DIR}/${INSTANCE_NAME}"
APT_DIR="${CACHE_DIR}/apt"
APT_ARCHIVE_DIR="${APT_DIR}/archives"
APT_LIST_DIR="${APT_DIR}/lists"
NPM_DIR="${CACHE_DIR}/npm"
NUGET_DIR="${CACHE_DIR}/nuget"
NUGET_CONFIG_DIR="${NUGET_DIR}/NuGet"
DOTNET_DIR="${CACHE_DIR}/dotnet"
MAVEN_DIR="${CACHE_DIR}/maven"
DOT_CACHE_DIR="${CACHE_DIR}/cache"
CONFIGURE_DIR="${CONFIGURE_BASE_DIR}/${INSTANCE_NAME}"
CONFIGURE_FILE_PATH="${CONFIGURE_DIR}/config.ini"

RUNNER_PACKAGE_CACHE_ENABLED=$(resolve_cache_setting "runner_package" "$CONFIGURE_FILE_PATH") || exit 1
APT_CACHE_ENABLED=$(resolve_cache_setting "apt" "$CONFIGURE_FILE_PATH") || exit 1
NPM_CACHE_ENABLED=$(resolve_cache_setting "npm" "$CONFIGURE_FILE_PATH") || exit 1
NUGET_CACHE_ENABLED=$(resolve_cache_setting "nuget" "$CONFIGURE_FILE_PATH") || exit 1
DOTNET_CACHE_ENABLED=$(resolve_cache_setting "dotnet" "$CONFIGURE_FILE_PATH") || exit 1
MAVEN_CACHE_ENABLED=$(resolve_cache_setting "maven" "$CONFIGURE_FILE_PATH") || exit 1
HOME_CACHE_ENABLED=$(resolve_cache_setting "home_cache" "$CONFIGURE_FILE_PATH") || exit 1

if [ "$RUNNER_PACKAGE_CACHE_ENABLED" = "true" ] || \
   [ "$APT_CACHE_ENABLED" = "true" ] || \
   [ "$NPM_CACHE_ENABLED" = "true" ] || \
   [ "$NUGET_CACHE_ENABLED" = "true" ] || \
   [ "$DOTNET_CACHE_ENABLED" = "true" ] || \
   [ "$MAVEN_CACHE_ENABLED" = "true" ] || \
   [ "$HOME_CACHE_ENABLED" = "true" ]; then
    prepare_cache_dir "$CACHE_DIR" 770
fi

if [ "$APT_CACHE_ENABLED" = "true" ]; then
    prepare_cache_dir "$APT_DIR" 775
    prepare_cache_dir "$APT_ARCHIVE_DIR" 775
    prepare_cache_dir "$APT_LIST_DIR" 775
fi

if [ "$NPM_CACHE_ENABLED" = "true" ]; then
    prepare_cache_dir "$NPM_DIR" 775
fi

if [ "$NUGET_CACHE_ENABLED" = "true" ]; then
    prepare_cache_dir "$NUGET_DIR" 775
    prepare_cache_dir "$NUGET_CONFIG_DIR" 775

    # Reset user-wide NuGet settings on each startup.
    # Sudo-based jobs may leave root-owned config files in the persistent cache.
    sudo rm -f "${NUGET_CONFIG_DIR}/NuGet.Config" "${NUGET_CONFIG_DIR}/nuget.config"
    sudo rm -rf "${NUGET_CONFIG_DIR}/config"
fi

if [ "$DOTNET_CACHE_ENABLED" = "true" ]; then
    prepare_cache_dir "$DOTNET_DIR" 775
fi

if [ "$MAVEN_CACHE_ENABLED" = "true" ]; then
    prepare_cache_dir "$MAVEN_DIR" 775
fi

if [ "$HOME_CACHE_ENABLED" = "true" ]; then
    prepare_cache_dir "$DOT_CACHE_DIR" 775
fi

#-------------------------------------------------

# Run the container
set -- podman run --rm --name "${CONTAINER_NAME}" \
    -e INSTANCE_NAME="$INSTANCE_NAME" \
    --userns=keep-id \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /etc/subuid:/etc/subuid:ro \
    -v /etc/subgid:/etc/subgid:ro \
    -v /dev/fuse:/dev/fuse:rw \
    -v "${CONFIGURE_DIR}:/config"

if [ "$RUNNER_PACKAGE_CACHE_ENABLED" = "true" ]; then
    set -- "$@" -v "${CACHE_DIR}:/runner-cache"
fi

if [ "$APT_CACHE_ENABLED" = "true" ]; then
    set -- "$@" \
        -v "${APT_ARCHIVE_DIR}:/var/cache/apt/archives" \
        -v "${APT_LIST_DIR}:/var/lib/apt/lists"
fi

if [ "$NPM_CACHE_ENABLED" = "true" ]; then
    set -- "$@" -v "${NPM_DIR}:/home/runner/.npm"
fi

if [ "$NUGET_CACHE_ENABLED" = "true" ]; then
    set -- "$@" -v "${NUGET_DIR}:/home/runner/.nuget"
fi

if [ "$DOTNET_CACHE_ENABLED" = "true" ]; then
    set -- "$@" -v "${DOTNET_DIR}:/home/runner/.dotnet"
fi

if [ "$MAVEN_CACHE_ENABLED" = "true" ]; then
    set -- "$@" -v "${MAVEN_DIR}:/home/runner/.m2/repository"
fi

if [ "$HOME_CACHE_ENABLED" = "true" ]; then
    set -- "$@" -v "${DOT_CACHE_DIR}:/home/runner/.cache"
fi

set -- "$@" "$IMAGE_NAME"
sudo "$@"

exit $?
