#!/bin/bash
# Packages the compiled wallet so it runs on another Mac (no Homebrew needed there).
# Run it in the monero-gui folder after compilar-macos.sh:
#   bash empaquetar-macos.sh
# Result: dist/XMR-wallet+.app and dist/XMR-wallet+-macos.zip
# It works on a copy, so build/release/bin/monero-wallet-gui.app stays as it is.
set -euo pipefail

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

# Folders where the app's non-Qt libraries live (pinned boost/protobuf/openssl and the rest)
LIBPATHS=()
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
  [ -n "$p" ] && [ -d "$p/lib" ] && LIBPATHS+=("-libpath=$p/lib")
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
"$MACDEPLOYQT" "$APP" -always-overwrite -qmldir="$PWD" ${LIBPATHS[@]+"${LIBPATHS[@]}"} || true

echo "== Copying libraries macdeployqt missed"
FW="$APP/Contents/Frameworks"
mkdir -p "$FW"
BREW="$(brew --prefix)"

# Copies a Homebrew Qt framework (e.g. QtMultimedia.framework) into the app with ditto,
# which keeps the framework's internal symlinks (cp -RL breaks them).
copy_framework() {
  local fw="$1" src=""
  for cand in "$BREW/lib/$fw" $(ls -d "$BREW"/opt/qt*/lib/"$fw" 2>/dev/null); do
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
  find "$APP/Contents" -type f ! -path "*/Resources/*" ! -path "*/Headers/*" ! -name "*.qml" \
       ! -name "*.qmltypes" ! -name "*.png" ! -name "*.plist" ! -name "qmldir" -print \
    | while IFS= read -r f; do file "$f" | grep -q "Mach-O" && echo "$f"; done
}
for pass in 1 2 3 4; do
  missing=0
  while IFS= read -r bin; do
    while IFS= read -r dep; do
      case "$dep" in
        @rpath/*.framework/*)
          # Qt framework macdeployqt could not resolve (QtMultimedia, QtStateMachine, ...)
          fw="${dep#@rpath/}"; fw="${fw%%/*}"
          if [ ! -e "$FW/$fw" ]; then copy_framework "$fw" && missing=1 || true; fi
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

echo "== Checking nothing still points at this Mac"
LEFT="$(macho_files | while IFS= read -r f; do otool -L "$f" | tail -n +2; done 2>/dev/null \
        | grep -E "^\s+(/opt/homebrew|/usr/local|$HOME)" | sort -u || true)"
# @rpath Qt frameworks that are still not in the app
for fw in $(macho_files | while IFS= read -r f; do otool -L "$f" | tail -n +2 | awk '{print $1}'; done \
            | grep -o '^@rpath/[^/]*\.framework' | sort -u | sed 's|@rpath/||'); do
  [ -e "$FW/$fw" ] || LEFT="$LEFT
missing in the app: $fw"
done
if [ -n "$LEFT" ]; then
  echo "WARNING: these libraries are still outside the app:"; echo "$LEFT"
else
  echo "OK: every library is inside the app"
fi

echo "== Signing (local certificate, ad hoc as fallback; required on Apple Silicon)"
source "$(dirname "$0")/firmar-macos.sh"; firmar_app "$APP"
codesign --verify --deep --strict "$APP" && echo "OK: signature valid"

echo "== Testing monerod from inside the app"
if "$APP/Contents/MacOS/monerod" --version; then
  echo "OK: monerod starts"
else
  echo "WARNING: monerod does not start (error above)"
fi

echo "== Making the zip"
ZIP="$DIST/XMR-wallet+-macos.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo
echo "Done: $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "On the other Mac, after unzipping:"
echo "  xattr -dr com.apple.quarantine \"XMR-wallet+.app\""
echo "then open it (the first time: right click > Open)."
