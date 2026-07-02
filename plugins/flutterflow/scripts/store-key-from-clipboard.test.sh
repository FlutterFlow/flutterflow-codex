#!/usr/bin/env bash
# Security-property tests for store-key-from-clipboard.sh.
#
# Uses FF_CLIPBOARD_FILE so the real clipboard is never read or cleared.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/store-key-from-clipboard.sh"
HOOK="$HERE/../hooks/session-start.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fails=0

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1"
  fails=$((fails + 1))
}

mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

run_script() {
  HOME="$1" FF_CLIPBOARD_FILE="$2" bash "$SCRIPT" >"$3" 2>&1
}

KEY="f54aaaaa-1111-2222-3333-444455556666"
MANAGED_MARKER="# managed-by: flutterflow-codex plugin"

echo "== A: valid key -> stored, 600, sources correctly, never printed =="
H="$WORK/A"
mkdir -p "$H"
printf '%s\n' "$KEY" >"$WORK/a.clip"
run_script "$H" "$WORK/a.clip" "$WORK/a.out"
RC=$?
EF="$H/.config/flutterflow/codex-env.sh"
if [ "$RC" -eq 0 ]; then
  pass "exit 0 on valid key"
else
  fail "exit $RC on valid key"
fi
if [ -f "$EF" ] && [ "$(mode "$EF")" = "600" ]; then
  pass "env file written with mode 600"
else
  fail "env file missing or wrong mode"
fi
GOT="$(env -i bash -c ". '$EF'; printf '%s' \"\$FF_API_KEY\"")"
if [ "$GOT" = "$KEY" ]; then
  pass "FF_API_KEY sources to the exact key"
else
  fail "FF_API_KEY mismatch"
fi
GOT="$(env -i bash -c ". '$EF'; printf '%s' \"\$FLUTTERFLOW_API_TOKEN\"")"
if [ "$GOT" = "$KEY" ]; then
  pass "FLUTTERFLOW_API_TOKEN sources to the exact key"
else
  fail "FLUTTERFLOW_API_TOKEN mismatch"
fi
if grep -qF "$KEY" "$WORK/a.out"; then
  fail "KEY LEAKED into script output"
else
  pass "key absent from script output"
fi
if grep -q 'key: STORED (clipboard cleared)' "$WORK/a.out"; then
  pass "fixed STORED status printed"
else
  fail "STORED status missing"
fi

echo
echo "== B: header is not a managed-file marker; hook must not delete it =="
if [ "$(head -n 1 "$EF")" = "$MANAGED_MARKER" ]; then
  fail "header collides with the hook managed marker"
else
  pass "header distinct from the hook marker"
fi
if [ -f "$HOOK" ]; then
  mkdir -p "$WORK/bin"
  printf '#!/bin/sh\nexit 0\n' >"$WORK/bin/flutterflow"
  chmod +x "$WORK/bin/flutterflow"
  HOME="$H" PATH="$WORK/bin:$PATH" CODEX_PLUGIN_OPTION_API_TOKEN='' bash "$HOOK" 2>/dev/null
  if [ -f "$EF" ]; then
    pass "hook preserves the clipboard-stored file"
  else
    fail "hook deleted the clipboard-stored file"
  fi
else
  pass "no session-start hook present"
fi

echo
echo "== C: messy-but-valid clipboards are normalized =="
H="$WORK/C"
mkdir -p "$H"
printf '  %s\r\n\n' "$KEY" >"$WORK/c.clip"
if run_script "$H" "$WORK/c.clip" "$WORK/c.out"; then
  GOT="$(env -i bash -c ". '$H/.config/flutterflow/codex-env.sh'; printf '%s' \"\$FF_API_KEY\"")"
  if [ "$GOT" = "$KEY" ]; then
    pass "whitespace/CRLF trimmed to exact key"
  else
    fail "normalization mismatch"
  fi
else
  fail "normalization input rejected"
fi
if grep -qF "$KEY" "$WORK/c.out"; then
  fail "KEY LEAKED into normalization output"
else
  pass "normalized key absent from script output"
fi

echo
echo "== D: invalid clipboards -> rejected, content never echoed =="
H="$WORK/D"
mkdir -p "$H"
printf '' >"$WORK/d1.clip"
if run_script "$H" "$WORK/d1.clip" "$WORK/d1.out"; then
  fail "empty clipboard accepted"
else
  pass "empty clipboard rejected"
fi
if grep -q 'key: INVALID — clipboard was empty' "$WORK/d1.out"; then
  pass "empty rejection class printed"
else
  fail "empty rejection class missing"
fi

printf 'line one\nline two\n' >"$WORK/d2.clip"
if run_script "$H" "$WORK/d2.clip" "$WORK/d2.out"; then
  fail "multi-line clipboard accepted"
else
  pass "multi-line clipboard rejected"
fi
if grep -q 'key: INVALID — clipboard held multiple lines' "$WORK/d2.out"; then
  pass "multi-line rejection class printed"
else
  fail "multi-line rejection class missing"
fi

# shellcheck disable=SC2016
SECRET='hunter2 with spaces $(rm -rf ~) `boom`'
printf '%s\n' "$SECRET" >"$WORK/d3.clip"
if run_script "$H" "$WORK/d3.clip" "$WORK/d3.out"; then
  fail "shell-metachar content accepted"
else
  pass "non-key content rejected"
fi
if grep -q "key: INVALID — contents don't match the API key format" "$WORK/d3.out"; then
  pass "format rejection class printed"
else
  fail "format rejection class missing"
fi

printf 'ghp_abcdefghij1234567890abcdefghij123456\n' >"$WORK/d4.clip"
if run_script "$H" "$WORK/d4.clip" "$WORK/d4.out"; then
  fail "non-UUID token accepted"
else
  pass "non-UUID token rejected"
fi

if grep -qF 'hunter2' "$WORK/d1.out" "$WORK/d2.out" "$WORK/d3.out" "$WORK/d4.out" 2>/dev/null; then
  fail "REJECTED CONTENT LEAKED into output"
else
  pass "rejected content never echoed"
fi
if [ -e "$H/.config/flutterflow/codex-env.sh" ]; then
  fail "env file written despite rejection"
else
  pass "nothing written on rejection"
fi
if compgen -G "$H/.config/flutterflow/.clip.*" >/dev/null; then
  fail "temp file left behind"
else
  pass "no temp files left behind"
fi

echo
echo "== E: symlinked config dir -> refused =="
H="$WORK/E"
mkdir -p "$H/.config" "$WORK/E_real"
ln -s "$WORK/E_real" "$H/.config/flutterflow"
printf '%s\n' "$KEY" >"$WORK/e.clip"
if run_script "$H" "$WORK/e.clip" "$WORK/e.out"; then
  fail "wrote through symlinked dir"
else
  pass "refused symlinked config dir"
fi
if grep -rqF "$KEY" "$WORK/E_real" 2>/dev/null; then
  fail "KEY LEAKED through symlink"
else
  pass "symlink target untouched"
fi

echo
echo "== F: preexisting symlinked env file -> replaced, target untouched =="
H="$WORK/F"
mkdir -p "$H/.config/flutterflow" "$WORK/F_real"
printf 'do-not-touch\n' >"$WORK/F_real/target"
ln -s "$WORK/F_real/target" "$H/.config/flutterflow/codex-env.sh"
printf '%s\n' "$KEY" >"$WORK/f.clip"
run_script "$H" "$WORK/f.clip" "$WORK/f.out"
RC=$?
EF="$H/.config/flutterflow/codex-env.sh"
if [ "$RC" -eq 0 ]; then
  pass "stored despite preexisting symlink env path"
else
  fail "failed to replace symlink env path"
fi
if [ -f "$EF" ] && [ ! -L "$EF" ]; then
  pass "env path is now a regular file"
else
  fail "env path is still unsafe"
fi
if grep -qF "$KEY" "$WORK/F_real/target"; then
  fail "KEY LEAKED through env symlink target"
else
  pass "env symlink target untouched"
fi

echo
echo "== G: leak-freedom static checks on the script itself =="
if grep -nE '\$\((pbpaste|wl-paste|xclip|xsel|powershell)' "$SCRIPT" >/dev/null; then
  fail "clipboard read via command substitution"
else
  pass "no command-substitution clipboard reads"
fi
if grep -nE '\$\(\s*(cat|head|tail|awk|sed)\b[^)]*TMP|\$\(<' "$SCRIPT" >/dev/null; then
  fail "key file read via command substitution"
else
  pass "key file never read into a variable or argv"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All clipboard-script tests passed."
  exit 0
fi

echo "$fails assertion(s) failed."
exit 1
