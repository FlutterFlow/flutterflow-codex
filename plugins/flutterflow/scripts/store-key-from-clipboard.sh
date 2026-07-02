#!/usr/bin/env bash
# store-key-from-clipboard.sh - one-shot secure hand-off of the FlutterFlow API
# key from the OS clipboard to ~/.config/flutterflow/codex-env.sh.
#
# Invoked verbatim by the FlutterFlow skill. Agents must never compose clipboard
# reads inline: a bare clipboard command can put its stdout into retained model
# context. Inside this script the key never enters argv, a shell variable, a
# command substitution, or stdout/stderr. It moves clipboard -> 0600 tmpfile ->
# validated -> env file by redirection only, and the clipboard is read exactly
# once.
#
# Output is exactly one status line, plus a fixed caveat on success:
#   key: STORED (clipboard cleared)
#   key: INVALID — <content-free class>
#   clipboard: UNAVAILABLE — <fixed reason>
#
# FF_CLIPBOARD_FILE: test-only override. Read from this user-owned regular file
# instead of the clipboard.
{ set +x; } 2>/dev/null
umask 077
set -o pipefail

ok() {
  printf 'key: STORED (clipboard cleared)\n'
  printf 'note: clipboard-history managers (Raycast, Alfred, Maccy, Windows Win+V, Apple Universal Clipboard) may retain a copy the script cannot clear.\n'
}

fail_invalid() {
  printf 'key: INVALID — %s\n' "$1" >&2
  exit 1
}

fail_unavail() {
  printf 'clipboard: UNAVAILABLE — %s\n' "$1" >&2
  exit 1
}

[ -n "${HOME:-}" ] || fail_unavail "HOME is not set"

# Choose the clipboard source. Absolute paths are used where the OS guarantees
# them. X11 uses the CLIPBOARD selection explicitly and has timeouts because
# xclip/xsel can hang without a server.
MODE=""
if [ -n "${FF_CLIPBOARD_FILE:-}" ]; then
  { [ -f "$FF_CLIPBOARD_FILE" ] && [ ! -L "$FF_CLIPBOARD_FILE" ] && [ -O "$FF_CLIPBOARD_FILE" ]; } \
    || fail_unavail "test override is not a user-owned regular file"
  MODE="testfile"
elif [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]; then
  fail_unavail "remote (SSH) session — run the terminal one-liner instead"
else
  case "$(uname -s 2>/dev/null)" in
    Darwin)
      [ -x /usr/bin/pbpaste ] && MODE="pbpaste"
      ;;
    Linux)
      if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
        MODE="wlpaste"
      elif [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
        MODE="xclip"
      elif [ -n "${DISPLAY:-}" ] && command -v xsel >/dev/null 2>&1; then
        MODE="xsel"
      elif grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
        MODE="wsl"
      fi
      ;;
  esac
fi
[ -n "$MODE" ] || fail_unavail "no local clipboard tool found — run the terminal one-liner instead"

read_clipboard() {
  case "$MODE" in
    testfile) cat "$FF_CLIPBOARD_FILE" ;;
    pbpaste) /usr/bin/pbpaste ;;
    wlpaste) wl-paste --no-newline ;;
    xclip) timeout 5 xclip -selection clipboard -o ;;
    xsel) timeout 5 xsel --clipboard --output ;;
    wsl) powershell.exe -NoProfile -Command Get-Clipboard ;;
  esac
}

clear_clipboard() {
  case "$MODE" in
    testfile)
      :
      ;;
    pbpaste)
      /usr/bin/pbcopy </dev/null 2>/dev/null
      ;;
    wlpaste)
      wl-copy --clear 2>/dev/null
      ;;
    xclip)
      printf '' | timeout 5 xclip -selection clipboard 2>/dev/null
      printf '' | timeout 5 xclip -selection primary 2>/dev/null
      ;;
    xsel)
      timeout 5 xsel --clipboard --clear 2>/dev/null
      timeout 5 xsel --primary --clear 2>/dev/null
      ;;
    wsl)
      printf '' | clip.exe 2>/dev/null
      ;;
  esac
  return 0
}

ENV_DIR="$HOME/.config/flutterflow"
ENV_FILE="$ENV_DIR/codex-env.sh"

[ -L "$ENV_DIR" ] && fail_unavail "refusing: $ENV_DIR is a symlink"
if [ -e "$ENV_DIR" ] && [ ! -d "$ENV_DIR" ]; then
  fail_unavail "refusing: $ENV_DIR is not a directory"
fi
mkdir -p "$ENV_DIR" 2>/dev/null || fail_unavail "cannot create $ENV_DIR"
[ -L "$ENV_DIR" ] && fail_unavail "refusing: $ENV_DIR is a symlink"
chmod 700 "$ENV_DIR" 2>/dev/null || fail_unavail "cannot secure $ENV_DIR"

TMP="$(mktemp "$ENV_DIR/.clip.XXXXXX" 2>/dev/null)" || fail_unavail "cannot create a temp file"
trap 'rm -f "$TMP" "$TMP.key" "$TMP.env"' EXIT

# Single read, then validate the file. The key itself is never captured in a
# variable or command substitution.
read_clipboard >"$TMP" 2>/dev/null || fail_unavail "clipboard read failed"

NONEMPTY="$(grep -c . "$TMP" 2>/dev/null || true)"
[ "${NONEMPTY:-0}" -eq 0 ] && fail_invalid "clipboard was empty"
[ "$NONEMPTY" -gt 1 ] && fail_invalid "clipboard held multiple lines"

# Normalize the single non-empty line by removing CR and surrounding whitespace.
# The normalized key file intentionally has no trailing newline, so it can be
# concatenated after an export assignment.
{
  grep -m1 . "$TMP" | tr -d '\r' \
    | awk '{gsub(/^[ \t]+|[ \t]+$/, ""); printf "%s", $0}'
} >"$TMP.key" 2>/dev/null || fail_invalid "contents don't match the API key format (expected a UUID)"

grep -q . "$TMP.key" || fail_invalid "clipboard was empty"

# Strict allowlist before writing: the env file is later dot-sourced, so this is
# the injection gate. FlutterFlow API keys are UUIDs.
grep -qE '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' "$TMP.key" \
  || fail_invalid "contents don't match the API key format (expected a UUID)"

# First line is deliberately not the managed-file marker a future session-start
# hook might auto-delete.
{
  printf '# flutterflow-codex: user-provided key (clipboard hand-off)\n'
  printf 'export FF_API_KEY='
  cat "$TMP.key"
  printf '\nexport FLUTTERFLOW_API_TOKEN='
  cat "$TMP.key"
  printf '\n'
} >"$TMP.env" 2>/dev/null || fail_unavail "cannot assemble $ENV_FILE"

# Never write through a pre-planted symlink or non-regular file.
if [ -L "$ENV_FILE" ] || { [ -e "$ENV_FILE" ] && [ ! -f "$ENV_FILE" ]; }; then
  rm -f "$ENV_FILE" 2>/dev/null || fail_unavail "cannot replace existing $ENV_FILE"
fi
chmod 600 "$TMP.env" 2>/dev/null || fail_unavail "cannot secure $ENV_FILE"
mv -f "$TMP.env" "$ENV_FILE" 2>/dev/null || fail_unavail "cannot write $ENV_FILE"

clear_clipboard
ok
exit 0
