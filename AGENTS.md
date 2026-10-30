# AGENTS.md

Guidance and working state for AI coding agents (and humans) working in this
repo. Keep the **State** and **TODO** sections current as work progresses.

## What this repo is

Runs the official Amazon WorkSpaces Linux client (`workspacesclient`, shipped
by AWS only as an Ubuntu `.deb`) on Fedora.

**Approach: Distrobox + a static custom Ubuntu 24.04 image.**

- AWS does not ship a Distrobox setup — AWS ships a `.deb` for Ubuntu
  20.04/22.04/24.04 (<https://clients.amazonworkspaces.com/linux-install>).
  Using Distrobox to run that `.deb` on Fedora is this repo's choice.
- `Containerfile` — `ubuntu:24.04` + distrobox-init's package list + Mesa
  GL/Vulkan/VA-API + AWS APT repo (`noble`) + `workspacesclient`, then
  `touch /.containersetupdone` so distrobox-init skips its runtime package
  install.
- `build.sh` — `build`, `setup` (idempotent `distrobox create` +
  `distrobox-export --app`), `launch`, `all`, `rebuild` (build + remove +
  prune + create + export), `remove`.
- Image tag: `quay.io/danclark/aws-workspace:latest`. Container name:
  `aws-workspace`.
- Docs: `README.md`, `docs/build.md`, `docs/launch.md`.

## Decisions

- **Static image, rebuild to update** (2026-10-30). The client is installed
  only at build time. Never `apt-get upgrade` inside the container; update
  with `./build.sh rebuild`.
- **Stay on Distrobox for now** (2026-10-30). Revisit a plain `podman run --rm`
  launcher (fresh container per launch, explicit mounts) only if failures turn
  out to be caused by Distrobox itself (stale container state, first-start
  setup, host integration).
- **Ubuntu 24.04 base** (2026-10-30). Both `jammy` and `noble` repos carry the
  current client; 24.04 was chosen for newer Mesa/WebKitGTK.

## Conventions

- Bash scripts: `set -euo pipefail`, functions per subcommand, match existing
  style in `build.sh`.
- Rootless podman only; never require `sudo` on the host beyond installing
  `podman`/`distrobox`.
- Keep docs in sync with `build.sh`/`Containerfile` changes in the same commit.
- Verify on a real Fedora Wayland session before claiming a fix works; record
  what was tested (Fedora version, GPU, session type, client version) in
  **State**.
- distrobox-init skips package setup when `/.containersetupdone` exists
  (`/usr/bin/distrobox-init`, `setup_apt` and the `containersetupdone`
  check). If a distrobox upgrade changes its dependency list, update the
  Containerfile list to match. Its "Installing basic packages..." log line is
  printed even when setup is skipped; check `podman logs aws-workspace` for
  `apt-get` to confirm.

## State (update as you go)

_Last updated: 2026-10-30_

- Host: Fedora 44, kernel 7.2, Wayland session (XWayland `:0`), podman
  5.8.9, distrobox 1.8.2.5. GPU exposed at `/dev/dri/card1`, `renderD128`.
- Image built on this host (with va-driver-all): Ubuntu 24.04, `workspacesclient`
  2026.0.5677-1, 1.36 GB.
- `aws-workspace` container created; first start took ~4 s with no
  `apt-get` runs (verified in `podman logs`). App exported as
  `~/.local/share/applications/aws-workspace-com.amazon.workspacesclient.desktop`.
- **2026-10-30 login test: working.** Registration, login, and streaming OK
  via `./build.sh launch`. Viewer log: GPU rendering via EGL on
  `Mesa Intel(R) Graphics (ARL)`, Mesa 25.2.8 (24.04); QUIC/UDP transport,
  RTT ~25-50 ms; only one benign WARN. H.264 decode was software in
  that first run; hardware (VA-API) since adding `va-driver-all` (see TODO).
- Older logs (2026-09-30 to 10-02, 22.04 image, Intel UHD CML GPU, Mesa 23.2)
  show no clear failure cause: session ends are `origin: Local` closes;
  recurring `certificate-store - Could not save the certificate store: No such
  file or directory` (not seen in the 24.04 run); a broker health-check
  `[ERROR]` appears in every run including the working one (benign).
- Original "doesn't always work well" symptoms not yet captured.

## Logs

The client logs to the host home dir (shared by Distrobox), not the terminal:

- `~/.local/share/Amazon Web Services/Amazon WorkSpaces/logs/WorkSpacesClient_<UTC timestamp>.log`
  — client/login/broker log, one per launch.
- `~/.local/share/Amazon Web Services/Amazon WorkSpaces/logs/WSP/viewer.log`
  (rotated `viewer.log.N`) — DCV streaming: GPU/GL renderer, decoder,
  transport (QUIC vs TCP), RTT, disconnects.
- Web view data: `~/.local/share/workspacesclient/`, `~/.cache/workspacesclient/`.

Client logs include the registration code; don't paste them publicly.

## Known / suspected issues

1. WebKitGTK in a container on Wayland can render the login page blank.
   Workarounds documented in `docs/launch.md` (`WEBKIT_DISABLE_DMABUF_RENDERER=1`,
   `WEBKIT_DISABLE_COMPOSITING_MODE=1`) but not baked in — only add them if
   testing shows they're needed.
2. Distrobox shares `$HOME`, so client config/logs land in the host home dir
   (likely `~/.local/share/Amazon Web Services/`). Survives rebuilds — good
   for registration, but stale config can survive too.
3. `distrobox create` also exports `aws-workspace.desktop` (a shell into the
   container); unclear whether `distrobox rm` removes it.
4. Multi-monitor support unverified with this setup.
5. **`distrobox enter` copies the whole host shell environment into the
   container as `--env=NAME=value` arguments to `podman exec`.** Fixed for
   `./build.sh launch` (`with_clean_env`); still open for the app menu. Any secrets
   exported in the shell (cloud keys, API tokens) are passed to the client and
   are visible in `ps` to every local user while it runs. Launching from a
   terminal with secrets in the environment is the worst case.
6. ~~Video decode is software~~ Fixed: `va-driver-all` restores VA-API
   hardware decode (verified 2026-10-30).

## TODO

- [x] User: test registration + login + connect to a WorkSpace with the 24.04
      image (2026-10-30: working; see **State**).
- [ ] Capture the original failure symptoms if they recur, plus client logs.
- [ ] Bake in WebKit env workarounds only if login rendering fails.
- [ ] Verify multi-monitor and the app-menu launcher. (Smart card
      passthrough confirmed working by user, 2026-10-30.)
- [ ] Decide whether to push the image to quay.io for other machines.
- [ ] Revisit plain `podman run --rm` launcher if Distrobox-specific issues
      show up.
- [x] **Stop leaking host env vars from `./build.sh launch`** (2026-10-30).
      `distrobox-enter` (lines ~441-443) passes the full `printenv` output as
      `--env=` args to `podman exec`, skipping only a fixed short list; no
      option disables it. `build.sh` now runs it via `with_clean_env`
      (`env -i` + `CLEAN_ENV_VARS` allowlist). A plain subshell is not enough:
      children inherit exported vars. Verified with a live session: 23
      `--env=` args, no secret names on the `podman exec` command line or in
      the `workspacesclient`/`dcvviewer` process env; login, streaming OK.
- [ ] **App menu entry still leaks env vars.** The GNOME session env has the
      same secrets (exported in `~/.bashrc`; verified by var name only), and
      the `distrobox-export` `.desktop` calls `distrobox-enter` directly.
      Plan: have `setup` write its own `.desktop` with
      Exec=`<repo>/build.sh launch %u` (or an installed launcher in
      `~/.local/bin`), keep `MimeType=x-scheme-handler/workspaces`, and stop
      exporting via `distrobox-export` (update `remove` to match). Verify with
      the same `ps`/`/proc/<pid>/environ` name-only check.
- [ ] Audio under the clean env: not checked (low priority per user).
      Keyboard/mouse input confirmed working 2026-10-30. Add allowlist vars
      (e.g. `PULSE_SERVER`) only if audio turns out broken.
- Side note for the user (their call): moving secrets out of `~/.bashrc`
  (e.g. `~/.aws/credentials`, a secret manager) limits exposure for every
  app, not just this one.
- [x] **Intel hardware video decode** (2026-10-30). Containerfile installs
      `va-driver-all` (iHD 24.1.0 + i965 + Mesa; GPU-neutral) + `vainfo`.
      DCV's viewer bundles its own FFmpeg and uses VA-API automatically when
      a driver is present (it also has `enable/disable-hardware-decoder` and
      `enable/disable-vaapi` options). Before: `source: Ffmpeg` +
      `ffmpeg-decoder - Initialized software context`. After rebuild:
      `media - Selected context: vaapi`, h264 decompressor `source: VA`, no
      decoder errors. The old 22.04 setup also used VA-API, so the first 24.04
      image was a regression. CPU while opening/closing Firefox: 0.5-3%
      (software) vs 1-1.5% (hardware); light desktop use barely differs,
      benefit is for video/heavy motion and battery. Check with
      `grep -E "Selected context|decompressor for h264" .../WSP/viewer.log`.
- [ ] Pass username + registration code on the CLI. The client natively
      accepts `workspacesclient 'workspaces://username@registration-code?MFACode=mfa-code'`
      (from `workspacesclient --help`; username and MFACode optional; no
      password field). The exported `.desktop` is already the
      `x-scheme-handler/workspaces` default, so `xdg-open 'workspaces://...'`
      also works. Untested. `./build.sh launch` now passes its arguments
      through to `workspacesclient` (untested with a URI); remaining: optionally build the URI from
      `./build.sh launch <username> <reg-code>`. Don't commit real codes.
