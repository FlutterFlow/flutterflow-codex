---
name: use
description: Use when working with FlutterFlow AI workspaces or the FlutterFlow CLI from Codex. Covers workspace init, auth, inspect/search/status/resources, Dart DSL validate/run, context refresh, diagnostics, export-code, and optional workspace-bound MCP setup.
---

# FlutterFlow CLI

Use this skill for tasks that mention FlutterFlow, FlutterFlow AI, `flutterflow ai`,
FlutterFlow CLI, or FlutterFlow project edits.

## Preconditions — read before running anything

This plugin is **CLI-first**: every capability works by running `flutterflow ai …`
in a shell. A working shell and the `flutterflow` CLI are a hard requirement. This
plugin has **no** GUI/desktop/browser path and registers **no** MCP server by
default.

If the shell, command runner, or file-read tooling is unavailable — e.g. a command
fails to launch with `Failed to create unified exec process: No such file or
directory` (which usually means the thread's working directory no longer exists, not
a permission denial) — **STOP**. Tell the user the plugin needs a working shell and
ask them to reopen the thread in a folder that exists (verify with `pwd`), then end
the turn. Do **not** retry alternate shells, enumerate MCP resources, read the
terminal, open desktop apps (e.g. FlutterFlow Campus), or drive a web browser — none
of those can perform FlutterFlow operations.

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

### Docs and reference specs

`flutterflow ai docs [topic]` only works **inside an initialized workspace** — before
`init` it fails with "No FlutterFlow AI workspace found … Run `flutterflow ai init`
first." Do **not** grep `.pub-cache` for the DSL API. The canonical specs are cached
on disk at `~/.flutterflow/packages/<env>/<hash>/` (the `<hash>` varies per SDK build
— pick the most recent). Useful read-only references there: `specs/dsl/*.dart` (worked
example flows), `doc/design_quality.md`, and `lib/src/docs/`. Read those when you
cannot run `flutterflow ai docs`.

## Authentication

- `flutterflow ai` uses `FF_API_KEY`, or the CLI credential store written by
  `flutterflow ai init`.
- `export-code` and `deploy-firebase` use `FLUTTERFLOW_API_TOKEN`.
- The credential store (`~/.flutterflow/credentials.json`) holds the key in
  plaintext (mode 0600 on POSIX). Never `cat`, copy, echo, or commit it; the
  preflight below only tests for its presence.
- Never print tokens, write them into repo files, or include them in final answers.
- Get an API key from the FlutterFlow account page:
  <https://app.flutterflow.io/account>.
- If credentials are missing, point the user to that page and have them set the
  key up out-of-band (see Auth Preflight) — e.g. by opening a terminal and
  running `flutterflow ai init` interactively. Never accept a key pasted into the
  chat.

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

If auth is missing, do not keep retrying failing commands. First tell the user
where to get a key — the FlutterFlow account page,
<https://app.flutterflow.io/account> — then ask them to set it up out-of-band
(never paste a key into the chat) using one of these paths:

- **Open a terminal and run `init` there (recommended).** If you are in the Codex
  app, open macOS Terminal (Cmd-Space → "Terminal") or your editor's integrated
  terminal — Codex's own shell may not inherit a key you export elsewhere. In
  that terminal run:

  ```bash
  flutterflow ai init <workspace>
  ```

  Enter the key when prompted; the CLI saves it to
  `~/.flutterflow/credentials.json`, which later `flutterflow ai` commands reuse
  automatically. Then come back and tell me it's ready.
- Or export `FF_API_KEY` in your shell profile (e.g. `~/.zshrc`) and relaunch
  Codex so its shell inherits it.
- For a single read-only command, pass a transient key inline as an environment
  variable: `FF_API_KEY=<key> flutterflow ai status <project-id>`. Avoid the
  `--api-key` flag — it puts the secret on the argument list (visible via
  `ps`/`/proc` and shell history), and `flutterflow ai init --api-key` persists
  the key to disk (`~/.flutterflow/credentials.json` and the workspace `.env`),
  so it is not one-time.

Never echo a key, store it in repo files, or include it in final answers.

### When auth is missing — stop and hand off

When the preflight prints `ff_auth: missing` and the task needs to create, run, or
push (anything beyond read-only/orienting), treat it as a **hard stop, not a detour**.
Do **not** author DSL, scaffold packages, or do build work you cannot `validate`/`run`
— that work is throwaway until a workspace and auth exist. Instead, reply with ONE
crisp, self-contained setup message: (1) the account-page link
<https://app.flutterflow.io/account>, and (2) the recommended path — open a terminal
and run `flutterflow ai init <workspace>`, entering the key when prompted. Then end the
turn and wait; resume only after the user confirms auth is set. (If the user explicitly
asks you to draft the DSL while they set up auth, you may — but say plainly it cannot be
validated or pushed yet, and author it inside a real workspace, never a standalone
package.)

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

Do **not** hand-author a standalone Dart package or path-pin a `pubspec.yaml` to the
cached SDK under `~/.flutterflow/packages/...`. `flutterflow ai init` scaffolds the
workspace for you — including its `pubspec.yaml` (which depends on the per-workspace
vendored SDK at `./.flutterflow/sdk/flutterflow_ai`) and starter `dsl/create.dart` +
`dsl/edit.dart`. Author your DSL as a file **inside** that workspace; `validate`/`run`
expect that layout, and a package pinned to the global cache is not portable (the cache
is GC'd/overwritten on the next `init`/`upgrade`). Also note `create.dart` is
**one-shot**: re-running it against an existing project fails with duplicate-name
errors — after the first successful `run`, make further changes via `dsl/edit.dart`.

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

1. Run the auth preflight above. If it reports `ff_auth: missing` and the task needs
   to create/run/push, stop and follow "When auth is missing — stop and hand off"
   before doing steps 2+.

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
