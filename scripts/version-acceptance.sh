#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)"

VERSION_FILE="$ROOT_DIR/VERSION"
CLI="$ROOT_DIR/march-env"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f "$VERSION_FILE" ]] ||
  fail 'VERSION file is missing.'

[[ -x "$CLI" ]] ||
  fail 'march-env is missing or not executable.'

VERSION="$(
  tr -d '\r\n' < "$VERSION_FILE"
)"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] ||
  fail 'VERSION does not contain a valid semantic version.'

EXPECTED="march-env $VERSION"

for command in --version -v version; do
  ACTUAL="$(
    "$CLI" "$command"
  )"

  [[ "$ACTUAL" == "$EXPECTED" ]] ||
    fail "$command returned version drift: expected '$EXPECTED', got '$ACTUAL'."
done

grep -Fq "MARCH_ENV_VERSION='$VERSION'" "$CLI" ||
  fail 'embedded MARCH_ENV_VERSION does not match VERSION file.'

printf 'VERSION=%s\n' "$VERSION"
printf '%s\n' 'VERSION_FILE=PASS'
printf '%s\n' 'VERSION_COMMANDS=PASS'
printf '%s\n' 'VERSION_EMBEDDED=PASS'
printf '%s\n' 'VERSION_ACCEPTANCE=PASS'
