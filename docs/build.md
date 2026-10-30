# Building the Container Image

## Overview

The build creates an Ubuntu 24.04 container image with the official Amazon
WorkSpaces client pre-installed. Podman runs rootless — no `sudo` needed for
the build itself.

The image is meant to be **static**: the client and every package the
container needs are installed at build time. To update the client, rebuild
the image and recreate the container (`./build.sh rebuild`) rather than
upgrading packages inside the running container.

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
podman build --pull=newer --squash -t quay.io/danclark/aws-workspace:latest -f Containerfile .
```

`--pull=newer` refreshes the `ubuntu:24.04` base image when a newer one is
published. `--squash` collapses the image layers to reduce size.

## What the Containerfile Does

It's a single-stage build with three steps:

### 1. Distrobox and GPU packages

Installs the packages `distrobox-init` would otherwise install the first time
you run `distrobox enter` (shell tools, `sudo`, `passwd`, locales, etc. — see
`setup_apt` in `/usr/bin/distrobox-init`), plus Mesa OpenGL and Vulkan for GPU
rendering. `va-driver-all` installs every VA-API driver (Intel iHD and i965,
Mesa for AMD) so the DCV viewer can decode the H.264 stream on the GPU; it
picks VA-API automatically when a driver works. `vainfo` is included for
troubleshooting. It also generates the `en_US.UTF-8` locale.

To confirm hardware decode is in use, check the streaming log after
connecting:

```bash
grep -E 'Selected context|decompressor for h264' \
  ~/.local/share/Amazon\ Web\ Services/Amazon\ WorkSpaces/logs/WSP/viewer.log
```

`source: VA` means hardware decode; `source: Ffmpeg` means software.

### 2. AWS WorkSpaces client

1. Downloads the AWS public GPG key from
   `https://workspaces-client-linux-public-key.s3-us-west-2.amazonaws.com/ADB332E7.asc`
2. Adds the official Amazon APT repository for Ubuntu 24.04:
   `deb https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu noble main`
3. Installs the `workspacesclient` package. The package declares its own
   runtime dependencies (WebKitGTK 4.1, libsoup 3, GStreamer, smart card
   support, etc.), so they are pulled in automatically.

See AWS's install instructions:
<https://clients.amazonworkspaces.com/linux-install>

### 3. Distrobox setup marker

Creates `/.containersetupdone`. When `distrobox-init` sees this file it skips
its package installation step, so the container starts quickly and its
contents match the image exactly.

Each step cleans up the APT cache (`rm -rf /var/lib/apt/lists/*`) to keep the
image smaller.

## Image Size

The final image is roughly 1.4 GB, mostly Ubuntu's GTK/WebKit/GStreamer stack.

## First-Time Setup

After building the image, run setup to create the distrobox container and
export the desktop shortcut:

```bash
./build.sh setup
```

This does two things:

1. **`distrobox create`** — Registers a container named `aws-workspace` backed
   by the image you just built. If the container already exists, this step is
   skipped.

2. **`distrobox-export --app`** — Copies a `.desktop` file to
   `~/.local/share/applications/` on the Fedora host so the WorkSpaces client
   appears in the app menu as **Amazon WorkSpaces (on aws-workspace)**.

On the first start, Distrobox still sets up your user, home directory, and
host integration inside the container (a few seconds), but installs no
packages.

## Combined Command

To build and set up in one step:

```bash
./build.sh all
```

## Updating the Client

When AWS publishes a new client version:

```bash
./build.sh rebuild
```

This builds a new image, removes the old container and its app-menu entry,
prunes the old untagged image, then recreates the container and re-exports
the app. Your WorkSpaces registration and settings live in your home
directory, so they survive the rebuild.

Don't run `apt-get upgrade` inside the container: those changes are lost on
the next rebuild and make the container drift from the image.

To check which client version is in the repo vs. installed:

```bash
curl -sL https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu/dists/noble/main/binary-amd64/Packages \
  | grep -A1 '^Package: workspacesclient' | grep Version
distrobox enter aws-workspace -- dpkg-query -W workspacesclient
```

## Pushing to a Registry

To share a tested image across machines:

```bash
podman login quay.io
./build.sh push
```

This tags the local image with the installed client version (e.g.
`quay.io/danclark/aws-workspace:2026.0.5677`, read from the image with
`dpkg-query`) and pushes both that tag and `latest`. The version tag is a
rollback point if a later AWS client release has problems.

The image contains Amazon's WorkSpaces client; keep the registry repository
private unless you've confirmed AWS's license allows redistribution. The
image holds no personal data — registration, settings, and logs live in your
home directory.

On another machine, skip the build and go straight to setup:

```bash
./build.sh setup
```

Distrobox will pull `latest` from the registry automatically. To roll back to
a specific client version, pull and retag it, then recreate the container:

```bash
podman pull quay.io/danclark/aws-workspace:2026.0.5677
podman tag quay.io/danclark/aws-workspace:2026.0.5677 quay.io/danclark/aws-workspace:latest
./build.sh remove && ./build.sh setup
```

## Troubleshooting

**Build fails downloading the GPG key** — Check network connectivity and
verify the key URL hasn't changed. The key ID is `ADB332E7`.

**Build fails with "Unable to locate package"** — A package was renamed in
Ubuntu. Check the name with `podman run --rm ubuntu:24.04 sh -c 'apt-get update -qq && apt-cache search <name>'`.

**`distrobox create` says the container already exists** — Use
`./build.sh rebuild` to recreate it from the current image, or
`./build.sh remove` to delete it.
