#!/bin/bash
# Downloads the free DB-IP "IP to Country Lite" database (CC BY 4.0, updated monthly) for the
# country of the local node's peers. The lookups are offline: no IP ever leaves the app.
# Run once, and again every month or two to keep it current.
set -e
DEST="$HOME/Monero/xmr-wallet-plus/geoip"
mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for MONTH in "$(date +%Y-%m)" "$(date -v-1m +%Y-%m 2>/dev/null || date -d '-1 month' +%Y-%m)"; do
    URL="https://download.db-ip.com/free/dbip-country-lite-$MONTH.csv.gz"
    echo "Descargando $URL"
    if curl -fL --progress-bar -o "$TMP/db.csv.gz" "$URL"; then
        gunzip -c "$TMP/db.csv.gz" > "$TMP/db.csv"
        mv "$TMP/db.csv" "$DEST/dbip-country-lite.csv"
        echo "Listo: $DEST/dbip-country-lite.csv ($(wc -l < "$DEST/dbip-country-lite.csv" | tr -d ' ') rangos, $MONTH)"
        echo "Reinicia XMR Wallet+ para cargar la base nueva."
        exit 0
    fi
done
echo "No se pudo descargar la base de DB-IP." >&2
exit 1
