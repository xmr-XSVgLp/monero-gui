#!/usr/bin/env bash
# Builds this fork (xmr-XSVgLp/monero-gui, branch safe7-matrix) on macOS with Homebrew.
# Run it from the root of the clone:
#   bash compilar-macos.sh           full build from scratch (first time, or after updating Homebrew)
#   bash compilar-macos.sh rapido    quick rebuild after changing QML, images or styles
# Installs the dependencies, pins OpenSSL 3 / Boost 1.85 / protobuf 21 (monero v0.18 does not
# build with newer ones), builds and opens the app from build/release/bin.
#   EMPAQUETAR=1 bash compilar-macos.sh   also runs macdeployqt (only needed to copy the app to
#                                         another Mac; not needed to use it on this one)
set -euo pipefail

[ -f CMakeLists.txt ] && [ -d monero ] || { echo "Run this from the monero-gui folder"; exit 1; }
WORK="$(pwd -P)"
JOBS="$(sysctl -n hw.ncpu)"
APP=build/release/bin/monero-wallet-gui.app

# Build the wallet-owned mixnet helper before configuring the bundle.
bash "$WORK/external/nym-client/build.sh"

# The UI sounds need Qt Multimedia linked into the app (upstream only links it for the webcam
# QR scanner). Harmless if the fork already has this change.
perl -0pi -e 's/if\(WITH_SCANNER\)\n  list\(APPEND QT_COMPONENTS Multimedia\)\nendif\(\)/list(APPEND QT_COMPONENTS Multimedia)/' CMakeLists.txt

# CMake marks pinned headers as -isystem. Clang then ignores an earlier -I
# for the same directory, letting Homebrew's generic -I include win. Search
# that generic directory last, without unlinking packages on the host.
write_pinned_launcher() {
  LAUNCHER="$WORK/build/pinned-includes-v2.sh"
  mkdir -p "$WORK/build"
  {
    printf '#!/bin/bash\n'
    printf 'pinned=(%q %q %q)\n' "-I$BOOST_PREFIX/include" "-I$PROTOBUF_PREFIX/include" "-I$OPENSSL_PREFIX/include"
    printf 'brew_include=%q\n' "$(brew --prefix)/include"
    cat <<'LAUNCHER_BODY'
cc="$1"; shift
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -I|-isystem)
      flag="$1"; shift
      if [ "${1:-}" = "$brew_include" ]; then
        args+=("-idirafter" "$1")
      else
        args+=("$flag" "$1")
      fi
      ;;
    -I"$brew_include"|-isystem"$brew_include") args+=("-idirafter" "$brew_include") ;;
    *) args+=("$1") ;;
  esac
  shift
done
exec "$cc" "${pinned[@]}" "${args[@]}"
LAUNCHER_BODY
  } > "$LAUNCHER"
  chmod +x "$LAUNCHER"
}

if [ "${1:-}" = "rapido" ]; then
  [ -f build/release/CMakeCache.txt ] || { echo "No previous build: run 'bash compilar-macos.sh' first"; exit 1; }
  # A copied CMake build still points at the original source tree. Reconfigure in
  # a fresh directory, preserving the pinned dependencies and the old build.
  CACHE="$WORK/build/release/CMakeCache.txt"
  cache_value() {
    sed -n "s/^$1:[^=]*=//p" "$CACHE"
  }
  BOOST_PREFIX="$(cache_value BOOST_ROOT)"
  PROTOBUF_PREFIX="$(cache_value Protobuf_ROOT)"
  OPENSSL_PREFIX="$(cache_value OPENSSL_ROOT_DIR)"
  [ -n "$BOOST_PREFIX" ] && [ -n "$PROTOBUF_PREFIX" ] && [ -n "$OPENSSL_PREFIX" ] || {
    echo "Missing pinned dependency paths: run 'bash compilar-macos.sh' first"; exit 1;
  }
  write_pinned_launcher
  OLD_SOURCE="$(cache_value CMAKE_HOME_DIRECTORY)"
  OLD_BUILD="$(cache_value CMAKE_CACHEFILE_DIR)"
  if [ "$OLD_SOURCE" != "$WORK" ] || [ "$OLD_BUILD" != "$WORK/build/release" ]; then
    echo "==> Project moved: configuring this copy (the first rebuild will take longer)"
    CONFIG_ARGS=()
    for key in CMAKE_BUILD_TYPE CMAKE_PREFIX_PATH BOOST_ROOT Boost_NO_SYSTEM_PATHS OPENSSL_ROOT_DIR Protobuf_ROOT ARCH USE_DEVICE_TREZOR; do
      value="$(cache_value "$key")"
      [ -z "$value" ] || CONFIG_ARGS+=("-D$key=$value")
    done
    GENERATOR="$(cache_value CMAKE_GENERATOR)"
    [ -z "$GENERATOR" ] || CONFIG_ARGS+=("-G" "$GENERATOR")
    if [ -f "$WORK/build/pinned-includes-v2.sh" ]; then
      CONFIG_ARGS+=("-DCMAKE_C_COMPILER_LAUNCHER=$WORK/build/pinned-includes-v2.sh"
                   "-DCMAKE_CXX_COMPILER_LAUNCHER=$WORK/build/pinned-includes-v2.sh")
    fi
    BACKUP="$(mktemp -d "$WORK/build/release-before-move.XXXXXX")"
    mv "$WORK/build/release" "$BACKUP/release"
    echo "==> Previous build saved in $BACKUP/release"
    cmake -S "$WORK" -B "$WORK/build/release" "${CONFIG_ARGS[@]}"
  else
    cmake -S "$WORK" -B "$WORK/build/release" \
      "-DCMAKE_C_COMPILER_LAUNCHER=$LAUNCHER" "-DCMAKE_CXX_COMPILER_LAUNCHER=$LAUNCHER"
  fi
  pkill -x monero-wallet-gui || true
  cmake --build build/release --target bundle_nym_client
  source "$WORK/firmar-macos.sh"; firmar_app "$APP"
  open "$APP"
  exit 0
fi

command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh"; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Run: xcode-select --install"; exit 1; }
git submodule update --init --recursive

echo "==> Installing dependencies with Homebrew"
brew install cmake ninja pkg-config openssl@3 unbound hidapi libusb zmq libpgm \
  libsodium expat libgcrypt qt
# monero v0.18 builds with C++14; protobuf 22+ needs C++17, so prefer protobuf@21 like the
# official macOS release build does (see DEPLOY.md).
if brew install protobuf@21 2>/dev/null; then
  PROTOBUF_PREFIX="$(brew --prefix protobuf@21)"
else
  echo "protobuf@21 is not available, falling back to the current protobuf"
  brew install protobuf
  PROTOBUF_PREFIX="$(brew --prefix protobuf)"
fi
QT_PREFIX="$(brew --prefix qt)"
# monero v0.18 still uses boost::asio::io_service, removed in Boost 1.87.
# Homebrew disabled boost@1.85 on 2026-04-05, so build it once from source into ~/.local.
if brew install boost@1.85; then
  BOOST_PREFIX="$(brew --prefix boost@1.85)"
else
  BOOST_PREFIX="$HOME/.local/boost-1.85"
fi
if [ ! -f "$BOOST_PREFIX/include/boost/version.hpp" ]; then
  echo "==> Building Boost 1.85 from source into $BOOST_PREFIX (only the first time)"
  TMPB="$(mktemp -d)"
  curl -fL --retry 3 -o "$TMPB/boost.tar.bz2" \
    https://archives.boost.io/release/1.85.0/source/boost_1_85_0.tar.bz2
  echo "7009fe1faa1697476bdc7027703a2badb84e849b7b0baad5086b087b971f8617  $TMPB/boost.tar.bz2" | shasum -a 256 -c -
  tar -xjf "$TMPB/boost.tar.bz2" -C "$TMPB"
  ( cd "$TMPB/boost_1_85_0" \
    && ./bootstrap.sh --prefix="$BOOST_PREFIX" \
         --with-libraries=system,filesystem,thread,date_time,chrono,regex,serialization,program_options,locale,atomic \
    && ./b2 -j"$JOBS" link=shared threading=multi variant=release boost.locale.icu=off \
         cxxflags=-std=c++14 install )
  rm -rf "$TMPB"
fi

# Newer Boost/protobuf/OpenSSL linked into /opt/homebrew/include and /opt/homebrew/lib get mixed
# with the pinned versions (wrong headers, missing symbols at link time). Unlink them for the
# build and link them back afterwards, even if the build fails.
RELINK=()
BREW="$(brew --prefix)"
for h in include/boost/version.hpp include/google/protobuf/message.h include/openssl/ssl.h; do
  [ -e "$BREW/$h" ] || continue
  f="$(readlink -f "$BREW/$h" | sed -n 's|.*/Cellar/\([^/]*\)/.*|\1|p')"
  [ -n "$f" ] || continue
  case " ${RELINK[*]-} " in *" $f "*) continue ;; esac
  echo "==> Temporarily unlinking $f"
  brew unlink "$f" >/dev/null && RELINK+=("$f")
done
relink() {
  for f in "${RELINK[@]+"${RELINK[@]}"}"; do
    echo "==> Linking $f back"
    brew link --force --overwrite "$f" >/dev/null || echo "Could not relink $f: run 'brew link $f'"
  done
}
trap relink EXIT
for h in include/boost/version.hpp include/google/protobuf/message.h include/openssl/ssl.h; do
  if [ -e "$BREW/$h" ]; then echo "Still found $BREW/$h after unlinking; send this output to Claude"; ls -l "$BREW/$h"; exit 1; fi
done

echo "==> Building the GUI (this takes a while)"
export PATH="$PROTOBUF_PREFIX/bin:$PATH"
# Pin OpenSSL 3 (monero v0.18 does not build against OpenSSL 4) and put Boost 1.85 headers
# ahead of any newer Boost linked into /opt/homebrew/include.
OPENSSL_PREFIX="$(brew --prefix openssl@3)"
# Homebrew's newer Boost/OpenSSL/protobuf headers are linked into /opt/homebrew/include, which
# reaches the compiler before CMAKE_CXX_FLAGS. A compiler launcher puts the pinned ones first.
write_pinned_launcher
PIN=("-DCMAKE_C_COMPILER_LAUNCHER=$LAUNCHER" "-DCMAKE_CXX_COMPILER_LAUNCHER=$LAUNCHER")
rm -rf build/release   # start clean: an earlier run may have cached other versions
cmake -S . -B build/release -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D ARCH=default \
  -D CMAKE_PREFIX_PATH="$BOOST_PREFIX;$QT_PREFIX;$PROTOBUF_PREFIX;$(brew --prefix openssl@3)" \
  -D BOOST_ROOT="$BOOST_PREFIX" -D Boost_NO_SYSTEM_PATHS=ON \
  -D OPENSSL_ROOT_DIR="$OPENSSL_PREFIX" \
  "${PIN[@]}" \
  -D Protobuf_ROOT="$PROTOBUF_PREFIX" \
  -D USE_DEVICE_TREZOR=ON
pkill -x monero-wallet-gui || true
cmake --build build/release -j "$JOBS"
if [ "${EMPAQUETAR:-0}" = "1" ]; then
  cmake --build build/release --target deploy || echo "WARNING: packaging (deploy) failed; the app in build/release/bin still runs on this Mac"
fi

source "$WORK/firmar-macos.sh"; firmar_app "$APP"

echo
echo "Done: $APP"
echo "Close Trezor Suite before opening the wallet: the Safe 7 is used directly over USB."
echo "Next time, after changing QML, images or styles: bash compilar-macos.sh rapido"
open "$APP"
