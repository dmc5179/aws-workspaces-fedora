#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="quay.io/danclark/aws-workspace:latest"
CONTAINER_NAME="aws-workspace"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build_image() {
    echo "Building container image..."
    podman build --squash -t "${IMAGE_NAME}" -f "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"
    echo "Image built: ${IMAGE_NAME}"
}

create_container() {
    if distrobox list 2>/dev/null | grep -q "${CONTAINER_NAME}"; then
        echo "Distrobox container '${CONTAINER_NAME}' already exists."
        echo "To recreate, run: distrobox rm ${CONTAINER_NAME}"
        return 1
    fi

    echo "Creating distrobox container from pre-built image..."
    distrobox create --name "${CONTAINER_NAME}" --image "${IMAGE_NAME}"
    echo "Container created: ${CONTAINER_NAME}"
}

export_app() {
    echo "Exporting WorkSpaces app to host desktop..."
    distrobox enter "${CONTAINER_NAME}" -- distrobox-export --app workspacesclient
    echo "Done. 'Amazon WorkSpaces' should appear in your application menu."
    echo "If it doesn't, log out and back in to refresh the desktop cache."
}

launch() {
    echo "Launching WorkSpaces client..."
    distrobox enter "${CONTAINER_NAME}" -- workspacesclient
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  build     Build the container image with podman
  setup     Create distrobox container and export the app to host desktop
  launch    Start the WorkSpaces client
  all       Run build + setup (first-time install)

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
        launch
        ;;
    all)
        build_image
        create_container
        export_app
        echo ""
        echo "Setup complete. Launch from your app menu or run:"
        echo "  $0 launch"
        ;;
    *)
        usage
        exit 1
        ;;
esac
