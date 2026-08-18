# Claude Sandboxed Plus Global Guidance

Global Claude guidance file that is inserted into the created container. Will apply to
every project that gets mounted under `/workspace`. Keep this file short and put
project-specific facts in a per-project `CLAUDE.md` instead.

## Code navigation — prefer Semble
- To find *where* code lives (behavior, implementations, callers, tests), use
  `semble search` / `semble find_related`, passing the project root as `repo`.
  One call returns `file:line` — go straight there; don't re-grep the same thing.
- Use ripgrep/`grep` instead for an **exact known string or symbol** — cheaper and exact.
- Skip Semble when you already know the file path (just read it) and for code you
  changed this session (the index can lag — read directly).
- For broad or exploratory searches, delegate to the `semble-search` sub-agent —
  it keeps bulky search results out of the main context.

## Durable memory — MemPalace is the single source
- MemPalace holds cross-session facts: decisions + their rationale, conventions,
  people, gotchas. Do not also write these into the built-in file memory — one system,
  and here it's MemPalace.
- **Recall:** when a task depends on prior project context, query MemPalace once
  (`mempalace_search` / `mempalace_kg_query`) before acting. Don't poll it — recall costs tokens.
- **Write:** at the end of a session, store what was decided or learned that isn't
  already in the code or git. Invalidate facts that changed.
- Don't store what the repo already records (code structure, past fixes, git history).
- The palace and semble index are SHARED across ALL projects: NEVER store secrets
  (keys, tokens, passwords) or client-confidential facts — they would be recallable
  from every other project.

## Token discipline
- A tool call earns its place only when it prevents more work than it costs
- Reach for Semble to avoid read/grep sprawl
- Reach for MemPalace to avoid re-deriving context across sessions
- Don't force either for a trivial lookup.

