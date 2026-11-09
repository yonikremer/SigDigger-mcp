#!/bin/bash
# SigDigger Windows build: sigutils -> suscan -> SuWidgets -> SigDigger.
# Run inside MSYS2 UCRT64:
#   MSYSTEM=UCRT64 C:/msys64/usr/bin/bash.exe -lc 'cd /c/Users/yonik/SigDigger-mcp/Scripts/windows && ./02-build.sh [step|all]'
# Steps: sigutils suscan suwidgets sigdigger all
set -e

REPO=/c/Users/yonik/SigDigger-mcp
BUILD=$REPO/.winbuild
SRC=$BUILD/src
PREFIX=$BUILD/prefix
MINGW=/ucrt64
QMAKE=$MINGW/bin/qmake6.exe
JOBS=$(nproc 2>/dev/null || echo 4)

export PATH=$MINGW/bin:/usr/bin:$PATH
# qmake shells out to cmd for its compiler probes; MSYS2's /usr/bin/cmd shim is
# "$COMSPEC $@", so without COMSPEC every probe silently returns nothing and
# qmake dies with "failed to parse default include paths from compiler output".
export COMSPEC="${COMSPEC:-C:\\Windows\\System32\\cmd.exe}"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"

mkdir -p "$BUILD/build" "$PREFIX"

step() { echo; echo "=========== $* ==========="; }

build_sigutils() {
  step "sigutils: configure"
  cmake -S "$SRC/sigutils" -B "$BUILD/build/sigutils" -G "MinGW Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON
  step "sigutils: build"
  cmake --build "$BUILD/build/sigutils" --parallel "$JOBS"
  step "sigutils: install"
  cmake --install "$BUILD/build/sigutils"
}

build_suscan() {
  step "suscan: configure"
  cmake -S "$SRC/suscan" -B "$BUILD/build/suscan" -G "MinGW Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DSUSCAN_PKGDIR=/usr -DENABLE_ALSA=OFF -DENABLE_PORTAUDIO=ON
  step "suscan: build"
  cmake --build "$BUILD/build/suscan" --parallel "$JOBS"
  step "suscan: install"
  cmake --install "$BUILD/build/suscan"
}

build_suwidgets() {
  step "SuWidgets: qmake"
  mkdir -p "$BUILD/build/SuWidgets"
  ( cd "$BUILD/build/SuWidgets" &&
    "$QMAKE" "$SRC/SuWidgets/SuWidgetsLib.pro" "CONFIG += release" \
      PREFIX="$PREFIX" )
  step "SuWidgets: build"
  ( cd "$BUILD/build/SuWidgets" && mingw32-make -j"$JOBS" )
  step "SuWidgets: install"
  ( cd "$BUILD/build/SuWidgets" && mingw32-make install )
}

build_sigdigger() {
  step "SigDigger: qmake"
  mkdir -p "$BUILD/build/SigDigger"
  ( cd "$BUILD/build/SigDigger" &&
    "$QMAKE" "$REPO/SigDigger.pro" "CONFIG += release" \
      SUWIDGETS_PREFIX="$PREFIX" PREFIX="$PREFIX" DISABLE_ALSA=1 )
  step "SigDigger: build"
  ( cd "$BUILD/build/SigDigger" && mingw32-make -j"$JOBS" )
  step "SigDigger: install"
  ( cd "$BUILD/build/SigDigger" && mingw32-make install )
}

case "${1:-all}" in
  sigutils)   build_sigutils ;;
  suscan)     build_suscan ;;
  suwidgets)  build_suwidgets ;;
  sigdigger)  build_sigdigger ;;
  all)
    build_sigutils
    build_suscan
    build_suwidgets
    build_sigdigger
    ;;
  *) echo "usage: $0 [sigutils|suscan|suwidgets|sigdigger|all]"; exit 1 ;;
esac

echo
echo "Build step done: ${1:-all}"
