#!/bin/bash
# Downloads the official Tor Expert Bundle (macOS) from torproject.org and, with an .app as argument,
# puts it inside it (Contents/MacOS/tor: the tor binary, its libevent, pluggable transports and the
# GeoIP files). The app's TOR NETWORK panel starts that tor. The bundle is checked against the
# SHA-256 list Tor publishes next to it, and that list against Tor's signing key when gpg is installed.
# Without network the copy from the last run is used; without any copy the app falls back to
# Homebrew's tor (brew install tor).
#   bash actualizar-tor.sh [path/to/App.app]
set -u
BASE="$HOME/Monero/xmr-wallet-plus/tor-bundle"
DIST="https://dist.torproject.org/torbrowser"
# Tor Browser signing key (https://support.torproject.org/tbb/how-to-verify-signature/)
TB_KEY="EF6E286DDA85EA2A4BA7DE684E2C6E8793298290"
case "$(uname -m)" in
    arm64) ARCH=aarch64 ;;
    *) ARCH=x86_64 ;;
esac
mkdir -p "$BASE"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Buscando la última versión del Tor Expert Bundle"
VERSION="$(curl -fsSL --max-time 30 https://aus1.torproject.org/torbrowser/update_3/release/downloads.json \
           | sed -n 's/.*"version" *: *"\([0-9][0-9.a-z]*\)".*/\1/p' | head -1)"
if [ -n "$VERSION" ] && [ ! -x "$BASE/$VERSION/tor/tor" ]; then
    FILE="tor-expert-bundle-macos-$ARCH-$VERSION.tar.gz"
    if curl -fsSL --max-time 300 -o "$TMP/$FILE" "$DIST/$VERSION/$FILE" \
       && curl -fsSL --max-time 30 -o "$TMP/sums.txt" "$DIST/$VERSION/sha256sums-signed-build.txt"; then
        OK=1
        if command -v gpg >/dev/null 2>&1; then
            if curl -fsSL --max-time 30 -o "$TMP/sums.txt.asc" "$DIST/$VERSION/sha256sums-signed-build.txt.asc"; then
                export GNUPGHOME="$TMP/gnupg"; mkdir -m 700 "$GNUPGHOME"
                gpg --quiet --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org >/dev/null 2>&1
                if ! gpg --list-keys "$TB_KEY" >/dev/null 2>&1; then
                    echo "NOTE: no se pudo obtener la clave de Tor; solo se comprueba el SHA-256 publicado por Tor"
                elif gpg --quiet --status-fd 1 --verify "$TMP/sums.txt.asc" "$TMP/sums.txt" 2>/dev/null \
                     | grep -q "VALIDSIG.*$TB_KEY"; then
                    echo "OK: lista SHA-256 firmada por Tor ($TB_KEY)"
                else
                    echo "WARNING: la firma de la lista SHA-256 NO es válida; no se instala esta versión"
                    OK=0
                fi
            fi
        else
            echo "NOTE: gpg no está instalado (brew install gnupg): solo se comprueba el SHA-256 publicado por Tor"
        fi
        WANT="$(grep " $FILE\$" "$TMP/sums.txt" | awk '{print $1}')"
        GOT="$(shasum -a 256 "$TMP/$FILE" | awk '{print $1}')"
        if [ "$OK" = 1 ] && [ -n "$WANT" ] && [ "$WANT" = "$GOT" ]; then
            mkdir -p "$TMP/x" && tar -xzf "$TMP/$FILE" -C "$TMP/x"
            if [ -x "$TMP/x/tor/tor" ]; then
                mkdir -p "$BASE/$VERSION"
                cp -R "$TMP/x/tor" "$BASE/$VERSION/"
                [ -d "$TMP/x/data" ] && cp -R "$TMP/x/data" "$BASE/$VERSION/tor/data"
                echo "OK: Tor Expert Bundle $VERSION ($ARCH)"
            else
                echo "WARNING: el paquete no trae tor/tor"
            fi
        elif [ "$OK" = 1 ]; then
            echo "WARNING: el SHA-256 del paquete no coincide con el publicado por Tor; no se instala"
        fi
    else
        echo "WARNING: no se pudo descargar el Tor Expert Bundle $VERSION"
    fi
elif [ -z "$VERSION" ]; then
    echo "WARNING: no se pudo consultar la versión de Tor; se usa la copia anterior si hay"
else
    echo "OK: Tor Expert Bundle $VERSION ya descargado"
fi

# newest copy on disk
LATEST="$(ls -1d "$BASE"/*/tor 2>/dev/null | sort -V | tail -1)"
if [ -n "${1:-}" ]; then
    DEST="$1/Contents/MacOS/tor"
    if [ -n "$LATEST" ] && [ -x "$LATEST/tor" ]; then
        rm -rf "$DEST"
        cp -R "$LATEST" "$DEST"
        xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
        # sign the loose binaries first; firmar_app then seals the whole app
        ID="XMR Wallet+ Local"
        security find-certificate -c "$ID" >/dev/null 2>&1 || ID="-"
        find "$DEST" -type f \( -perm -u+x -o -name '*.dylib' \) -print0 | while IFS= read -r -d '' f; do
            if file "$f" | grep -q Mach-O; then codesign --force --sign "$ID" "$f" 2>/dev/null; fi
        done
        echo "OK: tor dentro de $1 ($(basename "$(dirname "$LATEST")"))"
    else
        echo "WARNING: la app va sin Tor propio (el panel TOR NETWORK usará el tor de Homebrew si está)"
    fi
fi
exit 0
