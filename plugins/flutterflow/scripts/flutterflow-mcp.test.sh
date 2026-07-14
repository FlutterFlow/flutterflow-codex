#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/flutterflow-mcp.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

workspace="$TMP/workspace"
server="$workspace/.flutterflow/sdk/flutterflow_ai/mcp/server.dart"
mkdir -p "$(dirname "$server")" "$TMP/bin"
: > "$workspace/.flutterflow/config.yaml"
: > "$server"

cat > "$TMP/bin/dart" <<'DART'
#!/bin/sh
set -eu
printf '%s\n' "$@" > "$DART_LOG"
DART
chmod +x "$TMP/bin/dart"

echo "1..2"

PATH="$TMP/bin:/usr/bin:/bin" \
  DART_LOG="$TMP/dart.log" \
  FLUTTERFLOW_AI_WORKSPACE="$workspace" \
  sh "$SCRIPT"

line_count="$(wc -l < "$TMP/dart.log" | tr -d ' ')"
arg1="$(sed -n '1p' "$TMP/dart.log")"
arg2="$(sed -n '2p' "$TMP/dart.log")"
arg3="$(sed -n '3p' "$TMP/dart.log")"
arg4="$(sed -n '4p' "$TMP/dart.log")"
[[ "$line_count" == 4 ]] || fail "expected 4 Dart arguments, got $line_count"
[[ "$arg1" == run ]] || fail "expected 'run', got '$arg1'"
[[ "$arg2" == "$server" ]] || fail "unexpected server path: '$arg2'"
[[ "$arg3" == --dir ]] || fail "expected '--dir', got '$arg3'"
[[ "$arg4" == "$workspace" ]] || fail "unexpected workspace path: '$arg4'"
echo "ok 1 - launches the vendored MCP server directly"

rm "$server"
rm -f "$TMP/dart.log"
set +e
PATH="$TMP/bin:/usr/bin:/bin" \
  DART_LOG="$TMP/dart.log" \
  FLUTTERFLOW_AI_WORKSPACE="$workspace" \
  sh "$SCRIPT" >/dev/null 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || fail "expected missing-server exit 1, got $status"
[[ ! -e "$TMP/dart.log" ]] || fail "Dart should not run when the server is missing"
echo "ok 2 - fails before Dart when the vendored server is missing"
