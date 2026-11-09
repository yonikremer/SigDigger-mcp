#!/bin/bash
# SigDigger Windows toolchain: MSYS2 UCRT64 packages.
# Run via: MSYSTEM=UCRT64 C:/msys64/usr/bin/bash.exe -lc ./01-install-packages.sh
#
# UCRT64 (not MINGW64): MSYS2 dropped volk and SoapySDR from the mingw64 repo,
# and UCRT64 is the upstream-supported environment.
set -e

PACKAGES=(
  git
  zip
  unzip
  mingw-w64-ucrt-x86_64-gcc
  mingw-w64-ucrt-x86_64-make
  mingw-w64-ucrt-x86_64-cmake
  mingw-w64-ucrt-x86_64-pkgconf
  mingw-w64-ucrt-x86_64-fftw
  mingw-w64-ucrt-x86_64-volk
  mingw-w64-ucrt-x86_64-libxml2
  mingw-w64-ucrt-x86_64-libsndfile
  mingw-w64-ucrt-x86_64-libusb
  mingw-w64-ucrt-x86_64-portaudio
  mingw-w64-ucrt-x86_64-qt6
  mingw-w64-ucrt-x86_64-soapysdr
  mingw-w64-ucrt-x86_64-soapyrtlsdr
  mingw-w64-ucrt-x86_64-soapyhackrf
  mingw-w64-ucrt-x86_64-nsis
)

PACMAN_ARGS="--needed --noconfirm --disable-download-timeout"

echo "=== pacman -Syu (system update) ==="
pacman -Syu --noconfirm --disable-download-timeout || true

echo "=== installing build packages (ucrt64) ==="
# Mirror 500s are common; pacman keeps completed downloads, so retries converge.
installed=0
for attempt in 1 2 3 4; do
  # shellcheck disable=SC2086  # word splitting of the flag string is intended
  if pacman -S $PACMAN_ARGS "${PACKAGES[@]}"; then
    installed=1
    break
  fi
  echo "pacman attempt $attempt failed, retrying in 5s..."
  sleep 5
done

if [ "$installed" -ne 1 ]; then
  echo "FATAL: pacman could not install the package set" >&2
  exit 1
fi

echo "=== lrelease alias (upstream CI does the same) ==="
[ -e /ucrt64/bin/lrelease.exe ] || ln -s /ucrt64/bin/lrelease-qt6.exe /ucrt64/bin/lrelease.exe

echo "=== done ==="
