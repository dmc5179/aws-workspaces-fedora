# CLAUDE.md

@AGENTS.md

## Claude-specific notes

- `AGENTS.md` is the source of truth for project context, state, and TODOs.
  Update its **State** and **TODO** sections rather than duplicating them here.
- Before changing behavior, check the host state: `distrobox list`,
  `podman images | grep aws-workspace`,
  `ls ~/.local/share/applications | grep -i workspaces`.
- Testing a GUI change requires the user's desktop session; ask the user to
  launch the client and report what they see instead of claiming it works.
