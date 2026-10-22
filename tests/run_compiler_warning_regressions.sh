#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="${1:-build/release}"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/xmr-warning-tests.XXXXXX")"
# Header ownership paths are instrumented; production epee is tested as built.
clang++ -std=c++14 -fsanitize=address,undefined -fno-sanitize-recover=all -g \
  -I monero/contrib/epee/include -I monero/external/rapidjson/include \
  -I monero/external/easylogging++ -I /opt/homebrew/opt/openssl@3/include \
  -isystem /opt/homebrew/opt/boost@1.85/include \
  tests/compiler_warning_regressions.cpp \
  "$build_dir/monero/contrib/epee/src/libepee.a" \
  "$build_dir/monero/external/easylogging++/libeasylogging.a" \
  -L /opt/homebrew/opt/openssl@3/lib -lssl -lcrypto \
  -L /opt/homebrew/opt/boost@1.85/lib -lboost_filesystem -lboost_thread-mt \
  -o "$test_dir/compiler_warning_regressions"
"$test_dir/compiler_warning_regressions"
