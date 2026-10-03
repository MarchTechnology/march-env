#!/usr/bin/env bash
set -euo pipefail

REPO="${MARCH_ENV_REPO:-MarchTechnology/march-env}"
REF="${MARCH_ENV_REF:-main}"
INSTALL_DIR="${MARCH_ENV_INSTALL_DIR:-$HOME/.local/bin}"
DEST="$INSTALL_DIR/march-env"
RAW_URL="https://raw.githubusercontent.com/${REPO}/${REF}/march-env"
TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/march-env.XXXXXX")"

cleanup() {
  rm -f "$TMP_FILE"
}

trap cleanup EXIT HUP INT TERM

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

if ((BASH_VERSINFO[0] < 4)); then
  fail 'march-env requires Bash 4 or newer.'
fi

if ! command -v node >/dev/null 2>&1; then
  fail 'Node.js is required but was not found in PATH.'
fi

printf 'Installing march-env from %s@%s\n' "$REPO" "$REF"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$RAW_URL" -o "$TMP_FILE"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$TMP_FILE" "$RAW_URL"
else
  fail 'curl or wget is required to download march-env.'
fi

[[ -s "$TMP_FILE" ]] ||
  fail 'downloaded march-env file is empty.'

bash -n "$TMP_FILE" ||
  fail 'downloaded march-env failed Bash syntax validation.'

mkdir -p "$INSTALL_DIR"

TMP_DEST="$DEST.tmp.$$"
rm -f "$TMP_DEST"

if command -v install >/dev/null 2>&1; then
  install -m 700 "$TMP_FILE" "$TMP_DEST"
else
  cp "$TMP_FILE" "$TMP_DEST"
  chmod 700 "$TMP_DEST"
fi

mv -f "$TMP_DEST" "$DEST"

printf 'Installed: %s\n' "$DEST"
printf 'Validation: PASS\n'

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  printf '\nAdd this directory to PATH:\n'
  printf '  export PATH="%s:$PATH"\n' "$INSTALL_DIR"
  printf '\nFor Bash, you can persist it with:\n'
  printf '  printf '\''%%s\\n'\'' '\''export PATH="$HOME/.local/bin:$PATH"'\'' >> "$HOME/.bashrc"\n'
else
  if command -v march-env >/dev/null 2>&1; then
    printf 'Command: %s\n' "$(command -v march-env)"
  fi
fi

if [[ ! -x /usr/sbin/cloudlinux-selector ]]; then
  printf '\nWarning: /usr/sbin/cloudlinux-selector was not found or is not executable.\n' >&2
  printf 'march-env is intended for cPanel/CloudLinux Node.js Selector environments.\n' >&2
fi
