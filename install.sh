#!/usr/bin/env bash
# Install kit folders into a ZeroClaw data dir. The type is detected from the
# folder (agent.toml / risk_profile.toml / runtime_profile.toml / provider.toml).
#
#   ./install.sh --data <zeroclaw-data> agents/agent1
#   ./install.sh --data <zeroclaw-data> risk_profiles/strict runtime_profiles/fast
#   ./install.sh --data <zeroclaw-data> agents/agent1 --force
#
# --data (-d) is required: ZeroClaw's home dir, the one mounted into the
# container (it holds, or will hold, .zeroclaw/config.toml). If there's no
# config yet, it is created from templates/config.base.toml.
#
# Agent:    adds [agents.<name>] to config.toml, installs the provider and
#           risk/runtime profiles it names from this kit if the config lacks
#           them, and copies workspace/*.md to .zeroclaw/agents/<name>/workspace/.
# Profile:  adds [risk_profiles.<name>] or [runtime_profiles.<name>].
# Provider: adds [providers.models.<type>.<alias>] (no api_key: use env).
#
# --force replaces items already in the config (config.toml.bak is kept) and
# overwrites agent workspace files, including MEMORY.md; memory DB and
# sessions are kept. Providers/profiles pulled in by an agent are never
# replaced, since other agents may share them; install them explicitly with
# --force for that.
#
# Afterwards restart ZeroClaw, e.g. docker compose restart zeroclaw
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/zeroclaw.sh"

usage() { zc_die "usage: $0 --data <zeroclaw-data-dir> <folder>... [--force]"; }

FOLDERS=(); DATA_DIR=""; FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--data) [[ $# -ge 2 ]] || usage; DATA_DIR="$2"; shift 2 ;;
    --data=*)  DATA_DIR="${1#--data=}"; shift ;;
    --force)   FORCE=1; shift ;;
    -h|--help) usage ;;
    -*)        echo "unknown option: $1" >&2; usage ;;
    *)         FOLDERS+=("$1"); shift ;;
  esac
done
[[ ${#FOLDERS[@]} -gt 0 && -n "$DATA_DIR" ]] || usage

for f in "${FOLDERS[@]}"; do
  [[ -d "$f" ]] || zc_die "no such folder: $f"
  [[ "$(cd "$f" && pwd)" != "$KIT/templates/"* ]] || zc_die "that's a template; create an item with new.sh first: $f"
  zc_detect "$f" >/dev/null   # fail early on a non-kit folder
done

zc_ensure_config "$DATA_DIR"
echo "config: $CONFIG"
for f in "${FOLDERS[@]}"; do
  zc_install "$f" "$FORCE"
done
echo "next: restart ZeroClaw (e.g. docker compose restart zeroclaw)"
