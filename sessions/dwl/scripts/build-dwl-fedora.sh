#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/buchhwin-dwl"
SETTINGS="$CFG_DIR/settings.env"
[[ -f "$SETTINGS" ]] && source "$SETTINGS"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/buchhwin-dwl"
SOURCE="$DATA_DIR/src/dwl"
SCENEFX_SOURCE="$DATA_DIR/src/scenefx"
PATCHES_SOURCE="$DATA_DIR/src/dwl-patches"
BUILD_DIR="$DATA_DIR/build/dwl-scenefx-port"
SCENEFX_BUILD="$DATA_DIR/build/scenefx"
SCENEFX_PREFIX="$DATA_DIR/scenefx"
PATCH_CONFIG="$CFG_DIR/patch-dwl-config.py"
PATCH_SOURCE="$CFG_DIR/patch-dwl-source.py"
LAYOUT="${KEYBOARD_LAYOUT:-de}"
readonly DWL_COMMIT="d41ecb745cc94fbb48e93af01f5fd5d0b2488945"
readonly SCENEFX_COMMIT="3606f3d3bb4bb97e13228adc5190bf57fc687c88"
readonly PATCHES_COMMIT="dc517160a550da7da1b8e0f14cff624f56e94203"

[[ -x "$PATCH_CONFIG" && -x "$PATCH_SOURCE" ]] || {
  echo "Missing installed patch helpers in $CFG_DIR" >&2
  exit 1
}

mkdir -p "$DATA_DIR/src" "$DATA_DIR/build"
clone_pinned() {
  local url="$1" destination="$2" commit="$3"
  if [[ ! -d "$destination/.git" ]]; then
    git clone --filter=blob:none "$url" "$destination"
  fi
  git -C "$destination" fetch --depth=1 origin "$commit"
  git -C "$destination" checkout --detach --force "$commit"
}

clone_pinned https://codeberg.org/dwl/dwl.git "$SOURCE" "$DWL_COMMIT"
clone_pinned https://github.com/wlrfx/scenefx.git "$SCENEFX_SOURCE" "$SCENEFX_COMMIT"
clone_pinned https://git.pupes.org/jachym/dwl-patches.git "$PATCHES_SOURCE" "$PATCHES_COMMIT"

# SceneFX is installed below the user's data directory and is linked with an
# rpath. It neither replaces Fedora's wlroots nor changes Plasma.
rm -rf -- "$SCENEFX_BUILD" "$SCENEFX_PREFIX"
meson setup "$SCENEFX_BUILD" "$SCENEFX_SOURCE" \
  --prefix="$SCENEFX_PREFIX" --libdir=lib64 -Dexamples=false
ninja -C "$SCENEFX_BUILD"
meson install -C "$SCENEFX_BUILD"

mkdir -p "$BUILD_DIR"
find "$BUILD_DIR" -mindepth 1 -delete
tar --exclude='./.git' -C "$SOURCE" -cf - . | tar -C "$BUILD_DIR" -xf -
cd "$BUILD_DIR"
# Apply the maintained dwl SceneFX integration. The pinned patch predates
# wlroots-next and intentionally leaves a few rejects; patch-dwl-source.py
# supplies those small API-port hunks deterministically below.
git apply --reject "$PATCHES_SOURCE/stale-patches/scenefx/scenefx.patch" || true
find "$BUILD_DIR" -type f \( -name '*.rej' -o -name '*.orig' \) -delete
cp config.def.h config.h
BUCHHWIN_KEYBOARD_LAYOUT="$LAYOUT" python3 "$PATCH_CONFIG" "$BUILD_DIR/config.h"
python3 "$PATCH_SOURCE" "$BUILD_DIR/dwl.c"

# Fedora 44 ships wlroots 0.20.2 and this source tracks wlroots-next.
sed -i 's/^PKGS      = /PKGS      = scenefx-0.5 /' Makefile
sed -i 's/^#XWAYLAND = -DXWAYLAND/XWAYLAND = -DXWAYLAND/' config.mk
sed -i 's/^#XLIBS = xcb xcb-icccm/XLIBS = xcb xcb-icccm/' config.mk

make clean
PKG_CONFIG_PATH="$SCENEFX_PREFIX/lib64/pkgconfig" \
  make LDFLAGS="-Wl,-rpath,$SCENEFX_PREFIX/lib64"
printf 'Built Fedora dwl safely at %s/dwl\n' "$BUILD_DIR"
