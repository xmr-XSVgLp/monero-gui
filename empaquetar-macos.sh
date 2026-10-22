#!/bin/bash
# Packages the compiled wallet so it runs on another Mac (no Homebrew needed there).
# Run it in the monero-gui folder after compilar-macos.sh:
#   bash empaquetar-macos.sh
# Result: dist/XMR-wallet+.app and dist/XMR-wallet+-macos.zip
# It works on a copy, so build/release/bin/monero-wallet-gui.app stays as it is.
set -euo pipefail
cd "$(dirname "$0")"

SRC="build/release/bin/monero-wallet-gui.app"
DIST="dist"
APP="$DIST/XMR-wallet+.app"   # name of the .app people see (the executable inside keeps its name)
[ -d "$SRC" ] || { echo "No $SRC: run compilar-macos.sh first"; exit 1; }

QT_PREFIX="$(brew --prefix qt)"
MACDEPLOYQT="$QT_PREFIX/bin/macdeployqt"
[ -x "$MACDEPLOYQT" ] || MACDEPLOYQT="$(command -v macdeployqt)"

echo "== Copying the app"
rm -rf "$DIST"
mkdir -p "$DIST"
ditto "$SRC" "$APP"

# offline GeoIP base (country of the node's peers) inside the app, so no other Mac has to download it.
# Refreshed here when missing or older than 45 days.
echo "== GeoIP base"
GEOIP="$HOME/Monero/xmr-wallet-plus/geoip/dbip-country-lite.csv"
if [ ! -f "$GEOIP" ] || [ -n "$(find "$GEOIP" -mtime +45 2>/dev/null)" ]; then
  bash "$(dirname "$0")/actualizar-geoip.sh" || echo "WARNING: could not download the GeoIP base"
fi
if [ -f "$GEOIP" ]; then
  mkdir -p "$APP/Contents/Resources/geoip"
  cp "$GEOIP" "$APP/Contents/Resources/geoip/"
  echo "OK: GeoIP base inside the app"
else
  echo "WARNING: the app goes without the GeoIP base (countries show as -)"
fi

# MRL spy-node ban list, downloaded fresh and put inside the app (the local node uses it)
echo "== Spy-node ban list"
bash "$(dirname "$0")/actualizar-banlist.sh" "$APP"

# Folders where the app's non-Qt libraries live (pinned boost/protobuf/openssl and the rest)
LIBPATHS=("-libpath=$QT_PREFIX/lib")
QT_LIB_DIRS=("$QT_PREFIX/lib")
for f in boost@1.85 protobuf@21 openssl@3 abseil hidapi libusb zeromq libsodium unbound libpgm \
         icu4c readline expat; do
  p="$(brew --prefix "$f" 2>/dev/null || true)"
  [ -n "$p" ] && [ -d "$p/lib" ] && LIBPATHS+=("-libpath=$p/lib")
done
[ -d "$HOME/.local/boost-1.85/lib" ] && LIBPATHS+=("-libpath=$HOME/.local/boost-1.85/lib")
# Homebrew splits Qt into one formula per module (qtmultimedia, qtscxml, ...): macdeployqt
# only finds their frameworks if every module's lib folder is listed.
for f in $(brew list --formula | grep -E '^qt' || true); do
  p="$(brew --prefix "$f" 2>/dev/null || true)"
  if [ -n "$p" ] && [ -d "$p/lib" ]; then
    LIBPATHS+=("-libpath=$p/lib")
    QT_LIB_DIRS+=("$p/lib")
  fi
done

# macdeployqt fails on Boost's @rpath/@loader_path links between its own libraries
# ("libboost_atomic-mt.dylib: No such file"): put the Boost libraries in the app first.
echo "== Copying Boost libraries"
mkdir -p "$APP/Contents/Frameworks"
for d in "$(brew --prefix boost@1.85 2>/dev/null || true)/lib" "$HOME/.local/boost-1.85/lib"; do
  [ -d "$d" ] || continue
  for lib in "$d"/libboost_*.dylib; do
    [ -e "$lib" ] || continue
    name="$(basename "$lib")"
    [ -e "$APP/Contents/Frameworks/$name" ] && continue
    cp -L "$lib" "$APP/Contents/Frameworks/$name"
    chmod u+w "$APP/Contents/Frameworks/$name"
    install_name_tool -id "@rpath/$name" "$APP/Contents/Frameworks/$name" 2>/dev/null || true
  done
done

echo "== Running macdeployqt (copies Qt, QML modules and libraries into the app)"
# -libpath is not consulted when Qt resolves @rpath framework references.
# Supply temporary LC_RPATH entries on the copied executable. These also reach
# QML plugins discovered by macdeployqt, and are removed below before signing.
DEPLOY_EXE="$APP/Contents/MacOS/monero-wallet-gui"
codesign --remove-signature "$DEPLOY_EXE"
# Homebrew links Qt with absolute names. macdeployqt only propagates an
# LC_RPATH to QML plugins if a framework actually used it during deployment.
# Normalize Qt imports to @rpath so the aggregate Qt lib directory is retained.
while IFS= read -r dep; do
  case "$dep" in
    /opt/homebrew/*/lib/Qt*.framework/*|/usr/local/*/lib/Qt*.framework/*)
      rel="${dep#*/lib/}"
      [ -f "$QT_PREFIX/lib/$rel" ] || { echo "ERROR: missing Qt framework $rel"; exit 1; }
      install_name_tool -change "$dep" "@rpath/$rel" "$DEPLOY_EXE"
      ;;
  esac
done < <(otool -L "$DEPLOY_EXE" | tail -n +2 | sed 's/^[[:space:]]*//; s/ (compatibility version.*//')
for d in "${QT_LIB_DIRS[@]}"; do
  if ! otool -l "$DEPLOY_EXE" | awk '/LC_RPATH/{getline; getline; print $2}' | grep -Fx "$d" >/dev/null; then
    install_name_tool -add_rpath "$d" "$DEPLOY_EXE"
  fi
done
# Scan exactly the QML resources in the build, not Rust/build trees or older
# dist bundles. Those can contain unrelated imports and millions of files.
QML_SCAN="$(mktemp -d "$DIST/.qml-scan.XXXXXX")"
trap 'rm -rf "$QML_SCAN"' EXIT
python3 - "$QML_SCAN" <<'PYQML'
import pathlib, shutil, sys, xml.etree.ElementTree as ET
root = pathlib.Path(sys.argv[1])
manifest = pathlib.Path('build/release/.qt/rcc/monero-wallet-gui_raw_qml_0.qrc')
if not manifest.is_file():
    sys.exit('ERROR: QML build manifest missing; compile the wallet first')
for qrc in (manifest, manifest.with_name('monero-wallet-gui_raw_res_0.qrc')):
    for item in ET.parse(qrc).iter('file'):
        # the .qrc has absolute paths from where the build was configured; read the file from this
        # checkout (alias = path inside the repo) so a moved or renamed folder still works
        src = pathlib.Path(item.get('alias', ''))
        if not src.is_file():
            src = pathlib.Path(item.text)
        if src.suffix not in ('.qml', '.js', '.mjs') and src.name != 'qmldir':
            continue
        dest = root / item.get('alias', src.name)
        if not dest.resolve().is_relative_to(root.resolve()):
            sys.exit('ERROR: invalid QML resource alias')
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)
PYQML
DEPLOY_LOG="$DIST/macdeployqt.log"
# The destination is freshly copied. Re-overwriting frameworks for each QML
# plugin repeats their entire dependency traversal. Sign once after all edits.
"$MACDEPLOYQT" "$APP" -no-codesign -qmldir="$QML_SCAN" "${LIBPATHS[@]}" 2>&1 | tee "$DEPLOY_LOG"
# Some macdeployqt versions print errors but still return success.
if grep -E '^ERROR:' "$DEPLOY_LOG" >/dev/null; then
  echo "ERROR: macdeployqt failed; see $DEPLOY_LOG. No ZIP will be produced."
  exit 1
fi

echo "== Copying libraries macdeployqt missed"
FW="$APP/Contents/Frameworks"
mkdir -p "$FW"
BREW="$(brew --prefix)"

# Copies a Homebrew Qt framework (e.g. QtMultimedia.framework) into the app with ditto,
# which keeps the framework's internal symlinks (cp -RL breaks them).
copy_framework() {
  local fw="$1" src=""
  for cand in "$QT_PREFIX/lib/$fw" "$BREW/lib/$fw" "$BREW"/opt/qt*/lib/"$fw"; do
    [ -d "$cand" ] && { src="$(cd "$cand" && pwd -P)"; break; }
  done
  [ -n "$src" ] || { echo "  not found in Homebrew: $fw"; return 1; }
  echo "  + $fw"
  ditto "$src" "$FW/$fw"
  rm -rf "$FW/$fw/Headers" "$FW/$fw"/Versions/*/Headers
  chmod -R u+w "$FW/$fw"
}

# every Mach-O file in the app (executables, dylibs, plugins and framework binaries)
macho_files() {
  # QML plugins under Contents/Resources must be checked and repaired too.
  python3 scripts/check-macos-dependencies.py --list "$APP"
}

for pass in {1..32}; do
  missing=0
  while IFS= read -r bin; do
    while IFS= read -r dep; do
      case "$dep" in
        @rpath/*.framework/*)
          # Qt framework macdeployqt could not resolve (QtMultimedia, QtStateMachine, ...)
          fw="${dep#@rpath/}"; fw="${fw%%/*}"
          if [ ! -e "$FW/$fw" ]; then copy_framework "$fw"; missing=1; fi
          ;;
        */*.framework/*)
          # Qt framework: point at the copy macdeployqt put in the app (never copy it by hand)
          rel="${dep#*/lib/}"
          case "$dep" in /opt/homebrew/*|/usr/local/*)
            [ -e "$FW/$rel" ] && install_name_tool -change "$dep" "@rpath/$rel" "$bin" 2>/dev/null || true ;;
          esac
          ;;
        /opt/homebrew/*|/usr/local/*|"$HOME"/.local/*)
          name="$(basename "$dep")"
          if [ ! -e "$FW/$name" ]; then
            cp -L "$dep" "$FW/$name"; chmod u+w "$FW/$name"; missing=1
            install_name_tool -id "@rpath/$name" "$FW/$name" 2>/dev/null || true
          fi
          install_name_tool -change "$dep" "@rpath/$name" "$bin" 2>/dev/null || true
          ;;
      esac
    done < <(otool -L "$bin" 2>/dev/null | tail -n +2 | awk '{print $1}')
  done < <(macho_files)
  [ "$missing" = 0 ] && break
  [ "$pass" != 32 ] || { echo "ERROR: dependency traversal did not converge"; exit 1; }
done

echo "== Removing Homebrew rpaths from every library and plugin"
# otherwise, on this Mac, a copied library could load Homebrew's Qt next to the bundled one
while IFS= read -r bin; do
  # Frameworks copied with ditto retain their Homebrew install ID.
  case "$bin" in "$FW"/*.framework/*)
    install_name_tool -id "@rpath/${bin#"$FW"/}" "$bin"
    ;;
  esac
  while IFS= read -r rp; do
    case "$rp" in /opt/homebrew/*|/usr/local/*|"$HOME"/*) install_name_tool -delete_rpath "$rp" "$bin" 2>/dev/null || true ;; esac
  done < <(otool -l "$bin" | awk '/LC_RPATH/{getline; getline; print $2}')
  # libraries and plugins find the bundled Qt through the app's Frameworks folder
  otool -l "$bin" | grep -q "@executable_path/../Frameworks" \
    || install_name_tool -add_rpath "@executable_path/../Frameworks" "$bin" 2>/dev/null || true
done < <(macho_files)

echo "== Fixing rpaths (the wallet and monerod must look for libraries inside the app)"
# monerod lives next to the wallet in Contents/MacOS and also uses @rpath libraries:
# every executable there needs @executable_path/../Frameworks and no Homebrew rpaths.
for EXE in "$APP"/Contents/MacOS/*; do
  file "$EXE" | grep -q "Mach-O" || continue
  otool -l "$EXE" | grep -q "@executable_path/../Frameworks" \
    || install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXE"
  while IFS= read -r rp; do
    case "$rp" in /opt/homebrew/*|/usr/local/*|"$HOME"/*) install_name_tool -delete_rpath "$rp" "$EXE" || true ;; esac
  done < <(otool -l "$EXE" | awk '/LC_RPATH/{getline; getline; print $2}')
done

# bundled Tor (Tor Expert Bundle from torproject.org, SHA-256 checked). Added after the rpath
# fixes so its own binaries stay as Tor built them; the script signs them before the app is sealed.
echo "== Tor"
bash "$(dirname "$0")/actualizar-tor.sh" "$APP"
bash "$(dirname "$0")/actualizar-i2pd.sh" "$APP"


echo "== Checking all bundled dependencies"
python3 scripts/check-macos-dependencies.py "$APP"

echo "== Signing (local certificate, ad hoc as fallback; required on Apple Silicon)"
source "$(dirname "$0")/firmar-macos.sh"; firmar_app "$APP"
codesign --verify --deep --strict "$APP" && echo "OK: signature valid"

echo "== Testing monerod from inside the app"
if "$APP/Contents/MacOS/monerod" --version; then
  echo "OK: monerod starts"
else
  echo "ERROR: monerod does not start; no ZIP will be produced"
  exit 1
fi

echo "== Testing portable runtime resources and helpers"
python3 scripts/check-macos-runtime.py "$APP"

echo "== Making the zip"
ZIP="$DIST/XMR-wallet+-macos.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo
echo "Done: $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "On the other Mac, after unzipping:"
echo "  xattr -dr com.apple.quarantine \"XMR-wallet+.app\""
echo "then open it (the first time: right click > Open)."
