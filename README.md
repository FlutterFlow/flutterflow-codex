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
- `python3` on PATH — only for the plugin-validation scripts in
  [Local Development](#local-development) below (on Windows, use `py -3`).

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

If `flutterflow` is not globally installed, use the plugin helper. What matters is
the helper's own location, not your current directory, so run it from the repo
root or give an absolute path:

```bash
/absolute/path/to/plugins/flutterflow/scripts/flutterflow-cli.sh ai --help
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
  /absolute/path/to/plugins/flutterflow/scripts/flutterflow-mcp.sh
```

To make MCP automatic later, create a workspace-specific plugin/config that
points at an absolute workspace path. Do not rename `mcp.example.json` to
`.mcp.json` in this generic plugin unless you intentionally want Codex to start
MCP for every thread where this plugin is enabled.

## Authentication Notes

- Get an API key from the FlutterFlow account page:
  <https://app.flutterflow.io/account>.
- `flutterflow ai` uses `FF_API_KEY`, or the credential store created by
  `flutterflow ai init`.
- `flutterflow export-code` and `flutterflow deploy-firebase` use
  `FLUTTERFLOW_API_TOKEN`.
- The credential store (`~/.flutterflow/credentials.json`) holds the key in
  plaintext (file mode 0600 on POSIX). Never `cat`, copy, echo, or commit it.
- A workspace created with `--api-key` also writes the key to a `.env` in that
  workspace. Keep it out of version control — this repo's `.gitignore` covers
  `.env`, `.env.*`, and `credentials.json`.
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

If auth is missing, grab a key from <https://app.flutterflow.io/account>. The
most reliable path — especially in the Codex app, whose shell may not inherit a
key you export elsewhere — is to **open a terminal** (macOS Terminal or your
editor's integrated terminal) and run `flutterflow ai init <workspace>`
interactively; the CLI prompts for the key and saves it to
`~/.flutterflow/credentials.json`, which later commands reuse. Alternatively,
export `FF_API_KEY` in your shell profile and relaunch Codex. Avoid the
`--api-key` flag: it places the secret on the process
argument list (visible via `ps`/`/proc` and shell history), and
`flutterflow ai init --api-key` *persists* the key to disk
(`~/.flutterflow/credentials.json` and the workspace `.env`) — it is not
one-time. For a transient key on a read-only command, an inline environment
variable (`FF_API_KEY=<key> flutterflow ai status <project-id>`) at least avoids
persisting it to disk — but it is still recorded in shell history and readable
from the process environment for the command's lifetime, so prefer the
interactive `init` prompt. Do not print or commit the token.

## Local Development

> The validation helpers below ship with Codex under
> `~/.codex/skills/.system/plugin-creator/` — they are installed by Codex's
> plugin-creator, **not** by this repo, and require `python3`. If those paths do
> not exist on your machine, that skill isn't installed. The
> [CI workflow](.github/workflows/ci.yml) lints the scripts and configs without
> them.

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
