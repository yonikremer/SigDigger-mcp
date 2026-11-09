#!/bin/bash
# SigDigger Windows packaging: self-contained app folder for the installer.
# Run inside MSYS2 UCRT64:
#   MSYSTEM=UCRT64 C:/msys64/usr/bin/bash.exe -lc 'cd /c/Users/yonik/SigDigger-mcp/Scripts/windows && ./03-package.sh'
#
# Layout matches suscan's Win32 bundle resolver (util/win32-bundle.imp.h):
# everything the app loads at runtime sits next to SigDigger.exe:
#   config/      suscan config db      (suscan_bundle_get_confdb_path)
#   modules0.8/  SoapySDR modules       (suscan_bundle_get_soapysdr_module_path)
#   plugins/     SigDigger plugins     (suscan_bundle_get_plugin_path)
set -e

REPO=/c/Users/yonik/SigDigger-mcp
BUILD=$REPO/.winbuild
PREFIX=$BUILD/prefix
UCRT=/ucrt64
STAGE=$REPO/.winbuild/dist/SigDigger
JOBS=$(nproc 2>/dev/null || echo 4)

export PATH=$UCRT/bin:/usr/bin:$PATH
# See 02-build.sh: qmake/windeployqt need COMSPEC to shell out.
export COMSPEC="${COMSPEC:-C:\\Windows\\System32\\cmd.exe}"

SOAPY_ABI=0.8
step() { echo; echo "=========== $* ==========="; }

step "reset staging dir"
rm -rf "$STAGE"
mkdir -p "$STAGE"

step "copy app binaries"
cp "$PREFIX/bin/SigDigger.exe" "$STAGE/"
[ -f "$PREFIX/bin/suscli.exe" ] && cp "$PREFIX/bin/suscli.exe" "$STAGE/"

# Suscan/Sigutils/SuWidgets are installed by us, not by pacman: copy explicitly
# (libsuscan.dll lands in prefix/lib, the others in prefix/bin).
cp "$PREFIX"/lib/*.dll "$STAGE/" 2>/dev/null || true
cp "$PREFIX"/bin/*.dll "$STAGE/" 2>/dev/null || true

step "copy suscan config db"
cp -r "$PREFIX/share/suscan/config" "$STAGE/config"

step "copy SoapySDR modules"
mkdir -p "$STAGE/modules$SOAPY_ABI"
cp "$UCRT"/lib/SoapySDR/modules$SOAPY_ABI*/*.dll "$STAGE/modules$SOAPY_ABI/" 2>/dev/null || \
  echo "WARNING: no SoapySDR module DLLs found in $UCRT/lib"

step "windeployqt (Qt DLLs + plugins)"
WINDEPLOYQT=$(command -v windeployqt6 || command -v windeployqt-qt6 || command -v windeployqt)
echo "using $WINDEPLOYQT"
"$WINDEPLOYQT" --no-translations --no-opengl-sw --release --dir "$STAGE" "$STAGE/SigDigger.exe"

# Copy every /ucrt64 dependency of every PE binary in the staging dir, repeatedly,
# until the set stops growing. Qt plugins and Soapy modules pull extra DLLs.
step "collect MinGW runtime DLL closure"
for pass in 1 2 3 4 5; do
  before=$(ls "$STAGE"/*.dll 2>/dev/null | wc -l)
  for exe in "$STAGE"/*.exe "$STAGE"/*.dll "$STAGE"/modules$SOAPY_ABI/*.dll \
             "$STAGE"/platforms/*.dll "$STAGE"/styles/*.dll "$STAGE"/imageformats/*.dll \
             "$STAGE"/iconengines/*.dll "$STAGE"/networkinformation/*.dll \
             "$STAGE"/tls/*.dll "$STAGE"/multimedia/*.dll; do
    [ -f "$exe" ] || continue
    ldd "$exe" 2>/dev/null | awk '{print $3}' | grep -E '^(/ucrt64|/mingw64)/' | while read -r dep; do
      base=$(basename "$dep")
      case "$base" in
        ucrtbase.dll|api-ms-*|ext-ms-*) continue ;;
      esac
      [ -f "$STAGE/$base" ] || cp "$dep" "$STAGE/"
    done
  done
  after=$(ls "$STAGE"/*.dll 2>/dev/null | wc -l)
  echo "pass $pass: $before -> $after dlls"
  [ "$before" = "$after" ] && break
done

step "copy NSIS installer source"
[ -d "$STAGE" ] || { echo "staging dir missing"; exit 1; }

step "summary"
du -sh "$STAGE"
echo "DLL count: $(ls "$STAGE"/*.dll | wc -l)"
echo "Staged at: $STAGE"
