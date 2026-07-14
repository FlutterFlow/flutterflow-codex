#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/flutterflow-cli.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_line_count() {
  local expected="$1"
  local pattern="$2"
  local file="$3"
  local actual
  actual="$(grep -c "$pattern" "$file" || true)"
  [[ "$actual" == "$expected" ]] || fail "expected $expected '$pattern' lines in $file, got $actual"
}

make_fixture() {
  local name="$1"
  local cli_dir="$TMP/$name/cli"
  local bin_dir="$TMP/$name/bin"
  mkdir -p "$cli_dir/bin" "$bin_dir"
  : > "$cli_dir/bin/flutterflow_cli.dart"

  cat > "$bin_dir/dart" <<'DART'
#!/bin/sh
set -eu
printf '%s\n' "client=${FF_AI_AGENT_CLIENT:-}" >> "$DART_LOG"
case "${1:-}" in
  pub)
    printf '%s\n' "pub-get" >> "$DART_LOG"
    mkdir -p .dart_tool
    : > .dart_tool/package_config.json
    exit 0
    ;;
  *)
    printf '%s\n' "cli-invoke" >> "$DART_LOG"
    exit 254
    ;;
esac
DART
  chmod +x "$bin_dir/dart"
}

echo "1..3"

make_fixture existing
mkdir -p "$TMP/existing/cli/.dart_tool"
: > "$TMP/existing/cli/.dart_tool/package_config.json"
: > "$TMP/existing/dart.log"
set +e
PATH="$TMP/existing/bin:/usr/bin:/bin" \
  DART_LOG="$TMP/existing/dart.log" \
  FLUTTERFLOW_CLI_DIR="$TMP/existing/cli" \
  sh "$SCRIPT" ai run dsl/edit.dart >/dev/null 2>&1
status=$?
set -e
[[ "$status" == 254 ]] || fail "expected exit 254, got $status"
assert_line_count 1 '^cli-invoke$' "$TMP/existing/dart.log"
assert_line_count 0 '^pub-get$' "$TMP/existing/dart.log"
echo "ok 1 - exit 254 is propagated without retry"

make_fixture missing
: > "$TMP/missing/dart.log"
set +e
PATH="$TMP/missing/bin:/usr/bin:/bin" \
  DART_LOG="$TMP/missing/dart.log" \
  FLUTTERFLOW_CLI_DIR="$TMP/missing/cli" \
  sh "$SCRIPT" ai run dsl/edit.dart >/dev/null 2>&1
status=$?
set -e
[[ "$status" == 254 ]] || fail "expected exit 254 after dependency resolution, got $status"
assert_line_count 1 '^pub-get$' "$TMP/missing/dart.log"
assert_line_count 1 '^cli-invoke$' "$TMP/missing/dart.log"
echo "ok 2 - dependencies resolve before one CLI invocation"

# The existing fixture has one Dart call; the missing fixture has pub-get plus
# the CLI call. Every call should inherit the default Codex attribution.
assert_line_count 1 '^client=codex$' "$TMP/existing/dart.log"
assert_line_count 2 '^client=codex$' "$TMP/missing/dart.log"
echo "ok 3 - helper defaults attribution to Codex"
