# Building SigDigger on Windows

Upstream says Windows is unsupported. This directory makes it work on MSYS2/UCRT64
with MinGW-w64. Everything builds from stock upstream sources — no patches to
SigDigger, Suscan, Sigutils or SuWidgets.

## Requirements

- Windows 10/11 x64
- MSYS2 installed at `C:\msys64` (https://www.msys2.org/)

Packages are installed by `01-install-packages.sh`. Note it uses the **UCRT64**
environment, not MINGW64: MSYS2 no longer ships `volk` and `SoapySDR` for MINGW64.

## Build

Run each step inside the MSYS2 UCRT64 shell. From Git Bash / PowerShell:

```bash
MSYSTEM=UCRT64 C:/msys64/usr/bin/bash.exe -lc \
  'cd /c/path/to/SigDigger/Scripts/windows && ./01-install-packages.sh'
```

| Step | Script | What it does |
| ---- | ------ | ------------ |
| 1 | `01-install-packages.sh` | pacman: gcc, cmake, Qt6, fftw, volk, libxml2, libsndfile, portaudio, SoapySDR (+ rtlsdr/hackrf), NSIS |
| 2 | `02-build.sh [step\|all]` | builds sigutils → suscan → SuWidgets → SigDigger into `../../.winbuild/prefix` |
| 3 | `03-package.sh` | stages a self-contained folder in `../../.winbuild/dist/SigDigger` (Qt + MinGW DLL closure + suscan config + SoapySDR modules) |
| 4 | `makensis 04-installer.nsi` | builds `../../.winbuild/dist/SigDigger-0.3.0-win64-setup.exe` |

Steps 2 and 4 need the `COMSPEC` workaround below, which the scripts already set.

## Gotchas that cost hours

**`COMSPEC` must be set.** qmake shells out through `cmd` for its compiler probes,
and MSYS2's `/usr/bin/cmd` is literally `"$COMSPEC" "$@"`. Launched from an
environment without `COMSPEC` (Git Bash, CI containers, editors), every probe
silently returns nothing and qmake dies with:

```text
Variable QMAKE_CXX.COMPILER_MACROS is not defined.
Project ERROR: failed to parse default include paths from compiler output
```

**Clone with tags.** `sigutils` derives its version from `git describe --tags --match "v*"`.
A `--depth 1` clone has no tags, so sigutils reports `0.0.0` and suscan refuses it
(`Package dependency requirement 'sigutils >= 0.1' could not be satisfied`).
Use `git fetch --unshallow --tags` on a shallow clone.

**UCRT64, not MINGW64.** `mingw-w64-x86_64-volk` and `mingw-w64-x86_64-soapysdr`
are gone from the mingw64 repo. UCRT64 is the supported environment.

**Qt translation binary.** Upstream CI symlinks `lrelease-qt6.exe` to `lrelease.exe`;
`01-install-packages.sh` does the same. `.pro` files use `CONFIG += lrelease embed_translations`.

## Runtime layout

Suscan resolves its data next to `SigDigger.exe` on Windows
(`suscan/util/win32-bundle.imp.h`), so the staged folder is portable and needs no
environment variables or registry entries:

```text
SigDigger/
  SigDigger.exe
  suscli.exe
  config/        suscan config db (confdb, palettes, frequency allocations)
  modules0.8/    SoapySDR modules (SoapySDR ABI 0.8)
  *.dll          Qt6, suscan, sigutils, suwidgets, MinGW runtime, ...
  plugins/       SigDigger plugins (created when you add one)
```

`03-package.sh` uses `windeployqt` for the Qt side and then walks the PE import
graph with `ldd` until the DLL set stops growing, so Qt plugins and SoapySDR
modules pull in their own dependencies.
