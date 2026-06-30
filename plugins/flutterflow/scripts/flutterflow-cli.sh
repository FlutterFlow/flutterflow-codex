#!/bin/sh
set -eu

# Resolve the FlutterFlow CLI without changing the caller's working directory.
# `flutterflow ai` discovers `.flutterflow/config.yaml` from the current
# workspace for commands such as validate, run, and upgrade, so this wrapper
# never cd's the caller.

# Attempt to run the CLI from a source checkout. On success it exits with the
# CLI's status. It only RETURNS (nonzero) when the checkout can't be used
# (Dart missing, or dependency resolution failed), so callers can fall back.
run_source_cli() {
  cli_dir="$1"
  shift

  command -v dart >/dev/null 2>&1 || return 1

  package_config="$cli_dir/.dart_tool/package_config.json"
  if [ ! -f "$package_config" ]; then
    echo "Resolving FlutterFlow CLI dependencies in $cli_dir..." >&2
    if ! (cd "$cli_dir" && dart pub get >/dev/null); then
      echo "Failed to run dart pub get in $cli_dir." >&2
      return 1
    fi
  fi

  if dart --packages="$package_config" "$cli_dir/bin/flutterflow_cli.dart" "$@"; then
    exit 0
  else
    status=$?
  fi

  # Exit 254 = dart couldn't resolve packages, typically a stale package config
  # after a pubspec or branch change. Re-resolve and retry once. Any other
  # nonzero status is a genuine CLI error and is propagated unchanged (so a
  # command like `validate` that reports errors is never run twice).
  if [ "$status" -eq 254 ]; then
    echo "Re-resolving FlutterFlow CLI dependencies in $cli_dir (stale package config)..." >&2
    if (cd "$cli_dir" && dart pub get >/dev/null); then
      exec dart --packages="$package_config" "$cli_dir/bin/flutterflow_cli.dart" "$@"
    fi
  fi

  exit "$status"
}

# 1. Explicit source checkout via FLUTTERFLOW_CLI_DIR (for local CLI development).
if [ -n "${FLUTTERFLOW_CLI_DIR:-}" ]; then
  if [ ! -f "$FLUTTERFLOW_CLI_DIR/bin/flutterflow_cli.dart" ]; then
    echo "FLUTTERFLOW_CLI_DIR is set but does not point at a packages/flutterflow_cli checkout: $FLUTTERFLOW_CLI_DIR" >&2
    exit 127
  fi
  run_source_cli "$FLUTTERFLOW_CLI_DIR" "$@"
  # run_source_cli only returns here if the source checkout couldn't be used;
  # fall through to the installed binary.
  attempted_source="$FLUTTERFLOW_CLI_DIR"
fi

# 2. Installed global binary (the default for most users).
if command -v flutterflow >/dev/null 2>&1; then
  exec flutterflow "$@"
fi

# 3. Nothing worked — explain based on what we found.
if [ -n "${attempted_source:-}" ]; then
  echo "FlutterFlow CLI source found at $attempted_source, but Dart is unavailable" >&2
  echo "(or dependency resolution failed) and no global 'flutterflow' is on PATH." >&2
  echo "Install Flutter/Dart, or activate the CLI globally: dart pub global activate flutterflow_cli" >&2
else
  echo "Could not find the FlutterFlow CLI." >&2
  echo "Install it with: dart pub global activate flutterflow_cli" >&2
  echo "Or set FLUTTERFLOW_CLI_DIR to a packages/flutterflow_cli checkout." >&2
fi
exit 127
