---
name: use
description: Use when working with FlutterFlow AI workspaces or the FlutterFlow CLI from Codex. Covers workspace init, auth, inspect/search/status/resources, Dart DSL validate/run, context refresh, diagnostics, export-code, and optional workspace-bound MCP setup.
---

# FlutterFlow CLI

Use this skill for tasks that mention FlutterFlow, FlutterFlow AI, `flutterflow ai`,
FlutterFlow CLI, or FlutterFlow project edits.

## Command Resolution

Prefer the installed `flutterflow` binary for normal use:

```bash
flutterflow ai --help
```

If `flutterflow` is missing, install or update it:

```bash
dart pub global activate flutterflow_cli
```

For local plugin development, this plugin includes a helper at
`<plugin-root>/scripts/flutterflow-cli.sh`, where `<plugin-root>` is this
plugin's `plugins/flutterflow` directory. The path is relative to the plugin
root, not your current working directory — form an absolute path (or `cd` to the
plugin root first) before calling it:

```bash
/absolute/path/to/plugins/flutterflow/scripts/flutterflow-cli.sh ai --help
```

The helper preserves the caller's working directory. It runs a globally
installed `flutterflow` if present; to run from a local `flutterflow_cli` source
checkout instead, point it there with
`FLUTTERFLOW_CLI_DIR=/path/to/packages/flutterflow_cli`.

## Authentication

- `flutterflow ai` uses `FF_API_KEY`, or the CLI credential store written by
  `flutterflow ai init`.
- `export-code` and `deploy-firebase` use `FLUTTERFLOW_API_TOKEN`.
- The credential store (`~/.flutterflow/credentials.json`) holds the key in
  plaintext (mode 0600 on POSIX). Never `cat`, copy, echo, or commit it; the
  preflight below only tests for its presence.
- Never print tokens, write them into repo files, or include them in final answers.
- If credentials are missing, ask the user for the desired auth path or ask them
  to run `flutterflow ai init` interactively.

## Auth Preflight

Before non-interactive FlutterFlow AI commands that may need auth, check for an
environment key or a saved CLI credential store without exposing secret values:

```bash
if [ -n "${FF_API_KEY:-}" ]; then
  echo "ff_auth: env"
elif [ -f "$HOME/.flutterflow/credentials.json" ]; then
  echo "ff_auth: saved-store-present"
else
  echo "ff_auth: missing"
fi
```

If auth is missing, do not keep retrying failing commands. Ask the user to choose
one of these paths:

- Set `FF_API_KEY` in the terminal/session environment.
- Run `flutterflow ai init <workspace>` interactively so the CLI can prompt and
  save the key.
- For a single read-only command, pass a transient key inline as an environment
  variable: `FF_API_KEY=<key> flutterflow ai status <project-id>`. Avoid the
  `--api-key` flag — it puts the secret on the argument list (visible via
  `ps`/`/proc` and shell history), and `flutterflow ai init --api-key` persists
  the key to disk (`~/.flutterflow/credentials.json` and the workspace `.env`),
  so it is not one-time. Never echo a key, store it in repo files, or include it
  in final answers.

If a saved credential exists but the server rejects it, tell the user to refresh
the key from FlutterFlow account settings and run `flutterflow ai logout` only if
they want to inspect or clear saved base URLs.

## Workspace Rules

- FlutterFlow AI commands run inside an initialized workspace containing
  `.flutterflow/config.yaml`.
- If no workspace exists and the user wants to create or edit an app, run:

```bash
flutterflow ai init <workspace-name-or-path>
```

- To bind to an existing project, use:

```bash
flutterflow ai init <workspace-name-or-path> --project <project-id>
```

- Do not run `flutterflow ai init` into a populated non-workspace directory.
- If a workspace already exists, `cd` into it and run `flutterflow ai refresh-workspace`
  or `flutterflow ai upgrade --check` instead of reinitializing.

## Create A New App vs Edit An Existing Project

Decide which path the user wants before running anything. The two starter
prompts map directly to these flows.

### Create a new app

Use this when there is no FlutterFlow project yet. Omit `--project` so the CLI
uses the create-new flow, then `cd` into the scaffold:

```bash
flutterflow ai init <workspace-name-or-path>
cd <workspace-name-or-path>
```

Author the app as Dart DSL, then validate and apply. The first `run` creates the
project; pass `--find-or-create` to reuse a same-named project rather than
creating a duplicate:

```bash
flutterflow ai validate <file.dart>
flutterflow ai run <file.dart> --find-or-create
```

### Edit an existing project

Use this when the user already has a FlutterFlow project.

1. You need the project id — it is in the project URL
   (`app.flutterflow.io/project/<project-id>`). If the user has not provided it,
   ask for it; there is no CLI command that lists the projects in an account.
2. Bind a workspace to that project, then `cd` in:

```bash
flutterflow ai init <workspace-name-or-path> --project <project-id>
cd <workspace-name-or-path>
```

   If a workspace for this project already exists, `cd` into it and run
   `flutterflow ai refresh-workspace` instead of re-initializing.
3. Orient before changing anything (see Standard Agent Workflow below), then
   author, validate, and run DSL edits.

Either way: always `validate` before `run`, and never `init` into a populated
non-workspace directory.

## MCP Usage

This plugin is CLI-first and does not register an MCP server by default. Do not
assume FlutterFlow MCP tools are available in a thread.

Use CLI commands unless the user explicitly configures a workspace-bound MCP
server. The example config is `mcp.example.json`; it is intentionally not named
`.mcp.json` so Codex does not auto-start it.

The optional server launcher resolves the workspace from:

1. `FLUTTERFLOW_AI_WORKSPACE`
2. `CODEX_WORKSPACE_ROOT`
3. the process working directory

If MCP tools are available in the current Codex thread, verify they are connected
to the intended workspace before using them. If the MCP server is unavailable,
fails to start, or points at the wrong workspace, use the CLI commands below.

To start the MCP server manually:

```bash
FLUTTERFLOW_AI_WORKSPACE=/absolute/path/to/workspace \
  /absolute/path/to/plugins/flutterflow/scripts/flutterflow-mcp.sh
```

## Standard Agent Workflow

1. Run the auth preflight above.

2. Identify the workspace:

```bash
pwd
test -f .flutterflow/config.yaml && flutterflow ai upgrade --check
```

3. Orient before editing:

```bash
flutterflow ai status <project-id>
flutterflow ai inspect <project-id>
flutterflow ai resources <project-id>
flutterflow ai search <project-id> --query "<feature-or-screen>"
```

4. Capture intent when useful:

```bash
flutterflow ai plan save --content "<short implementation plan>"
```

5. Author changes as Dart DSL files, then validate before applying:

```bash
flutterflow ai validate <file.dart>
flutterflow ai run <file.dart>
```

The implementation path is Dart DSL -> FFProject protobuf -> generated Flutter
code. Avoid editing generated Flutter output when the requested change belongs
in FlutterFlow project state.

6. Verify and inspect the result:

```bash
flutterflow ai history --limit 5
flutterflow ai trace latest
flutterflow ai context-check
```

7. Refresh stale local context when needed:

```bash
flutterflow ai refresh-context <project-id>
flutterflow ai refresh-workspace --yes
flutterflow ai doctor --json
```

## Export Code

Use the non-AI CLI namespace for generated Flutter exports:

```bash
flutterflow export-code \
  --project <project-id> \
  --dest <output-folder> \
  --include-export-manifest
```

Set `FLUTTERFLOW_API_TOKEN` or pass `--token` for export/deploy commands. Keep
`.flutterflowignore` in mind when updating an existing export destination.

## Safety

- Inspect the current checkout and workspace before making edits.
- Preserve user changes and avoid unrelated refactors.
- Prefer `validate` before `run`.
- Report exact command failures with stderr/stdout summaries, but redact secrets.
