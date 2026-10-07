#!/usr/bin/env bash
set -euo pipefail

REPO="${MARCH_ENV_REPO:-MarchTechnology/march-env}"
REF="${MARCH_ENV_REF:-main}"
INSTALL_DIR="${MARCH_ENV_INSTALL_DIR:-$HOME/.local/bin}"
DEST="$INSTALL_DIR/march-env"
API_BASE="https://api.github.com/repos/${REPO}"
TMP_META="$(mktemp "${TMPDIR:-/tmp}/march-env-meta.XXXXXX")"
TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/march-env.XXXXXX")"
TMP_DEST=''

cleanup() {
  rm -f "$TMP_META" "$TMP_FILE"

  if [[ -n "$TMP_DEST" ]]; then
    rm -f "$TMP_DEST"
  fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

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

if [[ "$REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
  RESOLVED_SHA="${REF,,}"
else
  COMMIT_API_URL="$API_BASE/commits/$REF"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL \
      -H 'Accept: application/vnd.github+json' \
      -H 'User-Agent: march-env-installer' \
      "$COMMIT_API_URL" \
      -o "$TMP_META"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP_META" \
      --header='Accept: application/vnd.github+json' \
      --header='User-Agent: march-env-installer' \
      "$COMMIT_API_URL"
  else
    fail 'curl or wget is required to download march-env.'
  fi

  RESOLVED_SHA="$(
    node - "$TMP_META" <<'NODE'
'use strict';

const fs = require('node:fs');

const path = process.argv[2];
let data;

try {
  data = JSON.parse(fs.readFileSync(path, 'utf8'));
} catch {
  process.exit(2);
}

const sha =
  typeof data?.sha === 'string'
    ? data.sha.toLowerCase()
    : '';

if (!/^[0-9a-f]{40}$/.test(sha)) {
  process.exit(3);
}

process.stdout.write(sha);
NODE
  )" || fail 'unable to resolve requested ref to a commit SHA.'
fi

RAW_URL="https://raw.githubusercontent.com/${REPO}/${RESOLVED_SHA}/march-env"

printf 'Installing march-env from %s@%s\n' "$REPO" "$REF"
printf 'Resolved commit: %s\n' "$RESOLVED_SHA"

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

VERSION_OUTPUT="$(
  bash "$TMP_FILE" --version
)"

if [[ ! "$VERSION_OUTPUT" =~ ^march-env[[:space:]][0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  fail 'downloaded march-env returned an invalid version string.'
fi

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
TMP_DEST=''

INSTALLED_VERSION="$(
  "$DEST" --version
)"

[[ "$INSTALLED_VERSION" == "$VERSION_OUTPUT" ]] ||
  fail 'installed march-env version does not match downloaded binary.'

printf 'Installed: %s\n' "$DEST"
printf 'Version: %s\n' "$INSTALLED_VERSION"
printf 'Validation: PASS\n'

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  printf '\nAdd this directory to PATH:\n'
  printf '  export PATH="%s:$PATH"\n' "$INSTALL_DIR"
  printf '\nPersist the same export in your shell profile (for example ~/.bashrc).\n'
else
  if command -v march-env >/dev/null 2>&1; then
    printf 'Command: %s\n' "$(command -v march-env)"
  fi
fi

if [[ ! -x /usr/sbin/cloudlinux-selector ]]; then
  printf '\nWarning: /usr/sbin/cloudlinux-selector was not found or is not executable.\n' >&2
  printf 'march-env is intended for cPanel/CloudLinux Node.js Selector environments.\n' >&2
fi
