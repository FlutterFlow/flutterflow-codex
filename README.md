# FlutterFlow Codex Plugin

Build and edit [FlutterFlow](https://flutterflow.io) apps from
[Codex](https://developers.openai.com/codex) — describe what you want in plain
language and the agent drives the FlutterFlow CLI and project-scoped MCP to
scaffold workspaces, understand typed project context, test changes, and apply
them safely.

This repo ships one plugin, `flutterflow`, which adds:

- A **skill** that handles secure onboarding, then follows each workspace's
  version-matched `AGENTS.md` for typed SDK, branch-aware editing, testing,
  diagnostics, and code export.
- **Helper scripts** that resolve a globally installed `flutterflow` CLI (or a
  local `flutterflow_cli` source checkout), plus a secure clipboard hand-off
  script for FlutterFlow API keys.
- A **workspace-bound MCP example** that launches the vendored server directly.
  Current CLI onboarding also writes project-scoped agent configuration.

## Prerequisites

- [Codex](https://developers.openai.com/codex) installed.
- Dart/Flutter on your PATH.
- A FlutterFlow API key — get one from
  [your FlutterFlow account](https://app.flutterflow.io/account).

Install or update the FlutterFlow CLI:

```bash
dart pub global activate flutterflow_cli
```

## Install

Install from GitHub:

```bash
codex plugin marketplace add FlutterFlow/flutterflow-codex --ref main
codex plugin add flutterflow@flutterflow
```

You can also pass the full HTTPS URL:

```bash
codex plugin marketplace add https://github.com/FlutterFlow/flutterflow-codex --ref main
codex plugin add flutterflow@flutterflow
```

For local development or testing unpushed changes, run the local marketplace
command from the repo root:

```bash
cd /path/to/flutterflow-codex
codex plugin marketplace add .
codex plugin add flutterflow@flutterflow
```

Start a new Codex task so the skill loads. (A public Plugin Directory listing
is coming soon; until then, install from GitHub or a local clone.)

## Use it

Once installed, just ask Codex in plain language:

> Create a new FlutterFlow app called `habit_tracker`.

> Edit my FlutterFlow project — add a settings screen. The project id is `<id>`.

> Export my FlutterFlow project to Flutter code.

The skill walks through auth and workspace setup, then follows the generated
workspace contract for the installed FlutterFlow AI SDK.

### Use the CLI directly (optional)

You can also run the FlutterFlow CLI yourself:

For interactive human onboarding, bare `flutterflow ai` opens a searchable
project picker with a create-new option. For deterministic automation:

```bash
flutterflow ai init my-app --yes                          # new workspace
flutterflow ai init my-app --project <id> --yes           # existing project
cd my-app && flutterflow ai branch current                # confirm push target
flutterflow ai test                                       # workspace test gate
flutterflow ai run <file.dart> --commit-message "<why>"   # apply a change
```

If `flutterflow` isn't on your PATH, the plugin bundles a helper. Its own
location matters (not your working directory), so run it from the repo root or
give an absolute path:

```bash
/absolute/path/to/plugins/flutterflow/scripts/flutterflow-cli.sh ai --help
```

The helper preserves the caller's directory, invokes the CLI exactly once, and
defaults direct-command attribution to Codex unless `FF_AI_AGENT_CLIENT` is
already set.

## Authentication

- Onboarding can use `FF_API_KEY` or the per-machine store at
  `~/.flutterflow/credentials.json`. Ordinary initialized-workspace commands use
  the process environment, workspace `.env`, and `.flutterflow/.env`; the latter
  is the generated private store. `export-code` and `deploy-firebase` use
  `FLUTTERFLOW_API_TOKEN`.
- **Recommended in Codex:** use the bundled secure clipboard hand-off. Open
  [your FlutterFlow account](https://app.flutterflow.io/account), copy the API
  key, return to Codex, and say `copied`. The agent runs only
  `plugins/flutterflow/scripts/store-key-from-clipboard.sh`, which reads the
  clipboard once, validates the UUID format, writes
  `~/.config/flutterflow/codex-env.sh` with mode `0600`, and clears the live
  clipboard without displaying the key.
- To use the stored key in a shell command, source the env file in that same shell
  invocation. Do not print, inspect, or commit the file:

```bash
if [ -f "$HOME/.config/flutterflow/codex-env.sh" ]; then
  . "$HOME/.config/flutterflow/codex-env.sh"
fi
flutterflow ai status <project-id>
```

- You can also run bare `flutterflow ai` in a terminal; the onboarding wizard
  prompts for the key, stores machine-level onboarding credentials, and creates
  or binds a workspace with its own private env file.
- Avoid the `--api-key` flag: it puts the secret on the process argument list and
  persists it to disk (both the credential store and `.flutterflow/.env`).
- Never commit tokens. This repo's `.gitignore` covers `.env`, `.env.*`, and
  `credentials.json`; keep workspace env files out of version control too.

## MCP

FlutterFlow MCP is project-scoped. Current `flutterflow ai init` and intentional
`refresh-workspace` flows register the workspace's vendored server with supported
agents, including project-scoped Codex configuration at `.codex/config.toml`.
Open a new Codex task from that workspace after registration so the new tools
load.

For a manual setup, copy
[mcp.example.json](plugins/flutterflow/mcp.example.json) and fill in the absolute
workspace paths. The example and helper both launch
`.flutterflow/sdk/flutterflow_ai/mcp/server.dart` directly; this keeps pub/shim
status text out of MCP's JSON-RPC stdout. Smoke-test the helper with:

```bash
FLUTTERFLOW_AI_WORKSPACE=/absolute/path/to/workspace \
  /absolute/path/to/plugins/flutterflow/scripts/flutterflow-mcp.sh
```

The helper chooses the workspace from `FLUTTERFLOW_AI_WORKSPACE`, then
`CODEX_WORKSPACE_ROOT`, then the current directory.

## Development

The plugin's runtime surface is shell scripts plus the skill and configs. CI
([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs `shellcheck`, syntax
checks, exact-once CLI tests, direct MCP-launch tests, clipboard hand-off tests,
and JSON validation on every push.

> The validation and cachebuster helpers below ship with Codex under
> `~/.codex/skills/.system/plugin-creator/` (installed by Codex's plugin-creator,
> not by this repo) and require `python3`. Skip them if that skill isn't
> installed.

```bash
# validate the plugin manifest and structure
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/flutterflow

# after editing, bump the cachebuster and reinstall
python3 ~/.codex/skills/.system/plugin-creator/scripts/update_plugin_cachebuster.py plugins/flutterflow
codex plugin add flutterflow@flutterflow
```

## Support

- FlutterFlow docs: <https://docs.flutterflow.io>
- Bugs and feature requests:
  [open an issue](https://github.com/FlutterFlow/flutterflow-codex/issues)

## License

Business Source License 1.1 (BUSL-1.1) — see [LICENSE](LICENSE). You may use it
freely in connection with FlutterFlow products and services; it converts to
Apache 2.0 on the change date. It may not be used to build a competing product.
The license text is authoritative.
