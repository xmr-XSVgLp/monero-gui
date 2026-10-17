#!/usr/bin/env bash
# Puts Qt Multimedia (needed by the optional UI sounds) inside monero-wallet-gui.app.
# Homebrew's Qt libraries point at /opt/homebrew/...; loading them next to the Qt copy
# inside the app means two QtCores, so Qt refuses the module. This copies the libraries
# in, rewrites those paths to the app's own copies (@rpath) and re-signs the app.
# Usage, from the monero-gui folder:  bash arreglar-sonido-macos.sh [path/to/app]
set -euo pipefail
APP="${1:-build/release/bin/monero-wallet-gui.app}"
FW="$APP/Contents/Frameworks"
[ -d "$FW/QtCore.framework" ] || { echo "No Qt inside $APP: nothing to fix"; exit 0; }
QT="$(brew --prefix qt)"

for f in QtMultimedia QtMultimediaQuick QtNetwork QtConcurrent; do
  [ -d "$FW/$f.framework" ] && [ "$f" != QtMultimedia ] && [ "$f" != QtMultimediaQuick ] && continue
  rm -rf "$FW/$f.framework"
  ditto "$(cd "$QT/lib/$f.framework" && pwd -P)" "$FW/$f.framework"
  chmod -R u+w "$FW/$f.framework"
done
mkdir -p "$APP/Contents/PlugIns/multimedia"
for p in "$QT"/share/qt/plugins/multimedia/*.dylib; do cp -L "$p" "$APP/Contents/PlugIns/multimedia/"; done
chmod u+w "$APP"/Contents/PlugIns/multimedia/*.dylib

fix() {  # $1 = Mach-O file, $2 = rpath to add
  local bin="$1"
  otool -L "$bin" | awk 'NR>1{print $1}' | grep -E '^/opt/homebrew/.*/(Qt[A-Za-z]+)\.framework/' | while read -r dep; do
    name="$(echo "$dep" | sed -E 's|.*/(Qt[A-Za-z]+\.framework/.*)|\1|')"
    install_name_tool -change "$dep" "@rpath/$name" "$bin" 2>/dev/null
  done
  install_name_tool -add_rpath "$2" "$bin" 2>/dev/null || true
}
for f in QtMultimedia QtMultimediaQuick QtNetwork QtConcurrent; do
  bin="$FW/$f.framework/Versions/A/$f"
  install_name_tool -id "@rpath/$f.framework/Versions/A/$f" "$bin"
  fix "$bin" "@loader_path/../../.."
done
for p in "$APP"/Contents/PlugIns/multimedia/*.dylib "$APP"/Contents/PlugIns/quick/libquickmultimediaplugin.dylib; do
  [ -f "$p" ] && fix "$p" "@loader_path/../../Frameworks"
done

codesign --force --deep -s - "$APP"
echo "Listo. Comprobando que no quedan rutas de Homebrew a Qt:"
otool -L "$FW/QtMultimedia.framework/Versions/A/QtMultimedia" "$FW/QtMultimediaQuick.framework/Versions/A/QtMultimediaQuick" | grep -c "/opt/homebrew/.*Qt" || true
