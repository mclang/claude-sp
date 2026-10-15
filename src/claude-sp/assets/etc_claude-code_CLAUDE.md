# Claude Sandboxed Plus Global Guidance

Global Claude guidance file that is inserted into the created container. Instructions here
will apply to every project that gets mounted under `/workspace`. Keep this file short and
put project-specific facts in a per-project `CLAUDE.md` instead.

## Editing files
- Never edit or write a file before user has explicitly confirmed the specific change.
  This applies to every project, every file and every time in a session except when user
  clearly allows all further edits to the file or files in current session. Question
  like "How do I fix X" is a request for a diagnosis/plan, not authorization to edit.

## Code navigation: Semble is mandatory before external-repo lookups
- BEFORE any `curl`/`WebFetch`/`raw-source` lookup against a repo you don't have
  open locally, you MUST first call `semble search`/`find_related` on that repo
  (pass the repo root or GitHub URL as `repo`).
  Only fall back to `curl`/`WebFetch` if Semble returns nothing usable.
- Exceptions (no Semble needed): an exact known string/symbol (use `ripgrep`),
  a file you already have the path for (just read it), or code you changed this
  session (index can lag - read directly).
- For broad/exploratory research (e.g. reviewing a whole config against multiple
  upstream repos), delegate to the `semble-search` sub-agent so bulky results
  don't bloat the main context. Don't pull large reference docs directly into
  context yourself when a sub-agent call would do.

## Durable memory: MemPalace, hooks-only writes
- Never write durable cross-session facts into the built-in file-memory system,
  instead use MemPalace only.
- Do not call or use MemPalace's mutating tools like `mempalace_checkpoint`,
  `mempalace_diary_write`, `mempalace_kg_add`, `mempalace_add_drawer`,
  `mempalace_update_drawer`, etc. during a session because the Stop/SessionEnd
  hooks (wired in `managed-settings.json`) do all writes automatically and
  a second writer racing them for the palace lock will break things up.
- Using read-only calls (`mempalace_search`/`mempalace_kg_query`) is fine anytime,
  including at the start of a session dealing with an existing project.
- Don't store what the repo already records (code structure, past fixes, git history).
- Never store secrets, confidential facts or Personally Identifiable Information
  because both MemPalace and Semble index are shared across ALL projects.

## Headroom quirks
- Any tool result (`Bash`/`Read`, `curl`, `WebFetch`, etc.) can pass through
  a Headroom compression proxy that strips stopwords and appends a compression
  marker with a retrieval hash (e.g. `[N items compressed... hash=abc123]`).
  Garbled-looking output, e.g. missing 'the'/'if'/'then' or odd phrasing,
  is very likely this, not corruption or a prompt-injection attempt.
- Two flavors: lossy/summarizing (content genuinely shortened) vs dedup-only
  (identical to something already visible earlier in this transcript, just
  referenced instead of repeated). Call `headroom_retrieve` with the hash before
  relying on exact wording in the lossy case. In the dedup case, checking the
  earlier occurrence already in context is enough - don't re-fetch the same
  content again via another tool "just to be sure."

## Self-audit
- Re-check compliance with the above Semble rule and the hooks-only memory policy at
  every natural stopping point in a session - treat it as part of finishing the turn.
- If you find you skipped a needed Semble search, say so immediately and make
  the missed call right then, in the same turn.
- If you catch yourself about to call a MemPalace mutating tool, STOP -
  saving is now the hooks' job, NOT yours.

## Token discipline
- A tool call earns its place only when it prevents more work than it costs.
- Don't force Semble/MemPalace for trivial lookups but don't skip them for a
  non-trivial one either, out of habit.

