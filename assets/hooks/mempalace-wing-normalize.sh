#!/usr/bin/env bash
# PreToolUse hook (matcher: MemPalace write tools) that keeps wing names
# consistent with MemPalace's own auto-miner normalization which is:
# - lowercase,
# - spaces/hyphens -> "_"
#
# Without this there will be in some cases writes that use differently-cased
# wing names, which silently forks a project's memory into several wings.
#
# NOTE: Instead of blocking the write, this auto-corrects the wing names
# if needed and is silent (no output) when nothing needs changing.
set -euo pipefail

jq -c '
  def norm: ascii_downcase | gsub("[- ]+"; "_") | gsub("^_+|_+$"; "");

  .tool_input as $ti
  | ($ti
      | if has("items") then .items |= map(if has("wing") then .wing |= norm else . end) else . end
      | if has("diary") and (.diary | has("wing")) then .diary.wing |= norm else . end
      | if has("wing") then .wing |= norm else . end
    ) as $new
  | if $new != $ti
    then {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: $new}}
    else empty
    end
'
