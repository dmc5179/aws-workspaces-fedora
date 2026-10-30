# Launching and Using the WorkSpaces Client

## Launch Methods

### From the App Menu

After running `./build.sh setup` (or `./build.sh all`), the WorkSpaces client
appears in the Fedora application menu as **Amazon WorkSpaces (on
aws-workspace)**. Click it to launch.

If the icon doesn't appear, log out and back in to refresh the desktop file
cache.

### From the Command Line

```bash
./build.sh launch
```

This runs `distrobox enter aws-workspace -- workspacesclient` with a minimal
environment. `distrobox enter` copies the caller's entire environment into the
container as `podman exec --env=...` arguments, which are visible in `ps` to
all local users. `build.sh` uses `env -i` to pass only the display, D-Bus,
locale, and session variables listed in `CLEAN_ENV_VARS`, so secrets exported
from `~/.bashrc` (cloud keys, API tokens) don't reach the container.

The app menu entry does **not** use this wrapper yet (it calls
`distrobox-enter` directly). Prefer `./build.sh launch` until that's fixed.

Any arguments are passed to the client, e.g. a `workspaces://` URI:

```bash
./build.sh launch 'workspaces://username@registration-code'
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
3. The client connects over the **DCV protocol** on port 4195 (TCP, and UDP
   for QUIC when available).

No special firewall rules are needed on the Fedora host — the container shares
the host network namespace directly.

## Multi-Monitor Support

The client supports multiple monitors. Not yet verified with this container
setup.

## Updating the Client

Rebuild the image and recreate the container:

```bash
./build.sh rebuild
```

Don't `apt-get upgrade` inside the container; see
[Updating the Client](build.md#updating-the-client).

## Removing the Desktop Shortcut

```bash
distrobox enter aws-workspace -- distrobox-export --app workspacesclient --delete
```

## Removing Everything

```bash
./build.sh remove
podman rmi quay.io/danclark/aws-workspace:latest
```

Distrobox also exports an `aws-workspace.desktop` entry (a shell into the
container). `./build.sh remove` deletes the container; remove that entry with
`rm ~/.local/share/applications/aws-workspace.desktop` if it remains.

## Troubleshooting

**Client doesn't launch / blank window** — Verify the display server is being
forwarded. Inside the container, check:

```bash
distrobox enter aws-workspace -- sh -c 'echo "DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY"'
```

At least one should be set. (The single quotes matter: without them the host
shell expands the variables before they reach the container.)

If the window opens but the login page is blank or black, try disabling
WebKitGTK's GPU paths for one launch:

```bash
distrobox enter aws-workspace -- env WEBKIT_DISABLE_DMABUF_RENDERER=1 workspacesclient
distrobox enter aws-workspace -- env WEBKIT_DISABLE_COMPOSITING_MODE=1 workspacesclient
```

To see client output and errors, launch from a terminal with
`./build.sh launch` instead of the app menu.

**No audio** — PipeWire/PulseAudio should be forwarded automatically. If audio
is missing, check that `libpulse0` is installed inside the container:

```bash
distrobox enter aws-workspace -- dpkg-query -W libpulse0
```

**Cannot connect to WorkSpace** — Ensure port 4195 (DCV, TCP and UDP) is not
blocked by a firewall or VPN. The client uses the host network directly.

**"Container does not exist" error** — Run setup again:

```bash
./build.sh setup
```
