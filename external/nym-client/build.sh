#!/usr/bin/env bash
# Pinned Nym source, isolated Rust toolchain and build cache; never uses NymVPN files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
RUST=1.99.1
SOURCE="$ROOT/build/nym-vpn-source/nym-vpn-core"
export CARGO_HOME="$ROOT/build/nym-toolchain/cargo"
export RUSTUP_HOME="$ROOT/build/nym-toolchain/rustup"
mkdir -p "$ROOT/build/nym-toolchain/bootstrap" "$ROOT/build/nym-client"
case "$(uname -sm)" in
  "Darwin arm64") HOST=aarch64-apple-darwin ;;
  "Darwin x86_64") HOST=x86_64-apple-darwin ;;
  "Linux x86_64") HOST=x86_64-unknown-linux-gnu ;;
  "Linux aarch64") HOST=aarch64-unknown-linux-gnu ;;
  *) echo "Unsupported Nym build host" >&2; exit 1 ;;
esac
if [ ! -x "$CARGO_HOME/bin/rustup" ]; then
  curl -fL --retry 3 "https://static.rust-lang.org/rustup/dist/$HOST/rustup-init" \
    -o "$ROOT/build/nym-toolchain/bootstrap/rustup-init"
  chmod +x "$ROOT/build/nym-toolchain/bootstrap/rustup-init"
  "$ROOT/build/nym-toolchain/bootstrap/rustup-init" -y --no-modify-path --profile minimal --default-toolchain "$RUST"
fi
TOOLCHAIN="$RUST"
if "$CARGO_HOME/bin/rustup" run stable rustc --version 2>/dev/null | grep -q "rustc $RUST "; then
  TOOLCHAIN=stable
elif ! "$CARGO_HOME/bin/rustup" run "$RUST" rustc --version >/dev/null 2>&1; then
  "$CARGO_HOME/bin/rustup" toolchain install "$RUST" --profile minimal
fi
fetch_source() {
  local destination="$1" url="$2" checksum="$3" archive="$1.tar.gz"
  if [ ! -f "$destination/.xmr-verified-$checksum" ]; then
    curl -fL --retry 3 "$url" -o "$archive"
    echo "$checksum  $archive" | shasum -a 256 -c -
    if [ -d "$destination" ]; then mv "$destination" "$destination.previous.$(date +%s)"; fi
    mkdir -p "$destination"
    tar -xzf "$archive" --strip-components=1 -C "$destination"
    touch "$destination/.xmr-verified-$checksum"
  fi
}
fetch_source "$ROOT/build/nym-vpn-source" "https://codeload.github.com/nymtech/nym-vpn-client/tar.gz/refs/tags/nym-vpn-v2026.13.0" 29b5fc9f23e887e0c7d1025bd555294396d01ace6b7a9f4103659c0f9fab4d7c
fetch_source "$ROOT/build/nym-auth-core" "https://codeload.github.com/nymtech/nym/tar.gz/2631de5b04b1e5b300729c4af8d48f5783db865f" d4dd4ac9609f4886913efcf5da8a9a0efeba3554a186c89964cd47c274c3df15
python3 "$ROOT/external/nym-client/prepare.py" "$SOURCE" "$ROOT/build/nym-auth-core" "$ROOT/external/nym-client"
cp "$ROOT/external/nym-client/Cargo.lock" "$SOURCE/Cargo.lock"
"$CARGO_HOME/bin/cargo" "+$TOOLCHAIN" build --locked --manifest-path "$SOURCE/Cargo.toml" \
  --release -p xmr-nym-client -j "${NYM_BUILD_JOBS:-4}"
cp "$SOURCE/target/release/xmr-nym-client" "$ROOT/build/nym-client/xmr-nym-client"
cp "$ROOT/build/nym-vpn-source/LICENSE" "$ROOT/build/nym-client/NYM-LICENSE"
