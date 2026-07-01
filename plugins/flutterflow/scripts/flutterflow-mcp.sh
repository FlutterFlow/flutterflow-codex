#!/bin/sh
set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

workspace="${FLUTTERFLOW_AI_WORKSPACE:-${CODEX_WORKSPACE_ROOT:-$PWD}}"
case "$workspace" in
  /*) ;;
  *)
    if ! workspace="$(CDPATH='' cd -- "$workspace" 2>/dev/null && pwd)"; then
      echo "FlutterFlow workspace path not found: ${FLUTTERFLOW_AI_WORKSPACE:-${CODEX_WORKSPACE_ROOT:-$PWD}}" >&2
      echo "Set FLUTTERFLOW_AI_WORKSPACE to an absolute workspace path, or run Codex from a workspace created with:" >&2
      echo "  flutterflow ai init <workspace>" >&2
      exit 1
    fi
    ;;
esac

if [ ! -f "$workspace/.flutterflow/config.yaml" ]; then
  echo "FlutterFlow MCP requires an initialized FlutterFlow AI workspace." >&2
  echo "Set FLUTTERFLOW_AI_WORKSPACE to an absolute workspace path, or run Codex from a workspace created with:" >&2
  echo "  flutterflow ai init <workspace>" >&2
  exit 1
fi

# Invoke via `sh` so a distribution that dropped the executable bit on the helper
# still works (exec of a non-executable path fails with a bare "Permission denied").
exec sh "$script_dir/flutterflow-cli.sh" ai mcp --workspace "$workspace"
