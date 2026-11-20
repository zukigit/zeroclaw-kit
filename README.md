# ZeroClaw kit

A kit for creating ZeroClaw configs from templates and saving them for later
use. Agents, risk profiles, runtime profiles and model providers each live in
their own folder. You create them with `new.sh`, keep them in git, and
install them into any ZeroClaw setup with `install.sh`, again and again
across projects.

The kit is portable. You can put it anywhere: inside a project, in your home
dir, or in its own git repo. It never assumes where ZeroClaw's data lives;
you pass that location with `--data` every time you install.

```
<kit>/
  new.sh                          # create an item from its template
  install.sh                      # install item folders into a ZeroClaw config
  agents/<name>/                  # saved agents
    agent.toml                    #   [agent]         -> [agents.<name>]
    workspace/*.md                #   SOUL, IDENTITY, USER, AGENTS, TOOLS, HEARTBEAT, MEMORY
  risk_profiles/<name>/           # saved risk profiles
    risk_profile.toml             #   [risk_profile]  -> [risk_profiles.<name>]
  runtime_profiles/<name>/        # saved runtime profiles
    runtime_profile.toml          #   [runtime_profile] -> [runtime_profiles.<name>]
  providers/<type>.<alias>/       # saved model providers (no API keys)
    provider.toml                 #   [provider]      -> [providers.models.<type>.<alias>]
  templates/
    agent/  risk_profile/  runtime_profile/  provider/   # blank items, with defaults
    config.base.toml              # tools/gateway, used only if the data dir has no config yet
  lib/zeroclaw.sh                 # shared helpers
  docker-compose.example.yml      # ZeroClaw service to paste into a project's compose
```

Every item is a folder, and the folder name is the item's name. Names
follow ZeroClaw's alias rules: lowercase letters, digits and single
underscores, 1–63 chars, with no `-` and no `__`. ZeroClaw refuses to load
other names, so `new.sh` rejects them. Nothing in
the kit holds credentials, so it is safe to commit or share.

## Create

```bash
KIT=/path/to/zeroclaw-kit

$KIT/new.sh agent   agent1          # -> $KIT/agents/agent1/
$KIT/new.sh risk    risk_profile1   # -> $KIT/risk_profiles/risk_profile1/
$KIT/new.sh runtime fast            # -> $KIT/runtime_profiles/fast/
$KIT/new.sh provider openai.work    # -> $KIT/providers/openai.work/
```

Then edit the new folder. For an agent, that means `workspace/IDENTITY.md`,
`SOUL.md`, `USER.md`, and `agent.toml`. An agent picks its provider and
profiles in `agent.toml`:

```toml
model_provider = "openai.work"   # which model: providers/<type>.<alias>
risk_profile = "risk_profile1"   # what it may do without asking: commands, paths, approvals
runtime_profile = "default"      # how it runs: limits, context compression, thinking
```

The kit ships a `default` risk profile and a `default` runtime profile, both with ZeroClaw's default values, plus
the `opencode.deepseek_flash` provider (`deepseek-v4.1-flash`).

### Providers

A provider's name is `<type>.<alias>`. `<type>` is one of ZeroClaw's provider
slots, such as `openai`, `anthropic`, `openrouter`, `opencode`, `deepseek`,
`gemini`, `ollama`, `azure`, `bedrock` or `custom`. There are 79 in total; see the
[catalog](https://docs.zeroclawlabs.ai/master/en/providers/catalog.html).
`<alias>` is any name you choose. You can have several aliases per type
(`anthropic.personal`, `anthropic.work`).

`provider.toml` takes any field that type supports. The template lists the
common ones, and the catalog lists the type-specific ones. Examples:

```toml
[provider]                        # providers/ollama.home — local, no key
model = "qwen3:8b"
uri = "http://127.0.0.1:11434"

[provider]                        # providers/azure.prod
model = "gpt-5"
resource = "myres"
deployment = "gpt5"
api_version = "2025-01-01"

[provider]                        # providers/custom.my_gateway — any OpenAI-compatible endpoint
model = "llama-4"
uri = "https://gw.example.com/v1"
[provider.extra_headers]
X-Team = "ai"
```

A new provider starts with `model = "CHANGE_ME"`, and `install.sh` refuses
to install it until you fill that in. The file never contains `api_key`, and
`install.sh` warns if it finds one.

## Install

```bash
$KIT/install.sh --data ./zeroclaw-data $KIT/agents/agent1
$KIT/install.sh --data ./zeroclaw-data $KIT/risk_profiles/strict $KIT/runtime_profiles/fast
$KIT/install.sh --data ./zeroclaw-data $KIT/providers/openai.work
docker compose restart zeroclaw
```

- `--data` (or `-d`) is required. It's ZeroClaw's home dir, the folder
  mounted into the container, which holds `.zeroclaw/config.toml`, the
  secret key, sessions and memory. Keep it out of git. If it has no config
  yet, one is created from `templates/config.base.toml`.
- The type is detected from the folder (`agent.toml`, `risk_profile.toml`,
  `runtime_profile.toml` or `provider.toml`). You can pass several folders at once.
- An agent install also installs the provider and the risk and runtime
  profiles the agent names, if the config doesn't have them yet, and copies
  its workspace files.
- `--force` replaces items already in the config (a `config.toml.bak` is
  kept) and overwrites agent workspace files, including `MEMORY.md`. The
  memory DB and sessions are kept. Providers and profiles pulled in by an
  agent are never replaced, because other agents may share them. Pass their
  folder itself with `--force` to update one. Note that `--force` on a
  provider also drops an `api_key` stored for it in the config (e.g. one
  entered in the dashboard). Keys passed in through env vars aren't affected.

You can install the same folders into as many data dirs or projects as you like.

## API keys

API keys are never stored in the kit. Each provider's key comes from an
environment variable in the project's `docker-compose.yml`, and the value
lives in `.env` (gitignored). The variable is named after the provider type
(`opencode.*` → `OPENCODE_API_KEY`, `openai.*` → `OPENAI_API_KEY`), so all
aliases of one type share it. The exception is `custom`, where each alias is
a different service, so each gets its own (`custom.my_gateway` →
`CUSTOM_MY_GATEWAY_API_KEY`). Rename the variable if two aliases need
different keys, e.g. two OpenAI accounts.

```yaml
# docker-compose.yml, zeroclaw service
environment:
  - ZEROCLAW_providers__models__opencode__deepseek_flash__api_key=${OPENCODE_API_KEY:?set OPENCODE_API_KEY in .env}
```
```bash
# .env
OPENCODE_API_KEY=...
```

`new.sh provider <type>.<alias>` prints the exact line for the new
provider, and its `provider.toml` repeats it in a comment. Add one line per
provider, and only after it is installed: ZeroClaw aborts startup on a
`ZEROCLAW_...` variable that doesn't match a path in the config. Local and
CLI types (`ollama`, `lmstudio`, `llamacpp`, `vllm`, `sglang`, `gemini_cli`,
`grok_cli`, ...) and `bedrock`, which uses the AWS credential chain, normally
need no key, and `new.sh` says so. `:?` makes compose stop when the variable is
missing, instead of overriding a key stored in `config.toml` with `""`.

You can also enter the key in the dashboard instead, where ZeroClaw stores it
encrypted with its own `.secret_key`.
