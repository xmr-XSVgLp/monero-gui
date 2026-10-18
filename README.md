# XMR Wallet+ (unofficial Monero GUI fork)

> **This is an unofficial, community fork of the [Monero GUI](https://github.com/monero-project/monero-gui).
> It is not made, reviewed or endorsed by The Monero Project, by Trezor / SatoshiLabs or by Nym.**
> It handles real money: it is **experimental**, use it at your own risk and test with small amounts first.

XMR Wallet+ is the official Monero GUI with Trezor Safe 7 support, a privacy toolkit (NymVPN, connection
check, node manager, extreme privacy mode, security center), market data, encrypted notes and a Matrix-style
interface. It tracks upstream `monero-gui` **master** and Monero **v0.18.5.4**.

Tested on **macOS (Apple Silicon) with a Trezor Safe 7**, over USB and Bluetooth. Older Trezor models, Ledger
and other platforms are untested. The interface is available in English and Spanish.

## Official Monero GUI vs XMR Wallet+

| Feature | Monero GUI (official) | XMR Wallet+ |
|---|:---:|:---:|
| Send, receive, history, address book, subaddresses, accounts | ✅ | ✅ |
| Local node, remote nodes, bootstrap node, P2Pool mining | ✅ | ✅ |
| Simple / advanced modes, merchant view, sign / verify, proofs | ✅ | ✅ |
| Hardware wallets: Ledger and older Trezor (via Trezor Bridge) | ✅ | ⚠️ untested |
| **Trezor Safe 7** (Trezor Host Protocol, Noise-encrypted channel) | ❌ | ✅ |
| Trezor over **Bluetooth** | ❌ | ✅ (macOS) |
| Trezor passphrase entered on the device | ✅ | ✅ (also on the Safe 7) |
| Trezor device name shown in the title bar | ❌ | ✅ |
| SOCKS5 proxy (Tor, I2P…) | ✅ | ✅ |
| **NymVPN mixnet** for this app only, including the local node's P2P traffic | ❌ | ✅ |
| "Nym required" kill switch (nothing connects while Nym is down) | ❌ | ✅ |
| **Connection check** (exit IP, latency, speed, P2P reachability, node health) | ❌ | ✅ |
| List of every outside connection the wallet makes, and its route | ❌ | ✅ |
| Live list of the local node's peers (IP, in/out, height) | ❌ | ✅ |
| **Node manager** scored by availability, freshness, version and stability, with favourites and rotation | ❌ | ✅ |
| **Extreme privacy mode** (no prices, no update checks, sync blocked without an approved route) | ❌ | ✅ |
| **Security center** (file permissions, password strength, backups, node, session) | ❌ | ✅ |
| One-click backup of all wallet files to a folder | ❌ | ✅ |
| **Wallets on USB / SD**: open from the drive, save a copy to the drive | ❌ | ✅ |
| Used addresses flagged in red, copy blocked, optional hiding (no address reuse) | ❌ | ✅ |
| **Encrypted notes** tied to the wallet (and to the Trezor on hardware wallets) | ❌ | ✅ |
| Balance in fiat | ✅ | ✅ (Kraken / CoinPaprika, with 24 h and 7 d change) |
| **Trading data**: XMR/EUR, XMR/USD, XMR/BTC charts, wallet value over time, converter | ❌ | ✅ |
| **Price alerts** with system notifications | ❌ | ✅ |
| **Swaps** comparison: Wagyu, NonKYC and ChangeNOW, best routes, price history in CSV | ❌ | ✅ |
| Themes | Dark / light | Matrix dark / grey light, with optional effects |
| Languages | 40+ | English and Spanish (other languages show the new texts in English) |
| Platforms | Windows, macOS, Linux | macOS tested; others build from the same code, untested |
| Ready-to-run download | ✅ | ✅ macOS app in [Releases](https://github.com/xmr-XSVgLp/monero-gui/releases) |
| Signed and reproducible builds | ✅ | ❌ unsigned macOS app (see below how to open it) |

## What is new in XMR Wallet+

### Trezor Safe 7
- **USB and Bluetooth.** The Safe 7 uses the Trezor Host Protocol (THP, a Noise-encrypted channel) that the
  official Monero code does not speak yet. The [`safe7-thp` branch of the monero fork](https://github.com/xmr-XSVgLp/monero/tree/safe7-thp)
  adds THP over USB and over Bluetooth (CoreBluetooth on macOS), first-time pairing with the 6-digit code shown
  on the device, and passphrase entry on the device.
- The Trezor's name is shown in the title bar next to the wallet name.
- Close Trezor Suite before opening the wallet: the Safe 7 is used directly, not through Trezor Bridge.

### Wallet+ menu
A blue section below Settings groups the extra pages: an overview page with links, **Trading data** and
**Swaps** (only when price conversion is on), **Notes** and **Security**.

### Security page (Wallet+ → Security)
Four tabs:
- **Connections**: every service the wallet contacts (node, prices, trading data, swaps, update check, NymVPN,
  connection check, node manager, links), when it does it and which route it takes (Nym, proxy, direct or
  blocked). A button lists the local node's peers with their IP, direction and height. It also explains what a
  remote node can learn about you, and what it never sees.
- **Nodes**: a node manager that measures availability, freshness against the network, version, stability and
  latency through the app's current route. Speed counts only 10 % of the score, so a fast node that fails or lags
  does not win. Favourites, your own list, per-node test, "Use", and manual rotation to a random good node.
- **Extreme privacy**: one switch that turns off price queries, swaps, trading data and update checks, and lets
  traffic out only through NymVPN or the SOCKS5 proxy. Without an approved route the wallet does not sync and
  the local node does not start; with one, monerod starts with `--proxy`, `--no-igd`, `--hide-my-port` and no
  bootstrap node. Turning it off restores the previous settings.
- **Security center**: a score out of 6 covering wallet file permissions (with a "Fix permissions" button,
  600/700), password strength (never shown), backups, node connection, network privacy and session protection.
  It never reads or shows your keys.

### Backups and wallets on USB / SD
- **Save…** copies the wallet files (keys, cache with labels and history, encrypted notes) into
  `<folder>/xmr_<wallet name>/`, with the original names so the wallet opens straight from there.
- **Save to …** (one button per connected drive) does the same on a USB stick or SD card, in `XMR/xmr_<wallet name>/`.
- When you open a wallet from file, wallets found in the `XMR` folder of any connected USB / SD drive appear in
  a **USB / SD wallets** section above "Recently opened". The list updates while the page is open. Plug the drive
  in, open the wallet, close it, unplug: while unplugged the wallet is on no computer.

### Receive
- Addresses that already received a transaction are shown in red, their copy buttons are disabled and a warning
  offers to create a new address, to avoid address reuse.
- **Hide used addresses** removes them from the list.

### Privacy and network
- **NymVPN panel** on the welcome page and in Settings → Node / Network. It sends only this app's traffic
  through the Nym mixnet using NymVPN's SOCKS5 proxy (`nym-vpnc`), including the local node's P2P traffic.
  A new random exit is picked on every start; you can restart the route, see it, and set **Nym required**.
- **Connection check** in the "Local node" card: current IP, proxy, latency, speed, reachability of Monero seed
  nodes and node status. It runs when you press the button, and once 20 seconds after Nym connects.
- **Privacy chips** in the title bar: Nym, remote/local node and Trezor status at a glance.
- **Settings → Node / Network** groups node, NymVPN, price conversion and proxy options. The daemon button reads
  "Start daemon" / "Stop daemon" and turns red while the daemon runs.
- With price conversion off, the app makes no price or exchange requests at all.

### Trading data and swaps (only when price conversion is on)
- XMR/EUR, XMR/USD and XMR/BTC charts from CoinGecko for 24H, 7D, 30D, 90D, 1Y and MAX, cached as CSV under
  `~/Monero/xmr-wallet-plus/trading/` and refreshed every 15 minutes.
- Value of the current wallet over time, a converter, and **price alerts** with a macOS notification.
- **Swaps**: quotes from Wagyu, NonKYC and ChangeNOW side by side, the best cross-exchange routes and a comparison
  with earlier prices. Every refresh is saved to `~/Monero/xmr-wallet-plus/precios-swaps.csv`.

### Encrypted notes
- **Notes** page for private notes stored next to the wallet as `<wallet name>_notes`.
- Encrypted with AES-256-GCM using a key derived from the wallet keys. They open without asking for a password
  once the wallet is open, and lock when the wallet closes.
- On Trezor wallets the key also needs the device: the Trezor confirms "XMR Wallet+ notes" (SLIP-0011), so the
  file cannot be opened without that Trezor and passphrase.

### Look and feel
- **Matrix / cypherpunk theme**: dark neon theme with white text, redesigned pages, cards, dialogs and icons,
  and a softer grey light theme.
- Optional effects (Matrix rain in both themes, boot screen, page glitch, UI sounds) in
  *Settings → Interface*.

## Download (macOS)

Download `XMR-wallet+-macos.zip` from [Releases](https://github.com/xmr-XSVgLp/monero-gui/releases), unzip it
and move `XMR-wallet+.app` to Applications. The app is **not signed or notarized**, so macOS blocks it the first
time. Run this once in Terminal, then open it normally:
```
xattr -dr com.apple.quarantine /Applications/XMR-wallet+.app
```
It is built for Apple Silicon and includes everything it needs (no Homebrew required). If you prefer not to
trust a binary built by someone else, build it yourself as described below.

## Building (macOS)

```
git clone --recursive -b safe7-matrix https://github.com/xmr-XSVgLp/monero-gui.git
cd monero-gui
bash compilar-macos.sh          # first build: installs Homebrew dependencies and builds
bash compilar-macos.sh rapido   # later rebuilds
```
`compilar-macos.sh` pins OpenSSL 3, Boost 1.85 and protobuf 21, because Monero v0.18 does not build with newer
versions. The app ends up in `build/release/bin`.

To copy the app to another Mac, run `bash empaquetar-macos.sh`. It creates `dist/XMR-wallet+.app` and
`dist/XMR-wallet+-macos.zip`, which do not need Homebrew. On the other Mac, run
`xattr -dr com.apple.quarantine XMR-wallet+.app` once before opening it.

NymVPN is optional: install the NymVPN app (with `nym-vpnc` 2026.13 or newer) to use the Nym panel.

## License

Same as upstream: BSD 3-Clause, see [LICENSE](LICENSE). Copyright (c) 2014-2024, The Monero Project,
plus the contributors of this fork. "Monero", "Trezor" and "Nym" are used only to describe compatibility;
they are trademarks of their respective owners.

---

*The original README of the Monero GUI follows.*

# Monero GUI

Copyright (c) 2014-2024, The Monero Project

## Table of Contents
  * [Development resources](#development-resources)
  * [Vulnerability response](#vulnerability-response)
  * [Introduction](#introduction)
  * [About this project](#about-this-project)
  * [Supporting the project](#supporting-the-project)
  * [License](#license)
  * [Translations](#translations)
  * [Installing the Monero GUI from a package](#installing-the-monero-gui-from-a-package)
  * [Compiling the Monero GUI from source](#compiling-the-monero-gui-from-source)
    + [Building Reproducible Windows static binaries with Docker (any OS)](#building-reproducible-windows-static-binaries-with-docker-any-os)
    + [Building Reproducible Linux static binaries with Docker (any OS)](#building-reproducible-linux-static-binaries-with-docker-any-os)
    + [Building Android APK with Docker (any OS) *Experimental*](#building-android-apk-with-docker-any-os-experimental)
    + [Building on Linux](#building-on-linux)
    + [Building on OS X](#building-on-os-x)
    + [Building on Windows](#building-on-windows)

## Development resources

- Web: [getmonero.org](https://getmonero.org)
- Mail: [dev@getmonero.org](mailto:dev@getmonero.org)
- Github: [https://github.com/monero-project/monero-gui](https://github.com/monero-project/monero-gui)
- IRC: [#monero-gui on Libera](irc://irc.libera.chat/#monero-gui)
- Translation platform (Weblate): [translate.getmonero.org](https://translate.getmonero.org)
- UI Design: [Monero-GUI on Figma](https://www.figma.com/file/DplJ2DDQfIKiuRvolHX2hN/Monero-GUI)

## Vulnerability response

- Our [Vulnerability Response Process](https://github.com/monero-project/meta/blob/master/VULNERABILITY_RESPONSE_PROCESS.md) encourages responsible disclosure
- We are also available via [HackerOne](https://hackerone.com/monero)

## Introduction

Monero is a private, secure, untraceable, decentralised digital currency. You are your bank, you control your funds, and nobody can trace your transfers unless you allow them to do so.

**Privacy:** Monero uses a cryptographically sound system to allow you to send and receive funds without your transactions being easily revealed on the blockchain (the ledger of transactions that everyone has). This ensures that your purchases, receipts, and all transfers remain absolutely private by default.

**Security:** Using the power of a distributed peer-to-peer consensus network, every transaction on the network is cryptographically secured. Individual wallets have a 25 word mnemonic seed that is only displayed once, and can be written down to backup the wallet. Wallet files are encrypted with a passphrase to ensure they are useless if stolen.

**Untraceability:** By taking advantage of ring signatures, a special property of a certain type of cryptography, Monero is able to ensure that transactions are not only untraceable, but have an optional measure of ambiguity that ensures that transactions cannot easily be tied back to an individual user or computer.

## About this project

This is the GUI for the [core Monero implementation](https://github.com/monero-project/monero). It is open source and completely free to use without restrictions, except for those specified in the license agreement below. There are no restrictions on anyone creating an alternative implementation of Monero that uses the protocol and network in a compatible manner.

As with many development projects, the repository on Github is considered to be the "staging" area for the latest changes. Before changes are merged into that branch on the main repository, they are tested by individual developers in their own branches, submitted as a pull request, and then subsequently tested by contributors who focus on testing and code reviews. That having been said, the repository should be carefully considered before using it in a production environment, unless there is a patch in the repository for a particular show-stopping issue you are experiencing. It is generally a better idea to use a tagged release for stability.

## Supporting the project

Monero is a 100% community-sponsored endeavor. If you want to join our efforts, the easiest thing you can do is support the project financially. Both Monero and Bitcoin donations can be made to **donate.getmonero.org** if using a client that supports the [OpenAlias](https://openalias.org) standard.

The Monero donation address is: `888tNkZrPN6JsEgekjMnABU4TBzc2Dt29EPAvkRxbANsAnjyPbb3iQ1YBRk1UXcdRsiKc9dhwMVgN5S9cQUiyoogDavup3H` (viewkey: `f359631075708155cc3d92a32b75a7d02a5dcf27756707b47a2b31b21c389501`)

The Bitcoin donation address is: `1KTexdemPdxSBcG55heUuTjDRYqbC5ZL8H`

GUI development funding and/or some supporting services are also graciously provided by [sponsors](https://www.getmonero.org/community/sponsorships/):

[<img width="150" src="https://www.getmonero.org/img/sponsors/tarilabs.png"/>](https://tarilabs.com/)
[<img width="150" src="https://www.getmonero.org/img/sponsors/symas.png"/>](https://symas.com/)
[<img width="150" src="https://www.getmonero.org/img/sponsors/macstadium.png"/>](https://www.macstadium.com/)

There are also several mining pools that kindly donate a portion of their fees, [a list of them can be found on our Bitcointalk post](https://bitcointalk.org/index.php?topic=583449.0).

## License

See [LICENSE](LICENSE).

## Translations

Do you speak a second language and would like to help translate the Monero GUI? Check out Weblate, our localization platform, at [translate.getmonero.org](https://translate.getmonero.org/). Choose the language and suggest a translation for a string or review an existing one. The Localization Workgroup made [a guide with step-by-step instructions](https://github.com/monero-ecosystem/monero-translations/blob/master/weblate.md) for Weblate.

If you need help/support or any info you can contact the localization workgroup on the IRC channel #monero-translations (relayed on [Matrix](https://matrix.to/#/!BKMbQLMDzHKzmtrBfg:matrix.org?via=monero.social&via=matrix.org&via=libera.chat)) or by email at translate[at]getmonero[dot]org. For more info about the Localization workgroup: [github.com/monero-ecosystem/monero-translations](https://github.com/monero-ecosystem/monero-translations)

Status of the translations:  

<a href="https://translate.getmonero.org/engage/monero/?utm_source=widget">
<img src="https://translate.getmonero.org/widgets/monero/-/gui-wallet/horizontal-auto.svg" alt="Translation status" />
</a>

## Installing the Monero GUI from a package

Packages are available for
* Arch Linux: [monero-gui](https://archlinux.org/packages/extra/x86_64/monero-gui/)
* NixOS: `nix-shell -p monero-gui`
* Flatpak: [Monero GUI](https://flathub.org/apps/details/org.getmonero.Monero)
* GuixSD: `guix package -i monero-gui`
* macOS (homebrew): `brew install --cask monero-wallet`

Packaging for your favorite distribution would be a welcome contribution!

## Compiling the Monero GUI from source

*Note*: Qt 6.8 is the minimum version required to build the GUI.

*Note*: Official GUI releases use monero-wallet-gui from this process alongside the supporting binaries (monerod, etc) from the [CLI deterministic builds](https://github.com/monero-project/monero/blob/release-v0.18/contrib/gitian/README.md).

*Note*: The convenience targets in the project Makefile require the Ninja build system. Other CMake generators can still be used by invoking CMake directly. Ninja builds in parallel by default. To limit or set the number of parallel build jobs, set `CMAKE_BUILD_PARALLEL_LEVEL`, for example `CMAKE_BUILD_PARALLEL_LEVEL=4 make release`.

### Building Reproducible Windows static binaries with Docker (any OS)

1. Install Docker [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)
2. Clone the repository
   ```
   git clone --branch master --recursive https://github.com/monero-project/monero-gui.git
   ```
   \* `master` - replace with the desired version tag (e.g. `v0.18.5.4`) to build the release binaries.
3. Prepare build environment
   ```
   cd monero-gui
   docker build --tag monero:build-env-windows --build-arg THREADS=4 --file Dockerfile.windows .
   ```
   \* `4` - number of CPU threads to use

4. Build
   ```
   docker run --rm -it -v <MONERO_GUI_DIR_FULL_PATH>:/monero-gui -w /monero-gui monero:build-env-windows sh -c 'make depends root=/depends target=x86_64-w64-mingw32 tag=win-x64'
   ```
   \* `<MONERO_GUI_DIR_FULL_PATH>` - absolute path to `monero-gui` directory  
   \* Set `CMAKE_BUILD_PARALLEL_LEVEL` to control the number of parallel build jobs, e.g. add `-e CMAKE_BUILD_PARALLEL_LEVEL=4` to the `docker run` command
5. Monero GUI Windows static binaries will be placed in  `monero-gui/build/x86_64-w64-mingw32/release/bin` directory

### Building Reproducible Linux static binaries with Docker (any OS)

1. Install Docker [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)
2. Clone the repository
   ```
   git clone --branch master --recursive https://github.com/monero-project/monero-gui.git
   ```
   \* `master` - replace with the desired version tag (e.g. `v0.18.5.4`) to build the release binaries.
3. Prepare build environment
   ```
   cd monero-gui
   docker build --tag monero:build-env-linux --build-arg THREADS=4 --file Dockerfile.linux .
   ```
   \* `4` - number of CPU threads to use

   The image builds the non-Qt dependencies with Monero's `contrib/depends`
   system and installs Qt into the resulting `/depends/x86_64-linux-gnu`
   prefix.

4. Build
   ```
   docker run --rm -it -v <MONERO_GUI_DIR_FULL_PATH>:/monero-gui -w /monero-gui monero:build-env-linux sh -c 'make depends root=/depends target=x86_64-linux-gnu tag=linux-x64'
   ```
   \* `<MONERO_GUI_DIR_FULL_PATH>` - absolute path to `monero-gui` directory  
   \* Set `CMAKE_BUILD_PARALLEL_LEVEL` to control the number of parallel build jobs, e.g. add `-e CMAKE_BUILD_PARALLEL_LEVEL=4` to the `docker run` command

5. Monero GUI Linux static binary will be placed in `monero-gui/build/x86_64-linux-gnu/release/bin` directory
6. (*Note*) This process is only for building `monero-wallet-gui`, `monerod` has to be built separately according to the instructions in the `monero` repository.
7. (*Optional*) Compare `monero-wallet-gui` SHA-256 hash to the one obtained from a trusted source
   ```
   docker run --rm -it -v <MONERO_GUI_DIR_FULL_PATH>:/monero-gui -w /monero-gui monero:build-env-linux sh -c 'shasum -a 256 /monero-gui/build/x86_64-linux-gnu/release/bin/monero-wallet-gui'
   ```
   \* `<MONERO_GUI_DIR_FULL_PATH>` - absolute path to `monero-gui` directory  

### Building Android APK with Docker (any OS) *Experimental*
 - Minimum Android 9 Pie (API 28)
 - ARMv8-A 64-bit CPU
1. Install Docker [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)
2. Clone the repository
   ```
   git clone --recursive https://github.com/monero-project/monero-gui.git
   ```
3. Prepare build environment
   ```
   cd monero-gui
   docker build --tag monero:build-env-android --build-arg THREADS=4 --file Dockerfile.android .
   ```
   \* `4` - number of CPU threads to use

4. Build
   ```
   docker run --rm -it -v <MONERO_GUI_DIR_FULL_PATH>:/monero-gui monero:build-env-android
   ```
   \* `<MONERO_GUI_DIR_FULL_PATH>` - absolute path to `monero-gui` directory  
   \* Set `CMAKE_BUILD_PARALLEL_LEVEL` to control the number of parallel build jobs, e.g. add `-e CMAKE_BUILD_PARALLEL_LEVEL=4` to the `docker run` command
5. Monero GUI APK will be placed in  `monero-gui/build/Android/release/android-build` directory
6. Deploy
   * Using ADB (Android debugger bridge)
     - [Enable adb debugging on your device](https://developer.android.com/studio/command-line/adb.html#Enabling)
      * Connect your device with USB and install Monero GUI APK with adb:
      ```
      adb install build/Android/release/android-build/monero-gui.apk
      ```
      * Troubleshooting:
      ```
      adb devices -l
      adb logcat
      ```
      * If using adb inside docker, make sure you did
      ```
      docker run -v /dev/bus/usb:/dev/bus/usb --privileged
      ```
   * Using a web server
      ```
      mkdir /usr/tmp
      cp build/Android/release/android-build/monero-gui.apk /usr/tmp
      docker run -d -v /usr/tmp:/usr/share/nginx/html:ro -p 8080:80 nginx
      ```
      Now it should be accessible through a web browser at
      ```
      http://<your.local.ip>:8080/QtApp-debug.apk
      ```

### Comparing Docker Qt build times

`Dockerfile.linux`, `Dockerfile.windows`, and `Dockerfile.android` enable Qt unity
builds by default. Add `--build-arg QT_UNITY_BUILD=OFF` to disable them, or
`--build-arg QT_UNITY_BUILD=ON` to enable them explicitly. Use the same setting
when comparing reproducible binary hashes.

To compare fresh Qt builds, run both variants sequentially on the same builder
with the same CPU and memory allocation, thread count, and platform. For example,
from the repository root on an amd64 builder:

```sh
docker build --no-cache --progress=plain --platform linux/amd64 \
  --build-arg THREADS=4 --build-arg QT_UNITY_BUILD=OFF \
  --tag monero:build-env-linux-unity-off --file Dockerfile.linux . \
  > qt-unity-off.log 2>&1
docker build --no-cache --progress=plain --platform linux/amd64 \
  --build-arg THREADS=4 --build-arg QT_UNITY_BUILD=ON \
  --tag monero:build-env-linux-unity-on --file Dockerfile.linux . \
  > qt-unity-on.log 2>&1
```

Compare the Qt build step durations in the two logs as well as total image build
time; downloads and other dependencies can affect the total. For Windows or
Android, substitute the corresponding Dockerfile and image tags, and include
both the host-tools and target Qt build steps in the comparison.

### Building on Linux

1. Install Monero dependencies

  - For Debian distributions (Debian, Ubuntu, Mint, Tails...)

	`sudo apt install build-essential cmake ninja-build libunbound-dev graphviz doxygen pkg-config libssl-dev libzmq3-dev libsodium-dev libhidapi-dev libnorm-dev libusb-1.0-0-dev libpgm-dev libprotobuf-dev protobuf-compiler libgcrypt20-dev libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev libboost-locale-dev libboost-program-options-dev libboost-regex-dev libboost-serialization-dev libboost-system-dev libboost-thread-dev`

  - For Gentoo

	`sudo emerge app-arch/xz-utils app-doc/doxygen dev-build/ninja dev-cpp/gtest dev-libs/boost dev-libs/expat dev-libs/openssl dev-util/cmake media-gfx/graphviz net-dns/unbound net-libs/zeromq dev-libs/libsodium dev-libs/hidapi dev-libs/libgcrypt`

  - For Fedora

	`sudo dnf install make automake cmake ninja gcc-c++ boost-devel graphviz doxygen unbound-devel pkgconfig openssl-devel libcurl-devel hidapi-devel libusb-devel zeromq-devel libgcrypt-devel`

2. Install Qt:

  *Note*: The Qt 6.8 or newer requirement makes **some** distributions obsolete due to their repositories containing an older Qt version.

 The recommended way is to install 6.8 or newer from the [official Qt installer](https://www.qt.io/download-qt-installer) or [compiling it yourself](https://doc.qt.io/qt-6/build-sources.html). This ensures you have the correct version. Higher versions *can* work but as it differs from our production build target, slight differences may occur.

The following instructions will fetch Qt from your distribution's repositories instead. Take note of what version it installs. Your mileage may vary.

  - For Debian distributions (Debian, Ubuntu, Mint, Tails...)

    `sudo apt install qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-tools-dev qt6-tools-dev-tools qml6-module-qtcore qml6-module-qtqml qml6-module-qtqml-models qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-dialogs qml6-module-qtquick-effects qml6-module-qtquick-layouts qml6-module-qtquick-shapes qml6-module-qtquick-window qml6-module-qt-labs-folderlistmodel qml6-module-qt-labs-platform`

  - For Gentoo
  
   
    The *qml* USE flag must be enabled.

    `sudo emerge dev-qt/qtbase:6 dev-qt/qtdeclarative:6 dev-qt/qtsvg:6 dev-qt/qttools:6`

  - Optional : To build the flag `WITH_SCANNER`

    - For Debian distributions (Debian, Ubuntu, Mint, Tails...)

      `sudo apt install qt6-multimedia-dev qml6-module-qtmultimedia`

    - For Gentoo      

      `emerge dev-qt/qtmultimedia:6`


3. Clone repository

    ```
    git clone --recursive https://github.com/monero-project/monero-gui.git
    cd monero-gui
    ```

4. Build

    ```
    make release
    ```

    \* Add `CMAKE_PREFIX_PATH` environment variable to set a custom Qt install directory, e.g. `CMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/gcc_64 make release`
    \* Set `CMAKE_BUILD_PARALLEL_LEVEL` to control the number of parallel build jobs, e.g. `CMAKE_BUILD_PARALLEL_LEVEL=4 make release`

The executable can be found in the build/release/bin folder.

### Building on OS X

1. Install Xcode from AppStore

2. Install [homebrew](http://brew.sh/)

3. Install [monero](https://github.com/monero-project/monero) dependencies:

  `brew install cmake ninja pkg-config openssl boost unbound hidapi zmq libpgm libsodium expat protobuf libgcrypt`

4. Install Qt:

  `brew install qt`  (or download Qt 6.8+ from [qt.io](https://www.qt.io/download-open-source/))

5. Grab an up-to-date copy of the monero-gui repository

   ```
   git clone --recursive https://github.com/monero-project/monero-gui.git
   cd monero-gui
   ```

6. Start the build

    ```
    make release
    ```
    \* Add `CMAKE_PREFIX_PATH` environment variable to set a custom Qt install directory, e.g. `CMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/macos make release`
    \* Set `CMAKE_BUILD_PARALLEL_LEVEL` to control the number of parallel build jobs, e.g. `CMAKE_BUILD_PARALLEL_LEVEL=4 make release`

The executable can be found in the `build/release/bin` folder.

For building an application bundle see `DEPLOY.md`.

### Building on Windows

The Monero GUI on Windows is 64 bits only; 32-bit Windows GUI builds are not officially supported anymore.

1. Install [MSYS2](https://www.msys2.org/), follow the instructions on that page on how to update system and packages to the latest versions

2. Open an 64-bit MSYS2 shell: Use the *MSYS2 MinGW 64-bit* shortcut, or use the `msys2_shell.cmd` batch file with a `-mingw64` parameter

3. Install MSYS2 packages for Monero dependencies; the needed 64-bit packages have `x86_64` in their names

    ```
    pacman -S mingw-w64-x86_64-toolchain make mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-boost mingw-w64-x86_64-openssl mingw-w64-x86_64-zeromq mingw-w64-x86_64-libsodium mingw-w64-x86_64-hidapi mingw-w64-x86_64-protobuf-c mingw-w64-x86_64-libusb mingw-w64-x86_64-libgcrypt mingw-w64-x86_64-unbound mingw-w64-x86_64-pcre mingw-w64-x86_64-angleproject
    ```

    You find more details about those dependencies in the [Monero documentation](https://github.com/monero-project/monero). Note that that there is no more need to compile Boost from source; like everything else, you can install it now with a MSYS2 package.

4. Install Qt6

    ```
    pacman -S mingw-w64-x86_64-qt6-base mingw-w64-x86_64-qt6-declarative mingw-w64-x86_64-qt6-svg mingw-w64-x86_64-qt6-tools
    ```

    There is no more need to download some special installer from the Qt website, the standard MSYS2 package for Qt will do in almost all circumstances.

5. Install git

    ```
    pacman -S git
    ```

6. Clone repository

    ```
    git clone --recursive https://github.com/monero-project/monero-gui.git
    cd monero-gui
    ```

7. Build

    ```
    make release-win64
    cd build/release
    cmake --build . --target deploy
    ```
    \* Set `CMAKE_BUILD_PARALLEL_LEVEL` to control the number of parallel build jobs, e.g. `CMAKE_BUILD_PARALLEL_LEVEL=4 make release-win64`

The executable can be found in the `.\bin` directory.
