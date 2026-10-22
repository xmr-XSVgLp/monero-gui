# Authenticated wallet-owned Nym client

The helper integrates the official NymVPN 2026.13.0 account controller and its
matching Nym core revision 2631de5b04b1e5b300729c4af8d48f5783db865f.
Both source archives are SHA-256 pinned in build.sh. The helper is GPL-3.0-only;
upstream components retain their respective licenses. NYM-LICENSE accompanies
its executable in the app.

The wallet requires the user's NymVPN 24-word account phrase. The account
controller checks the subscription and registers a separate device. SDK
credentials mode is mandatory, using the account controller's bandwidth
provider. There is no fallback to the previous unauthenticated SDK mode.

The phrase travels through the child process's stdin, never command-line
arguments, settings, wallet cache or the packaged app. Connecting automatically remembers the phrase in a JSON file at
~/Monero/xmr-wallet-plus/nym.conf (beside the price CSVs), using atomic replacement
and owner-only read/write permissions. The phrase is plaintext in this file.
The panel has a two-line phrase input. The connected device ID opens the
account dialog, where the phrase can be revealed and logout disconnects while retaining the account and device identity.
The removed local device name is discarded when saving the config. DNS customization is not exposed for the SOCKS5 mode.
An explicit migration action copies the legacy Keychain phrase to the file and
removes that Keychain item only after successful saving. New secrets are never
written to Keychain. The phrase is retained for retries even if a connection attempt fails. Device keys and bandwidth credentials are stored under the wallet's
AppLocalDataLocation/nym-account-v1, outside the app bundle. Forget stops the
owned child, removes this directory, nym.conf and any legacy dedicated Keychain item, and clears
the in-memory phrase. It does not revoke the device remotely: the user can
remove the device in the Nym account portal.

The wallet owns loopback SOCKS5 port 17890 and refuses to adopt an occupied port.
Reconnect closes its previous child before launching a different exit. A failed
connection keeps traffic blocked. Explicit Disconnect restores previous proxy
settings; Nym required continues to block traffic. No official NymVPN service,
account files or connections are controlled. Closing the wallet closes its proxy;
a local node using it waits until the wallet reconnects.

## Build and checks

`bash compilar-macos.sh rapido` builds the helper and wallet as usual. The first
build downloads pinned sources and an isolated Rust 1.99.1 toolchain into build/.
Python 3.11+ is required by prepare.py. To build without closing the running app:

```sh
bash external/nym-client/build.sh
cmake -S . -B build/release
cmake --build build/release --target bundle_nym_client -j4
```

Use the project's signing and packaging scripts afterwards.

```sh
node tests/nym_lifecycle.cjs
cmake -S tests/nym_client -B /private/tmp/xmr-auth-tests -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt
cmake --build /private/tmp/xmr-auth-tests
/private/tmp/xmr-auth-tests/nym_client_tests
```

Tests use a fake helper and isolated JSON account store; they never read the real
Keychain or contact Nym. They cover missing accounts, protocol authentication,
port collisions, reconnect ordering, cancellation and forgetting credentials.
End-to-end paid authentication requires entering a valid subscription account
in the wallet UI. Never put a recovery phrase in a shell command or test log.
