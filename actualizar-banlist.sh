#!/bin/bash
# Downloads the Monero Research Lab spy-node ban list (Boog900/monero-ban-list) and, with an .app
# as argument, puts it inside it (Contents/Resources/ban_list.txt). The local node starts with
# --ban-list pointing there, and Security > Nodes checks remote nodes against it.
#   bash actualizar-banlist.sh [path/to/App.app]
set -u
URL="https://raw.githubusercontent.com/Boog900/monero-ban-list/main/ban_list.txt"
DEST="$HOME/Monero/xmr-wallet-plus/ban_list.txt"
mkdir -p "$(dirname "$DEST")"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
echo "Descargando la lista de baneos de nodos espía"
if curl -fsSL --max-time 30 -o "$TMP" "$URL"; then
    # only accept a file of IPv4 addresses, subnets and comments (never an HTML error page)
    ENTRIES="$(grep -cE '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?[[:space:]]*$' "$TMP" || true)"
    OTHER="$(grep -vE '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?[[:space:]]*$|^[[:space:]]*(#.*)?$' "$TMP" | wc -l | tr -d ' ')"
    if [ "$ENTRIES" -ge 50 ] && [ "$OTHER" = "0" ]; then
        mv "$TMP" "$DEST"
        echo "OK: $ENTRIES entradas ($(head -1 "$DEST" | sed 's/^# *//'))"
    else
        echo "WARNING: the downloaded file does not look like the ban list; keeping the previous one"
    fi
else
    echo "WARNING: could not download the ban list; keeping the previous one"
fi
if [ -n "${1:-}" ]; then
    if [ -f "$DEST" ]; then
        mkdir -p "$1/Contents/Resources"
        cp "$DEST" "$1/Contents/Resources/ban_list.txt"
        echo "OK: ban list inside $1"
    else
        echo "WARNING: the app goes without the ban list"
    fi
fi
exit 0
