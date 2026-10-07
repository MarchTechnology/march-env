#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/march-env-install-isolation.XXXXXX")"
BIN_DIR="$TMP_ROOT/bin"
MOCK_BIN="$TMP_ROOT/mock-bin"
SENTINEL="$BIN_DIR/marchjson"

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$BIN_DIR" "$MOCK_BIN"

printf '%s\n' 'marchjson-install-isolation-sentinel' > "$SENTINEL"
chmod 755 "$SENTINEL"

BEFORE_HASH="$(
  sha256sum "$SENTINEL" |
    awk '{print $1}'
)"

BEFORE_MODE="$(
  stat -c '%a' "$SENTINEL"
)"

cat > "$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

OUTPUT=''
URL=''

while (($#)); do
  case "$1" in
    -o)
      OUTPUT="$2"
      shift 2
      ;;

    -H)
      shift 2
      ;;

    http://*|https://*)
      URL="$1"
      shift
      ;;

    *)
      shift
      ;;
  esac
done

[[ -n "$OUTPUT" ]] || exit 2
[[ -n "$URL" ]] || exit 2

if [[ "$URL" == *"/commits/"* ]]; then
  printf '{"sha":"1111111111111111111111111111111111111111"}\n' > "$OUTPUT"
else
  cp "$MARCH_ENV_TEST_SOURCE" "$OUTPUT"
fi
EOF

cat > "$MOCK_BIN/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod 755 "$MOCK_BIN/curl" "$MOCK_BIN/node"

PATH="$MOCK_BIN:$PATH" \
MARCH_ENV_TEST_SOURCE="$ROOT_DIR/march-env" \
MARCH_ENV_INSTALL_DIR="$BIN_DIR" \
  bash "$ROOT_DIR/install.sh" >/dev/null

[[ -x "$BIN_DIR/march-env" ]] ||
  fail 'march-env was not installed.'

cmp -s "$ROOT_DIR/march-env" "$BIN_DIR/march-env" ||
  fail 'installed march-env does not match repository source.'

[[ -f "$SENTINEL" ]] ||
  fail 'marchjson sentinel was deleted.'

AFTER_HASH="$(
  sha256sum "$SENTINEL" |
    awk '{print $1}'
)"

AFTER_MODE="$(
  stat -c '%a' "$SENTINEL"
)"

[[ "$BEFORE_HASH" == "$AFTER_HASH" ]] ||
  fail 'marchjson content changed during march-env installation.'

[[ "$BEFORE_MODE" == "$AFTER_MODE" ]] ||
  fail 'marchjson permissions changed during march-env installation.'

PATH="$MOCK_BIN:$PATH" \
MARCH_ENV_TEST_SOURCE="$ROOT_DIR/march-env" \
MARCH_ENV_INSTALL_DIR="$BIN_DIR" \
  bash "$ROOT_DIR/install.sh" >/dev/null

SECOND_HASH="$(
  sha256sum "$SENTINEL" |
    awk '{print $1}'
)"

SECOND_MODE="$(
  stat -c '%a' "$SENTINEL"
)"

[[ "$BEFORE_HASH" == "$SECOND_HASH" ]] ||
  fail 'marchjson content changed during march-env update.'

[[ "$BEFORE_MODE" == "$SECOND_MODE" ]] ||
  fail 'marchjson permissions changed during march-env update.'

printf '%s\n' 'MARCH_ENV_INSTALL_ISOLATION=PASS'
printf '%s\n' 'MARCHJSON_CONTENT_PRESERVED=PASS'
printf '%s\n' 'MARCHJSON_PERMISSIONS_PRESERVED=PASS'
printf '%s\n' 'MARCH_ENV_REINSTALL=PASS'
