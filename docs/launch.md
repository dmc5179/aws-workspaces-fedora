# Launching and Using the WorkSpaces Client

## Launch Methods

### From the App Menu

After running `./build.sh setup` (or `./build.sh all`), the WorkSpaces client
appears in the Fedora application menu as **Amazon WorkSpaces**. Click it to
launch.

If the icon doesn't appear, log out and back in to refresh the desktop file
cache.

### From the Command Line

```bash
./build.sh launch
```

This runs:

```bash
distrobox enter aws-workspace -- workspacesclient
```

## What Happens at Launch

1. Distrobox enters the `aws-workspace` container.
2. The container shares the host's Wayland/X11 display, PulseAudio/PipeWire
   audio, D-Bus session, and network stack — no port forwarding or display
   configuration needed.
3. The WorkSpaces client opens as a normal window on the Fedora desktop.

## Connecting to a WorkSpace

1. Enter your **registration code** (provided by your IT administrator).
2. Sign in with your WorkSpaces credentials.
3. The client connects over the **DCV protocol** on TCP port 4195.

No special firewall rules are needed on the Fedora host — the container shares
the host network namespace directly.

## Multi-Monitor Support

The client supports multiple monitors. Tested and confirmed working with 3+
displays.

## Updating the Client

To update to the latest client version without rebuilding the container image:

```bash
distrobox enter aws-workspace -- sudo apt-get update
distrobox enter aws-workspace -- sudo apt-get upgrade -y
```

To rebuild from scratch with the latest version:

```bash
./build.sh build
distrobox rm aws-workspace
./build.sh setup
```

## Removing the Desktop Shortcut

```bash
distrobox enter aws-workspace -- distrobox-export --app workspacesclient --delete
```

## Removing Everything

```bash
distrobox rm aws-workspace
podman rmi quay.io/danclark/aws-workspace:latest
```

## Troubleshooting

**Client doesn't launch / blank window** — Verify the display server is being
forwarded. Inside the container, check:

```bash
distrobox enter aws-workspace -- echo $WAYLAND_DISPLAY
distrobox enter aws-workspace -- echo $DISPLAY
```

At least one should be set.

**No audio** — PipeWire/PulseAudio should be forwarded automatically. If audio
is missing, check that `libpulse0` is installed inside the container:

```bash
distrobox enter aws-workspace -- dpkg -l libpulse0
```

**Cannot connect to WorkSpace** — Ensure TCP 4195 (DCV) is not blocked by a
firewall or VPN. The client uses the host network directly.

**"Container does not exist" error** — Run setup again:

```bash
./build.sh setup
```
