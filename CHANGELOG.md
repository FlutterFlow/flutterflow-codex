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
- `flutterflow-cli.sh`: the exit-254 retry now fires only when the package config
  pre-existed (a genuine stale-config case), so a command — including a
  state-mutating one — is never silently re-run after an application-level error.
- `flutterflow-mcp.sh`: the helper is now invoked via `sh`, so a distribution that
  dropped the executable bit no longer fails with an opaque "Permission denied".
- `SKILL.md`: aligned the create/edit flow with the FlutterFlow CLI's own
  guidance — iterate on `run` (which validates internally and only pushes on
  success) instead of always running `validate` first, and use the documented
  `--project-name`/`--commit-message` create form with `--find-or-create` reserved
  for recovery.
- Credential guidance (`SKILL.md`, `README.md`): note that an inline
  `FF_API_KEY=<key> ...` prefix still lands in shell history and the process
  environment, and that `--api-key` persists the key to both
  `~/.flutterflow/credentials.json` and the workspace `.env`.
- `mcp.example.json`: use an absolute command path and an explicit
  `FLUTTERFLOW_AI_WORKSPACE` instead of a relative command/cwd that resolved
  against the host's working directory.
- `plugin.json`: corrected the license identifier to the SPDX id `BUSL-1.1`.
- `README.md`: documented the `python3` requirement, clarified that the validation
  scripts are Codex-provided, and used absolute helper paths that work from any
  directory.

### Added

- `store-key-from-clipboard.sh`: secure one-shot FlutterFlow API-key hand-off
  from the OS clipboard to `~/.config/flutterflow/codex-env.sh`, with validation,
  symlink protections, live clipboard clearing, and leak-freedom tests.
- `SKILL.md` and `README.md`: documented the no-chat clipboard flow, fixed retry
  wording, unavailable fallback, and hard rules against bare clipboard reads.
- `.github/workflows/ci.yml`: shellcheck, POSIX syntax check, clipboard hand-off
  tests, and JSON validation.
- `.gitignore` entries for `.env`, `.env.*`, and `credentials.json`.
- This changelog.

## [0.1.0]

- Initial release: FlutterFlow CLI skill, helper scripts that resolve a global or
  source-checkout `flutterflow`, and an optional workspace-bound MCP example.
