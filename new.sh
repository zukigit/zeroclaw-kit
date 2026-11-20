#!/usr/bin/env bash
# Create a new kit item from its template. The folder name is the item's name.
#
#   ./new.sh agent   agent1      -> agents/agent1/            (agent.toml + workspace/*.md)
#   ./new.sh risk    strict      -> risk_profiles/strict/     (risk_profile.toml)
#   ./new.sh runtime fast        -> runtime_profiles/fast/    (runtime_profile.toml)
#   ./new.sh provider openai.work -> providers/openai.work/  (provider.toml, <type>.<alias>)
#
# Edit the new folder, then install it with ./install.sh --data <dir> <folder>.
# Works from any directory; paths are relative to this kit folder.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/zeroclaw.sh"

[[ $# -eq 2 ]] || zc_die "usage: $0 <agent|risk|runtime|provider> <name>"
zc_type "$1"
NAME="$2"
zc_check_name "$NAME"

DEST="$T_DIR/$NAME"
[[ ! -e "$DEST" ]] || zc_die "already exists: $DEST"

mkdir -p "$T_DIR"
cp -r "$KIT/templates/$T_HEADER" "$DEST"
# Fill in the template placeholders:
#   {{NAME}}      the item's name
#   {{NAME_ENV}}  name in env-var path form (opencode.big -> opencode__big)
#   {{KEY_VAR}}   .env variable for a provider's API key (-> OPENCODE_API_KEY)
# Provider templates carry two variants of the key comment: lines starting
# `#@key` (needs an API key) and `#@nokey` (local/CLI/AWS). Keep one.
KEY_VAR=""; KEEP=key; DROP=nokey
if [[ "$T_KIND" == provider ]]; then
  KEY_VAR="$(zc_key_var "${NAME%%.*}" "${NAME#*.}")"
  if zc_in_list "${NAME%%.*}" "$ZC_KEYLESS"; then KEEP=nokey; DROP=key; fi
fi
find "$DEST" -type f \( -name '*.md' -o -name '*.toml' \) \
  -exec sed -i -e "/^#@$DROP /d" -e "s/^#@$KEEP /# /" \
               -e "s|{{NAME}}|$NAME|g" -e "s|{{NAME_ENV}}|${NAME//./__}|g" \
               -e "s|{{KEY_VAR}}|$KEY_VAR|g" {} +

echo "created $DEST"
if [[ "$T_KIND" == provider ]]; then
  echo "set model (and any type-specific fields) in $DEST/provider.toml"
  if [[ $KEEP == key ]]; then
    echo "api key: after installing, add to docker-compose.yml (zeroclaw environment):"
    echo "  - ZEROCLAW_providers__models__${NAME//./__}__api_key=\${$KEY_VAR:?set $KEY_VAR in .env}"
    echo "  and $KEY_VAR=<key> to .env"
  else
    echo "api key: '${NAME%%.*}' normally needs none (local server / CLI login / AWS chain)"
  fi
fi
echo "next: edit it, then run"
echo "  $KIT/install.sh --data <zeroclaw-data-dir> $DEST"
