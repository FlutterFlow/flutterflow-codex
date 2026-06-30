# FlutterFlow Codex Plugin

A local Codex plugin for CLI-first FlutterFlow AI workflows.

It ships one plugin, `flutterflow`, which provides:

- A Codex skill for FlutterFlow AI workspace setup, inspection, validation, run,
  refresh, diagnostics, and export-code workflows.
- Helper scripts that resolve either a globally installed `flutterflow` command
  or a local `flutterflow_cli` source checkout (set `FLUTTERFLOW_CLI_DIR` to its
  path).
- An optional MCP example for initialized FlutterFlow AI workspaces. MCP is not
  registered or started by default.

## Prerequisites

- Dart/Flutter available on PATH.
- A FlutterFlow API token from <https://app.flutterflow.io/account>.

Install or update the CLI:

```bash
dart pub global activate flutterflow_cli
```

## Install In Codex

From this repo root:

```bash
codex plugin marketplace add .
codex plugin add flutterflow@flutterflow
```

Start a new Codex thread after installing so the skill is loaded.

## Use The CLI

Create a workspace:

```bash
flutterflow ai init my-app
```

Or bind a workspace to an existing FlutterFlow project:

```bash
flutterflow ai init my-app --project <project-id>
```

Run common workspace commands from inside that workspace:

```bash
flutterflow ai upgrade --check
flutterflow ai status <project-id>
flutterflow ai inspect <project-id>
flutterflow ai validate <file.dart>
flutterflow ai run <file.dart>
```

If `flutterflow` is not globally installed, use the plugin helper:

```bash
plugins/flutterflow/scripts/flutterflow-cli.sh ai --help
```

## Use MCP

This plugin does not auto-register MCP. That is intentional: `flutterflow ai mcp`
requires one concrete initialized workspace, while this plugin should be usable
from any Codex thread.

For an advanced workspace-bound MCP setup, use
[mcp.example.json](plugins/flutterflow/mcp.example.json)
as a starting point. The launcher resolves the workspace from:

1. `FLUTTERFLOW_AI_WORKSPACE`
2. `CODEX_WORKSPACE_ROOT`
3. the process working directory

For reliable MCP startup, set:

```bash
export FLUTTERFLOW_AI_WORKSPACE=/absolute/path/to/flutterflow-ai-workspace
```

Then start the launcher manually for a smoke test:

```bash
FLUTTERFLOW_AI_WORKSPACE=/absolute/path/to/workspace \
  plugins/flutterflow/scripts/flutterflow-mcp.sh
```

To make MCP automatic later, create a workspace-specific plugin/config that
points at an absolute workspace path. Do not rename `mcp.example.json` to
`.mcp.json` in this generic plugin unless you intentionally want Codex to start
MCP for every thread where this plugin is enabled.

## Authentication Notes

- `flutterflow ai` uses `FF_API_KEY`, or the credential store created by
  `flutterflow ai init`.
- `flutterflow export-code` and `flutterflow deploy-firebase` use
  `FLUTTERFLOW_API_TOKEN`.
- The credential store (`~/.flutterflow/credentials.json`) holds the key in
  plaintext (file mode 0600 on POSIX). Never `cat`, copy, echo, or commit it.
- Do not commit tokens into this repo.

Codex should preflight auth before non-interactive FlutterFlow AI commands:

```bash
if [ -n "${FF_API_KEY:-}" ]; then
  echo "ff_auth: env"
elif [ -f "$HOME/.flutterflow/credentials.json" ]; then
  echo "ff_auth: saved-store-present"
else
  echo "ff_auth: missing"
fi
```

If auth is missing, prefer setting `FF_API_KEY` in the session environment, or
run `flutterflow ai init <workspace>` interactively so the CLI prompts for and
saves the key. Avoid the `--api-key` flag: it places the secret on the process
argument list (visible via `ps`/`/proc` and shell history), and
`flutterflow ai init --api-key` *persists* the key to disk
(`~/.flutterflow/credentials.json` and the workspace `.env`) — it is not
one-time. For a genuinely transient key on a read-only command, use an inline
environment variable instead:
`FF_API_KEY=<key> flutterflow ai status <project-id>`. Do not print or commit
the token.

## Local Development

Validate the plugin:

```bash
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py \
  plugins/flutterflow
```

If you edit the plugin after installing it, bump the Codex cachebuster:

```bash
python3 ~/.codex/skills/.system/plugin-creator/scripts/update_plugin_cachebuster.py \
  plugins/flutterflow
codex plugin add flutterflow@flutterflow
```
