# Shared helpers for new.sh and install.sh. Source it; don't run it.
#
# Every kit item is a folder whose name is the item's name, holding one
# settings file with a name-free table header:
#
#   type      folder                       file                  header              config table
#   agent     agents/<name>/               agent.toml            [agent]             [agents.<name>]
#   risk      risk_profiles/<name>/        risk_profile.toml     [risk_profile]      [risk_profiles.<name>]
#   runtime   runtime_profiles/<name>/     runtime_profile.toml  [runtime_profile]   [runtime_profiles.<name>]
#   provider  providers/<type>.<alias>/    provider.toml         [provider]          [providers.models.<type>.<alias>]
#
# Installing renames the headers (sub-tables too, e.g. [agent.memory] ->
# [agents.<name>.memory]) and appends them to ZeroClaw's config.toml.

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZC_TYPES=(agent risk runtime provider)

zc_die() { echo "$*" >&2; exit 1; }

# zc_type <agent|risk|runtime|provider> -> T_KIND, T_HEADER, T_TABLE, T_FILE, T_DIR
zc_type() {
  case "$1" in
    agent|agents)                             T_KIND=agent;    T_HEADER=agent;           T_TABLE=agents ;;
    risk|risk_profile|risk_profiles)          T_KIND=risk;     T_HEADER=risk_profile;    T_TABLE=risk_profiles ;;
    runtime|runtime_profile|runtime_profiles) T_KIND=runtime;  T_HEADER=runtime_profile; T_TABLE=runtime_profiles ;;
    provider|providers)                       T_KIND=provider; T_HEADER=provider;        T_TABLE=providers.models ;;
    *) zc_die "unknown type '$1' (use: ${ZC_TYPES[*]})" ;;
  esac
  T_FILE="$T_HEADER.toml"
  T_DIR="$KIT/${T_TABLE%%.*}"   # providers.models -> providers/
}

# ZeroClaw's provider slots (<type> in providers.models.<type>.<alias>), from
# docs.zeroclawlabs.ai providers/catalog. Unknown types only warn, since new
# slots get added upstream.
ZC_SLOTS=" ai21 aihubmix anthropic anyscale arcee astrai atlascloud atomic_chat
  avian azure baichuan baseten bedrock cerebras cloudflare cohere copilot crusoe
  custom deepinfra deepmyst deepseek doubao featherless fireworks friendli gemini
  gemini_cli github_models glm grok_cli groq hailo_ollama huggingface hunyuan
  hyperbolic inception kilo kilocli lambda_ai lepton litellm llamacpp lmstudio
  manifest minimax mistral moonshot morph nearai nebius novita nscale nvidia
  ollama openai opencode openrouter osaurus ovh perplexity qianfan qwen reka
  sambanova sglang siliconflow stepfun synthetic telnyx together upstage venice
  vercel vllm xai yi zai zerorouter "
# Slots that normally need no API key: local servers, CLI logins, AWS chain.
ZC_KEYLESS=" ollama hailo_ollama lmstudio llamacpp sglang vllm osaurus atomic_chat
  gemini_cli grok_cli kilocli bedrock "
zc_in_list() { [[ "$(tr -s ' \n' '  ' <<<" $2 ")" == *" $1 "* ]]; }

# ZeroClaw's alias grammar (applies to every name in the config): lowercase
# letters, digits and single underscores, starting and ending with a letter or
# digit, 1-63 chars. Anything else is a load-time error in ZeroClaw.
zc_valid_alias() { [[ "$1" =~ ^[a-z0-9]+(_[a-z0-9]+)*$ && ${#1} -le 63 ]]; }

# zc_check_name <name>: validate a name for the current type
zc_check_name() {
  local rule="lowercase letters, digits and single underscores (no '-' or '__'), max 63"
  if [[ "$T_KIND" == provider ]]; then
    [[ "$1" == *.* && "${1#*.}" != *.* ]] \
      || zc_die "provider name must be <type>.<alias> (e.g. opencode.deepseek_flash): $1"
    local type="${1%%.*}" alias="${1#*.}"
    zc_valid_alias "$type"  || zc_die "provider type '$type': $rule"
    zc_valid_alias "$alias" || zc_die "provider alias '$alias': $rule"
    zc_in_list "$type" "$ZC_SLOTS" \
      || echo "warning: '$type' is not a known ZeroClaw provider type (see docs: providers/catalog)" >&2
  else
    zc_valid_alias "$1" || zc_die "name '$1': $rule"
  fi
}

# zc_key_var <type> <alias>: .env variable for a provider's API key.
# Named after the type so its aliases share one key (OPENAI_API_KEY, ...);
# `custom` gateways are unrelated services, so they get one per alias.
zc_key_var() {
  local t="${1^^}" a="${2^^}"
  if [[ "$1" == custom ]]; then echo "CUSTOM_${a}_API_KEY"; else echo "${t}_API_KEY"; fi
}

# zc_detect <folder> -> sets T_* from whichever settings file the folder has
zc_detect() {
  local t
  for t in "${ZC_TYPES[@]}"; do
    zc_type "$t"
    [[ -f "$1/$T_FILE" ]] && return 0
  done
  zc_die "not a kit folder (no agent.toml, risk_profile.toml, runtime_profile.toml or provider.toml): $1"
}

# zc_ensure_config <data-dir> -> sets CONFIG, creates it from the base if missing
zc_ensure_config() {
  mkdir -p "$1/.zeroclaw"
  CONFIG="$(cd "$1/.zeroclaw" && pwd)/config.toml"
  if [[ ! -f "$CONFIG" ]]; then
    cp "$KIT/templates/config.base.toml" "$CONFIG"
    echo "created $CONFIG from templates/config.base.toml"
  fi
}

# zc_re <text>: escape dots for use in a regex
zc_re() { printf '%s' "${1//./\\.}"; }

# zc_has <table> <name>: is [<table>.<name>] in $CONFIG?
zc_has() { grep -qE "^\[$(zc_re "$1.$2")(\.|\])" "$CONFIG"; }

# zc_remove <table> <name>: drop [<table>.<name>] and its sub-tables from $CONFIG
zc_remove() {
  cp "$CONFIG" "$CONFIG.bak"
  awk -v p="$(zc_re "$1.$2" | sed 's/\\/\\\\/g')" '
    /^\[/ { skip = ($0 ~ "^\\[" p "(\\.|\\])") }
    !skip
  ' "$CONFIG.bak" > "$CONFIG"
  echo "removed old $1.$2 (backup: $CONFIG.bak)"
}

# zc_value <file> <key>: first string value of `key = "..."`
zc_value() { sed -nE "s/^$2 *= *\"([^\"]+)\".*/\1/p" "$1" | head -1; }

# zc_install <folder> <force 0|1>: install one kit folder into $CONFIG
zc_install() {
  local src force="$2" name
  src="$(cd "$1" && pwd)"
  name="$(basename "$src")"
  zc_detect "$src"
  zc_check_name "$name"
  local kind="$T_KIND" header="$T_HEADER" table="$T_TABLE" file="$T_FILE"

  if grep -q 'CHANGE_ME' "$src/$file"; then
    zc_die "$src/$file still has CHANGE_ME placeholders; fill them in first"
  fi
  if grep -qE '^[[:space:]]*api_key[[:space:]]*=' "$src/$file"; then
    echo "warning: $src/$file contains api_key; keep keys out of the kit (use env vars)" >&2
  fi

  if zc_has "$table" "$name"; then
    [[ "$force" -eq 1 ]] || zc_die "$table.$name is already installed; use --force to replace it"
    zc_remove "$table" "$name"
  fi
  {
    echo
    echo "# --- $table.$name ---"
    sed -E -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' \
           -e "s/^\[$header(\.|\])/[$table.$name\1/" "$src/$file"
  } >> "$CONFIG"
  echo "added $table.$name"

  [[ "$kind" == agent ]] && zc_install_agent_extras "$src" "$name" "$force"
  return 0
}

# Agent-only steps: missing provider/profiles it uses, workspace files.
zc_install_agent_extras() {
  local src="$1" name="$2" force="$3" kind key ref f dest
  for kind in provider risk runtime; do
    zc_type "$kind"
    case "$kind" in provider) key=model_provider ;; *) key="$T_HEADER" ;; esac
    ref="$(zc_value "$src/agent.toml" "$key")"
    [[ -n "$ref" ]] || continue
    zc_has "$T_TABLE" "$ref" && continue
    if [[ -f "$T_DIR/$ref/$T_FILE" ]]; then
      zc_install "$T_DIR/$ref" 0
    else
      echo "warning: $key '$ref' is not in the config or the kit ($T_DIR/$ref)" >&2
    fi
  done

  local ws
  ws="$(dirname "$CONFIG")/agents/$name/workspace"
  mkdir -p "$ws"
  if [[ -d "$src/workspace" ]]; then
    for f in "$src"/workspace/*; do
      dest="$ws/$(basename "$f")"
      if [[ -e "$dest" && "$force" -eq 0 ]]; then
        echo "  kept existing workspace/$(basename "$f")"
      else
        cp -r "$f" "$dest"
      fi
    done
  fi
  echo "  workspace: $ws"
}
