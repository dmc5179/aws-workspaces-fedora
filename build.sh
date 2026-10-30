#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="quay.io/danclark/aws-workspace:latest"
CONTAINER_NAME="aws-workspace"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
DESKTOP_FILE="${APPS_DIR}/${CONTAINER_NAME}-com.amazon.workspacesclient.desktop"

container_exists() {
    podman container exists "${CONTAINER_NAME}"
}

build_image() {
    echo "Building container image..."
    podman build --pull=newer --squash -t "${IMAGE_NAME}" -f "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"
    echo "Image built: ${IMAGE_NAME}"
}

create_container() {
    if container_exists; then
        echo "Distrobox container '${CONTAINER_NAME}' already exists; skipping create."
        echo "To recreate it from the current image, run: $0 rebuild"
        return 0
    fi

    echo "Creating distrobox container from pre-built image..."
    # --no-entry: skip the "terminal into the container" app menu entry, which
    # would call distrobox enter with the full session environment.
    with_clean_env distrobox create --yes --no-entry --name "${CONTAINER_NAME}" --image "${IMAGE_NAME}"
    echo "Container created: ${CONTAINER_NAME}"
}

export_app() {
    echo "Exporting WorkSpaces app to host desktop..."
    with_clean_env distrobox enter "${CONTAINER_NAME}" -- distrobox-export --app workspacesclient

    # distrobox-export's Exec line calls distrobox-enter directly, which passes
    # the desktop session's environment (including secrets) into the
    # container. Route the menu entry and workspaces:// links through launch.
    sed -i "s|^Exec=.*|Exec=\"${SCRIPT_DIR}/build.sh\" launch %u|" "${DESKTOP_FILE}"
    update-desktop-database "${APPS_DIR}" 2>/dev/null || true

    # Remove the terminal entry created by older versions of this script.
    rm -f "${APPS_DIR}/${CONTAINER_NAME}.desktop"
    echo "Done. 'Amazon WorkSpaces' should appear in your application menu."
    echo "If it doesn't, log out and back in to refresh the desktop cache."
}

remove_container() {
    if ! container_exists; then
        echo "Distrobox container '${CONTAINER_NAME}' does not exist; nothing to remove."
        return 0
    fi

    echo "Removing exported app and distrobox container..."
    with_clean_env distrobox enter "${CONTAINER_NAME}" -- distrobox-export --app workspacesclient --delete || true
    # distrobox-export --delete only finds entries whose Exec calls
    # distrobox-enter, so remove our rewritten entry explicitly.
    rm -f "${DESKTOP_FILE}" "${APPS_DIR}/${CONTAINER_NAME}.desktop"
    update-desktop-database "${APPS_DIR}" 2>/dev/null || true
    with_clean_env distrobox rm --force "${CONTAINER_NAME}"
}

prune_images() {
    # Old image versions are left untagged after a rebuild.
    podman image prune -f >/dev/null
}

# Client version in the local image without the Debian revision,
# e.g. 2026.0.5677-1 -> 2026.0.5677.
client_version() {
    local version
    version="$(podman run --rm --pull=never --network=none --entrypoint dpkg-query \
        "${IMAGE_NAME}" -W -f='${Version}' workspacesclient)"
    echo "${version%-*}"
}

push_image() {
    local versioned
    versioned="${IMAGE_NAME%:*}:$(client_version)"
    echo "Pushing ${versioned} and ${IMAGE_NAME}..."
    podman tag "${IMAGE_NAME}" "${versioned}"
    podman push "${versioned}"
    podman push "${IMAGE_NAME}"
}

# Variables the client needs from the host session. Everything else is dropped,
# because distrobox-enter copies the caller's whole environment into the
# container as `podman exec --env=...` arguments (visible in `ps`), which
# would include any secrets exported from ~/.bashrc.
CLEAN_ENV_VARS=(
    HOME USER LOGNAME PATH LANG TERM
    DISPLAY WAYLAND_DISPLAY XAUTHORITY
    XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP
    DBUS_SESSION_BUS_ADDRESS XMODIFIERS
)

with_clean_env() {
    local keep=() var
    for var in "${CLEAN_ENV_VARS[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            keep+=("${var}=${!var}")
        fi
    done
    env -i "${keep[@]}" "$@"
}

launch() {
    echo "Launching WorkSpaces client..."
    with_clean_env distrobox enter "${CONTAINER_NAME}" -- workspacesclient "$@"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  build     Build the container image with podman
  setup     Create distrobox container and export the app to host desktop
  launch    Start the WorkSpaces client (optional: a workspaces:// URI)
  all       Run build + setup (first-time install)
  rebuild   Rebuild the image and recreate the container (use to update the client)
  remove    Remove the exported app and the distrobox container
  push      Push the local image to the registry, tagged with the client
            version and as latest (run 'podman login quay.io' first)

Prerequisites:
  sudo dnf install -y podman distrobox
EOF
}

case "${1:-}" in
    build)
        build_image
        ;;
    setup)
        create_container
        export_app
        ;;
    launch)
        shift
        launch "$@"
        ;;
    all)
        build_image
        create_container
        export_app
        echo ""
        echo "Setup complete. Launch from your app menu or run:"
        echo "  $0 launch"
        ;;
    rebuild)
        build_image
        remove_container
        prune_images
        create_container
        export_app
        ;;
    remove)
        remove_container
        ;;
    push)
        push_image
        ;;
    *)
        usage
        exit 1
        ;;
esac
