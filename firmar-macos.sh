#!/usr/bin/env bash
# Signs the app with a local, self-signed certificate ("XMR Wallet+ Local") instead of ad hoc.
# macOS remembers permissions (USB / SD drives, Bluetooth, camera, notifications) per signing
# identity: with an ad-hoc signature every build counts as a new app and asks again.
# The certificate is created once in the login keychain; it never leaves this Mac.
#   source firmar-macos.sh; firmar_app path/to/App.app
IDENTITY="XMR Wallet+ Local"

crear_identidad() {
  security find-certificate -c "$IDENTITY" >/dev/null 2>&1 && return 0
  echo "==> Creating the local signing certificate \"$IDENTITY\" (once)"
  local ossl tmp
  ossl="$(brew --prefix openssl@3 2>/dev/null)/bin/openssl"
  [ -x "$ossl" ] || ossl=openssl
  tmp="$(mktemp -d)"
  "$ossl" req -x509 -newkey rsa:2048 -nodes -days 3650 -subj '/CN=XMR Wallet\+ Local' \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1
  "$ossl" pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12" \
    -name "$IDENTITY" -passout pass:xmrwallet \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
  security import "$tmp/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P xmrwallet -T /usr/bin/codesign >/dev/null
  # trusted for code signing only, so codesign accepts it (macOS asks for your password once)
  security add-trusted-cert -r trustRoot -p codeSign \
    -k "$HOME/Library/Keychains/login.keychain-db" "$tmp/cert.pem" || true
  rm -rf "$tmp"
}

firmar_app() {
  local app="$1"
  if crear_identidad && codesign --force --deep --sign "$IDENTITY" "$app" 2>/dev/null; then
    echo "OK: signed with \"$IDENTITY\" (macOS keeps the permissions between builds)"
  else
    echo "WARNING: local certificate not usable, signing ad hoc (macOS will ask for permissions again)"
    codesign --force --deep --sign - "$app"
  fi
}
