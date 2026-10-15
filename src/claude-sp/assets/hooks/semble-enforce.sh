#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash|WebFetch) enforcing CLAUDE.md's
# "Semble is mandatory before external-repo lookups" rule.
# NOTE: Soft-warn only, never blocks - instead just reminds via systemMessage.
set -euo pipefail

INPUT=$(cat)

if echo "$INPUT" | jq -e '
    (.tool_name == "WebFetch") or
    (.tool_name == "Bash" and
      (.tool_input.command // "" | test("curl.*(codeberg\\.org|github\\.com|raw\\.githubusercontent\\.com|gitlab\\.com)"))
    )' >/dev/null 2>&1
then
  echo '{"systemMessage":"Semble-before-lookup rule: try semble search/find_related on this repo first (CLAUDE.md)."}'
fi
true

