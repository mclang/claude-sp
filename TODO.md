# Additional Things Worth Considering

## Quality of Life Improvements

- Refresh path for seeded `~/.claude` files in EXISTING volumes (volume shadows image; today a
  one-line `CLAUDE.md` edit needs `--clean`, which nukes palace + indexes + model cache)
  - Bake assets also to `~/assets/` staging dir; entrypoint copies on version-marker bump
    (`.assets-synced-vN`, same pattern as `.mcp-configured-vN`): `CLAUDE.md` + re-run semble
    sub-agent install
  - `settings.json` stays seed-once (runtime-mutable - Claude Code writes e.g. `model` into it;
    force-refresh would clobber user settings)
  - Update flow becomes: edit asset -> bump marker -> `--build` -> restart

- Wing naming: Since 3.11 MemPalace hooks write transcripts into `<project>` (was `wing_<project>`),
  same as `mempalace init`/`mine`. Only the diary still goes into `wing_<project>`, so the fix
  added to `entrypoint.sh` (commit: `c5745f0`) is not needed anymore:
  - https://github.com/MemPalace/mempalace/issues/1861
  - https://github.com/MemPalace/mempalace/pull/1511 (`MEMPALACE_WING` env override, unmerged)

- Optimization to evaluate later: new `mempalace-light-mcp` (3-tool, PQL-based) cuts MCP
  schema tokens ~4x vs our current 45-tool server; would need `CLAUDE.md` rewritten around
  PQL instead of named tools, so treat as a separate design decision, not a drop-in.


## Hardening (from in-container validation review, 2026-07-15)

- Pin supply chain: base image digest, `pip install semble==X mempalace==Y` (unpinned already caused the `-v2` model drift)
- CVE-scan the built image with [Grype](https://github.com/anchore/grype) (out-of-image step, most useful once deps are pinned)
- Resource limits: `--memory`, `--pids-limit`, `--cpus` (`run.sh` and project configs)
- Reconsider secret ingest on BOTH paths into the *shared* store - semble `--content all` AND
  `mempalace init --auto-mine` pull raw file contents in, so `.env`/config secrets become recallable
  (cross-project with `run.sh`). Add `.sembleignore` exclusions and a mempalace mine-exclude (or drop `--auto-mine`)
- Egress allowlist proxy if threat model grows (full outbound + broad file read = exfil path; Claude API needs some egress)
- `run.sh`: warn if `~/.config/git` missing before bind-mounting (Docker creates it as empty dir otherwise)


## Dev container Feature

Decided against:
- `CLAUDE_CODE_OAUTH_TOKEN`: model requests only, no claude.ai connectors / Remote Control
- `managed-mcp.json`: exclusive control blocks user servers and connectors

Next:
- Remove Headroom from `run.sh`; evaluate RTK as replacement
- Rewrite `run.sh` as CSP-only devcontainer wrapper (up+exec, --stop, --rebuild, --clean); remove `Dockerfile`,
  `check-volume-drift` skill; rewrite `validate-docs`
- Drop Chroma's duplicate `onnx.tar.gz` (~83 MB) after the bake, if Chroma doesn't re-download it (verify)


## New Functionality

- https://github.com/mukul975/Anthropic-Cybersecurity-Skills
  - 817 security skills (agentskills.io standard); NOT Anthropic despite the name - independent community project (Apache 2.0)
  - FOR adding: real practitioner workflows mapped to MITRE/NIST; genuinely useful for cloud-infra work
  - AGAINST adding by default: (1) third-party prompt content = supply-chain risk, pin to reviewed commit;
    (2) includes offensive/dual-use techniques - opt-in only; (3) 817 skill descriptions bloat EVERY session's
    context - cherry-pick relevant domains instead of installing all
  - Verdict: YES but behind an off-by-default build switch (`ARG INSTALL_SECURITY_SKILLS=0`), pinned commit,
    ideally a curated domain subset (cloud security, IaC, compliance)

---

_Yours, sincerely:_
~ Claude

