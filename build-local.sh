#!/usr/bin/env bash
# Build this zmk-config locally, mirroring the targets in build.yaml.
#
# The west workspace lives outside this repo because the repo root already has a
# zephyr/ directory (the module manifest), which would collide with the zephyr
# project west fetches. The config is handed to the build via -DZMK_CONFIG, so
# no build output ever lands in this repo.
#
# Setup instructions are in readme.md.
#
# Usage:
#   ./build-local.sh                       # build every target
#   ./build-local.sh corne_left            # build selected targets only
#   OUT_DIR=/tmp/fw ./build-local.sh       # override the output directory

set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ZMK_WORKSPACE="${ZMK_WORKSPACE:-$HOME/zmk-workspace}"
OUT_DIR="${OUT_DIR:-$HOME/Downloads/zmk-firmware}"
BOARD="nice_nano_v2"

export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="${ZEPHYR_SDK_INSTALL_DIR:-$HOME/zephyr-sdk-0.16.3}"
export PATH="$ZMK_WORKSPACE/.venv/bin:$PATH"

# Kept in sync with build.yaml.
TARGET_NAMES="corne_left corne_right settings_reset"

shield_for() {
  case "$1" in
    corne_left)     echo "corne_left nice_view_adapter nice_view" ;;
    corne_right)    echo "corne_right nice_view_adapter nice_view" ;;
    settings_reset) echo "settings_reset" ;;
    *)              return 1 ;;
  esac
}

die() { echo "error: $*" >&2; exit 1; }

[ -d "$ZMK_WORKSPACE/zmk/app" ] || die "no ZMK checkout at $ZMK_WORKSPACE/zmk (see readme.md)"
[ -d "$ZEPHYR_SDK_INSTALL_DIR" ] || die "no Zephyr SDK at $ZEPHYR_SDK_INSTALL_DIR (see readme.md)"
command -v west >/dev/null || die "west not found; expected it in $ZMK_WORKSPACE/.venv/bin"

wanted="$*"
for name in $wanted; do
  shield_for "$name" >/dev/null || die "unknown target: $name (known: $TARGET_NAMES)"
done

mkdir -p "$OUT_DIR"
built=""

for name in $TARGET_NAMES; do
  if [ -n "$wanted" ]; then
    case " $wanted " in
      *" $name "*) ;;
      *) continue ;;
    esac
  fi

  echo "==> building $name"
  ( cd "$ZMK_WORKSPACE/zmk" && west build -p -s app -b "$BOARD" -d "build/$name" -- \
      -DSHIELD="$(shield_for "$name")" \
      -DZMK_CONFIG="$REPO_DIR/config" )

  cp "$ZMK_WORKSPACE/zmk/build/$name/zephyr/zmk.uf2" "$OUT_DIR/$name-$BOARD-zmk.uf2"
  built="$built $name"
done

echo
echo "firmware written to $OUT_DIR"
for name in $built; do
  ls -lh "$OUT_DIR/$name-$BOARD-zmk.uf2"
done
