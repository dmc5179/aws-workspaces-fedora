# AWS WorkSpaces on Fedora

Run the official Amazon WorkSpaces Linux client on Fedora using Podman and
Distrobox. The client is packaged in an Ubuntu 24.04 container image and
integrated into the Fedora desktop via Distrobox's app export.

## Why This Exists

Amazon only publishes the WorkSpaces client as a `.deb` for Ubuntu. There is
no RPM, no Flatpak, and the unofficial Snap package (`amz-workspaces`) has been
abandoned since February 2023 — shipping a client version too old to support
the current DCV protocol.

This project builds a container image with the official client pre-installed,
then uses Distrobox to integrate it as a native-feeling desktop app on Fedora.

## How It Works

**Build time** — A `Containerfile` creates an Ubuntu 24.04 image with the
official AWS WorkSpaces `.deb` client, its GUI dependencies, and the packages
Distrobox needs, so nothing is installed at container start. Podman builds
this image locally (or it can be pulled from a registry).

**Runtime** — Distrobox creates a container from the image and shares the
host's display server, audio (PulseAudio/PipeWire), network stack, and home
directory. `distrobox-export --app` writes a `.desktop` file so the client
appears in the Fedora app menu and launches like any other application.

## Prerequisites

```
sudo dnf install -y podman distrobox
```

## Quick Start

```bash
# First-time: build the image, create the container, export the app
./build.sh all

# After that, launch from the app menu or:
./build.sh launch

# When AWS releases a new client: rebuild the image and recreate the container
./build.sh rebuild
```

The image is static: the client is installed at build time only. Don't
`apt-get upgrade` inside the container; rebuild instead.

## Documentation

- [Building the container image](docs/build.md)
- [Launching and using the client](docs/launch.md)

## Project Structure

```
.
├── Containerfile    # Ubuntu 24.04 image with AWS WorkSpaces client
├── build.sh         # Build, setup, and launch wrapper script
├── docs/
│   ├── build.md     # Build process details
│   └── launch.md    # Launch and day-to-day usage
├── AGENTS.md        # Project state and TODOs for agents/contributors
├── CLAUDE.md        # Claude Code entry point (imports AGENTS.md)
└── README.md
```
