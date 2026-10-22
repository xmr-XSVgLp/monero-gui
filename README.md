# XMR Wallet+ (unofficial Monero GUI fork)

> **This is an unofficial, community fork of the [Monero GUI](https://github.com/monero-project/monero-gui).
> It is not made, reviewed or endorsed by The Monero Project, by Trezor / SatoshiLabs or by Nym.**
> It handles real money: it is **experimental**, use it at your own risk and test with small amounts first.

XMR Wallet+ is the official Monero GUI with Trezor Safe 7 support, built-in Nym, Tor and I2P with configurable private routes, a privacy toolkit (connection check, node manager, spy-node ban list, extreme privacy mode, security
center), several wallets open and syncing at once, address mining, address groups and scheduled sends, market data,
encrypted notes, macOS menu bar and desktop widgets, and a Matrix / cyberpunk interface.
It tracks upstream `monero-gui` **master** and Monero **v0.18.5.4**.

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
| **Trezor settings** from the wallet: name, homescreen gallery, brightness, haptics, auto-lock | ❌ | ✅ (Safe 7, Safe 5 and Safe 3 homescreens) |
| Pick which Trezor to use when several are connected | ❌ | ✅ |
| Cancel a Trezor confirmation from the app (e.g. if the device freezes) | ❌ | ✅ |
| **Several wallets open at once**, syncing in the background, switch without the password | ❌ | ✅ |
| **Seed accounts**: extra wallets (addresses starting with 4) from the same seed + passphrase 1, 2, 3… | ❌ | ✅ |
| SOCKS5 proxy (Tor, I2P…) | ✅ | ✅ |
| **Built-in Nym mixnet client** for this app only, including the local node's P2P traffic | ❌ | ✅ |
| Nym watchdog: detects a hung Nym connection and reconnects by itself | ❌ | ✅ |
| **Built-in Tor** and **built-in I2P** (i2pd), no extra install | ❌ | ✅ |
| **Private network routes**: choose Tor / Nym / I2P for the wallet, for syncing and for sending transactions | ❌ | ✅ |
| Remote .onion and .i2p nodes found and tested from the app | ❌ | ✅ |
| **Spy-node ban list** (MRL) for the local node, and spy check of remote nodes | ❌ | ✅ |
| **Connection check** (exit IP, latency, 1 MB speed test, P2P reachability, node health) | ❌ | ✅ |
| List of every outside connection the wallet makes, and its route | ❌ | ✅ |
| Live list of the local node's peers (IP, country, in/out, height), click to copy | ❌ | ✅ (country from an offline GeoIP base) |
| Sync details: blocks left, last block, speed, ETA | ❌ | ✅ |
| **Node manager** scored by availability, freshness, version and stability, with favourites and rotation | ❌ | ✅ |
| **Extreme privacy mode** (no prices, no update checks, sync blocked without an approved route) | ❌ | ✅ |
| **Security center** (file permissions, password strength, backups, node, session) | ❌ | ✅ |
| One-click backup of all wallet files to a folder | ❌ | ✅ |
| **Wallets on USB / SD**: open from the drive, save a copy to the drive | ❌ | ✅ |
| Used addresses flagged in red, copy blocked, optional hiding (no address reuse) | ❌ | ✅ |
| **Address mining**: search your own subaddresses for a chosen prefix / suffix | ❌ | ✅ |
| **Mined addresses** account (one-off addresses, spent one at a time) | ❌ | ✅ |
| **Address groups**: 2 to 50 new addresses in one row, copied together, random split of a payment request | ❌ | ✅ |
| Paste a list of addresses (with amounts) in Send to fill every recipient | ❌ | ✅ (up to 50 recipients) |
| **Scheduled sends** (send at a date and time) | ❌ | ✅ |
| Remove empty accounts | ❌ | ✅ |
| **Encrypted notes** tied to the wallet (and to the Trezor on hardware wallets) | ❌ | ✅ |
| Balance in fiat | ✅ | ✅ (Kraken / CoinPaprika, with 24 h and 7 d change, last price cached) |
| XMR price in mBTC with 24 h trend in the title bar | ❌ | ✅ (live from Kraken, every minute) |
| **Markets**: XMR/EUR, XMR/USD, XMR/BTC charts, wallet value and balance over time, converter | ❌ | ✅ (CoinGecko, Kraken, KuCoin, CoinMarketCap) |
| **Price alerts** with system notifications | ❌ | ✅ |
| **Swaps** comparison: Wagyu, NonKYC and ChangeNOW, best routes, price history in CSV | ❌ | ✅ |
| **Swaps No-KYC** table (MoneroPriceNow + NonKYC) in USD / EUR / BTC | ❌ | ✅ |
| Scrolling **price ticker** at the bottom (XMR in BTC and every fiat) | ❌ | ✅ |
| **macOS menu bar icon** with price, balance, node and Nym status | ❌ | ✅ |
| **Desktop widget** on the wallpaper (price, 24 h chart, balance, node, Nym) | ❌ | ✅ (macOS) |
| Themes | Dark / light | 9 colour palettes (Matrix, Cyberpunk, Tron, Amber, Monero, Ice, Ultraviolet, Acid, Black and white), each dark or light and neon or matte, with optional effects |
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
- The Trezor's name is shown in the title bar next to the wallet name. While the device waits for a
  confirmation, the wallet shows an animated Safe 7 and, when relevant, the address to compare. The top of that
  window names the wallet being opened or used and the Trezor (remembered per wallet, so the very first opening
  shows only the wallet).
- **Cancel** in that window gives up the wait if the Trezor does not respond: the app stops waiting, tells the
  device to cancel, and the operation ends as if it had been cancelled on the Trezor. If nothing answers, the
  window closes after 8 seconds anyway.
- The built-in homescreens keep their text in the middle of the screen, clear of the Safe 5 / Safe 7 status and
  menu bars.
- **Wallet+ → Trezor** changes the device settings from the wallet: name, homescreen (with a built-in gallery
  and your own images), brightness, haptic feedback and auto-lock time. Each change is confirmed on the device.
- Each model gets homescreens in its own format: a JPEG of 380×520 on the Safe 7 and 240×240 on the Safe 5, and on
  the **Safe 3** (128×64, black and white) a Trezor TOIF image, dithered to black and white, with its own gallery
  drawn for that screen. Images dropped in `images/trezor-wallpapers/` (`safe5/`, `safe3/`) join the gallery
  after a rebuild.
- **Several Trezors connected**: before opening a Trezor wallet the app lists the connected devices (by name and
  model, Bluetooth on request) and remembers which Trezor each wallet uses.
- Close Trezor Suite before opening the wallet: the Safe 7 is used directly, not through Trezor Bridge.

### Several wallets at once
- Every wallet you unlock stays loaded and **keeps syncing in the background**. The **⇄** button next to the
  wallet name in the title bar lists them with their state (open, synced, syncing) and switches instantly,
  without the password and without reloading or rescanning. The password is checked before resuming.
- Passwords are kept **only in memory**: they are forgotten when the app quits, and an inactivity lock closes
  every background wallet. ✕ closes one. The option is in *Settings → Interface → Security*.
- A Trezor wallet can sync in the background too while the device stays connected and unlocked (one Trezor
  wallet at a time). If it asks for a passphrase or pairing in the background, its sync pauses until you switch
  back to it. Switching back resumes the same session, so the Trezor does not ask for the passphrase again.
- Closing a wallet no longer blocks the window: it saves and closes on its own thread. Quitting the app waits
  until every wallet has been saved.

### Seed accounts (several "4…" addresses from one seed)
- Only a wallet's primary address starts with 4; accounts and subaddresses always start with 8. To get more
  "4…" addresses from the same seed, XMR Wallet+ creates **seed accounts**: account N is the same seed restored
  with the seed offset passphrase "N" (1, 2, 3…), stored with the same password in a `wallets_passphrase` folder
  inside the wallet's folder (`<wallet folder>/wallets_passphrase/<wallet>.cuenta-N`). The wallet list skips that
  folder, so accounts only appear in their own wallet's menu, not as separate wallets nor in the ⇄ list.
- Click the safe icon left of the wallet name to see the accounts of this seed, switch between them (they sync
  in the background like any other wallet) and create a new one.
- To restore account N in any Monero wallet you need the seed **and** the passphrase "N". Anyone with the seed can
  try these numbers too: seed accounts separate funds, they do not hide them.

### Wallet+ menu
A blue section below Settings groups the extra pages: a collapsible feature guide with practical examples and shortcuts, **Markets**
(with **Markets / Swaps / Swaps No-KYC** tabs), **Notes**, **Mined addresses** and **Security**. Trezor settings
are reached from the overview or by clicking the Trezor icon in the title bar.

### Security page (Wallet+ → Security)
Four tabs:
- **Connections**: at the top, the **external IPs of the local node**: its peers with IP, country flag,
  direction, state and height, refreshed every 3 s; click an IP to copy it. Below, every service the wallet
  contacts (node, prices, markets, swaps, update check, Nym, connection check, node manager, links), when it does
  it and which route it takes (Nym, proxy, direct or blocked), and what a remote node can learn about you.
- The peers' **country** comes from the free DB-IP "IP to Country Lite" base (CC BY 4.0, *IP Geolocation by
  DB-IP*), looked up **offline** inside the app: no IP is sent anywhere. `empaquetar-macos.sh` downloads it (or
  refreshes it when older than 45 days) and puts it inside the app; `actualizar-geoip.sh` updates it by hand in
  `~/Monero/xmr-wallet-plus/geoip/`, which takes precedence.
- **Nodes**: a node manager that measures availability, freshness against the network, version, stability and
  latency through the app's current route. Speed counts only 10 % of the score, so a fast node that fails or lags
  does not win. Favourites, your own list, per-node test, "Use", and manual rotation to a random good node.
- **Extreme privacy**: one switch that turns off price queries, swaps, market data and update checks, and lets
  traffic out only through Nym or the SOCKS5 proxy. Without an approved route the wallet does not sync and
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
  a **USB / SD wallets** section above "Recently opened". A wallet opened from a drive shows a purple USB icon in
  the title bar. Plug the drive in, open the wallet, close it, unplug: while unplugged the wallet is on no computer.

### Receive
- Addresses that already received a transaction are shown in red, their copy buttons are disabled and a warning
  offers to create a new address, to avoid address reuse.
- **Hide used addresses** removes them from the list.
- **Create addresses in bulk** (next to "Create new address") makes 2 to 50 new addresses with one label and shows
  them as a single row. Selecting it shows all the addresses separated by commas, ready to copy. In **Payment
  request** you write the total and it is split at random among the addresses (**Split again** for another split);
  the box then holds `address:amount,address:amount,…`, and the description and name fields are hidden.

### Send
- **Several recipients at once**: pasting a list of addresses separated by commas (optionally `address:amount`) in
  the address field fills one recipient per address, up to 50. "Send all" only works with one recipient, as in the
  official wallet (Monero's sweep sends to one address).
- **Schedule the send**: Now, or a date and time. The transaction is created and sent automatically at that moment
  if the app is open and synced. Scheduling is disabled for all hardware wallets (including Trezor and Ledger). Schedules are stored in the encrypted wallet cache. Legacy schedules migrate when their wallet is opened,
  and are removed from general settings only after a successful save. An interrupted broadcast is held for
  history verification and cannot be automatically or manually retried from the same entry.
  Scheduled sends are listed below with
  **Send now** and **Cancel**. Any payment already due when its wallet is reopened requires confirmation,
  even if only seconds late. Closing the app warns that schedules are preserved but cannot run while closed.
  The source account is reserved against other sends for 25 minutes before a scheduled payment (including
  a final check before broadcasting a manually prepared transaction). This is a buffer, not a guarantee:
  spendable outputs must still be unlocked. Keep this wallet selected and synced; hardware wallets cannot schedule payments, and a background-sync lock that removes spending access cannot execute payments.

### Accounts and mined addresses
- **Wallet+ → Mined addresses** searches your own subaddresses for a text at the start, at the end or anywhere
  (optionally ignoring case), over a range of accounts and addresses or without end, with live results, a progress
  bar and an estimated time per match. It only derives addresses: it creates nothing until you save one.
- **Save to mined** keeps an address as a one-off address of the wallet, without creating the accounts and
  addresses before it. All of them appear together in a virtual **Mined addresses** account (⛏, with its own
  quarry-style card) on the Accounts page: its balance is counted only there and the addresses are hidden from
  Receive.
- **Send** from a mined address spends from that address alone, for privacy; the change goes back to the account 0
  address 0:1 (or the next non-mined one) and the transaction note says "(mined address change)". A mined address
  that has received anything cannot be removed, and none can be removed while the wallet is syncing.
- **Remove empty accounts** on the Accounts page deletes trailing accounts that never received or sent anything.

### Privacy and network
- **Built-in Nym client.** The wallet ships its own Nym mixnet client (`external/nym-client`, built from the
  pinned NymVPN 2026.13.0 account controller and Nym core sources). It needs an active NymVPN subscription: enter
  the 24-word NymVPN account phrase in the Nym panel and the wallet registers its own device. Only this app's
  traffic goes through the mixnet, on a local SOCKS5 port (127.0.0.1:17890), including the local node's P2P
  traffic. It does not control or need the official NymVPN app.
- The phrase is sent to the helper through stdin and saved in plain text, owner-only, in
  `~/Monero/xmr-wallet-plus/nym.conf` (not in the macOS Keychain). **Log out** disconnects while retaining the phrase and device keys. Connecting with a different phrase replaces the local device identity. **Reconnect** picks a different random exit.
- **Nym watchdog**: every 90 s the app checks that Nym still carries traffic (two small HTTPS requests through the
  mixnet). After two failed rounds it reconnects by itself (at most once every 2 minutes) and says so in the status
  bar. If the client stops or fails, it retries with growing pauses (20 s up to 5 min, 8 tries). When the route
  comes back, prices and Markets are asked again at once instead of waiting for the next round.
- With Nym on, monerod uses proxy-friendly sync settings (longer peer timeouts, smaller block batches), so the
  local node keeps syncing through the mixnet.
- **Connection check**: current IP, proxy, latency, a 1 MB speed test, reachability of Monero seed nodes and node
  status. It runs only when you press the button, always through the network being checked; if that network's
  local SOCKS port does not answer, the check stops without sending anything.
- **Built-in Tor.** The app ships the Tor Expert Bundle (downloaded and SHA-256 / signature checked by
  `actualizar-tor.sh`) and runs its own Tor client for this app only (SOCKS 127.0.0.1:17950), with **New identity**
  and the exit IP. Tor stops when the app quits. The panel also finds **remote .onion nodes**, tests them through
  Tor and lists the synced ones by latency.
- **Built-in I2P.** The app ships i2pd and runs its own router (SOCKS 127.0.0.1:17960, no outproxy). It can be on
  together with Tor or Nym. The panel shows routers, tunnels and progress, and finds and tests **remote .i2p
  nodes**. Rows in the .onion / .i2p lists can be used as remote node or as a P2P peer of the local node.
- The last good .onion and .i2p node lists are saved in `~/Monero/xmr-wallet-plus/nodes/tor.json` and `i2p.json`
  and shown at start; a new search runs by itself only when the list is older than a day (or with **Find nodes**).
- **Network configuration** (*Settings → Node / Network*): the wallet requires a configured private route; there is no clearnet
  option for wallet traffic. The network clients still need bootstrap and entry connections. You choose the network for the **wallet** (Tor or Nym), for **syncing** the local node (Tor, Nym or I2P;
  I2P alone cannot sync a node, the app warns) and for **sending transactions** (Tor, I2P or both). .onion nodes
  always go through Tor and .i2p nodes through I2P. monerod gets the matching `--proxy`, `--tx-proxy`,
  `--p2p-bind-ip 127.0.0.1`, `--hide-my-port` and `--pad-transactions`, and is restarted when the choice changes.
  The card also holds the node address lists (exclusive nodes, priority peers, extra peers, remote nodes) and
  shows the real monerod command line.
- The **Welcome to Monero** page (before opening a wallet) shows the same **Network configuration** card, then
  the Nym, Tor and I2P panels and the **Connection check**, so the network can be set up before the first wallet.
- Below it: the **Node** card (start / stop, Local / Remote node, live list of the node's external IPs), a
  **connection check per network**, the Nym, Tor and I2P panels and **External connections** (price and market
  services).
- **Spy-node ban list**: the MRL ban list ([Boog900/monero-ban-list](https://github.com/Boog900/monero-ban-list))
  is downloaded at build time (`actualizar-banlist.sh`) and the local node starts with `--ban-list` and
  `--enable-dns-blocklist`. In Security → Nodes each remote node is also checked over P2P: a node on the list, or
  one whose peers are largely on it, is marked and left out of rotation.
- Hovering the daemon progress bar in the left menu shows the sync details (blocks left, last block number and
  time, speed, ETA) with a blue border when synced and yellow while syncing.
- **NODE chip** in the title bar: green when the node is connected, blinking yellow while Nym connects, red when
  disconnected; the tooltip shows local/remote node and Nym exit, and a click opens Settings → Node / Network.
- With external connections off, the app makes no price or exchange requests at all.

### Markets and swaps (only when external connections are on)
- XMR/EUR, XMR/USD and XMR/BTC charts for 24H, 7D, 30D, 90D, 1Y and MAX with tabs for CoinGecko, Kraken, KuCoin
  and CoinMarketCap, cached as CSV under `~/Monero/xmr-wallet-plus/markets/<source>/` (coingecko, kraken, kucoin,
  coinmarketcap) and refreshed every 15 minutes.
- **Value of your wallet** chart with the same grid, dates and crosshair as the price chart; hovering one chart
  moves the other and shows the date, value and balance at that moment.
- Converter and **price alerts** with a macOS notification.
- **Swaps** tab: quotes from Wagyu, NonKYC and ChangeNOW side by side, the best cross-exchange routes and a
  comparison with earlier prices. Every refresh is saved to `~/Monero/xmr-wallet-plus/precios-swaps.csv`.
- **Swaps No-KYC** tab: buy and sell prices of the no-KYC exchanges listed by MoneroPriceNow, plus NonKYC, in
  XMR/USD, XMR/EUR and XMR/BTC, with spread, minimum, time and privacy rating, sortable, refreshed every minute.
- **Price ticker** at the bottom of the window (*Settings → Interface*): XMR in BTC and in every fiat currency with
  its 24 h change, scrolling, paused on hover. It uses the prices already loaded and makes no requests of its own.
- **Price chip** in the title bar: XMR in mBTC with a green ▲ / red ▼ for the last 24 h. The price comes live
  from Kraken every minute (XMR/BTC, XMR/USD; EUR from the fiat rate); the 24 h change is measured against the
  CoinGecko series from Markets. Hover for BTC, EUR and USD prices and their source; click to open Markets.
- After a failed price request the app tries again after 20 s instead of waiting for the next minute. Swaps ask
  three quotes at a time, and the No-KYC table loads its USD and BTC lists together.
- The last price is cached in `~/Monero/xmr-wallet-plus/precio-actual.csv`, so the balance shows a fiat value
  as soon as the app starts.

### macOS menu bar and desktop widget
- **Menu bar icon** (*Settings → Interface → Menu bar*): a Monero icon in the macOS menu bar. Next to it you
  choose what to show: XMR price in mBTC / EUR / USD, 24 h change, balance (hidden when the balance is hidden),
  node sync % and Nym status. Its menu lists prices, wallet, balance, node and Nym, and opens the wallet.
- **Desktop widget** (*Settings → Interface → Desktop widget*): a translucent neon panel pinned to the wallpaper,
  behind all windows and on every Space, with the price, a 24 h chart, balance, node and Nym. Drag it anywhere;
  double click opens the wallet. Currency, rows and background opacity are configurable. It is shown while the
  app is running.

### Encrypted notes
- **Notes** page for private notes stored next to the wallet as `<wallet name>_notes`.
- Encrypted with AES-256-GCM using a key derived from the wallet keys. They open without asking for a password
  once the wallet is open, and lock when the wallet closes.
- On Trezor wallets the key also needs the device: the Trezor confirms "XMR Wallet+ notes" (SLIP-0011), so the
  file cannot be opened without that Trezor and passphrase.

### Look and feel
- **Themes**: the moon button in the title bar opens a list with Dark / Light and 9 colour palettes (Matrix,
  Cyberpunk, Tron, Amber, Monero, Ice, Ultraviolet, Acid, Black and white). Every accent of the neon design follows the palette;
  error reds, greys and white text stay the same. The choice is saved. Some PNG images still use the Matrix green.
- **Neon / Matte**: below Dark / Light. Neon is the bright original; Matte softens every palette: neutral grey
  backgrounds instead of pure black or white, less glaring text and muted accents.
- **Wallet+ guide**: collapsible sections with practical uses, including scheduled payments, custom address mining
  and removable USB wallets. Shortcuts open the corresponding tools.
- **Settings → Info**: larger XMR Wallet+ logo, compact build and wallet details, responsive cards and themed donation buttons.
- Redesigned pages, cards, dialogs and icons, with white text on the dark themes and narrower window buttons.
- Minimal loading panel with wallet name and an indeterminate activity bar. Device prompts retain the Trezor
  illustration, confirmation instructions, address comparison and cancellation.
- Optional effects (Matrix rain in both themes, boot screen, page glitch, UI sounds) in
  *Settings → Interface*. The rain pauses while the window is minimized, to save CPU.

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
versions. It also puts Tor (`actualizar-tor.sh`), i2pd (`actualizar-i2pd.sh`, needs `brew install i2pd` once)
and the spy-node ban list (`actualizar-banlist.sh`) inside the app. It also builds the Nym client: the first time it downloads the pinned (SHA-256 checked) Nym sources and
an isolated Rust toolchain into `build/` (Python 3.11+ required). `build/` and `dist/` are not committed. The app
ends up in `build/release/bin`.

To copy the app to another Mac, run `bash empaquetar-macos.sh`. It creates `dist/XMR-wallet+.app` and
`dist/XMR-wallet+-macos.zip`, which do not need Homebrew and include the GeoIP base (downloaded by the script; it
is not in the repository). On the other Mac, run
`xattr -dr com.apple.quarantine XMR-wallet+.app` once before opening it.

The Nym client needs an active NymVPN subscription account. Without it, everything else works (use a SOCKS5
route such as the built-in Tor client).

## License

Same as upstream: BSD 3-Clause, see [LICENSE](LICENSE). Copyright (c) 2014-2024, The Monero Project,
plus the contributors of this fork. The Nym client helper in `external/nym-client` is GPL-3.0-only; its
upstream components keep their own licenses. "Monero", "Trezor" and "Nym" are used only to describe
compatibility; they are trademarks of their respective owners.

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
