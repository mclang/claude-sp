---
name: check-volume-drift
description: Check whether this session's running container has drifted from what the current Dockerfile produces. Use after editing assets or the Dockerfile, or when live behavior doesn't match the repo.
---

Named volumes (see `run.sh`'s `DOCKER_VOLUMES`) are seeded from the image ONLY when first created.
Later rebuilds don't touch an existing volume's contents, so a change in repo files can silently
stop matching what's actually running. Using `--clean` fixes it but don't suggest it as a fix
unless user is fine losing ALL volume data (MemPalace, Headroom stats, etc).

This skill should be run only from inside the container it's checking, so "live" means reading
paths under `$HOME` (i.e. `/home/claude`) directly on this filesystem. Don't try `docker` CLI
commands like `docker exec` or `docker inspect`, instead go straight to reading the files directly.

Bail out and warn user if this isn't "Claude Sandboxed Plus" (wrong `UID` or `HOME`) container.

Don't rely on a fixed list of past-known files here — re-derive it fresh each run:

1. Read `Dockerfile` and `run.sh`'s `DOCKER_VOLUMES` paths fresh.
2. List every `COPY` destination in the Dockerfile and flag any that fall under a `DOCKER_VOLUMES` path.
3. Read every `RUN` command and reason about what files it writes and where. Flag like above
   if it overlaps a `DOCKER_VOLUMES` path. If a command's target program is unfamiliar
   (no direct experience what it writes), say so explicitly instead of assuming it's safe.
4. For each flagged file, compare live vs repo. Mismatch means that changes need to be merged into
   the live file, not overwriting it (live may hold runtime-only fields, e.g. Claude `model`).
5. Check also the other direction: anything present under a `DOCKER_VOLUMES` path that nothing in
   the CURRENT Dockerfile would create is possible orphaned leftover from something since removed.
   Before flagging, rule out runtime-generated state that's supposed to be there like session
   transcripts, MCP-configured marker, MemPalace data, Headroom's savings ledger, etc.

Report as a table:

| Artifact | Live vs repo | Action |

Merge the diff into the live file only after the user agrees to the changes.

