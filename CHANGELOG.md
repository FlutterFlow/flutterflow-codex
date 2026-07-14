# Changelog

All notable changes to the FlutterFlow Codex plugin are documented here.

The base version follows [semantic versioning](https://semver.org). The
`+codex.<timestamp>` build-metadata suffix in `plugin.json` is a Codex cachebuster
(bumped by `update_plugin_cachebuster.py`) and is not part of the semantic version.

## [Unreleased]

### Fixed

- `flutterflow-cli.sh`: `set -e` no longer aborts the wrapper on the intended
  fall-through path, so setting `FLUTTERFLOW_CLI_DIR` without a usable Dart
  toolchain correctly falls back to the globally installed `flutterflow` binary
  (and prints the intended diagnostics on total failure).
- `flutterflow-cli.sh`: removed the post-execution exit-254 retry. Every CLI
  command now runs exactly once, so an application or network failure cannot
  silently repeat a state-mutating operation.
- `flutterflow-mcp.sh` and `mcp.example.json`: launch the workspace's vendored
  MCP server directly with Dart, preventing pub/shim output from corrupting
  JSON-RPC stdout.
- Auth guidance now distinguishes machine-level onboarding credentials from the
  initialized workspace's private `.flutterflow/.env`.
- `SKILL.md`: documents the real `run` failure boundary—validation failures do
  not push, while later create, conflict, network, push, and post-push failures
  can have remote side effects.
- Credential guidance (`SKILL.md`, `README.md`): note that an inline
  `FF_API_KEY=<key> ...` prefix still lands in shell history and the process
  environment, and that `--api-key` persists the key to both
  `~/.flutterflow/credentials.json` and `.flutterflow/.env`.
- `plugin.json`: corrected the license identifier to the SPDX id `BUSL-1.1`.
- `README.md`: documented GitHub marketplace installation as the primary path,
  with local `marketplace add .` reserved for repo-root development installs.
- `README.md`: documented the `python3` requirement, clarified that the validation
  scripts are Codex-provided, and used absolute helper paths that work from any
  directory.

### Added

- CLI 0.0.38 onboarding guidance: bare `flutterflow ai` for the interactive
  project picker, and `init ... --yes` for deterministic agent automation.
- Version-matched workflow guidance: read generated `AGENTS.md`, inspect the
  typed project SDK, use generated Flutter code as read-only runtime truth,
  confirm branch state, and run `flutterflow ai test` before pushes.
- Codex attribution for direct CLI calls via `FF_AI_AGENT_CLIENT`, while
  preserving explicit caller overrides.
- Exact-once CLI and direct MCP-launch regression tests.
- `store-key-from-clipboard.sh`: secure one-shot FlutterFlow API-key hand-off
  from the OS clipboard to `~/.config/flutterflow/codex-env.sh`, with validation,
  symlink protections, live clipboard clearing, and leak-freedom tests.
- `SKILL.md` and `README.md`: documented the no-chat clipboard flow, fixed retry
  wording, unavailable fallback, and hard rules against bare clipboard reads.
- `.github/workflows/ci.yml`: shellcheck, POSIX syntax checks, all helper-script
  tests, and JSON validation.
- `.gitignore` entries for `.env`, `.env.*`, and `credentials.json`.
- This changelog.

## [0.1.0]

- Initial release: FlutterFlow CLI skill, helper scripts that resolve a global or
  source-checkout `flutterflow`, and an optional workspace-bound MCP example.
