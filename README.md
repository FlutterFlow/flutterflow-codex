# FlutterFlow Codex Plugin

Build and edit [FlutterFlow](https://flutterflow.io) apps from
[Codex](https://developers.openai.com/codex) — describe what you want in plain
language and the agent drives the FlutterFlow CLI to scaffold workspaces, author
changes as Dart DSL, validate them, and apply them.

This repo ships one plugin, `flutterflow`, which adds:

- A **skill** that teaches Codex the FlutterFlow AI workflow — workspace setup,
  inspection, validating and running Dart DSL edits, diagnostics, and code export.
- **Helper scripts** that resolve a globally installed `flutterflow` CLI (or a
  local `flutterflow_cli` source checkout), plus a secure clipboard hand-off
  script for FlutterFlow API keys.
- An **optional MCP example** for workspace-bound setups. MCP is not registered
  or started by default.

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

From a clone of this repo:

```bash
codex plugin marketplace add .
codex plugin add flutterflow@flutterflow
```

Start a new Codex thread so the skill loads. (A public Plugin Directory listing
is coming soon; until then, install from this repo.)

## Use it

Once installed, just ask Codex in plain language:

> Create a new FlutterFlow app called `habit_tracker`.

> Edit my FlutterFlow project — add a settings screen. The project id is `<id>`.

> Export my FlutterFlow project to Flutter code.

The skill walks through auth, workspace setup, validation, and applying the
change for you.

### Use the CLI directly (optional)

You can also run the FlutterFlow CLI yourself:

```bash
flutterflow ai init my-app                   # new workspace
flutterflow ai init my-app --project <id>    # bind to an existing project
flutterflow ai status <project-id>           # inspect
flutterflow ai run <file.dart>               # apply a Dart DSL change
```

If `flutterflow` isn't on your PATH, the plugin bundles a helper. Its own
location matters (not your working directory), so run it from the repo root or
give an absolute path:

```bash
/absolute/path/to/plugins/flutterflow/scripts/flutterflow-cli.sh ai --help
```

## Authentication

- `flutterflow ai` uses `FF_API_KEY` or the credential store created by
  `flutterflow ai init`. `export-code` and `deploy-firebase` use
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

- You can also run `flutterflow ai init` once in a terminal — it prompts for your
  key and saves it to `~/.flutterflow/credentials.json` (mode `0600`) for later
  commands.
- Avoid the `--api-key` flag: it puts the secret on the process argument list and
  persists it to disk (both the credential store and the workspace `.env`).
- Never commit tokens. This repo's `.gitignore` covers `.env`, `.env.*`, and
  `credentials.json`; keep any workspace `.env` out of version control too.

## MCP (optional)

This plugin does not auto-register an MCP server — `flutterflow ai mcp` needs one
concrete workspace, while the plugin should work from any Codex thread. For a
workspace-bound setup, copy
[mcp.example.json](plugins/flutterflow/mcp.example.json), fill in absolute paths,
and point `FLUTTERFLOW_AI_WORKSPACE` at your workspace. Smoke-test the launcher:

```bash
FLUTTERFLOW_AI_WORKSPACE=/absolute/path/to/workspace \
  /absolute/path/to/plugins/flutterflow/scripts/flutterflow-mcp.sh
```

Don't rename `mcp.example.json` to `.mcp.json` unless you want Codex to start MCP
for every thread where this plugin is enabled.

## Development

The plugin's runtime surface is shell scripts plus the skill and configs. CI
([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs `shellcheck`, syntax
checks, clipboard hand-off tests, and JSON validation on every push.

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
