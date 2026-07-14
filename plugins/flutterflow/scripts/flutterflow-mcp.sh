#!/bin/sh
set -eu

workspace="${FLUTTERFLOW_AI_WORKSPACE:-${CODEX_WORKSPACE_ROOT:-$PWD}}"
if ! workspace="$(CDPATH='' cd -- "$workspace" 2>/dev/null && pwd)"; then
  echo "FlutterFlow workspace path not found: ${FLUTTERFLOW_AI_WORKSPACE:-${CODEX_WORKSPACE_ROOT:-$PWD}}" >&2
  echo "Set FLUTTERFLOW_AI_WORKSPACE to a workspace path, or initialize one with:" >&2
  echo "  flutterflow ai init <workspace> --yes" >&2
  exit 1
fi

if [ ! -f "$workspace/.flutterflow/config.yaml" ]; then
  echo "FlutterFlow MCP requires an initialized FlutterFlow AI workspace." >&2
  echo "Set FLUTTERFLOW_AI_WORKSPACE to a workspace path, or initialize one with:" >&2
  echo "  flutterflow ai init <workspace> --yes" >&2
  exit 1
fi

server="$workspace/.flutterflow/sdk/flutterflow_ai/mcp/server.dart"
if [ ! -f "$server" ]; then
  echo "FlutterFlow MCP server not found in the workspace SDK: $server" >&2
  echo "Run 'flutterflow ai upgrade' from the workspace, then try again." >&2
  exit 1
fi

if ! command -v dart >/dev/null 2>&1; then
  echo "FlutterFlow MCP requires Dart on PATH." >&2
  exit 127
fi

# Match the launcher written by upstream workspace registration. Calling the
# vendored server directly avoids pub/shim status text on stdout, where an MCP
# client expects only JSON-RPC frames.
exec dart run "$server" --dir "$workspace"
