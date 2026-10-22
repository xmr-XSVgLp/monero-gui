#!/bin/bash
# Copies Homebrew's i2pd (router for the I2P network) into the app with its libraries,
# so the I2P NETWORK panel works without Homebrew on the Mac where the app runs.
#   bash actualizar-i2pd.sh [path/to/App.app]
# Needs once: brew install i2pd   (Homebrew checks the bottle's SHA-256)
# Without an app it only says which i2pd would go in.
set -u

BREW="$(command -v brew || true)"
[ -z "$BREW" ] && [ -x /opt/homebrew/bin/brew ] && BREW=/opt/homebrew/bin/brew
[ -z "$BREW" ] && [ -x /usr/local/bin/brew ] && BREW=/usr/local/bin/brew
if [ -z "$BREW" ]; then
    echo "WARNING: no hay Homebrew; la app va sin I2P propio"
    exit 0
fi
PREFIX="$("$BREW" --prefix i2pd 2>/dev/null)"
BIN="$PREFIX/bin/i2pd"
if [ ! -x "$BIN" ]; then
    echo "WARNING: i2pd no está instalado; la app va sin I2P (instálalo una vez con: brew install i2pd)"
    exit 0
fi
BIN="$(realpath "$BIN" 2>/dev/null || echo "$BIN")"
CERTS="$(find "$PREFIX/" "$("$BREW" --prefix)/share/i2pd" -type d -name certificates 2>/dev/null | while read -r d; do [ -d "$d/reseed" ] && echo "$d" && break; done)"
VERSION="$("$BIN" --version 2>/dev/null | head -1)"
if [ -z "$CERTS" ]; then
    echo "WARNING: no se encuentran los certificados de reseed de i2pd en $PREFIX; la app va sin I2P"
    exit 0
fi
[ -z "${1:-}" ] && { echo "OK: i2pd de Homebrew: $VERSION"; exit 0; }

DEST="$1/Contents/MacOS/i2pd"
rm -rf "$DEST"
mkdir -p "$DEST/lib"
cp "$BIN" "$DEST/i2pd"
chmod 755 "$DEST/i2pd"
cp -R "$CERTS" "$DEST/certificates"

# non-system libraries (Homebrew's boost, openssl, miniupnpc, zlib...), recursively,
# rewritten to load from i2pd/lib next to the binary. References like @rpath/... or
# @loader_path/... are resolved against the original file (its LC_RPATH entries and folder).
deps() { otool -L "$1" | tail -n +2 | awk '{print $1}' | grep -vE '^(/usr/lib/|/System/)'; }
rpaths() { otool -l "$1" | awk '/LC_RPATH/{f=1} f&&/ path /{print $2; f=0}'; }
resolve() {   # $1 = reference, $2 = original file that references it
    local ref="$1" src="$2" dir rp cand
    dir="$(dirname "$src")"
    case "$ref" in
        @loader_path/*|@executable_path/*) cand="$dir/${ref#*/}"; [ -f "$cand" ] && { echo "$cand"; return; } ;;
        @rpath/*)
            for rp in $(rpaths "$src"); do
                rp="${rp/@loader_path/$dir}"; rp="${rp/@executable_path/$dir}"
                [ -f "$rp/${ref#@rpath/}" ] && { echo "$rp/${ref#@rpath/}"; return; }
            done
            [ -f "$dir/${ref#@rpath/}" ] && { echo "$dir/${ref#@rpath/}"; return; } ;;
        *) [ -f "$ref" ] && { echo "$ref"; return; } ;;
    esac
    cand="$(find "$("$BREW" --prefix)/opt/" -maxdepth 3 -name "$(basename "$ref")" 2>/dev/null | head -1)"
    [ -n "$cand" ] && echo "$cand"
}
fix() {   # $1 = Mach-O inside DEST, $2 = prefix for its deps, $3 = the original file it came from
    local f="$1" src="$3" ref name real
    for ref in $(deps "$src"); do
        name="$(basename "$ref")"
        [ "$name" = "$(basename "$src")" ] && continue   # its own install id
        real="$(resolve "$ref" "$src")"
        if [ -z "$real" ]; then echo "WARNING: no encuentro $ref (de $src)"; continue; fi
        if [ ! -f "$DEST/lib/$name" ]; then
            cp -L "$real" "$DEST/lib/$name" || { echo "WARNING: falta $real"; continue; }
            chmod 644 "$DEST/lib/$name"
            install_name_tool -id "@loader_path/$name" "$DEST/lib/$name" 2>/dev/null
            fix "$DEST/lib/$name" "@loader_path" "$(realpath "$real" 2>/dev/null || echo "$real")"
        fi
        install_name_tool -change "$ref" "$2/$name" "$f" 2>/dev/null
    done
}
fix "$DEST/i2pd" "@executable_path/lib" "$BIN"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# sign the loose binaries first; firmar_app then seals the whole app
ID="XMR Wallet+ Local"
security find-certificate -c "$ID" >/dev/null 2>&1 || ID="-"
for f in "$DEST"/lib/*.dylib "$DEST/i2pd"; do
    [ -f "$f" ] && codesign --force --sign "$ID" "$f" 2>/dev/null
done
if "$DEST/i2pd" --version >/dev/null 2>&1; then
    echo "OK: i2pd dentro de $1 ($VERSION, $(ls "$DEST/lib" | wc -l | tr -d ' ') librerías)"
else
    echo "WARNING: el i2pd copiado no arranca; el panel I2P usará el de Homebrew. Error:"
    "$DEST/i2pd" --version 2>&1 | head -8
    otool -L "$DEST/i2pd" | head -20
    rm -rf "$DEST"
fi
exit 0
