# Nym connection regression checks

Run from the monero-gui repository:

```sh
node tests/nym_lifecycle.cjs
cmake -S tests/connection_probe -B build/connection-probe-tests -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt
cmake --build build/connection-probe-tests
ctest --test-dir build/connection-probe-tests --output-on-failure
```

The normal tests use an ephemeral loopback HTTP server, not the Internet or NymVPN.
They cover chunked responses, redirects, HTTP errors, partial downloads, timeouts,
cancellation and node launch defaults. The lifecycle tests mock the independent
helper interface; they do not modify the installed service or account. For the
process lifecycle tests, see external/nym-client/README.md.

An optional real 64 kB download uses only the explicit SOCKS5 proxy:

```sh
build/connection-probe-tests/connection_probe_tests --nym-probe 127.0.0.1:17890
```

There is no direct fallback. A disabled proxy produces a connection error.

## Applying the node changes

Reopen the newly built wallet and restart **the local Monero node** to use the
new monerod executable and flags. Reconnecting the wallet alone cannot update an
already running node. The new wallet never stops/restarts Nym's shared service
or disables its SOCKS5 listener. The independent helper stops when the wallet
exits. It uses no NymVPN account. Restart an older node once to change its proxy
from port 1080 to 17890.

For Nym, the wallet defaults to four outbound peers and batches of five blocks,
unless the user supplied these options explicitly. The node allows 60 seconds
for a proxy handshake and 120 seconds for a proxied public peer's block response;
direct connections retain their original limits. These changes tolerate slow
routes; they cannot guarantee throughput or a particular exit route.
