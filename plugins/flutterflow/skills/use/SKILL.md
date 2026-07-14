---
name: use
description: Use when working with FlutterFlow AI workspaces or the FlutterFlow CLI from Codex. Covers onboarding, auth, version-matched workspace guidance, typed project context, branch-safe editing, validation, push, diagnostics, export-code, and workspace-bound MCP.
---

# FlutterFlow CLI

Use this skill for tasks that mention FlutterFlow, FlutterFlow AI, `flutterflow ai`,
FlutterFlow CLI, or FlutterFlow project edits.

## Preconditions — read before running anything

This plugin uses the FlutterFlow CLI to initialize, authenticate, upgrade, and
repair workspaces, so a working shell and `flutterflow` command are hard
requirements. An initialized workspace can also auto-register its project-scoped
MCP server and pair with FlutterFlow Desktop. Follow the workspace's generated
`AGENTS.md` once it exists; it is version-matched to that workspace's SDK.

If the shell, command runner, or file-read tooling is unavailable — e.g. a command
fails to launch with `Failed to create unified exec process: No such file or
directory` (which usually means the task's working directory no longer exists, not
a permission denial) — **STOP**. Tell the user the plugin needs a working shell and
ask them to reopen the task in a folder that exists (verify with `pwd`), then end
the turn. Do **not** retry unrelated shells, apps, or browsers as a substitute for
the missing bootstrap path.

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
`FLUTTERFLOW_CLI_DIR=/path/to/packages/flutterflow_cli`. It invokes the CLI
exactly once and defaults `FF_AI_AGENT_CLIENT` to `codex` while preserving an
explicit caller override.

For direct commands that do not use the helper, set the same attribution once:

```bash
export FF_AI_AGENT_CLIENT="${FF_AI_AGENT_CLIENT:-codex}"
```

### Docs and reference specs

After initialization, read the workspace's `AGENTS.md` completely before making
changes, plus any more specific nested `AGENTS.md` that applies. Use
`flutterflow ai docs [topic]` for version-matched detail. These generated sources
are authoritative for the current workspace's SDK surface and edit lanes. The
bootstrap, secret-handling, exact-once execution, and remote-side-effect safety
boundaries in this plugin still apply if older generated prose overstates a
guarantee.

Before initialization, `flutterflow ai docs` is unavailable. Do not grep a global
`.pub-cache` for DSL APIs or path-pin a project to cached packages; initialize the
workspace first so its vendored SDK and guidance are internally consistent.

## Authentication

- Onboarding (`flutterflow ai` or `flutterflow ai init`) can use an exported
  `FF_API_KEY`, the plugin's sourced config, or the per-machine credential store
  at `~/.flutterflow/credentials.json`.
- Ordinary commands inside an initialized workspace use the process environment,
  workspace `.env`, and `.flutterflow/.env`. The latter is the generated private
  store; the per-machine credential store is not a substitute for workspace auth
  after initialization.
- `export-code` and `deploy-firebase` use `FLUTTERFLOW_API_TOKEN`.
- This plugin can store a copied FlutterFlow API key without the key entering
  model context. The bundled script writes `~/.config/flutterflow/codex-env.sh`
  with mode `0600`; source it only inside the same shell invocation as commands
  that need auth.
- Both `~/.flutterflow/credentials.json` and `.flutterflow/.env` hold secrets in
  plaintext. Never `cat`, copy, echo, grep, or commit either file; the preflight
  below only tests for presence.
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

Before non-interactive FlutterFlow AI commands that may need auth, identify the
applicable credential source without exposing secret values:

```bash
if [ -f "$HOME/.config/flutterflow/codex-env.sh" ]; then
  . "$HOME/.config/flutterflow/codex-env.sh"
fi

workspace_root="$PWD"
while [ "$workspace_root" != "/" ] && [ ! -f "$workspace_root/.flutterflow/config.yaml" ]; do
  workspace_root="$(dirname "$workspace_root")"
done
if [ ! -f "$workspace_root/.flutterflow/config.yaml" ]; then
  workspace_root=""
fi

if [ -n "${FF_API_KEY:-}" ]; then
  echo "ff_auth: env"
elif [ -n "$workspace_root" ] && [ -f "$workspace_root/.flutterflow/.env" ]; then
  echo "ff_auth: workspace-store-present"
elif [ -n "$workspace_root" ] && [ -f "$workspace_root/.env" ]; then
  echo "ff_auth: workspace-env-file-present"
elif [ -f "$HOME/.flutterflow/credentials.json" ]; then
  echo "ff_auth: init-store-present"
else
  echo "ff_auth: missing"
fi
```

Run that source step in the same shell invocation as FlutterFlow commands that
need auth; do not inspect or print any secret file. Presence does not prove a key
is valid—the CLI remains authoritative. `init-store-present` is sufficient for
the router's onboarding/init flow, but ordinary workspace commands require
`env`, `workspace-store-present`, or an intentionally configured
`workspace-env-file-present`. If the required source is missing, do not keep
retrying or paste a key into chat. Stop and follow the hand-off below.

### When auth is missing — stop and hand off

When the required auth source is missing and the task needs to initialize,
create, run, or push, treat it as a hard stop. Do not author DSL or do build work
that cannot be verified against a real workspace.

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
`~/.flutterflow/credentials.json` and `.flutterflow/.env`, so it is not one-time.
Ensure workspace env files are gitignored and never committed.

If a saved credential exists but the server rejects it, tell the user to refresh
the key from FlutterFlow account settings and run `flutterflow ai logout` only if
they want to inspect or clear saved base URLs.

## Workspace Rules

- FlutterFlow AI commands run inside an initialized workspace containing
  `.flutterflow/config.yaml`.
- For human onboarding in an interactive terminal, bare `flutterflow ai` launches
  the searchable project picker and includes a create-new option.
- For deterministic agent automation, initialize a new workspace with:

```bash
flutterflow ai init <workspace-name-or-path> --yes
```

- Bind directly to a known project with:

```bash
flutterflow ai init <workspace-name-or-path> --project <project-id> --yes
```

- Do not run `flutterflow ai init` into a populated non-workspace directory.
- After init, `cd` to the workspace root and read `AGENTS.md` completely.
- If a workspace already exists, do not reinitialize it. Run
  `flutterflow ai upgrade --check`, then follow its `AGENTS.md`.
- `flutterflow ai refresh-workspace` is not routine context refresh. It overwrites
  the managed `CLAUDE.md`, `AGENTS.md`, `README.md`, `references/`, and
  `patterns/` after confirmation and backs them up under
  `.flutterflow/backups/refresh-workspace/<timestamp>/`. Use it deliberately,
  review the targets, and inspect the resulting changes.

## Create A New App vs Edit An Existing Project

Decide which path the user wants before running anything.

### Create a new app

Use this when there is no FlutterFlow project yet. Omit `--project` so the CLI
uses the create-new flow, then `cd` into the scaffold:

```bash
flutterflow ai init <workspace-name-or-path> --yes
cd <workspace-name-or-path>
```

Read `AGENTS.md`, author the app using its current SDK workflow, run
`flutterflow ai test`, then apply it. The first `run` on `dsl/create.dart`
creates the project; pass `--project-name` and `--commit-message`:

```bash
flutterflow ai run dsl/create.dart --project-name "<name>" --commit-message "<what the app does>"
```

Add `--find-or-create` **only** as a retry/recovery option — when a previous
create run may already have created the remote project but the local workspace is
not bound yet. It matches an existing project by name, so using it as the default
create path can bind to and overwrite the wrong same-named project.

`run` performs a validation gate before remote creation or push, so a
validation-phase failure has no remote mutation. Do not generalize that guarantee
to every failure: create, conflict, network, push, and post-push failures occur
later and can have remote side effects. A failed create can leave an unbound
remote project; recover with `--find-or-create` only when that is the project you
intend to reuse.

Once the project exists, **always report it back with a clickable link** so the
user can open it in one click — format the FlutterFlow project URL as Markdown:
`[<project-name>](https://app.flutterflow.io/project/<project-id>)`. Do this on
every create and push, not only when asked.

Do not hand-author a standalone Dart package or path-pin `pubspec.yaml` to a
global cache. `init` scaffolds the versioned workspace and vendored SDK. Also
note `create.dart` is one-shot; after the first successful run, make further
changes through the edit workflow described by `AGENTS.md`.

### Edit an existing project

Use this when the user already has a FlutterFlow project.

1. For deterministic agent setup, get the project id from the FlutterFlow URL
   (`app.flutterflow.io/project/<project-id>`). There is no separate
   non-interactive project-list command. If the user does not know the id, offer
   the interactive bare `flutterflow ai` picker rather than claiming projects
   cannot be listed.
2. Bind a workspace to that project, then `cd` in:

```bash
flutterflow ai init <workspace-name-or-path> --project <project-id> --yes
cd <workspace-name-or-path>
```

   If a workspace for this project already exists, `cd` into it; do not
   reinitialize or routinely refresh managed guidance.
3. Read `AGENTS.md`, orient, test, and apply edits using the standard workflow.

Never `init` into a populated non-workspace directory.

## MCP Usage

The plugin itself does not globally register an MCP server because each server
is bound to one workspace. Current `init` and deliberate `refresh-workspace`
flows auto-register the vendored project server with supported agents, including
project-scoped Codex configuration at `.codex/config.toml`. A newly written
Codex config may require a new task opened from the workspace before its MCP
tools appear.

If FlutterFlow MCP tools are already available, verify they point at the intended
workspace and use them as directed by that workspace's `AGENTS.md`—including any
fast-patch lane. Otherwise continue through the CLI; do not block on MCP.

The manual `mcp.example.json` launches the vendored server directly. Do not route
stdio MCP through `flutterflow ai mcp` or a pub/global shim: dependency status
text on stdout can corrupt JSON-RPC framing.

The optional server launcher resolves the workspace from:

1. `FLUTTERFLOW_AI_WORKSPACE`
2. `CODEX_WORKSPACE_ROOT`
3. the process working directory

To start the MCP server manually:

```bash
FLUTTERFLOW_AI_WORKSPACE=/absolute/path/to/workspace \
  /absolute/path/to/plugins/flutterflow/scripts/flutterflow-mcp.sh
```

## Standard Agent Workflow

1. Run the auth preflight above. If the applicable source is missing and the
   task needs init/create/run/push, stop and follow the secure hand-off.

2. Identify the workspace, set direct-CLI attribution, check for an upgrade, and
   read the generated agent contract before editing:

```bash
if [ -f "$HOME/.config/flutterflow/codex-env.sh" ]; then
  . "$HOME/.config/flutterflow/codex-env.sh"
fi
export FF_AI_AGENT_CLIENT="${FF_AI_AGENT_CLIENT:-codex}"
pwd
test -f .flutterflow/config.yaml
flutterflow ai upgrade --check
```

Read `AGENTS.md` completely, plus any nested instructions for files in scope.

3. Confirm the active branch before any mutation. The active branch's
   `project_id` in `.flutterflow/config.yaml` is what every push writes to; do
   not blindly substitute the trunk project id:

```bash
flutterflow ai branch current
flutterflow ai branch status
```

For checkout/merge/close details, use `flutterflow ai docs branches` and the
workspace contract.

4. Orient before editing. Prefer the generated typed SDK at
   `lib/flutterflow_project.dart` and its per-entity files. Use
   `generated_code/.flutterflow/export_manifest.json` to find runtime files when
   diagnosing layout, rendering, or build behavior; treat `generated_code/` as
   read-only. CLI summaries remain useful when needed:

```bash
flutterflow ai status <project-id>
flutterflow ai inspect <project-id>
flutterflow ai resources <project-id>
flutterflow ai search <project-id> --query "<feature-or-screen>"
```

5. Capture intent when useful:

```bash
flutterflow ai plan save --content "<short implementation plan>"
```

6. Author changes using the workspace's current `AGENTS.md`. Use typed handles
   from `lib/flutterflow_project.dart` for edit flows, not raw names. If the
   workspace contract identifies an MCP fast-patch and the connected tool fits
   the change, use it; otherwise use the CLI/DSL path.

7. Run the workspace test gate before applying changes:

```bash
flutterflow ai test
```

Use `flutterflow ai validate <file.dart>` when an offline/CI validation-only
result is specifically useful.

8. Apply the change with an explicit commit message:

```bash
flutterflow ai run <file.dart> --commit-message "<what changed and why>"
```

Remember the failure boundary described above: validation-phase failures do not
push; later create/conflict/network/push/post-push failures are distinct and can
have remote side effects.

9. Verify and inspect the result:

```bash
flutterflow ai history --limit 5
flutterflow ai trace latest
flutterflow ai context-check
```

10. Refresh project context after meaningful remote changes made outside this
    workspace, and use diagnostics when needed:

```bash
flutterflow ai refresh-context <project-id>
flutterflow ai doctor --json
```

Use `refresh-workspace` only for an intentional managed-guidance refresh after
reviewing its overwrite targets and backups; it is not a context-refresh step.

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
- Treat only validation-phase `run` failures as guaranteed no-push failures;
  inspect later failures for remote side effects before retrying.
- Use `validate` for a requested offline/CI validation-only result; use
  `flutterflow ai test` as the normal pre-push workspace gate.
- Report exact command failures with stderr/stdout summaries, but redact secrets.
- Whenever you create, push to, or report on a project, give the user a
  **clickable** link to open it — format the FlutterFlow project URL as Markdown:
  `[<project-name>](https://app.flutterflow.io/project/<project-id>)`. Never
  surface a bare project id without the link.
