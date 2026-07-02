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
- This plugin can store a copied FlutterFlow API key without the key entering
  model context. The bundled script writes `~/.config/flutterflow/codex-env.sh`
  with mode `0600`; source it only inside the same shell invocation as commands
  that need auth.
- The credential store (`~/.flutterflow/credentials.json`) holds the key in
  plaintext (mode 0600 on POSIX). Never `cat`, copy, echo, or commit it; the
  preflight below only tests for its presence.
- Never print tokens, write them into repo files, or include them in final answers.
- Get an API key from the FlutterFlow account page:
  <https://app.flutterflow.io/account>.
- If credentials are missing, point the user to that page and use the secure
  clipboard hand-off below. Never accept a key pasted into the chat.

### Secure Clipboard Hand-Off

When auth is missing and a FlutterFlow API key is needed, use this wording:

1) Open <https://app.flutterflow.io/account> and copy your API key.
2) Come back and just say **copied** — do NOT paste the key into this chat. I'll
read your clipboard once, without displaying it, then clear it.

When the user says `copied`, run the bundled script immediately as a standalone
command, with no intervening tool calls:

```bash
/absolute/path/to/plugins/flutterflow/scripts/store-key-from-clipboard.sh
```

Use the exact installed plugin path. Do not compose an inline clipboard command.
If the script prints `key: STORED (clipboard cleared)`, continue. If it prints
`key: INVALID`, use this fixed retry line:

> That didn't look like an API key — something may have overwritten your clipboard.
> Copy the key again (make it the last thing you copy) and say copied.

If it prints `clipboard: UNAVAILABLE` because the session is SSH/headless/no local
clipboard tool, fall back to this own-terminal hidden prompt. The user runs it in
their own terminal; they still must not paste the key into chat:

```bash
bash -lc 'set -euo pipefail; umask 077; dir="$HOME/.config/flutterflow"; file="$dir/codex-env.sh"; mkdir -p "$dir"; chmod 700 "$dir"; read -rsp "FlutterFlow API key: " key; printf "\n"; [[ "$key" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || { echo "key: INVALID"; exit 1; }; tmp="$(mktemp "$dir/.manual.XXXXXX")"; { printf "# flutterflow-codex: user-provided key (manual hand-off)\n"; printf "export FF_API_KEY=%q\n" "$key"; printf "export FLUTTERFLOW_API_TOKEN=%q\n" "$key"; } > "$tmp"; chmod 600 "$tmp"; mv -f "$tmp" "$file"; echo "key: STORED"'
```

Hard rules:

- Never run bare `pbpaste`, `wl-paste`, `xclip`, `xsel`, `Get-Clipboard`, or any
  composed clipboard pipeline. Their stdout enters model context.
- Never `cat`, grep, print, or otherwise inspect the stored config file. The only
  permitted access is sourcing `~/.config/flutterflow/codex-env.sh` immediately
  before commands that need the key. Debug with `ls -l` or `[ -n "$FF_API_KEY" ]`.
- Never request the key via chat or AskUserQuestion.
- If a key-shaped string appears in chat anyway, treat it as compromised. Do not
  store it; tell the user to rotate it.
- Only the exact `store-key-from-clipboard.sh` path may be allowlisted. Never
  allowlist bare clipboard binaries.

## Auth Preflight

Before non-interactive FlutterFlow AI commands that may need auth, check for an
environment key or a saved CLI credential store without exposing secret values:

```bash
if [ -f "$HOME/.config/flutterflow/codex-env.sh" ]; then
  . "$HOME/.config/flutterflow/codex-env.sh"
fi

if [ -n "${FF_API_KEY:-}" ]; then
  echo "ff_auth: env"
elif [ -f "$HOME/.flutterflow/credentials.json" ]; then
  echo "ff_auth: saved-store-present"
else
  echo "ff_auth: missing"
fi
```

Run that source step in the same shell invocation as FlutterFlow commands that
need auth; do not inspect or print the file. If the preflight prints
`ff_auth: missing`, do not keep retrying failing commands and do not paste a key
into the chat. **Stop and walk the user through setup** — see **When auth is
missing — stop and hand off** below.

### When auth is missing — stop and hand off

When the preflight prints `ff_auth: missing` and the task needs to create, run, or
push (anything beyond read-only/orienting), treat it as a **hard stop, not a detour**.
Do **not** author DSL, scaffold packages, or do build work you cannot `validate`/`run`
— that work is throwaway until a workspace and auth exist.

Instead, **stop and give the user one simple, self-contained setup message, then
wait.** Assume they may know nothing about terminals or code: use the clipboard
hand-off wording above and tell them to come back with only `copied`. Resume only
after they do.

Use this template:

> I can build this — FlutterFlow just needs to sign in first. It takes about a
> minute. Here's exactly what to do:
>
> **1. Open the FlutterFlow account page** —
> https://app.flutterflow.io/account — and copy your API key.
>
> **2. Come back here and type only `copied`.** Do **not** paste the key into this
> chat. I'll read your clipboard once, without displaying it, then clear it.

After the key is stored:

- After `key: STORED (clipboard cleared)`, source
  `~/.config/flutterflow/codex-env.sh` in the same shell invocation as
  `flutterflow ai init <workspace-name-or-path>` or later FlutterFlow commands.
- Never accept a key pasted into the chat; never echo, inspect, store in repo
  files, or print it.

**Advanced alternatives** (only if the user prefers): export `FF_API_KEY` in their
shell profile and relaunch Codex, or use the own-terminal hidden prompt above when
the clipboard is unavailable. Avoid the `--api-key` flag — it puts the secret on
the argument list and `init --api-key` *persists* it to disk in **both**
`~/.flutterflow/credentials.json` and the workspace `.env`, so it is not one-time.
Ensure any workspace `.env` is gitignored and never committed.

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

Author the app as Dart DSL, then apply it. `flutterflow ai run` validates
internally and only pushes if validation passes, so iterate directly on `run` — a
failing `run` is identical to a failing `validate` (same errors, no remote
mutation, no half-pushed state). The first `run` on `dsl/create.dart` creates the
project; pass `--project-name` and a `--commit-message`:

```bash
flutterflow ai run dsl/create.dart --project-name "<name>" --commit-message "<what the app does>"
```

Add `--find-or-create` **only** as a retry/recovery option — when a previous
create run may already have created the remote project but the local workspace is
not bound yet. It matches an existing project by name, so using it as the default
create path can bind to and overwrite the wrong same-named project.

Once the project exists, **always report it back with a clickable link** so the
user can open it in one click — format the FlutterFlow project URL as Markdown:
`[<project-name>](https://app.flutterflow.io/project/<project-id>)`. Do this on
every create and push, not only when asked.

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

Either way: `run` validates internally before pushing, so iterate directly on
`run` (reserve `validate` for offline/CI pre-flight — see below), and never `init`
into a populated non-workspace directory.

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
if [ -f "$HOME/.config/flutterflow/codex-env.sh" ]; then
  . "$HOME/.config/flutterflow/codex-env.sh"
fi
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

5. Author changes as Dart DSL files, then apply them. `run` validates internally
   and only pushes on success, so iterate directly on `run`:

```bash
flutterflow ai run <file.dart>
```

   Use `flutterflow ai validate <file.dart>` only when you want validation output
   *without* a push — CI pre-flight or an offline preview. It runs the same
   pipeline as `run` minus the push, so it is not part of the normal edit loop.

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
- `run` validates internally before pushing; reserve `validate` for offline/CI
  pre-flight, not the normal edit loop.
- Report exact command failures with stderr/stdout summaries, but redact secrets.
- Whenever you create, push to, or report on a project, give the user a
  **clickable** link to open it — format the FlutterFlow project URL as Markdown:
  `[<project-name>](https://app.flutterflow.io/project/<project-id>)`. Never
  surface a bare project id without the link.
