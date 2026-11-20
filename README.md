# ZeroClaw kit

Create ZeroClaw configs from templates, keep them in git, and install them
into any ZeroClaw setup.

- **Create** agents, risk profiles, runtime profiles and model providers with `new.sh`.
- **Install** them into a ZeroClaw data dir with `install.sh`, as often as you like, across projects.
- **Portable**: put the kit anywhere (in a project, your home dir, or its own repo).
  It never assumes where ZeroClaw's data lives; you pass `--data` on every install.
- **Safe to share**: nothing in the kit holds credentials.

## Naming rules

Every item is a folder, and the folder name is the item's name. Names follow
ZeroClaw's alias rules (ZeroClaw refuses anything else, so `new.sh` rejects it):

- lowercase letters, digits and single underscores
- 1–63 characters
- no `-`, no `__`

## Included defaults

| Item             | Name                       | Notes                       |
| ---------------- | -------------------------- | --------------------------- |
| Risk profile     | `default`                  | ZeroClaw's default values   |
| Runtime profile  | `default`                  | ZeroClaw's default values   |
| Provider         | `opencode.deepseek_flash`  | model `deepseek-v4.1-flash` |

## 1. Create

```bash
KIT=/path/to/zeroclaw-kit

$KIT/new.sh agent    agent1          # -> $KIT/agents/agent1/
$KIT/new.sh risk     risk_profile1   # -> $KIT/risk_profiles/risk_profile1/
$KIT/new.sh runtime  fast            # -> $KIT/runtime_profiles/fast/
$KIT/new.sh provider openai.work     # -> $KIT/providers/openai.work/
```

Then edit the new folder.

### Agents

Edit `workspace/IDENTITY.md`, `SOUL.md`, `USER.md` and `agent.toml`.
The agent picks its provider and profiles in `agent.toml`:

```toml
model_provider  = "openai.work"    # which model: providers/<type>.<alias>
risk_profile    = "risk_profile1"  # what it may do without asking: commands, paths, approvals
runtime_profile = "default"        # how it runs: limits, context compression, thinking
```

### Providers

A provider is named `<type>.<alias>`:

- `<type>` is one of ZeroClaw's 79 provider slots, e.g. `openai`, `anthropic`,
  `openrouter`, `opencode`, `deepseek`, `gemini`, `ollama`, `azure`, `bedrock`,
  `custom`. See the [catalog](https://docs.zeroclawlabs.ai/master/en/providers/catalog.html).
- `<alias>` is any name you choose. One type can have several aliases
  (`anthropic.personal`, `anthropic.work`).

`provider.toml` accepts any field the type supports. The template lists the
common ones; the catalog lists the type-specific ones.

```toml
[provider]                        # providers/ollama.home — local, no key
model = "qwen3:8b"
uri = "http://127.0.0.1:11434"
```

```toml
[provider]                        # providers/azure.prod
model = "gpt-5"
resource = "myres"
deployment = "gpt5"
api_version = "2025-01-01"
```

```toml
[provider]                        # providers/custom.my_gateway — any OpenAI-compatible endpoint
model = "llama-4"
uri = "https://gw.example.com/v1"
[provider.extra_headers]
X-Team = "ai"
```

Notes:

- A new provider starts with `model = "CHANGE_ME"`; `install.sh` refuses to
  install it until you change it.
- `provider.toml` never contains `api_key`; `install.sh` warns if it finds one.
  See [API keys](#3-api-keys).

## 2. Install

```bash
$KIT/install.sh --data ./zeroclaw-data $KIT/agents/agent1
$KIT/install.sh --data ./zeroclaw-data $KIT/risk_profiles/strict $KIT/runtime_profiles/fast
$KIT/install.sh --data ./zeroclaw-data $KIT/providers/openai.work
docker compose restart zeroclaw
```

**`--data` / `-d`** (required) — ZeroClaw's home dir: the folder mounted into
the container, holding `.zeroclaw/config.toml`, the secret key, sessions and
memory. Keep it out of git. If it has no config yet, one is created from
`templates/config.base.toml`.

**Item type** is detected from the file in the folder (`agent.toml`,
`risk_profile.toml`, `runtime_profile.toml` or `provider.toml`). You can pass
several folders at once.

**Installing an agent** also:

- installs the provider and the risk/runtime profiles it names, if the config
  doesn't have them yet
- copies its workspace files

**`--force`**:

- replaces items already in the config (a `config.toml.bak` is kept)
- overwrites agent workspace files, including `MEMORY.md`; the memory DB and
  sessions are kept
- does **not** replace providers or profiles pulled in by an agent, since other
  agents may share them. To update one, pass its own folder with `--force`.
- on a provider, also drops any `api_key` stored for it in the config (e.g.
  entered in the dashboard). Keys from env vars aren't affected.

You can install the same folders into as many data dirs or projects as you like.

## 3. API keys

Keys are never stored in the kit. Each provider's key comes from an environment
variable in the project's `docker-compose.yml`; the value lives in `.env`
(gitignored).

```yaml
# docker-compose.yml, zeroclaw service
environment:
  - ZEROCLAW_providers__models__opencode__deepseek_flash__api_key=${OPENCODE_API_KEY:?set OPENCODE_API_KEY in .env}
```

```bash
# .env
OPENCODE_API_KEY=...
```

**Variable names** follow the provider type, so all aliases of a type share one key:

| Provider             | Variable                    |
| -------------------- | --------------------------- |
| `opencode.*`         | `OPENCODE_API_KEY`          |
| `openai.*`           | `OPENAI_API_KEY`            |
| `custom.my_gateway`  | `CUSTOM_MY_GATEWAY_API_KEY` |

`custom` is the exception: each alias is a different service, so each gets its
own variable. Rename the variable if two aliases of one type need different
keys (e.g. two OpenAI accounts).

**Rules:**

- `new.sh provider <type>.<alias>` prints the exact line to add, and
  `provider.toml` repeats it in a comment.
- Add one line per provider, **only after it is installed**. ZeroClaw aborts
  startup on a `ZEROCLAW_...` variable that doesn't match a path in the config.
- `:?` makes compose stop if the variable is missing, instead of overriding a
  key stored in `config.toml` with `""`.
- No key needed (normally): local and CLI types (`ollama`, `lmstudio`,
  `llamacpp`, `vllm`, `sglang`, `gemini_cli`, `grok_cli`, ...) and `bedrock`,
  which uses the AWS credential chain. `new.sh` tells you when this applies.

**Alternative:** enter the key in the dashboard. ZeroClaw stores it encrypted
with its own `.secret_key`.
