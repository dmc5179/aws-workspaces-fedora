# Building the Container Image

## Overview

The build creates an Ubuntu 22.04 container image with the official Amazon
WorkSpaces client and all required GUI libraries pre-installed. Podman runs
rootless — no `sudo` needed for the build itself.

## Prerequisites

Install Podman and Distrobox on the Fedora host:

```bash
sudo dnf install -y podman distrobox
```

## Build Command

```bash
./build.sh build
```

This runs:

```bash
podman build --squash -t quay.io/danclark/aws-workspace:latest -f Containerfile .
```

The `--squash` flag collapses the image layers to reduce size.

## What the Containerfile Does

The build runs in two stages:

### Stage 1: GUI Dependencies

Installs the libraries the WorkSpaces client needs to render its UI and
interact with display, audio, and notification systems:

| Package                    | Purpose                        |
|----------------------------|--------------------------------|
| `libcanberra-gtk-module`   | GTK event sounds               |
| `libcanberra-gtk3-module`  | GTK3 event sounds              |
| `packagekit-gtk3-module`   | GTK3 PackageKit integration    |
| `libsoup2.4-1`             | HTTP client library            |
| `libwebkit2gtk-4.0-37`     | Embedded web views             |
| `libgtk-3-0`               | GTK3 toolkit                   |
| `libnotify4`               | Desktop notifications          |
| `libnss3`                  | Network security services      |
| `libxss1`                  | X11 screensaver extension      |
| `libasound2`               | ALSA audio                     |
| `libgbm1`                  | Mesa GBM (GPU buffer mgmt)     |
| `libpulse0`                | PulseAudio client              |
| `dbus-x11`                 | D-Bus / X11 integration        |
| `xdg-utils`                | Desktop utility commands        |

### Stage 2: AWS WorkSpaces Client

1. Downloads the AWS public GPG key from:
   `https://workspaces-client-linux-public-key.s3-us-west-2.amazonaws.com/ADB332E7.asc`

2. Adds the official Amazon APT repository:
   `deb https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu jammy main`

3. Installs the `workspacesclient` package.

Both stages clean up the APT cache (`rm -rf /var/lib/apt/lists/*`) to keep
the image smaller.

## Image Size

The final image is roughly 2-3 GB. Most of this is Ubuntu's base layer plus
the GTK/WebKit dependencies the client requires.

## First-Time Setup

After building the image, run setup to create the distrobox container and
export the desktop shortcut:

```bash
./build.sh setup
```

This does two things:

1. **`distrobox create`** — Registers a container named `aws-workspace` backed
   by the image you just built. This is metadata only; nothing is installed on
   the host.

2. **`distrobox-export --app`** — Copies a `.desktop` file to
   `~/.local/share/applications/` on the Fedora host so the WorkSpaces client
   appears in the app menu.

On the first `distrobox enter`, Distrobox installs its own integration
packages inside the container (display forwarding, host font access, etc.).
This is a one-time operation that takes a minute or so and only modifies the
container, not the host.

## Combined Command

To build and set up in one step:

```bash
./build.sh all
```

## Rebuilding

To update the client (e.g., when AWS publishes a new version), rebuild the
image and recreate the container:

```bash
./build.sh build
distrobox rm aws-workspace
./build.sh setup
```

Or update in place without rebuilding:

```bash
distrobox enter aws-workspace -- sudo apt-get update
distrobox enter aws-workspace -- sudo apt-get upgrade -y
```

## Pushing to a Registry

If you want to share the image across machines:

```bash
podman push quay.io/danclark/aws-workspace:latest
```

On another machine, skip the build and go straight to setup:

```bash
./build.sh setup
```

Distrobox will pull the image from the registry automatically.

## Troubleshooting

**Build fails downloading the GPG key** — Check network connectivity and
verify the key URL hasn't changed. The key ID is `ADB332E7`.

**Image is too large** — The `--squash` flag is already applied. The bulk of
the size comes from Ubuntu's GTK/WebKit stack, which is required by the
client.

**`distrobox create` says the container already exists** — Remove it first:

```bash
distrobox rm aws-workspace
```
