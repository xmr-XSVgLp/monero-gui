// Copyright (c) 2014-2024, The Monero Project
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import QtQml.Models
import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs


import FontAwesome

import moneroComponents.Network 1.0
import moneroComponents.Wallet 1.0
import moneroComponents.WalletManager 1.0
import moneroComponents.PendingTransaction 1.0
import moneroComponents.NetworkType 1.0
import moneroComponents.Settings 1.0
import moneroComponents.P2PoolManager 1.0

import "js/PriceSources.js" as PriceSources
import "js/TransactionPrices.js" as TransactionPrices
import "components"
import "components" as MoneroComponents
import "components/effects" as MoneroEffects
import "pages/merchant" as MoneroMerchant
import "wizard"
import "js/Utils.js" as Utils
import "js/Windows.js" as Windows
import "version.js" as Version

ApplicationWindow {
    id: appWindow
    signal gracefulShutdownComplete()
    title: "XMR Wallet+" +
        (persistentSettings.displayWalletNameInTitleBar && walletName
        ? " - " + walletName
        : "")
    // the redesigned pages (cards, side panel, NYM panel) need room: below this they overlap
    minimumWidth: (isAndroid || isIOS) ? 750 : Math.min(1100, screenAvailableWidth)
    minimumHeight: (isAndroid || isIOS) ? 450 : Math.min(720, screenAvailableHeight)

    property var currentItem
    property var previousActiveFocusItem
    property bool hideBalanceForced: false
    property bool ctrlPressed: false
    property alias persistentSettings : persistentSettings
    property string accountsDir: !portableSettings.portable ? moneroAccountsDir : portableSettings.portableFolderName + "/wallets"
    property var currentWallet;
    property bool disconnected: currentWallet ? currentWallet.disconnected : false
    property var transaction;
    property double transactionRequestId: 0
    property double activeTransactionRequestId: 0
    property var walletPassword
    property int restoreHeight:0
    property bool daemonSynced: false
    property bool walletSynced: false
    property real daemonHeight: 0
    property real daemonTarget: 0
    property int maxWindowHeight: (isAndroid || isIOS)? screenAvailableHeight : (screenAvailableHeight < 900)? 720 : 800;
    // the wallet reports "disconnected" while it (re)connects, e.g. right after switching wallets;
    // localDaemonAlive (checked with daemonManager) keeps the node shown as running meanwhile
    property bool localDaemonAlive: false
    property bool daemonRunning: !persistentSettings.useRemoteNode && (!disconnected || localDaemonAlive)
    onDaemonRunningChanged: if (daemonRunning) daemonRouteTimer.restart()
    property int daemonStartStopInProgress: 0
    property alias toolTip: toolTip
    property string walletName
    property string walletDeviceLabel: ""   // Trezor name shown in the title bar
    // remember the Trezor name of each wallet, so the "proceed to the device" screen can show it while opening
    onWalletDeviceLabelChanged: {
        if (walletDeviceLabel === "" || !persistentSettings.wallet_path) return;
        var m = {};
        try { m = JSON.parse(persistentSettings.trezorLabels || "{}"); } catch (e) {}
        if (m[persistentSettings.wallet_path] === walletDeviceLabel) return;
        m[persistentSettings.wallet_path] = walletDeviceLabel;
        persistentSettings.trezorLabels = JSON.stringify(m);
    }
    function knownTrezorLabel(path) {
        if (walletDeviceLabel !== "" && currentWallet && path === persistentSettings.wallet_path) return walletDeviceLabel;
        try { return JSON.parse(persistentSettings.trezorLabels || "{}")[path] || ""; } catch (e) { return ""; }
    }
    property string deviceShowAddress: ""   // address sent to the Trezor screen, shown in the splash to compare

    // ---- several Trezors connected: the user picks one (TrezorPicker) ----
    // persistentSettings.trezorDevices: JSON transport path -> {label, model}, so the list shows names it saw before
    // persistentSettings.trezorWallets: JSON wallet path -> transport path of the Trezor it was opened with
    function jsonSetting(name) {
        try { return JSON.parse(persistentSettings[name] || "{}") || {}; } catch (e) { return {}; }
    }
    function rememberTrezorDevices(list) {
        var m = jsonSetting("trezorDevices"), changed = false;
        list.forEach(function(d) {
            if (!d.label) return;
            if (m[d.path] && m[d.path].label === d.label && m[d.path].model === d.model) return;
            m[d.path] = { label: d.label, model: d.model };
            changed = true;
        });
        if (changed) persistentSettings.trezorDevices = JSON.stringify(m);
    }
    function withKnownTrezorNames(list) {
        var m = jsonSetting("trezorDevices");
        return list.map(function(d) {
            var known = m[d.path] || {};
            return { path: d.path, name: d.name, label: d.label || known.label || "",
                     model: d.model || known.model || "", lastUsed: d.lastUsed };
        });
    }
    function rememberTrezorWallet(walletPath, devicePath) {
        if (!walletPath) return;
        var m = jsonSetting("trezorWallets");
        if (m.hasOwnProperty(walletPath) && (devicePath === undefined || m[walletPath] === devicePath)) return;
        m[walletPath] = devicePath || m[walletPath] || "";
        persistentSettings.trezorWallets = JSON.stringify(m);
    }
    function isTrezorWallet(path) {
        if (jsonSetting("trezorWallets").hasOwnProperty(path) || knownTrezorLabel(path) !== "") return true;
        return unlockedWallets.some(function(w) { return w.path === path && w.hw; });
    }
    // a wallet was renamed (newPath) or moved to the Trash (newPath ""): carry or drop what the app keeps per wallet path
    function moveWalletSettings(oldPath, newPath) {
        var key = function(p) { return String(p).replace(/\.keys$/, ""); };
        ["trezorWallets", "trezorLabels", "securityBackups"].forEach(function(name) {
            var m = {};
            try { m = JSON.parse(persistentSettings[name] || "{}") || {}; } catch (e) { m = {}; }
            var changed = false;
            Object.keys(m).forEach(function(k) {
                if (key(k) !== key(oldPath)) return;
                if (newPath !== "") m[newPath + (/\.keys$/.test(k) ? ".keys" : "")] = m[k];
                delete m[k];
                changed = true;
            });
            if (changed) persistentSettings[name] = JSON.stringify(m);
        });
        if (key(persistentSettings.wallet_path) === key(oldPath))
            persistentSettings.wallet_path = newPath === "" ? "" : newPath + (/\.keys$/.test(persistentSettings.wallet_path) ? ".keys" : "");
    }
    function isParkedWallet(path) {
        var key = String(path).replace(/\.keys$/, "");
        return walletManager.parkedWallets().some(function(w) { return String(w.path).replace(/\.keys$/, "") === key; });
    }
    // A cable device must not hide the Bluetooth discovery option.
    property string openingTrezorLabel: ""
    property string openingTrezorPath: ""
    function chooseTrezor(walletPath, onChosen, onCancelled) {
        openingTrezorLabel = "";
        openingTrezorPath = "";
        walletManager.setTrezorDevicePath("");
        walletManager.trezorDevicesAsync(false, function(json) {
            var list = [];
            try { list = JSON.parse(json); } catch (e) {}
            rememberTrezorDevices(list);
            hideProcessingSplash();
            trezorPicker.open(withKnownTrezorNames(list), jsonSetting("trezorWallets")[walletPath] || "", function(path) {
                walletManager.setTrezorDevicePath(path);
                // A remembered wallet label is not evidence of the connected device's identity.
                openingTrezorLabel = "Trezor · " + trezorPicker.connectionName(path);
                openingTrezorPath = path;
                onChosen(path);
            }, function() {
                walletManager.setTrezorDevicePath("");
                openingTrezorLabel = "";
                openingTrezorPath = "";
                if (onCancelled) onCancelled();
            });
        });
    }

    // true when the path lives on a USB stick / SD card (oshelper.removableVolumes)
    function isRemovablePath(path) {
        if (!path)
            return false;
        var volumes = oshelper.removableVolumes();
        for (var i = 0; i < volumes.length; ++i)
            if (path.indexOf(volumes[i].root + "/") === 0)
                return true;
        return false;
    }
    property bool viewOnly: false
    property bool foundNewBlock: false
    property bool qrScannerEnabled: (typeof builtWithScanner != "undefined") && builtWithScanner
    property int blocksToSync: 1
    property int firstBlockSeen
    property bool isMining: false
    property int walletMode: persistentSettings.walletMode
    property var cameraUi
    property bool androidCloseTapped: false;
    property int userLastActive;  // epoch
    // Default daemon addresses
    readonly property string localDaemonAddress : "localhost:" + getDefaultDaemonRpcPort(persistentSettings.nettype)
    property string currentDaemonAddress;
    property int disconnectedEpoch: 0
    property int estimatedBlockchainSize: persistentSettings.pruneBlockchain ? 110 : 270 // GB
    property alias viewState: rootItem.state
    property string prevSplashText;
    property bool splashDisplayedBeforeButtonRequest;
    property bool themeTransition: false
    property int backgroundSyncType: Wallet.BackgroundSync_Off;
    property bool isQuitting: false
    // open StandardDialogs (information, confirmation, page popups): the window behind is blurred
    property int modalDialogs: 0

    // fiat price conversion
    property real fiatPrice: 0
    property real fiatPriceUSD: 0
    property var fiatRates: ({"USD": 1}) // units of each currency per 1 USD
    property real fiatRatesTimestamp: 0
    readonly property real fiatRatesMaxAge: 60 * 60 * 1000
    readonly property string fiatRatesAPI: "https://api.frankfurter.dev/v1/latest?base=USD"
    // 7-day price change shown on the Account page
    property real fiatPriceUSD7d: 0
    property real fiatHistoryTimestamp: 0
    property var fiatRates7d: ({"USD": 1})
    property string fiatRates7dDate: ""
    property real fiatChange7d: NaN // percent, NaN while unknown
    property real fiatPriceUSD24h: 0
    property real fiatChange24h: NaN
    property real priceBtc: 0             // BTC received for 1 XMR (Wagyu swap quote, fee included)
    property double priceBtcTimestamp: 0
    property real priceBtcLive: 0            // XMR/BTC last trade (Kraken ticker, every minute)
    property double priceBtcLiveTime: 0

    // Nym SDK: a bundled process owns the wallet's independent mixnet session. States: off, missing, working, ready, connected, error
    property string nymVpnState: "off"
    property string nymVpnMessage: ""
    property string nymVpnLog: ""
    // route info: public IP seen through the proxy, and the entry / exit gateways from the daemon log
    property string nymVpnIp: ""
    property string nymVpnIpPlace: ""
    property string nymVpnEntryId: ""
    property string nymVpnExitId: ""
    property string nymVpnRouteNote: ""
    property bool nymVpnInfoLoading: false
    // kill switch: while restarting, every proxied request goes to a dead address (see getProxyAddress)
    property bool nymVpnRestarting: false
    // Connection diagnostics are manual: never compete with initial blockchain sync. One check per
    // anonymous network (Settings > Node / Network > Connection check), one running at a time.
    property var connTests: ({ nym: {}, tor: {}, i2p: {} })     // net -> { key: result }
    property var connTestTimes: ({})                             // net -> Date of the last finished check
    property string connTestingNet: ""                           // "" = none running
    property int connTestGen: 0
    // kept for older callers: true while any check runs
    readonly property bool connTesting: connTestingNet !== ""
    function netDisplayName(net) { return net === "nym" ? "Nym" : net === "i2p" ? "I2P" : "Tor"; }
    function netSocks(net) {
        return net === "nym" ? persistentSettings.nymVpnSocksAddress : net === "i2p" ? oshelper.i2pClient.address : oshelper.torClient.address;
    }
    function netUp(net) { return net === "nym" ? nymVpnProxyUp() : net === "i2p" ? i2pProxyUp() : torProxyUp(); }
    // the node a network's check looks at: the remote node when the wallet reaches it through this
    // network, the local node when this network syncs it; { address, socks } or null
    function connTestNode(net) {
        if (persistentSettings.useRemoteNode) {
            var a = remoteNodesModel.currentRemoteNode().address;
            var via = isI2pNode(a) ? "i2p" : isOnionNode(a) ? "tor" : persistentSettings.netWallet;
            return via === net ? { address: a, socks: netSocks(net) } : null;
        }
        return persistentSettings.netSync === net ? { address: localDaemonAddress, socks: "" } : null;
    }
    function setConnResult(net, r) {
        var all = Object.assign({}, connTests);
        var t = Object.assign({}, all[net] || {});
        t[r.key] = r;
        all[net] = t;
        connTests = all;
    }
    function finishConnTest(net) {
        var times = Object.assign({}, connTestTimes);
        times[net] = new Date();
        connTestTimes = times;
        connTestingNet = "";
    }
    function cancelConnectionTest() {
        connTestGen++;
        connTestingNet = "";
        oshelper.cancelConnectionTest();
    }
    // net: "nym" | "tor" | "i2p"; without it, the wallet's network
    function runConnectionTest(net) {
        if (net === undefined || net === "") net = persistentSettings.netWallet;
        if (connTestingNet !== "") return;
        var all = Object.assign({}, connTests);
        all[net] = {};
        connTests = all;
        connTestingNet = net;
        var gen = ++connTestGen;
        var node = connTestNode(net);
        if (net === "i2p") {
            runI2pConnectionTest(gen, node);
            return;
        }
        oshelper.nymVpnTest(netSocks(net), node ? node.address : "", function(json) {
            if (gen !== connTestGen) return;
            var r = JSON.parse(json);
            if (r.key === "done") { finishConnTest(net); return; }
            setConnResult(net, r);
        }, node ? node.socks : "");
    }
    // I2P has no exit to the internet: router state, monerod's built-in I2P seed nodes (P2P handshake,
    // the peers --tx-proxy i2p uses) and the .i2p remote node or the local node
    readonly property var i2pSeedNodes: ["uqj3aphckqtjsitz7kxx5flqpwjlq5ppr3chazfued7xucv3nheq.b32.i2p",
                                         "vdmnehdjkpkg57nthgnjfuaqgku673r5bpbqg56ix6fyqoywgqrq.b32.i2p",
                                         "ugnlcdciyhghh2zert7c3kl4biwkirc43ke33jiy5slnd3mv2trq.b32.i2p"]
    function runI2pConnectionTest(gen, node) {
        var c = oshelper.i2pClient;
        setConnResult("i2p", { key: "router", ok: c.state === "connected", state: c.state, routers: c.routers,
                               tunnels: c.clientTunnels, rate: c.successRate, status: c.networkStatus });
        if (c.state !== "connected") { finishConnTest("i2p"); return; }
        var peers = [], left = i2pSeedNodes.length;
        i2pSeedNodes.forEach(function(host) {
            var t0 = Date.now();
            oshelper.nodeP2pProbe(host, c.address, [18080, 18085, 18083, 18084], 90000, function(json) {
                if (gen !== connTestGen) return;
                var r = {};
                try { r = JSON.parse(json); } catch (e) {}
                peers.push({ ok: r.ok === true, pingMs: Date.now() - t0, error: r.error || "" });
                if (--left > 0) return;
                setConnResult("i2p", { key: "p2p", ok: peers.some(function(x) { return x.ok; }),
                                       reached: peers.filter(function(x) { return x.ok; }).length, total: peers.length, peers: peers });
                if (!node) { finishConnTest("i2p"); return; }
                oshelper.nodeRpc(node.address, node.socks, "/get_info", "", 120000, function(ok, ms, body, error) {
                    if (gen !== connTestGen) return;
                    var o = { key: "node", ok: false, error: error || "" };
                    if (ok) {
                        try {
                            var j = JSON.parse(body);
                            o = { key: "node", ok: true, height: j.height, target_height: j.target_height,
                                  outgoing_connections_count: j.outgoing_connections_count,
                                  incoming_connections_count: j.incoming_connections_count, ms: ms };
                        } catch (e) { o.error = "bad answer"; }
                    }
                    setConnResult("i2p", o);
                    finishConnTest("i2p");
                });
            });
        });
    }
    readonly property bool nymClientAvailable: oshelper.nymClient.available()
    function nymVpnCheckInstall(callback) {
        if (!oshelper.nymClient.available()) {
            nymVpnState = "missing";
            nymVpnMessage = qsTr("The bundled Nym client is missing. Rebuild the app with compilar-macos.sh.") + translationManager.emptyString;
        }
        if (callback) callback();
    }
    property var nymVpnGateways: ({})   // identity key -> { name, place }

    // Public IP services, used as sequential fallbacks; each request goes through the proxy, so it shows the exit IP
    readonly property var nymVpnIpServices: ["https://ipwho.is/", "https://ipinfo.io/json", "https://api.ipify.org?format=json"]
    property int nymVpnInfoGen: 0      // ignores answers from an older lookup
    property bool nymVpnDirectoryLoading: false

    function nymVpnParseIp(url, j) {
        if (url.indexOf("ipwho.is") >= 0)
            return j.success === false ? null
                 : { ip: j.ip, place: [j.city, j.country_code].filter(Boolean).join(", ") + (j.connection && j.connection.org ? " · " + j.connection.org : "") };
        if (url.indexOf("ipinfo.io") >= 0)
            return { ip: j.ip, place: [j.city, j.country].filter(Boolean).join(", ") + (j.org ? " · " + j.org : "") };
        return { ip: j.ip, place: "" };
    }

    function nymVpnLoadInfo() {
        if (!nymVpnProxyUp() || nymVpnInfoLoading) return;
        nymVpnInfoGen++;
        nymVpnInfoLoading = true;
        nymVpnIp = "";
        nymVpnIpPlace = "";
        nymVpnInfoWatchdog.restart();
        nymVpnReadRoute();                 // nodes come from the local log: show them right away
        nymVpnTryIp(nymVpnInfoGen, 0);
    }

    // Try one IP provider at a time, leaving bandwidth for blockchain synchronization.
    function nymVpnTryIp(gen, index) {
        if (gen !== nymVpnInfoGen || !nymVpnProxyUp()) return;
        var url = nymVpnIpServices[index];
        network.getJSON(url, function(u, resp, error) {
            if (gen !== nymVpnInfoGen || !nymVpnProxyUp()) return;
            var info = null;
            try { if (!error) info = nymVpnParseIp(url, JSON.parse(resp)); } catch (e) {}
            if (info && info.ip) {
                nymVpnIp = info.ip;
                nymVpnIpPlace = info.place + "  (" + url.split("/")[2] + ")";
                nymVpnInfoLoading = false;
                nymVpnInfoWatchdog.stop();
                nymVpnReadRoute();
            } else if (index + 1 < nymVpnIpServices.length) {
                nymVpnIpRetryTimer.gen = gen;
                nymVpnIpRetryTimer.round = index + 1;
                nymVpnIpRetryTimer.restart();
            } else {
                nymVpnIpPlace = qsTr("Could not get the IP through Nym") + translationManager.emptyString;
                nymVpnInfoLoading = false;
                nymVpnInfoWatchdog.stop();
            }
        });
    }

    Timer {
        id: nymVpnIpRetryTimer
        property int gen: 0
        property int round: 0
        interval: 3000
        onTriggered: appWindow.nymVpnTryIp(gen, round)
    }

    // never leave the panel loading: after 150 s show what we have
    Timer {
        id: nymVpnInfoWatchdog
        interval: 150000
        onTriggered: {
            if (!appWindow.nymVpnInfoLoading) return;
            appWindow.nymVpnInfoGen++;
            if (appWindow.nymVpnIp === "")
                appWindow.nymVpnIpPlace = qsTr("Could not get the IP through Nym") + translationManager.emptyString;
            appWindow.nymVpnInfoLoading = false;
            appWindow.nymVpnReadRoute();
        }
    }

    function nymVpnReadRoute() {
        nymVpnEntryId = oshelper.nymClient.entry;
        nymVpnExitId = oshelper.nymClient.exit;
        nymVpnRouteNote = "";
        nymVpnLoadDirectory();
    }

    function nymVpnLoadDirectory() {
        if (Object.keys(nymVpnGateways).length > 0 || nymVpnDirectoryLoading)
            return;
        nymVpnDirectoryLoading = true;   // names arrive later; the ids are already shown
        network.getJSON("https://nymvpn.com/api/public/v1/directory/gateways", function(url, resp, error) {
            try {
                if (error) throw error;
                var list = JSON.parse(resp), map = {};
                for (var i = 0; i < list.length; i++) {
                    var g = list[i], loc = g.location || {};
                    map[g.identity_key] = { name: g.name || "",
                                            place: [loc.city, loc.two_letter_iso_country_code].filter(Boolean).join(", ") };
                }
                nymVpnGateways = map;
            } catch (e) {
                console.log("NymVPN: gateway directory failed: " + e);
            }
            nymVpnDirectoryLoading = false;
        });
    }

    function nymVpnDescribeGateway(id) {
        if (id === "") return "";
        var g = nymVpnGateways[id];
        return g ? (g.name + (g.place !== "" ? " · " + g.place : "")) : id.slice(0, 10) + "…";
    }

    function nymVpnFail(message) {
        nymVpnRestarting = true;
        nymVpnState = "error";
        nymVpnMessage = message + "\n" + qsTr("App traffic stays blocked. Press Reconnect again or Disconnect.") + translationManager.emptyString;
    }

    function nymVpnResetInfo() {
        cancelConnectionTest();
        nymVpnInfoGen++;
        nymVpnIpRetryTimer.stop();
        nymVpnInfoWatchdog.stop();
        nymVpnInfoLoading = false;
        nymVpnIp = ""; nymVpnIpPlace = "";
        nymVpnEntryId = ""; nymVpnExitId = ""; nymVpnRouteNote = "";
    }

    function nymVpnOpenAccount() { nymAccountDialog.open(); }

    function nymVpnConnect(words) {
        if (nymVpnState === "working") return;
        // Block first, including failed starts, before changing the selected proxy.
        nymVpnRestarting = true;
        if (!persistentSettings.nymVpnEnabled) {
            persistentSettings.nymVpnPrevProxyEnabled = persistentSettings.proxyEnabled;
            persistentSettings.nymVpnPrevProxyAddress = persistentSettings.proxyAddress;
        }
        persistentSettings.nymVpnEnabled = true;
        persistentSettings.proxyAddress = oshelper.nymClient.address;
        persistentSettings.proxyEnabled = true;
        nymVpnResetInfo();
        oshelper.nymClient.start(words || "");
    }

    function nymVpnRestart() {
        if (!persistentSettings.nymVpnEnabled || nymVpnState === "working") return;
        nymVpnRestarting = true;
        nymVpnResetInfo();
        oshelper.nymClient.reconnect();
    }

    Connections {
        target: oshelper.nymClient
        function onChanged() {
            if (isQuitting || !persistentSettings.nymVpnEnabled) return;
            var client = oshelper.nymClient;
            if (client.state === "error") {
                nymVpnFail(client.message);
                scheduleNymRetry();
            } else if (client.state === "connected") {
                nymAutoRetries = 0;
                nymWatchFails = 0;
                nymRetryTimer.stop();
                var justConnected = nymVpnState !== "connected";
                nymVpnState = "connected";
                // new route (connect or reconnect): test it right away
                if (justConnected) {
                    if (connTesting) cancelConnectionTest();
                    Qt.callLater(runConnectionTest, "nym");
                }
                nymVpnRestarting = false;
                nymVpnMessage = qsTr("Independent Nym client · SOCKS5 %1").arg(client.address) + translationManager.emptyString
                    + (client.message !== "" ? " · " + client.message : "");
                nymVpnReadRoute();
                Qt.callLater(nymVpnLoadInfo);
            } else if (client.state === "working") {
                nymVpnState = "working";
                nymVpnRestarting = true;
                nymVpnMessage = qsTr("Connecting the independent Nym client…") + translationManager.emptyString;
            } else {
                nymVpnFail(qsTr("The independent Nym client stopped.") + translationManager.emptyString);
                scheduleNymRetry();
            }
        }
    }

    // ---- Nym watchdog: the mixnet route can hang while the client still says "connected". Every 90 s a
    // tiny HTTPS request goes through Nym (two hosts); two failed rounds in a row -> reconnect on its own.
    // A client that stopped or failed to connect is started again with a growing pause (20 s … 5 min).
    property int nymWatchFails: 0
    property bool nymProbeBusy: false
    property int nymAutoRetries: 0
    property double nymLastAutoReconnect: 0
    readonly property var nymProbeTargets: [["https://api.kraken.com:443", "/0/public/Time"], ["https://ipwho.is:443", "/"]]
    function nymWatchProbe() {
        if (nymProbeBusy || !nymVpnProxyUp() || connTestingNet === "nym") return;
        nymProbeBusy = true;
        var socks = persistentSettings.nymVpnSocksAddress;
        var tryOne = function(i) {
            var t = nymProbeTargets[i];
            oshelper.nodeRpc(t[0], socks, t[1], "", 45000, function(ok, ms, body, error) {
                if (!nymVpnProxyUp()) { nymProbeBusy = false; return; }      // reconnecting meanwhile
                if (ok || body !== "") { nymProbeBusy = false; nymWatchFails = 0; return; }
                if (i + 1 < nymProbeTargets.length) { tryOne(i + 1); return; }
                nymProbeBusy = false;
                nymWatchFails++;
                console.warn("Nym watchdog: no answer through Nym (" + error + "), " + nymWatchFails + "/2");
                if (nymWatchFails >= 2) {
                    nymWatchFails = 0;
                    nymAutoReconnect(qsTr("Nym stopped answering: reconnecting…") + translationManager.emptyString);
                } else {
                    nymWatchSoon.start();       // second round sooner than the next 90 s
                }
            });
        };
        tryOne(0);
    }
    function nymAutoReconnect(message) {
        if (!persistentSettings.nymVpnEnabled || nymVpnState === "working") return;
        if (Date.now() - nymLastAutoReconnect < 120000) return;
        nymLastAutoReconnect = Date.now();
        console.warn("Nym watchdog: " + message);
        showStatusMessage(message, 6);
        nymVpnRestart();
    }
    Timer {
        interval: 90000
        repeat: true
        running: persistentSettings.nymVpnEnabled && appWindow.nymVpnState === "connected" && !appWindow.nymVpnRestarting
        onTriggered: appWindow.nymWatchProbe()
    }
    Timer {
        id: nymWatchSoon
        interval: 20000
        onTriggered: appWindow.nymWatchProbe()
    }
    Timer {
        id: nymRetryTimer
        onTriggered: {
            if (!persistentSettings.nymVpnEnabled || appWindow.nymVpnState !== "error") return;
            appWindow.nymAutoRetries++;
            appWindow.nymAutoReconnect(qsTr("Nym was down: connecting again…") + translationManager.emptyString);
        }
    }
    function scheduleNymRetry() {
        // only with a saved account (a wrong or missing phrase needs the user) and not forever
        if (!persistentSettings.nymVpnEnabled || !oshelper.nymClient.accountSaved || nymAutoRetries >= 8) return;
        nymRetryTimer.interval = Math.min(300000, 20000 * Math.pow(2, nymAutoRetries));
        nymLastAutoReconnect = 0;
        nymRetryTimer.restart();
    }

    // ---- bundled Tor (Settings > Node / Network > TOR NETWORK). Tor, Nym and I2P can run together:
    // "Network configuration" (netWallet / netSync / netTx) says which one each kind of traffic uses.
    property string torState: oshelper.torClient.state   // off | starting | connected | error
    property bool torNewIdentityBusy: false

    function torProxyUp() {
        return persistentSettings.torEnabled && oshelper.torClient.state === "connected";
    }

    function torConnect() {
        persistentSettings.torEnabled = true;
        oshelper.torClient.start();
    }

    function torDisconnect() {
        persistentSettings.torEnabled = false;
        oshelper.torClient.stop();
    }

    // ---- Network configuration (Settings > Node / Network, top). Anonymous by default: there is no
    // "normal network" choice; while the chosen network is not connected, that traffic is blocked.
    //   netWallet: wallet requests (prices, swaps, updates, remote nodes): "tor" | "nym"
    //   netSync:   local node peers and block sync (monerod --proxy):     "tor" | "nym" | "i2p"
    //              (i2p: no exits to clearnet peers and monerod takes no blocks from .i2p peers, so it does not sync)
    //   netTx:     local node's own transactions (monerod --tx-proxy):     "tor" | "i2p" | "both" (one --tx-proxy each)
    readonly property bool torNeeded: persistentSettings.netWallet === "tor" || persistentSettings.netSync === "tor" || txUses("tor")
    readonly property bool nymNeeded: persistentSettings.netWallet === "nym" || persistentSettings.netSync === "nym"
    readonly property bool i2pNeeded: txUses("i2p") || persistentSettings.netSync === "i2p"
    // Send transactions uses this network ("both" = Tor and I2P)
    function txUses(net) { return persistentSettings.netTx === net || persistentSettings.netTx === "both"; }
    // what a network is used for, for the TOR / NYM / I2P panels
    function netUses(net) {
        var u = [];
        if (persistentSettings.netWallet === net) u.push(qsTr("wallet") + translationManager.emptyString);
        if (persistentSettings.netSync === net) u.push(qsTr("node sync") + translationManager.emptyString);
        if (txUses(net)) u.push(qsTr("node transactions") + translationManager.emptyString);
        return u;
    }
    // start the networks the configuration needs (they are never stopped here: the user can disconnect one)
    function ensureNetworks() {
        if (isQuitting) return;
        if (torNeeded && !persistentSettings.torEnabled) torConnect();
        if (nymNeeded && !persistentSettings.nymVpnEnabled) nymVpnConnect();
        if (i2pNeeded && !persistentSettings.i2pEnabled) i2pConnect();
    }
    function setNetwork(kind, net) {
        if (kind === "wallet") persistentSettings.netWallet = net;
        else if (kind === "sync") persistentSettings.netSync = net === "i2p" ? "tor" : net;   // the local node cannot sync over I2P
        else if (kind === "tx") persistentSettings.netTx = net;
        ensureNetworks();
        daemonRouteTimer.restart();
        if (connTesting) cancelConnectionTest();
        if (kind === "wallet") Qt.callLater(runConnectionTest);
    }

    function torNewIdentity() {
        if (!torProxyUp() || torNewIdentityBusy) return;
        torNewIdentityBusy = true;
        oshelper.torClient.newIdentity();
    }

    // ---- bundled I2P (Settings > Node / Network > I2P NETWORK). I2P has no exits to the normal
    // internet, so it works next to Tor or Nym: .b32.i2p remote nodes and monerod --tx-proxy i2p.
    property string i2pState: oshelper.i2pClient.state
    property bool i2pWaitingTor: false   // Tor on but not up yet: the reseed waits for it

    function i2pOn() {
        return persistentSettings.i2pEnabled || i2pNeeded;
    }
    function i2pProxyUp() {
        return persistentSettings.i2pEnabled && oshelper.i2pClient.state === "connected";
    }
    function i2pConnect() {
        persistentSettings.i2pEnabled = true;
        // the first routers come by HTTPS from the reseed servers: through Tor or Nym when they are on
        if (torNeeded && !torProxyUp()) {
            i2pWaitingTor = true;
            return;
        }
        i2pWaitingTor = false;
        var route = approvedRoute();
        oshelper.i2pClient.start(route !== "" ? "socks://" + route : "");
    }
    function i2pDisconnect() {
        i2pWaitingTor = false;
        persistentSettings.i2pEnabled = false;
        oshelper.i2pClient.stop();
    }

    Connections {
        target: oshelper.i2pClient
        property bool wasConnected: false
        function onChanged() {
            var up = oshelper.i2pClient.state === "connected";
            if (up && !wasConnected) daemonRouteTimer.restart();
            wasConnected = up;
        }
    }

    Connections {
        target: oshelper.torClient
        property bool wasConnected: false
        function onChanged() {
            var up = oshelper.torClient.state === "connected";
            if (up && i2pWaitingTor && persistentSettings.i2pEnabled) Qt.callLater(i2pConnect);
            // new route: test it right away, like Nym
            if (up && !wasConnected && persistentSettings.torEnabled && !isQuitting) {
                if (connTesting) cancelConnectionTest();
                Qt.callLater(runConnectionTest, "tor");
            }
            if (up && !wasConnected) daemonRouteTimer.restart();
            wasConnected = up;
        }
        function onNewIdentityDone(ok, error) {
            torNewIdentityBusy = false;
            if (ok) {
                if (connTesting) cancelConnectionTest();
                Qt.callLater(runConnectionTest, "tor");
            } else {
                console.warn("Tor NEWNYM failed: " + error);
            }
        }
    }

    // the SOCKS5 address of the wallet's network when it is up, "" if not (extreme privacy, I2P reseed)
    function approvedRoute() {
        if (persistentSettings.netWallet === "nym")
            return nymVpnProxyUp() ? persistentSettings.nymVpnSocksAddress : (torProxyUp() ? oshelper.torClient.address : "");
        return torProxyUp() ? oshelper.torClient.address : (nymVpnProxyUp() ? persistentSettings.nymVpnSocksAddress : "");
    }

    // wallet through Tor: remote nodes must be hidden services (.onion / .i2p): no clearnet node sees the wallet's requests
    function torOnionOnly() {
        return persistentSettings.netWallet === "tor";
    }
    function isOnionNode(address) {
        return /^(?:https?:\/\/)?[a-z2-7]{16,56}\.onion(?::\d+)?\/?$/i.test((address || "").trim());
    }
    function isI2pNode(address) {
        return /^(?:https?:\/\/)?[a-z2-7]{52,}\.b32\.i2p(?::\d+)?\/?$/i.test((address || "").trim());
    }
    // .i2p nodes need I2P, .onion ones Tor; with the wallet through Tor clearnet nodes are not used
    // (through Nym they are: the node only sees a Nym exit)
    function remoteNodeAllowed(address) {
        if (isI2pNode(address)) return i2pOn();
        if (isOnionNode(address)) return torNeeded || persistentSettings.torEnabled;
        return !torOnionOnly();
    }
    // why a node of the list cannot be used now ("" = it can)
    function remoteNodeBlockedText(address) {
        if (remoteNodeAllowed(address)) return "";
        if (isI2pNode(address)) return qsTr(".i2p: connect I2P to use it") + translationManager.emptyString;
        if (isOnionNode(address)) return qsTr(".onion: connect Tor to use it") + translationManager.emptyString;
        return (i2pOn() ? qsTr("not .onion or .i2p: blocked") : qsTr("not .onion: blocked while Tor is on")) + translationManager.emptyString;
    }
    // index of the first node of the list that can be used now, -1 if none
    function firstAllowedNode() {
        for (var i = 0; i < remoteNodesModel.count; i++)
            if (remoteNodeAllowed(remoteNodesModel.get(i).address)) return i;
        return -1;
    }
    function showNodeNotAllowed(address) {
        if (isI2pNode(address)) {
            informationPopup.title = qsTr("I2P is off") + translationManager.emptyString;
            informationPopup.text = qsTr("This is an I2P node (.b32.i2p). Connect I2P in Settings > Node / Network > I2P NETWORK to use it.") + translationManager.emptyString;
        } else if (isOnionNode(address)) {
            informationPopup.title = qsTr("Tor is off") + translationManager.emptyString;
            informationPopup.text = qsTr("This is a Tor node (.onion). Connect Tor in Settings > Node / Network > TOR NETWORK to use it.") + translationManager.emptyString;
        } else {
            informationPopup.title = qsTr("Tor: .onion nodes only") + translationManager.emptyString;
            informationPopup.text = qsTr("While the wallet's connections go through Tor, it only connects to remote nodes that are hidden services (.onion). Pick one in Settings > Node / Network > TOR NETWORK > Remote .onion nodes, or choose Nym for the wallet in Network configuration.") + translationManager.emptyString
                                    + (i2pOn() ? " " + qsTr("With I2P on, .i2p nodes can be used too.") + translationManager.emptyString : "");
        }
        informationPopup.onCloseCallback = null;
        informationPopup.open();
    }
    // Tor / I2P changed with a remote node selected that cannot be used now: move to one that can
    function remoteRouteCheck() {
        if (!persistentSettings.useRemoteNode || !currentWallet || isQuitting)
            return;
        var address = remoteNodesModel.currentRemoteNode().address;
        if (remoteNodeAllowed(address))
            return;
        var i = firstAllowedNode();
        if (i >= 0) {
            remoteNodesModel.applyRemoteNode(i);
        } else {
            disconnectRemoteNode();
            showNodeNotAllowed(address);
        }
    }

    // .onion / .b32.i2p P2P peers the user added to the local node (TOR / I2P panels): "host:port"
    readonly property var anonPeers: {
        try { var l = JSON.parse(persistentSettings.anonPeers || "[]"); return Array.isArray(l) ? l : []; }
        catch (e) { return []; }
    }
    function anonPeerNet(address) {
        return /\.onion:\d+$/i.test(address) ? "tor" : /\.b32\.i2p:\d+$/i.test(address) ? "i2p" : "clear";
    }
    // address lists of Network configuration > Node addresses (monerod --add-exclusive-node / --add-peer;
    // --add-priority-node is anonPeers, shared with the TOR / I2P panels)
    function jsonList(text) {
        try { var l = JSON.parse(text || "[]"); return Array.isArray(l) ? l : []; }
        catch (e) { return []; }
    }
    readonly property var exclusiveNodes: jsonList(persistentSettings.exclusiveNodes)
    readonly property var extraPeers: jsonList(persistentSettings.extraPeers)
    function nodeList(kind) {
        return kind === "exclusive" ? exclusiveNodes : kind === "peer" ? extraPeers : anonPeers;
    }
    function setNodeList(kind, list) {
        var t = JSON.stringify(list);
        if (kind === "exclusive") persistentSettings.exclusiveNodes = t;
        else if (kind === "peer") persistentSettings.extraPeers = t;
        else persistentSettings.anonPeers = t;
        daemonRouteTimer.restart();
    }
    // "" when added, else the reason
    function addNodeAddress(kind, address) {
        address = (address || "").trim().replace(/^[a-z]+:\/\//i, "").replace(/\/+$/, "");
        if (!/^(?:[A-Za-z0-9.-]+|\[[0-9A-Fa-f:]+\]):\d{1,5}$/.test(address))
            return qsTr("Write host:port, for example abc…xyz.onion:18083 or 1.2.3.4:18080") + translationManager.emptyString;
        var l = nodeList(kind);
        if (l.indexOf(address) >= 0)
            return qsTr("Already in the list") + translationManager.emptyString;
        setNodeList(kind, l.concat([address]));
        return "";
    }
    function removeNodeAddress(kind, address) {
        setNodeList(kind, nodeList(kind).filter(function(a) { return a !== address; }));
    }
    // a .onion / .i2p address only works while its network's --tx-proxy is on
    function nodeAddressActive(address) {
        var net = anonPeerNet(address);
        return net === "clear" || txUses(net);
    }
    function addAnonPeer(address) {
        if (anonPeers.indexOf(address) >= 0) return;
        persistentSettings.anonPeers = JSON.stringify(anonPeers.concat([address]));
        daemonRouteTimer.restart();
    }
    function removeAnonPeer(address) {
        persistentSettings.anonPeers = JSON.stringify(anonPeers.filter(function(a) { return a !== address; }));
        daemonRouteTimer.restart();
    }
    // the peers monerod can reach now: their network's --tx-proxy is on
    function activeAnonPeers() {
        return anonPeers.filter(function(a) {
            return nodeAddressActive(a);
        });
    }

    // SOCKS5 route the local node must use right now ("" = direct)
    function daemonRoute() {
        // monerod reads a bare ip:port as SOCKS4a: say socks5:// explicitly
        return "socks5://" + (persistentSettings.netSync === "nym" ? persistentSettings.nymVpnSocksAddress
                            : persistentSettings.netSync === "i2p" ? oshelper.i2pClient.address : oshelper.torClient.address);
    }
    // monerod --tx-proxy for the node's own transactions (Network configuration > Send transactions)
    function daemonTxProxies() {
        var l = [];
        if (txUses("tor")) l.push("tor,socks5://" + oshelper.torClient.address + ",10");
        if (txUses("i2p")) l.push("i2p,socks5://" + oshelper.i2pClient.address + ",10");
        return l;
    }
    function daemonBaseFlags() {
        return persistentSettings.walletMode < 2 ? "--enable-dns-blocklist --out-peers 16 --no-igd" : persistentSettings.daemonFlags;
    }
    // the flags the app manages, in a fixed order: compared between the running monerod and the configuration
    function managedDaemonFlags(command) {
        var out = [];
        var re = /(?:^|\s)(--proxy|--tx-proxy|--bootstrap-daemon-proxy|--add-priority-node|--add-exclusive-node|--add-peer)(?:=|\s+)(\S+)|(?:^|\s)(--hide-my-port|--pad-transactions)(?=\s|$)/g;
        var m;
        while ((m = re.exec(command || "")) !== null) {
            if (m[3]) out.push(m[3]);
            else out.push(m[1] + " " + m[2]);
        }
        return out.sort().join(" ");
    }
    // true while the running monerod still has flags of an older Network configuration (a restart is due)
    property bool daemonCommandStale: false

    // the route changed (Tor <-> Nym) while monerod keeps running with the old --proxy:
    // restart it so it does not wait on a SOCKS5 port nobody listens to anymore
    function daemonRouteCheck() {
        if (persistentSettings.useRemoteNode || !daemonRunning || isQuitting) {
            daemonCommandStale = false;
            return;
        }
        // starting or stopping: look again a bit later instead of losing the change
        if (daemonStartStopInProgress !== 0) {
            daemonRouteTimer.restart();
            return;
        }
        // no monerod process found: nothing to compare, so do not restart (that loop left the node on "Starting...")
        var runningCommand = daemonManager.command(true);
        if (runningCommand === "") {
            daemonCommandStale = false;
            return;
        }
        var base = daemonBaseFlags();
        var running = managedDaemonFlags(runningCommand);
        var wanted = managedDaemonFlags(daemonFlagsFor(base));
        daemonCommandStale = running !== wanted;
        if (!daemonCommandStale)
            return;
        console.log("local node configuration changed (" + running + " -> " + wanted + "), restarting monerod");
        stopDaemon(function() { startDaemon(base); });
    }

    Timer {
        id: daemonRouteTimer
        interval: 3000
        onTriggered: { appWindow.daemonRouteCheck(); appWindow.remoteRouteCheck(); }
    }

    Connections {
        target: persistentSettings
        function onTorEnabledChanged() { daemonRouteTimer.restart(); }
        function onNymVpnEnabledChanged() { daemonRouteTimer.restart(); }
        function onI2pEnabledChanged() { daemonRouteTimer.restart(); }
        function onI2pRequiredChanged() { daemonRouteTimer.restart(); }
        function onNetSyncChanged() { daemonRouteTimer.restart(); }
        function onNetTxChanged() { daemonRouteTimer.restart(); }
        function onAnonPeersChanged() { daemonRouteTimer.restart(); }
        function onExclusiveNodesChanged() { daemonRouteTimer.restart(); }
        function onExtraPeersChanged() { daemonRouteTimer.restart(); }
        function onExtremePrivacyChanged() { daemonRouteTimer.restart(); }
        function onBootstrapNodeAddressChanged() { daemonRouteTimer.restart(); }
    }

    function setExtremePrivacy(on) {
        if (on === persistentSettings.extremePrivacy)
            return;
        if (on) {
            persistentSettings.extremePrivacyPrev = JSON.stringify({
                fiatPriceEnabled: persistentSettings.fiatPriceEnabled,
                checkForUpdates: persistentSettings.checkForUpdates
            });
            persistentSettings.fiatPriceEnabled = false;
            persistentSettings.checkForUpdates = false;
            persistentSettings.extremePrivacy = true;
        } else {
            persistentSettings.extremePrivacy = false;
            try {
                var prev = JSON.parse(persistentSettings.extremePrivacyPrev);
                if (prev.fiatPriceEnabled !== undefined) persistentSettings.fiatPriceEnabled = prev.fiatPriceEnabled;
                if (prev.checkForUpdates !== undefined) persistentSettings.checkForUpdates = prev.checkForUpdates;
            } catch (e) {}
        }
        // a remote node picks up the new proxy only when the wallet reconnects
        if (currentWallet && persistentSettings.useRemoteNode)
            connectRemoteNode();
    }

    // ---- macOS menu bar item (Settings > Interface) ----
    property string menuBarLast: ""

    function menuBarPriceText(cur) {
        var chip = titleBar.priceChip;
        var q = chip.quotes[cur];
        if (!q || !(q.price > 0)) return "";
        return chip.fmtPrice(cur, q.price);
    }

    function updateMenuBar() {
        var s = persistentSettings;
        var on = Qt.platform.os === "osx" && s.menuBarEnabled;
        if (!on) {
            if (menuBarLast !== "") {
                oshelper.setMenuBarItem(false, "", [], "");
                menuBarLast = "";
            }
            return;
        }
        var chip = titleBar.priceChip;
        var title = [];
        var lines = [];

        var unit = s.menuBarPriceUnit;
        var q = chip.quotes[unit];
        if (s.menuBarPrice && q && q.price > 0) {
            var t = chip.fmtPrice(unit, q.price);
            if (s.menuBarChange && !isNaN(q.change))
                t += " " + (q.change >= 0 ? "▲" : "▼") + Math.abs(q.change).toFixed(1) + "%";
            title.push(t);
        }
        var prices = ["BTC", "EUR", "USD"].filter(function(k) { return chip.quotes[k] && chip.quotes[k].price > 0; });
        if (prices.length > 0) {
            lines.push(qsTr("1 XMR · last 24 h") + translationManager.emptyString);
            prices.forEach(function(k) {
                var c = chip.quotes[k].change;
                lines.push("   " + chip.fmtPrice(k, chip.quotes[k].price) + (isNaN(c) ? "" : "   " + chip.fmtChange(c)));
            });
            lines.push("");
        }

        if (currentWallet) {
            var hidden = hideBalanceForced || s.hideBalance;
            var bal = hidden ? "•••" : walletManager.displayAmount(currentWallet.balance());
            if (s.menuBarBalance && !hidden)
                title.push(Number(bal).toFixed(4) + " XMR");
            lines.push(qsTr("Wallet") + ": " + walletName);
            lines.push(qsTr("Balance") + ": " + bal + " XMR");
            lines.push("");
        }

        var sync;
        if (daemonTarget > 1) {
            sync = daemonSynced
                ? qsTr("Node synchronized · block %1").arg(daemonHeight.toFixed(0))
                : qsTr("Node synchronizing · %1 / %2").arg(daemonHeight.toFixed(0)).arg(daemonTarget.toFixed(0));
            if (s.menuBarSync && !daemonSynced)
                title.push((daemonHeight / daemonTarget * 100).toFixed(1) + "%");
        } else {
            sync = qsTr("Node: no data");
        }
        lines.push(sync);
        var nym = nymVpnProxyUp() ? qsTr("NYM: connected")
                : s.nymVpnEnabled ? qsTr("NYM: connecting…") : qsTr("NYM: off");
        lines.push(nym);
        if (s.menuBarNym && s.nymVpnEnabled)
            title.push(nymVpnProxyUp() ? "NYM ●" : "NYM ○");

        var titleText = title.join("  ·  ");
        var open = qsTr("Open XMR Wallet+") + translationManager.emptyString;
        var key = titleText + "\n" + lines.join("\n");
        if (key === menuBarLast) return;
        menuBarLast = key;
        oshelper.setMenuBarItem(true, titleText, lines, open);
    }

    Timer {
        id: menuBarTimer
        interval: 15000
        repeat: true
        triggeredOnStart: true
        running: persistentSettings.menuBarEnabled
        onTriggered: appWindow.updateMenuBar()
        onRunningChanged: if (!running) appWindow.updateMenuBar()
    }

    // desktop widget on the wallpaper (Settings > Interface)
    Loader {
        active: Qt.platform.os === "osx" && persistentSettings.desktopWidgetEnabled
        sourceComponent: Component {
            MoneroComponents.DesktopWidget {
                visible: true
            }
        }
    }

    Connections {
        target: oshelper
        function onMenuBarOpenRequested() {
            appWindow.show();
            appWindow.raise();
            appWindow.requestActivate();
        }
    }

    function nymVpnProxyUp() {
        return persistentSettings.nymVpnEnabled && !nymVpnRestarting
               && (nymVpnState === "ready" || nymVpnState === "connected");
    }

    function nymVpnDisconnect() {
        nymVpnResetInfo();
        // Clear enabled before the synchronous state signal from stop().
        var wasEnabled = persistentSettings.nymVpnEnabled;
        persistentSettings.nymVpnEnabled = false;
        oshelper.nymClient.stop();
        if (wasEnabled) {
            persistentSettings.proxyEnabled = persistentSettings.nymVpnPrevProxyEnabled;
            persistentSettings.proxyAddress = persistentSettings.nymVpnPrevProxyAddress;
        }
        nymVpnRestarting = false;
        nymVpnState = "off";
        nymVpnMessage = qsTr("The wallet's Nym client is disconnected. NymVPN is unchanged; a local node using this proxy will wait until you reconnect.") + translationManager.emptyString;
    }

    readonly property var fiatCurrencies: [
        "USD", "EUR", "GBP", "AUD", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK",
        "HKD", "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR",
        "NOK", "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "ZAR"
    ]
    readonly property var priceSources: PriceSources.catalog
    readonly property var favoriteCurrencies: {
        var list;
        try { list = JSON.parse(persistentSettings.favoriteCurrenciesJson); } catch (e) { list = []; }
        if (!Array.isArray(list)) list = [];
        list = list.filter(function(c,i) { return (fiatCurrencies.indexOf(c) >= 0 || c === "BTC") && list.indexOf(c) === i; });
        return list.length ? list : ["USD", "EUR", "BTC"];
    }
    function priceSourceEnabled(key) { return PriceSources.enabled(persistentSettings.priceSourcesJson, key); }
    function historicalPriceSource(pair) { return PriceSources.historySource(persistentSettings.priceSourcesJson, persistentSettings.fiatPriceProvider, pair); }
    function priceSourceName(key) {
        var source = priceSources.filter(function(s) { return s.key === key; });
        return source.length ? source[0].name : "Sin fuente histórica activa";
    }
    function setPriceSourceEnabled(key, enabled) {
        var state;
        try { state = JSON.parse(persistentSettings.priceSourcesJson); } catch(e) { state = {}; }
        if (!state || typeof state !== "object" || Array.isArray(state)) state = {};
        state[key] = enabled;
        persistentSettings.priceSourcesJson = JSON.stringify(state);
        if (!enabled && persistentSettings.fiatPriceProvider === key) {
            var alternatives = priceSources.filter(function(s) { return s.ticker && priceSourceEnabled(s.key); });
            persistentSettings.fiatPriceProvider = alternatives.length ? alternatives[0].key : "";
        } else if (enabled && !persistentSettings.fiatPriceProvider && fiatPriceAPIs.hasOwnProperty(key)) {
            persistentSettings.fiatPriceProvider = key;
        }
    }
    function setFavoriteCurrency(code, enabled) {
        var list = favoriteCurrencies.slice();
        if (enabled && list.indexOf(code) < 0) list.push(code);
        if (!enabled) list = list.filter(function(c) { return c !== code; });
        if (!list.length) return;
        persistentSettings.favoriteCurrenciesJson = JSON.stringify(list);
        if (list.indexOf(fiatApiCurrencySymbol()) < 0)
            persistentSettings.fiatPriceCurrency = "xmr" + list[0].toLowerCase();
    }
    function priceRequestAllowed(url) {
        var key = PriceSources.sourceForUrl(url);
        return persistentSettings.fiatPriceEnabled && key !== "" && priceSourceEnabled(key);
    }
    function priceGetJSON(url, callback) {
        if (!priceRequestAllowed(url)) { callback(url, "", "Fuente desactivada"); return; }
        network.getJSON(url, function(u,r,e) { callback(u, priceRequestAllowed(u) ? r : "", priceRequestAllowed(u) ? e : "Fuente desactivada"); });
    }
    function pricePostJSON(url, body, callback) {
        if (!priceRequestAllowed(url)) { callback(url, "", "Fuente desactivada"); return; }
        network.postJSON(url, body, function(u,r,e) { callback(u, priceRequestAllowed(u) ? r : "", priceRequestAllowed(u) ? e : "Fuente desactivada"); });
    }
    Connections {
        target: persistentSettings
        function onPriceSourcesJsonChanged() { appWindow.fiatApiUpdatePrice(); appWindow.fiatApiRefresh(); }
        function onFiatPriceProviderChanged() {
            appWindow.restoreFiatTicker();
            appWindow.fiatApiUpdatePrice();
            appWindow.fiatApiRefresh();
        }
        function onFiatPriceCurrencyChanged() { appWindow.fiatApiUpdatePrice(); appWindow.fiatApiRefresh(); }
    }

    property var fiatPriceAPIs: {
        return {
            "kraken": "https://api.kraken.com/0/public/Ticker?pair=XMRUSD",
            "coinpaprika": "https://api.coinpaprika.com/v1/tickers/xmr-monero",
            "coingecko": "https://api.coingecko.com/api/v3/coins/monero/market_chart?vs_currency=usd&days=1"
        }
    }

    // true if wallet ever synchronized
    property bool walletInitialized : false

    // Current selected address / subaddress / (Receive/Account page)
    property var current_address
    property var current_address_label: "Primary"
    property int current_subaddress_table_index: 0

    function showPageRequest(page) {
        middlePanel.state = page
        leftPanel.selectItem(page)
    }

    function lock() {
        if (currentWallet && currentWallet.getBackgroundSyncType() != Wallet.BackgroundSync_Off) {
            appWindow.showProcessingSplash(qsTr("Locking..."));
            currentWallet.startBackgroundSync()
            return;
        }

        passwordDialog.onRejectedCallback = function() { appWindow.showWizard(); }
        passwordDialog.onAcceptedCallback = function() {
            if(walletPassword === passwordDialog.password)
                passwordDialog.close();
            else 
                passwordDialog.showError(qsTr("Wrong password") + translationManager.emptyString);
        }
        passwordDialog.open(usefulName(persistentSettings.wallet_path));
    }

    function sequencePressed(obj, seq) {
        if(seq === undefined || !leftPanel.enabled)
            return
        if(seq === "Ctrl") {
            ctrlPressed = true
            return
        }

        // lock wallet on demand
        if(seq === "Ctrl+L" && !passwordDialog.visible) lock()
        if(seq === "Ctrl+S") middlePanel.state = "Transfer"
        else if(seq === "Ctrl+R") middlePanel.state = "Receive"
        else if(seq === "Ctrl+H") middlePanel.state = "History"
        else if(seq === "Ctrl+B") middlePanel.state = "AddressBook"
        else if(seq === "Ctrl+E") middlePanel.state = "Settings"
        else if(seq === "Ctrl+D") middlePanel.state = "Advanced"
        else if(seq === "Ctrl+T") middlePanel.state = "Account"
        else if(seq === "Ctrl+Tab" || seq === "Alt+Tab") {
            /*
            if(middlePanel.state === "Transfer") middlePanel.state = "Receive"
            else if(middlePanel.state === "Receive") middlePanel.state = "TxKey"
            else if(middlePanel.state === "TxKey") middlePanel.state = "SharedRingDB"
            else if(middlePanel.state === "SharedRingDB") middlePanel.state = "History"
            else if(middlePanel.state === "History") middlePanel.state = "AddressBook"
            else if(middlePanel.state === "AddressBook") middlePanel.state = "Mining"
            else if(middlePanel.state === "Mining") middlePanel.state = "Sign"
            else if(middlePanel.state === "Sign") middlePanel.state = "Settings"
            */
            if(middlePanel.state === "Settings") middlePanel.state = "Account"
            else if(middlePanel.state === "Account") middlePanel.state = "Transfer"
            else if(middlePanel.state === "Transfer") middlePanel.state = "AddressBook"
            else if(middlePanel.state === "AddressBook") middlePanel.state = "Receive"
            else if(middlePanel.state === "Receive") middlePanel.state = "History"
            else if(middlePanel.state === "History") middlePanel.state = "Advanced"
            else if(middlePanel.state === "Advanced") middlePanel.state = "Settings"
        } else if(seq === "Ctrl+Shift+Backtab" || seq === "Alt+Shift+Backtab") {
            /*
            if(middlePanel.state === "Settings") middlePanel.state = "Sign"
            else if(middlePanel.state === "Sign") middlePanel.state = "Mining"
            else if(middlePanel.state === "Mining") middlePanel.state = "AddressBook"
            else if(middlePanel.state === "AddressBook") middlePanel.state = "History"
            else if(middlePanel.state === "History") middlePanel.state = "SharedRingDB"
            else if(middlePanel.state === "SharedRingDB") middlePanel.state = "TxKey"
            else if(middlePanel.state === "TxKey") middlePanel.state = "Receive"
            else if(middlePanel.state === "Receive") middlePanel.state = "Transfer"
            */
            if(middlePanel.state === "Settings") middlePanel.state = "Advanced"
            else if(middlePanel.state === "Advanced") middlePanel.state = "History"
            else if(middlePanel.state === "History") middlePanel.state = "Receive"
            else if(middlePanel.state === "Receive") middlePanel.state = "AddressBook"
            else if(middlePanel.state === "AddressBook") middlePanel.state = "Transfer"
            else if(middlePanel.state === "Transfer") middlePanel.state = "Account"
            else if(middlePanel.state === "Account") middlePanel.state = "Settings"
        }

        if (middlePanel.state !== "Advanced") updateBalance();

        leftPanel.selectItem(middlePanel.state)
    }

    function sequenceReleased(obj, seq) {
        if(seq === "Ctrl")
            ctrlPressed = false
    }

    function mousePressed(obj, mouseX, mouseY) {}
    function mouseReleased(obj, mouseX, mouseY) {}

    function loadPage(page) {
        middlePanel.state = page;
        leftPanel.selectItem(page);
    }

    function openWallet(prevState) {
        passwordDialog.onAcceptedCallback = function() {
            walletPassword = passwordDialog.password;
            initialize();
        }
        passwordDialog.onRejectedCallback = function() {
            if (prevState) {
                appWindow.viewState = prevState;
            }
            if (wizard.wizardState == "wizardOpenWallet1") {
                wizard.wizardStateView.wizardOpenWallet1View.pageRoot.forceActiveFocus();
            }
        };
        passwordDialog.open(usefulName(persistentSettings.wallet_path));
    }

    function initialize() {
        console.log("initializing..")

        // Reload transfer page with translations enabled
        middlePanel.transferView.onPageCompleted();

        // If currentWallet exists, we're just switching daemon - close/reopen wallet
        if (typeof currentWallet !== "undefined" && currentWallet !== null) {
            console.log("Daemon change - closing " + currentWallet)
            closeWallet();
        } else if (!walletInitialized) {
            // start on the Account page if not changing daemon
            middlePanel.state = "Account";
            leftPanel.selectItem(middlePanel.state)
        }

        // Local daemon settings
        walletManager.setDaemonAddressAsync(localDaemonAddress);

        // enable timers
        userInActivityTimer.running = true;

        // wallet already opened with wizard, we just need to initialize it
        var wallet_path = persistentSettings.wallet_path;
        if(isIOS)
            wallet_path = appWindow.accountsDir + wallet_path;
        console.log("opening wallet at: ", wallet_path, ", network type: ", persistentSettings.nettype == NetworkType.MAINNET ? "mainnet" : persistentSettings.nettype == NetworkType.TESTNET ? "testnet" : "stagenet");

        // the splash shows at once, also while the connected Trezors are listed
        this.onWalletOpening();
        var openNow = function() {
            appWindow.onWalletOpening();
            walletManager.openWalletAsync(
                wallet_path,
                walletPassword,
                persistentSettings.nettype,
                persistentSettings.kdfRounds);
        };
        // a Trezor wallet asks which Trezor to use when several are connected (a parked one keeps its own)
        if (isTrezorWallet(persistentSettings.wallet_path) && !isParkedWallet(wallet_path))
            chooseTrezor(persistentSettings.wallet_path, openNow, function() { appWindow.showWizard(); });
        else
            openNow();
    }

    // ---- quick wallet switch: wallets unlocked in this session, password kept only in memory ----
    property var unlockedWallets: []   // [{ path, name, nettype, password }]

    function rememberUnlockedWallet(path, password, nettype) {
        if (!persistentSettings.quickWalletSwitch || !path) return;
        var list = unlockedWallets.filter(function(w) { return w.path !== path; });
        list.push({ path: path, name: usefulName(path), nettype: nettype, password: password,
                    hw: !!(currentWallet && currentWallet.isHwBacked()) });
        unlockedWallets = list;
    }

    function isUnlockedWallet(path) {
        return persistentSettings.quickWalletSwitch && unlockedWallets.some(function(w) { return w.path === path; });
    }

    function forgetUnlockedWallet(path) {
        unlockedWallets = unlockedWallets.filter(function(w) { return w.path !== path; });
        walletManager.closeParkedWallet(path);
    }

    // keep only the open wallet (inactivity lock, option turned off)
    function forgetOtherUnlockedWallets() {
        var cur = persistentSettings.wallet_path;
        unlockedWallets = persistentSettings.quickWalletSwitch
            ? unlockedWallets.filter(function(w) { return w.path === cur; }) : [];
        walletManager.closeParkedWallets(persistentSettings.quickWalletSwitch && !currentWallet ? cur : "");
    }

    // ---- seed accounts: more wallets ("4..." addresses) from the same seed + passphrase N ----
    // account 0 is the wallet itself (no passphrase); account N lives in <wallet>.cuenta-N and was
    // restored from the same seed with the seed offset passphrase "N"
    // the accounts live in <wallet folder>/wallets_passphrase/<name>.cuenta-N, a folder the wallet list skips
    readonly property string seedAccountsFolder: "wallets_passphrase"

    function seedBasePath(path) {
        var p = String(path).replace(/\.keys$/, "");
        var m = p.match(/^(.*)\/wallets_passphrase\/([^\/]+)\.cuenta-\d+$/);
        if (m) return m[1] + "/" + m[2];
        return p.replace(/\.cuenta-\d+$/, "");
    }

    function seedAccountOffset(path) {
        var m = String(path).replace(/\.keys$/, "").match(/\.cuenta-(\d+)$/);
        return m ? parseInt(m[1]) : 0;
    }

    function seedAccountPath(base, n, ext) {
        if (n === 0) return base + ext;
        var i = base.lastIndexOf("/");
        return base.substring(0, i) + "/" + seedAccountsFolder + "/" + base.substring(i + 1) + ".cuenta-" + n + ext;
    }

    // [{ offset, path }] of the accounts of the open wallet's seed that exist on disk
    function seedAccounts() {
        var cur = String(persistentSettings.wallet_path);
        if (!cur) return [];
        var base = seedBasePath(cur);
        var ext = /\.keys$/.test(cur) ? ".keys" : "";
        var list = [{ offset: 0, path: seedAccountPath(base, 0, ext) }];
        var misses = 0;
        for (var n = 1; n <= 100 && misses < 5; n++) {
            var p = seedAccountPath(base, n, ext);
            if (walletManager.walletExists(p)) {
                list.push({ offset: n, path: p });
                misses = 0;
            } else {
                misses++;
            }
        }
        return list;
    }

    // the accounts share the wallet password: unlocking one unlocks the switch to all of them
    function rememberSeedAccounts() {
        if (!persistentSettings.quickWalletSwitch || !currentWallet || currentWallet.isHwBacked()) return;
        seedAccounts().forEach(function(a) {
            if (!unlockedWallets.some(function(w) { return w.path === a.path; }))
                rememberUnlockedWallet(a.path, walletPassword, persistentSettings.nettype);
        });
    }

    function canCreateSeedAccount() {
        return !!currentWallet && !currentWallet.isHwBacked() && !viewOnly
               && seedAccountOffset(persistentSettings.wallet_path) === 0;
    }

    function createSeedAccount() {
        if (!canCreateSeedAccount()) return;
        var seed = currentWallet.seed;
        if (!seed) {
            appWindow.showStatusMessage(qsTr("This wallet has no seed (created from keys)"), 6);
            return;
        }
        var cur = String(persistentSettings.wallet_path);
        var ext = /\.keys$/.test(cur) ? ".keys" : "";
        var accounts = seedAccounts();
        var n = accounts[accounts.length - 1].offset + 1;
        var path = seedAccountPath(seedBasePath(cur), n, ext);
        var password = walletPassword;
        var nettype = persistentSettings.nettype;
        appWindow.showProcessingSplash(qsTr("Creating account %1...").arg(n));
        walletManager.createSeedOffsetWalletAsync(path, password, seed, String(n), nettype,
                                                  currentWallet.walletCreationHeight, persistentSettings.kdfRounds,
                                                  function(ok, error, address) {
            hideProcessingSplash();
            if (!ok) {
                appWindow.showStatusMessage(qsTr("Could not create the account: %1").arg(error), 8);
                return;
            }
            console.log("Seed account created");
            rememberUnlockedWallet(path, password, nettype);
            openSeedAccount(path);
        });
    }

    // switch to another account of the same seed (same password)
    function openSeedAccount(path) {
        if (!currentWallet || path === persistentSettings.wallet_path) return;
        if (isUnlockedWallet(path)) {
            switchWallet(path);
            return;
        }
        var password = walletPassword;
        closeWallet(function() {
            clearMoneroCardLabelText();
            persistentSettings.wallet_path = path;
            walletPassword = password;
            initialize();
        }, true);
    }

    function switchWallet(path) {
        if (!currentWallet || path === persistentSettings.wallet_path) return;
        var w = unlockedWallets.filter(function(x) { return x.path === path; })[0];
        if (!w) return;
        if (!walletManager.walletExists(w.path)) {
            forgetUnlockedWallet(w.path);
            appWindow.showStatusMessage(qsTr("Wallet not found: %1").arg(w.name), 5);
            return;
        }
        closeWallet(function() {
            clearMoneroCardLabelText();
            leftPanel.minutesToUnlock = "";
            middlePanel.transferView.clearFields();
            middlePanel.receiveView.clearFields();
            middlePanel.historyView.clearFields();
            middlePanel.addressBookView.clearFields();
            persistentSettings.wallet_path = w.path;
            persistentSettings.nettype = w.nettype;
            walletPassword = w.password;
            initialize();
        }, "park");
    }

    Timer {
        id: localDaemonCheck
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: !persistentSettings.useRemoteNode && appWindow.disconnected && daemonStartStopInProgress === 0
                 && typeof daemonManager !== "undefined"
        onTriggered: daemonManager.runningAsync(persistentSettings.nettype, persistentSettings.blockchainDataDir, function(running) {
            appWindow.localDaemonAlive = running && daemonStartStopInProgress === 0;
        })
        onRunningChanged: if (!running && !appWindow.disconnected) appWindow.localDaemonAlive = false
    }

    function gracefulQuit() {
        if (!requestScheduledExit(function() { gracefulQuit(); })) return;
        if (isQuitting)
            return;
        isQuitting = true;
        closeWallet(function() {
            // wallets closed in the background by a quick switch must finish saving first
            appWindow.showProcessingSplash(qsTr("Closing wallet..."));
            walletManager.waitClosingWalletsAsync(function() {
                hideProcessingSplash();
                gracefulShutdownComplete();
            });
        })
    }

    // background: the wallet saves and closes on its own thread (quick switch, back to the wizard),
    // so the UI does not wait for a refresh in progress
    function closeWallet(callback, background) {
        if (middlePanel.trezorView.busy !== "") {
            isQuitting = false;
            showStatusMessage(qsTr("Wait for the Trezor operation to finish before closing or switching wallets."), 5);
            return;
        }
        if (scheduledRunningId !== "" || scheduledSaving) {
            isQuitting = false;
            showStatusMessage(qsTr("Wait for the payment or save to finish before closing or switching wallets."), 5);
            return;
        }

        // Finish wallet-specific writes before detaching their owner.
        if ((middlePanel.notesView && middlePanel.notesView.saving)
                || (middlePanel.receiveView && middlePanel.receiveView.creatingGroup)
                || (middlePanel.customAddressesView && middlePanel.customAddressesView.adding)
                || (middlePanel.accountView && middlePanel.accountView.trimming)) {
            isQuitting = false;
            showStatusMessage(qsTr("Wait for the payment or save to finish before closing or switching wallets."), 5);
            return;
        }
        if (middlePanel.notesView && middlePanel.notesView.dirty && middlePanel.notesView.unlocked) {
            middlePanel.notesView.save(function() {
                if (!middlePanel.notesView.dirty) closeWallet(callback, background);
                else isQuitting = false;
            });
            return;
        }

        // Disconnect all listeners
        if (typeof currentWallet === "undefined" || currentWallet === null) {
            if (callback) {
                callback();
            }
            return;
        }

        currentWallet.heightRefreshed.disconnect(onHeightRefreshed);
        currentWallet.refreshed.disconnect(onWalletRefresh)
        currentWallet.updated.disconnect(onWalletUpdate)
        currentWallet.backgroundSyncSetup.disconnect(onBackgroundSyncSetup)
        currentWallet.backgroundSyncStarted.disconnect(onBackgroundSyncStarted)
        currentWallet.backgroundSyncStopped.disconnect(onBackgroundSyncStopped)
        currentWallet.newBlock.disconnect(onWalletNewBlock)
        currentWallet.moneySpent.disconnect(onWalletMoneySent)
        currentWallet.moneyReceived.disconnect(onWalletMoneyReceived)
        currentWallet.unconfirmedMoneyReceived.disconnect(onWalletUnconfirmedMoneyReceived)
        currentWallet.transactionCreated.disconnect(onTransactionCreated)
        currentWallet.connectionStatusChanged.disconnect(onWalletConnectionStatusChanged)
        currentWallet.deviceButtonRequest.disconnect(onDeviceButtonRequest);
        currentWallet.deviceButtonPressed.disconnect(onDeviceButtonPressed);
        currentWallet.walletPassphraseNeeded.disconnect(onWalletPassphraseNeededWallet);
        currentWallet.walletPairingCodeNeeded.disconnect(onWalletPairingCodeNeededWallet);
        currentWallet.transactionCommitted.disconnect(onTransactionCommitted);
        scheduledRunningId = "";
        scheduledRequestId = 0;
        scheduledCommitting = false;
        minedSpend = null;
        minedAccountActive = false;
        middlePanel.paymentClicked.disconnect(handlePayment);
        middlePanel.sweepUnmixableClicked.disconnect(handleSweepUnmixable);
        middlePanel.getProofClicked.disconnect(handleGetProof);
        middlePanel.checkProofClicked.disconnect(handleCheckProof);

        currentWallet.cancelAddressSearch();
        // Dialogs opened for this wallet must not remain actionable in the next one.
        inputDialog.onAcceptedCallback = null;
        inputDialog.onRejectedCallback = null;
        if (inputDialog.visible) inputDialog.close();
        confirmationDialog.onAcceptedCallback = null;
        confirmationDialog.onRejectedCallback = null;
        if (confirmationDialog.visible) confirmationDialog.close();
        informationPopup.onCloseCallback = null;
        if (informationPopup.visible) informationPopup.close();
        middlePanel.clearWalletPages();
        current_subaddress_table_index = 0;
        current_address = "";
        appWindow.walletName = "";
        appWindow.walletDeviceLabel = "";
        currentWallet = undefined;

        if (background === "park") {
            // stays loaded and syncing; switching back resumes it at once
            walletManager.parkWallet();
            if (callback)
                callback();
            return;
        }
        if (background) {
            walletManager.closeWalletInBackground();
            if (callback)
                callback();
            return;
        }

        appWindow.showProcessingSplash(qsTr("Closing wallet..."));
        if (callback) {
            walletManager.closeWalletAsync(function() {
                hideProcessingSplash();
                callback();
            });
        } else {
            walletManager.closeWallet();
            hideProcessingSplash();
        }
    }

    function connectWallet(wallet) {
        currentWallet = wallet
        loadScheduledSends(wallet);

        walletName = usefulName(wallet.path)
        walletDeviceLabel = wallet.isTrezor() ? wallet.deviceLabel() : ""
        if (wallet.isTrezor() && openingTrezorPath !== "")
            rememberTrezorWallet(persistentSettings.wallet_path, openingTrezorPath);
        openingTrezorPath = "";
        openingTrezorLabel = "";

        viewOnly = currentWallet.viewOnly;
        backgroundSyncType = currentWallet.getBackgroundSyncType();

        // New wallets saves the testnet flag in keys file.
        if(persistentSettings.nettype != currentWallet.nettype) {
            console.log("Using network type from keys file")
            persistentSettings.nettype = currentWallet.nettype;
        }

        // connect handlers
        currentWallet.heightRefreshed.connect(onHeightRefreshed);
        currentWallet.refreshed.connect(onWalletRefresh)
        currentWallet.updated.connect(onWalletUpdate)
        currentWallet.backgroundSyncSetup.connect(onBackgroundSyncSetup)
        currentWallet.backgroundSyncStarted.connect(onBackgroundSyncStarted)
        currentWallet.backgroundSyncStopped.connect(onBackgroundSyncStopped)
        currentWallet.newBlock.connect(onWalletNewBlock)
        currentWallet.moneySpent.connect(onWalletMoneySent)
        currentWallet.moneyReceived.connect(onWalletMoneyReceived)
        currentWallet.unconfirmedMoneyReceived.connect(onWalletUnconfirmedMoneyReceived)
        currentWallet.transactionCreated.connect(onTransactionCreated)
        currentWallet.connectionStatusChanged.connect(onWalletConnectionStatusChanged)
        currentWallet.deviceButtonRequest.connect(onDeviceButtonRequest);
        currentWallet.deviceButtonPressed.connect(onDeviceButtonPressed);
        currentWallet.walletPassphraseNeeded.connect(onWalletPassphraseNeededWallet);
        currentWallet.walletPairingCodeNeeded.connect(onWalletPairingCodeNeededWallet);
        currentWallet.transactionCommitted.connect(onTransactionCommitted);
        currentWallet.proxyAddress = Qt.binding(persistentSettings.getWalletProxyAddress);
        middlePanel.paymentClicked.connect(handlePayment);
        middlePanel.sweepUnmixableClicked.connect(handleSweepUnmixable);
        middlePanel.getProofClicked.connect(handleGetProof);
        middlePanel.checkProofClicked.connect(handleCheckProof);

        persistentSettings.restore_height = currentWallet.walletCreationHeight;

        console.log("Recovering from seed: ", persistentSettings.is_recovering)
        console.log("restore Height", persistentSettings.restore_height)

        if (persistentSettings.useRemoteNode) {
            // Tor on / I2P required: never open against a node that cannot be used; take the first one that can, else nothing reachable
            if (!remoteNodeAllowed(remoteNodesModel.currentRemoteNode().address) && firstAllowedNode() >= 0)
                remoteNodesModel.selected = firstAllowedNode();
            const remoteNode = remoteNodesModel.currentRemoteNode();
            currentDaemonAddress = remoteNodeAllowed(remoteNode.address) ? remoteNode.address : "127.0.0.1:1";
            if (!remoteNodeAllowed(remoteNode.address))
                Qt.callLater(function() { showNodeNotAllowed(remoteNode.address); });
            currentWallet.setDaemonLogin(remoteNode.username, remoteNode.password);
        } else {
            currentDaemonAddress = localDaemonAddress;
        }

        // resumed from the background (quick switch): already initialised, connected and synced
        if (walletManager.lastOpenResumed()) {
            console.log("wallet resumed from the background, skipping init");
            currentWallet.startRefresh();   // a hardware wallet may have paused while in the background
            Qt.callLater(function() {
                if (!currentWallet) return;
                onWalletConnectionStatusChanged(currentWallet.connected(true));
                currentWallet.history.refresh(currentWallet.currentSubaddressAccount);
                onWalletRefresh();
                onWalletUpdate();
            });
            return;
        }

        console.log("initializing with daemon address: ", currentDaemonAddress)
        currentWallet.initAsync(
            currentDaemonAddress,
            isTrustedDaemon(),
            0,
            persistentSettings.is_recovering,
            persistentSettings.is_recovering_from_device,
            persistentSettings.restore_height,
            persistentSettings.getWalletProxyAddress());

        // save wallet keys in case wallet settings have been changed in the init
        currentWallet.setPassword(walletPassword);
    }

    function isTrustedDaemon() {
        return appWindow.walletMode >= 2 && (!persistentSettings.useRemoteNode || remoteNodesModel.currentRemoteNode().trusted);
    }

    function usefulName(path) {
        // arbitrary "short enough" limit
        if (path.length < 32)
            return path
        return path.replace(/.*[\/\\]/, '').replace(/\.keys$/, '')
    }

    function getUnlockedBalance() {
        if(!currentWallet){
            return 0
        }
        return currentWallet.unlockedBalance()
    }

    Connections {
        target: appWindow.currentWallet
        function onCurrentSubaddressAccountChanged() {
            appWindow.updateBalance();
        }
    }

    property int accountLabelsRevision: 0
    Connections {
        target: appWindow.currentWallet ? appWindow.currentWallet.subaddressAccount : null
        function onRefreshFinished() { appWindow.accountLabelsRevision++; }
    }
    Connections {
        target: appWindow.currentWallet ? appWindow.currentWallet.subaddress : null
        function onRefreshFinished() { appWindow.accountLabelsRevision++; }
    }

    function updateBalance() {
        if (!currentWallet)
            return;

        var balance = "?.??";
        var balanceU = "?.??";
        if(!hideBalanceForced && !persistentSettings.hideBalance){
            balance = walletManager.displayAmount(currentWallet.balance());
            balanceU = walletManager.displayAmount(currentWallet.unlockedBalance());
        }

        if (persistentSettings.fiatPriceEnabled) {
            appWindow.fiatApiUpdateBalance(balance);
        }

        leftPanel.minutesToUnlock = (balance !== balanceU) ? currentWallet.history.minutesToUnlock : "";
        leftPanel.balanceString = balance
        leftPanel.balanceUnlockedString = balanceU
        if (middlePanel.state === "Account") {
            middlePanel.accountView.balanceAllText = walletManager.displayAmount(appWindow.currentWallet.balanceAll()) + " XMR";
            middlePanel.accountView.unlockedBalanceAllText = walletManager.displayAmount(appWindow.currentWallet.unlockedBalanceAll()) + " XMR";
        }
    }

    function onUriHandler(uri){
        if (uri && (uri.startsWith("monero://") || uri.startsWith("monero:"))) {
            const normalizedUri = uri.replace("monero://", "monero:");
            const parsed = walletManager.parse_uri_to_object(normalizedUri);

            if (parsed.error) {
                console.log("Invalid Monero URI: " + parsed.error);
            } else {
                middlePanel.transferView.sendTo(
                    parsed.address || "",
                    parsed.payment_id || "",
                    parsed.tx_description || "",
                    parsed.amount || ""
                );

                appWindow.raise();
                appWindow.show();
            }
        }
    }

    function onWalletConnectionStatusChanged(status){
        console.log("Wallet connection status changed " + status)
        middlePanel.updateStatus();
        leftPanel.networkStatus.connected = status
        if (status == Wallet.ConnectionStatus_Disconnected) {
            firstBlockSeen = 0;
        }

        // If wallet isnt connected, advanced wallet mode and no daemon is running - Ask
        if (appWindow.walletMode >= 2 && !persistentSettings.useRemoteNode && !walletInitialized && disconnected) {
            daemonManager.runningAsync(persistentSettings.nettype, persistentSettings.blockchainDataDir, function(running) {
                // start the local node right away (no "starting in 10 seconds" window);
                // skip if a start or stop is already under way
                if (!running && daemonStartStopInProgress === 0) {
                    appWindow.startDaemon(persistentSettings.daemonFlags);
                }
            });
        }
        // initialize transaction history once wallet is initialized first time;
        if (!walletInitialized) {
            currentWallet.history.refresh(currentWallet.currentSubaddressAccount)
            walletInitialized = true

            // check if daemon was already mining and add mining logo if true
            if (!persistentSettings.useRemoteNode || persistentSettings.allowRemoteNodeMining) {
                middlePanel.advancedView.miningView.update();
            }
        }
    }

    function onDeviceButtonRequest(code){
        // the Trezor animation lives inside the window that is already open (no full-window overlay)
        playFx("alert");
        if (txConfirmationPopup.visible) {
            txConfirmationPopup.bottomTextAnimation.running = true
            if (!txConfirmationPopup.errorText.visible) {
                txConfirmationPopup.bottomText.text  = qsTr("Please confirm transaction on the device...") + translationManager.emptyString;
            } else {
                txConfirmationPopup.bottomText.text  = qsTr("Please proceed to the device...") + translationManager.emptyString;
            }
        } else {
            prevSplashText = splash.messageText;
            splashDisplayedBeforeButtonRequest = splash.visible;
            splash.addressText = deviceShowAddress;
            splash.subText = deviceShowAddress !== ""
                ? qsTr("Check that the address on the device is exactly this one:") + translationManager.emptyString
                : qsTr("Check the details on the device screen and confirm them there.") + translationManager.emptyString;
            splash.deviceMode = true;
            splash.cancelling = false;
            appWindow.showProcessingSplash(qsTr("Please proceed to the device..."));
        }
    }

    function onDeviceButtonPressed(){
        devicePrompt.hide();
        splash.deviceMode = false;
        splash.cancelling = false;
        deviceShowAddress = "";
        if (txConfirmationPopup.visible) {
            txConfirmationPopup.bottomTextAnimation.running = false;
            txConfirmationPopup.bottomText.text  = qsTr("Signing transaction in the device...") + translationManager.emptyString;
        } else {
            if (splashDisplayedBeforeButtonRequest){
                appWindow.showProcessingSplash(prevSplashText);
            } else {
                hideProcessingSplash();
            }
        }
    }

    function onWalletOpening(){
        appWindow.showProcessingSplash(qsTr("Opening wallet ..."));
    }

    // ---- mined addresses (Wallet+ > Mine addresses): watched one by one, kept in the wallet cache ----
    property int minedAddressesTick: 0     // bumps when the list changes, for bindings
    // a mined address being spent from the Send page ({account, index, address, label}); while set, the wallet
    // takes inputs only from it and its balance is the one shown and checked
    property var minedSpend: null
    // the mined addresses account is the selected account (Accounts page)
    property bool minedAccountActive: false
    function selectMinedAccount(on) {
        if (scheduledRunningId !== "") return;
        on = on && !!currentWallet && minedAddresses().length > 0;
        if (currentWallet) currentWallet.setMinedAccountActive(on);
        if (minedAccountActive === on) return;
        minedAccountActive = on;
        updateBalance();
    }
    function spendFromMined(m) {
        if (!currentWallet || scheduledRunningId !== "") return;
        currentWallet.setSpendSource(m.account, m.index);
        minedSpend = m;
        updateBalance();
        showPageRequest("Transfer");
    }
    function stopMinedSpend() {
        if (currentWallet) currentWallet.setSpendSource(-1, -1);
        if (!minedSpend) return;
        minedSpend = null;
        updateBalance();
    }
    // leaving the Send page ends spending from the mined address
    Connections {
        target: middlePanel
        function onStateChanged() {
            if (middlePanel.state !== "Transfer" && appWindow.minedSpend)
                appWindow.stopMinedSpend();
        }
    }
    readonly property string minedAddressesKey: "walletplus.mined"
    function minedAddresses(wallet) {
        var w = wallet || currentWallet;
        if (!w) return [];
        try {
            var l = JSON.parse(w.getCacheAttribute(minedAddressesKey) || "[]");
            return Array.isArray(l) ? l : [];
        } catch (e) { return []; }
    }
    function setMinedAddresses(list) {
        if (!currentWallet) return;
        // the ones taken out stop counting in the totals
        var before = minedAddresses();
        for (var i = 0; i < before.length; ++i)
            if (!list.some(function(x) { return x.account === before[i].account && x.index === before[i].index; }))
                currentWallet.forgetMinedAddress(before[i].account, before[i].index);
        currentWallet.setCacheAttribute(minedAddressesKey, JSON.stringify(list));
        if (list.length === 0) selectMinedAccount(false);
        currentWallet.storeAsync(function(ok) {});
        ++minedAddressesTick;
    }
    // Wallet+ address groups ("Create addresses in bulk", Receive page): consecutive addresses shown as one row,
    // kept in the wallet cache as [{account, from, count, label}]
    property int addressGroupsTick: 0
    readonly property string addressGroupsKey: "walletplus.groups"
    function addressGroups(wallet) {
        var w = wallet || currentWallet;
        if (!w) return [];
        try {
            var l = JSON.parse(w.getCacheAttribute(addressGroupsKey) || "[]");
            return Array.isArray(l) ? l : [];
        } catch (e) { return []; }
    }
    function setAddressGroups(list) {
        if (!currentWallet) return;
        currentWallet.setCacheAttribute(addressGroupsKey, JSON.stringify(list));
        currentWallet.storeAsync(function(ok) {});
        ++addressGroupsTick;
    }

    // the scanning table is rebuilt with the cache (rescan, restore): watch them again on every open
    function rewatchMinedAddresses(wallet) {
        var list = minedAddresses(wallet);
        for (var i = 0; i < list.length; ++i)
            if (!wallet.watchMinedAddress(list[i].account, list[i].index))
                console.warn("mined address " + list[i].account + "/" + list[i].index + ": could not be watched");
        ++minedAddressesTick;
    }

    function onWalletOpened(wallet) {
        hideProcessingSplash();
        if (wallet.status === Wallet.Status_Ok)
            rewatchMinedAddresses(wallet);
        if (wallet.status === Wallet.Status_Ok && wallet.isHwBacked())
            rememberTrezorWallet(persistentSettings.wallet_path);
        walletName = usefulName(wallet.path)
        console.log(">>> wallet opened: " + wallet)
        if (wallet.status !== Wallet.Status_Ok) {
            openingTrezorPath = "";
            openingTrezorLabel = "";
            // try to resolve common wallet cache errors automatically
            switch (wallet.errorString) {
                case "basic_string::_M_replace_aux":
                case "std::bad_alloc":
                    walletManager.clearWalletCache(wallet.path);
                    walletPassword = passwordDialog.password;
                    appWindow.initialize();
                    console.error("Repairing wallet cache with error: ", wallet.errorString);
                    appWindow.showStatusMessage(qsTr("Repairing incompatible wallet cache. Resyncing wallet."),6);
                    return;
                default:
                    // opening with password but password doesn't match
                    console.error("Error opening wallet with password: ", wallet.errorString);
                    var errorMessage = qsTr("Couldn't open wallet: ") + wallet.errorString;
                    if (wallet.isLedger()) {
                        errorMessage += "\n" + qsTr("Make sure your Ledger is connected and unlocked, and the Monero app is open.");
                    } else if (wallet.isTrezor()) {
                        errorMessage += "\n" + qsTr("Make sure your Trezor is connected and unlocked.");
                    }
                    passwordDialog.showError(errorMessage);
                    console.log("Closing wallet asynchronously")
                    closeWallet();
                    return;
            }
        }

        // Don't allow opening background wallets in the GUI
        if (wallet.isBackgroundWallet()) {
            passwordDialog.onCancel();
            appWindow.showStatusMessage(qsTr("Can't open background wallets in the GUI"),6);
            console.log("closing background wallet");
            closeWallet();
            return;
        }

        // wallet opened successfully, subscribing for wallet updates
        connectWallet(wallet)
        rememberUnlockedWallet(persistentSettings.wallet_path, walletPassword, persistentSettings.nettype);
        rememberSeedAccounts();

        // Persistent pages must rebind/reload even when the selected page did not change.
        if (middlePanel.currentView && typeof middlePanel.currentView.onPageCompleted === "function")
            middlePanel.currentView.onPageCompleted();

        updateBalance();

        // Force switch normal view
        rootItem.state = "normal";

        // Process queued IPC command
        if(typeof IPC !== "undefined" && IPC.queuedCmd().length > 0){
            var queuedCmd = IPC.queuedCmd();
            if(/^\w+:\/\/(.*)$/.test(queuedCmd)) appWindow.onUriHandler(queuedCmd); // uri
        }
    }

    function onWalletPassphraseNeededManager(on_device){
        // the wizard answers it itself while creating a wallet from the device (opening the dialog twice
        // left an invisible dialog counted and the window blurred)
        if (wizard.deviceWalletCreationInProgress)
            return;
        onWalletPassphraseNeeded(walletManager, on_device)
    }

    function onWalletPassphraseNeededWallet(on_device){
        onWalletPassphraseNeeded(currentWallet, on_device)
    }

    function onWalletPassphraseNeeded(handler, on_device){
        hideProcessingSplash();

        console.log(">>> wallet passphrase needed: ")
        devicePassphraseDialog.onAcceptedCallback = function(passphrase) {
            handler.onPassphraseEntered(passphrase, false, false);
            appWindow.onWalletOpening();
        }
        devicePassphraseDialog.onWalletEntryCallback = function() {
            handler.onPassphraseEntered("", true, false);
            appWindow.onWalletOpening();
        }
        devicePassphraseDialog.onRejectedCallback = function() {
            handler.onPassphraseEntered("", false, true);
            appWindow.onWalletOpening();
        }

        devicePassphraseDialog.open(on_device)
    }

    function onWalletPairingCodeNeededManager(){
        if (wizard.deviceWalletCreationInProgress)   // the wizard asks for the code itself
            return;
        onWalletPairingCodeNeeded(walletManager)
    }

    function onWalletPairingCodeNeededWallet(){
        onWalletPairingCodeNeeded(currentWallet)
    }

    // Trezor Safe 7 and newer pair with the computer once: the device shows a 6-digit code
    function onWalletPairingCodeNeeded(handler){
        hideProcessingSplash();
        console.log(">>> device pairing code needed")
        inputDialog.labelText = qsTr("Pair your Trezor with this computer.\nEnter the 6-digit code shown on the device:") + translationManager.emptyString;
        inputDialog.onAcceptedCallback = function() {
            var code = inputDialog.inputText.replace(/[^0-9]/g, "");
            handler.onPairingCodeEntered(code, false);
            appWindow.onWalletOpening();
        }
        inputDialog.onRejectedCallback = function() {
            handler.onPairingCodeEntered("", true);
            appWindow.onWalletOpening();
        }
        inputDialog.open("")
    }

    function onWalletUpdate(stoppedBackgroundSync) {
        if (!currentWallet)
            return;

        console.log(">>> wallet updated")
        updateBalance();
        // Update history if new block found since last update or background sync was just stopped
        if(foundNewBlock || stoppedBackgroundSync) {
            if (foundNewBlock)
                console.log("New block found - updating history")
            foundNewBlock = false;
            currentWallet.history.refresh(currentWallet.currentSubaddressAccount)

            if(middlePanel.state == "History")
                middlePanel.historyView.update();
        }
    }

    function onBackgroundSyncSetup() {
        console.log(">>> background sync setup");
        hideProcessingSplash();
        if (currentWallet.status !== Wallet.Status_Ok) {
            console.error("Error setting up background sync: ", currentWallet.errorString);
            appWindow.showStatusMessage(currentWallet.errorString, 5);
            return;
        }
        appWindow.backgroundSyncType = currentWallet.getBackgroundSyncType();
    }

    function onBackgroundSyncStarted() {
        console.log(">>> background sync started");
        hideProcessingSplash();
        var started = currentWallet.status === Wallet.Status_Ok;
        if (!started) {
            console.error("Error starting background sync: ", currentWallet.errorString);
            appWindow.showStatusMessage(currentWallet.errorString, 5);
        }

        passwordDialog.onRejectedCallback = function() { appWindow.showWizard(); }
        passwordDialog.onAcceptedCallback = function() {
            if(walletPassword === passwordDialog.password) {
                if (currentWallet && started) {
                    appWindow.showProcessingSplash(qsTr("Unlocking..."));
                    currentWallet.stopBackgroundSync(walletPassword);
                } else {
                    passwordDialog.close();
                }
            } else {
                passwordDialog.showError(qsTr("Wrong password") + translationManager.emptyString);
            }
        }
        passwordDialog.open(usefulName(persistentSettings.wallet_path), "", "", "", started);
    }

    function onBackgroundSyncStopped() {
        console.log(">>> background sync stopped");
        var stopped = currentWallet.status === Wallet.Status_Ok;
        if (!stopped) {
            hideProcessingSplash();
            console.error("Error stopping background sync: ", currentWallet.errorString);

            // If there is an error stopping background sync, the spend key
            // won't be loaded and the wallet will be in a broken state. Don't
            // let the user continue normal wallet operations in this state.
            passwordDialog.showError(qsTr("Error stopping background sync: ") + currentWallet.errorString);
            return;
        }

        onWalletUpdate(stopped);
        hideProcessingSplash();
        passwordDialog.close();
    }

    function connectRemoteNode() {
        console.log("connecting remote node");

        p2poolManager.exit();
        p2poolManager.getStatus();

        if (!remoteNodeAllowed(remoteNodesModel.currentRemoteNode().address)) {
            showNodeNotAllowed(remoteNodesModel.currentRemoteNode().address);
            return;
        }

        const callback = function() {
            persistentSettings.useRemoteNode = true;
            const remoteNode = remoteNodesModel.currentRemoteNode();
            currentDaemonAddress = remoteNode.address;
            currentWallet.setDaemonLogin(remoteNode.username, remoteNode.password);
            currentWallet.initAsync(
                currentDaemonAddress,
                isTrustedDaemon(),
                0,
                false,
                false,
                0,
                persistentSettings.getWalletProxyAddress());
            walletManager.setDaemonAddressAsync(currentDaemonAddress);
        };

        if (typeof daemonManager != "undefined" && daemonRunning) {
            showDaemonIsRunningDialog(callback);
        } else {
            callback();
        }
    }

    function disconnectRemoteNode() {
        if (typeof currentWallet === "undefined" || currentWallet === null)
            return;

        console.log("disconnecting remote node");

        p2poolManager.exit();
        p2poolManager.getStatus();

        persistentSettings.useRemoteNode = false;
        currentDaemonAddress = localDaemonAddress
        currentWallet.setDaemonLogin("", "");
        currentWallet.initAsync(
            currentDaemonAddress,
            isTrustedDaemon(),
            0,
            false,
            false,
            0,
            persistentSettings.getWalletProxyAddress());
        walletManager.setDaemonAddressAsync(currentDaemonAddress);
        firstBlockSeen = 0;
    }

    function onHeightRefreshed(bcHeight, dCurrentBlock, dTargetBlock) {
        // Daemon fully synced
        // TODO: implement onDaemonSynced or similar in wallet API and don't start refresh thread before daemon is synced
        // targetBlock = currentBlock = 1 before network connection is established.
        if (firstBlockSeen == 0 && dTargetBlock != 1) {
            firstBlockSeen = dCurrentBlock;
        }
        daemonSynced = dCurrentBlock >= dTargetBlock && dTargetBlock != 1
        daemonHeight = dCurrentBlock;
        daemonTarget = dTargetBlock;
        walletSynced = bcHeight >= dTargetBlock

        // Update progress bars
        if(!daemonSynced) {
            leftPanel.daemonProgressBar.updateProgress(dCurrentBlock,dTargetBlock, dTargetBlock-firstBlockSeen);
            leftPanel.progressBar.updateProgress(0,dTargetBlock, dTargetBlock, qsTr("Waiting for daemon to sync"));
        } else {
            leftPanel.daemonProgressBar.updateProgress(dCurrentBlock,dTargetBlock, 0, qsTr("Daemon is synchronized (%1)").arg(dCurrentBlock.toFixed(0)));
            if(walletSynced)
                leftPanel.progressBar.updateProgress(bcHeight,dTargetBlock,dTargetBlock-bcHeight, qsTr("Wallet is synchronized"))
        }

        // Update wallet sync progress
        leftPanel.isSyncing = !disconnected && !daemonSynced;
        // Update transfer page status
        middlePanel.updateStatus();

        // Refresh is succesfull if blockchain height > 1
        if (bcHeight > 1){
            // recovering from seed is finished after first refresh
            if(persistentSettings.is_recovering) {
                persistentSettings.is_recovering = false
            }
            if (persistentSettings.is_recovering_from_device) {
                persistentSettings.is_recovering_from_device = false;
            }
        }

        // Update history on every refresh if it's empty
        if(currentWallet.history.count == 0)
            currentWallet.history.refresh(currentWallet.currentSubaddressAccount)

        onWalletUpdate();
    }

    function onWalletRefresh() {
        console.log(">>> wallet refreshed")

        // Daemon connected
        leftPanel.networkStatus.connected = currentWallet ? currentWallet.connected() : Wallet.ConnectionStatus_Disconnected

        if (currentWallet)
            currentWallet.refreshHeightAsync();
    }

    // extreme privacy: no bootstrap node (it would answer for the wallet while monerod syncs)
    function daemonBootstrapAddress() {
        return persistentSettings.extremePrivacy ? "" : persistentSettings.walletMode < 2 ? "auto" : persistentSettings.bootstrapNodeAddress;
    }
    // monerod flags for the current Network configuration (startDaemon, the restart check and the command preview)
    function daemonFlagsFor(flags) {
        // with NymVPN on (or "Nym required") monerod also reaches its peers through the Nym SOCKS5 proxy
        flags = (flags || "").trim();
        // a saved --proxy / --tx-proxy to the wallet's own Tor or Nym port may be stale: the current route is added below
        flags = flags.replace(/(^|\s)--proxy(?:=|\s+)(?:socks5:\/\/)?127\.0\.0\.1:(?:17890|17899|17950|17960)(?=\s|$)/g, " ")
                     .replace(/(^|\s)--tx-proxy(?:=|\s+)tor,(?:socks5:\/\/)?127\.0\.0\.1:17950\S*(?=\s|$)/g, " ")
                     .replace(/(^|\s)--tx-proxy(?:=|\s+)i2p,(?:socks5:\/\/)?127\.0\.0\.1:17960\S*(?=\s|$)/g, " ")
                     .replace(/\s+/g, " ").trim();
        // MRL recommendation: block spy nodes also through the DNS blocklist (the packaged ban list
        // goes in DaemonManager). monerod itself skips the DNS lookup when it runs behind --proxy.
        if (!/(^|\s)--enable-dns-blocklist(\s|$)/.test(flags))
            flags = (flags !== "" ? flags + " " : "") + "--enable-dns-blocklist";
        // Network configuration: always anonymous. Sync (peers, blocks) through Tor or Nym, no P2P
        // listening on the network (docs/ANONYMITY_NETWORKS.md); own transactions through Tor or I2P
        // hidden services only (monerod has built-in onion and I2P seed nodes). While the chosen network
        // is not connected monerod simply waits on its SOCKS5 port.
        const viaTor = persistentSettings.netSync !== "nym";   // Tor or I2P: more peers
        if (flags.indexOf("--proxy") < 0)
            flags = (flags !== "" ? flags + " " : "") + "--proxy " + daemonRoute();
        if (!/(^|\s)--p2p-bind-ip(?:=|\s)/.test(flags)) flags += " --p2p-bind-ip 127.0.0.1";
        if (!/(^|\s)--tx-proxy(?:=|\s)/.test(flags))
            daemonTxProxies().forEach(function(p) { flags += " --tx-proxy " + p; });
        // more outgoing peers through Tor because many exits are slow or refused
        if (!/(^|\s)--out-peers(?:=|\s)/.test(flags)) flags += viaTor ? " --out-peers 8" : " --out-peers 4";
        if (!/(^|\s)--block-sync-size(?:=|\s)/.test(flags)) flags += " --block-sync-size 5";
        if (flags.indexOf("--no-igd") < 0) flags += " --no-igd";
        // do not announce our P2P port, and pad our transactions against traffic volume analysis
        if (!/(^|\s)--hide-my-port(\s|$)/.test(flags)) flags += " --hide-my-port";
        if (!/(^|\s)--pad-transactions(\s|$)/.test(flags)) flags += " --pad-transactions";
        // .onion / .i2p peers chosen in the panels (only with their network's --tx-proxy)
        activeAnonPeers().forEach(function(a) {
            if (flags.indexOf(a) < 0) flags += " --add-priority-node " + a;
        });
        exclusiveNodes.filter(nodeAddressActive).forEach(function(a) {
            if (flags.indexOf(a) < 0) flags += " --add-exclusive-node " + a;
        });
        extraPeers.filter(nodeAddressActive).forEach(function(a) {
            if (flags.indexOf(a) < 0) flags += " --add-peer " + a;
        });

        // the bootstrap node (answers for the wallet while monerod syncs) also through the sync network
        if (daemonBootstrapAddress() !== "" && !/(^|\s)--bootstrap-daemon-proxy(?:=|\s)/.test(flags))
            // monerod only accepts a bare ip:port here (bootstrap_daemon::set_proxy uses get_tcp_endpoint):
            // with socks5:// in front it throws "invalid proxy address format" and does not start
            flags += " --bootstrap-daemon-proxy " + daemonRoute().replace(/^socks5:\/\//, "");
        return flags;
    }

    function startDaemon(flags){
        daemonStartStopInProgress = 1;

        // Pause refresh while starting daemon
        currentWallet.pauseRefresh();

        flags = daemonFlagsFor(flags);
        const noSync = appWindow.walletMode === 0;
        const bootstrapNodeAddress = daemonBootstrapAddress();
        console.log("starting monerod: " + flags + " | data-dir: " + persistentSettings.blockchainDataDir
                    + " | bootstrap: " + bootstrapNodeAddress + " | no-sync: " + noSync + " | prune: " + persistentSettings.pruneBlockchain);
        daemonManager.start(flags, persistentSettings.nettype, persistentSettings.blockchainDataDir, bootstrapNodeAddress, noSync, persistentSettings.pruneBlockchain);
    }

    function stopDaemon(callback, splash){
        daemonStartStopInProgress = 2;
        localDaemonAlive = false;
        if (splash) {
            appWindow.showProcessingSplash(qsTr("Waiting for daemon to stop..."));
        }
        p2poolManager.exit()
        daemonManager.stopAsync(persistentSettings.nettype, persistentSettings.blockchainDataDir, function(result) {
            daemonStartStopInProgress = 0;
            if (splash) {
                hideProcessingSplash();
            }
            callback(result);
        });
    }

    function onDaemonStarted(){
        console.log("daemon started");
        daemonStartStopInProgress = 0;
        if (currentWallet) {
            currentWallet.connected(true);
            // resume refresh
            currentWallet.startRefresh();
        }
        // resume simplemode connection timer
        appWindow.disconnectedEpoch = Utils.epoch();
    }
    function onDaemonStopped(){
        if (currentWallet) {
            currentWallet.connected(true);
        }
    }

    function onDaemonStartFailure(error) {
        console.log("daemon start failed");
        daemonStartStopInProgress = 0;
        // resume refresh
        currentWallet.startRefresh();
        informationPopup.title = qsTr("Daemon failed to start") + translationManager.emptyString;
        informationPopup.text  = error + ".\n\n" + qsTr("Please check your wallet and daemon log for errors. You can also try to start %1 manually.").arg((isWindows)? "monerod.exe" : "monerod")
        if (middlePanel.advancedView.miningView.stopMiningEnabled == true) {
            walletManager.stopMining()
            p2poolManager.exit()
            middlePanel.advancedView.miningView.update()
            informationPopup.text += qsTr("\n\nExiting p2pool. Please check that port 18083 is available.") + translationManager.emptyString;
        }
        informationPopup.onCloseCallback = null
        informationPopup.open();
    }

    function onWalletNewBlock(blockHeight, targetHeight) {
        // Update progress bar
        var remaining = targetHeight - blockHeight;
        if(blocksToSync < remaining) {
            blocksToSync = remaining;
        }

        leftPanel.progressBar.updateProgress(blockHeight,targetHeight, blocksToSync);

        // If wallet is syncing, daemon is already synced
        leftPanel.daemonProgressBar.updateProgress(1,1,0,qsTr("Daemon is synchronized"));

        foundNewBlock = true;
    }

    function onWalletMoneyReceived(txId, amount) {
        // refresh transaction history here
        console.log("Confirmed money found")
        // history refresh is handled by walletUpdated
        currentWallet.history.refresh(currentWallet.currentSubaddressAccount) // this will refresh model
        currentWallet.subaddress.refresh(currentWallet.currentSubaddressAccount)

        if(middlePanel.state == "History")
            middlePanel.historyView.update();
    }

    function onWalletUnconfirmedMoneyReceived(txId, amount) {
        // refresh history
        console.log("unconfirmed money found")
        currentWallet.history.refresh(currentWallet.currentSubaddressAccount);

        if(middlePanel.state == "History")
            middlePanel.historyView.update();
    }

    function onWalletMoneySent(txId, amount) {
        // refresh transaction history here
        console.log("monero sent found")
        currentWallet.history.refresh(currentWallet.currentSubaddressAccount); // this will refresh model

        if(middlePanel.state == "History")
            middlePanel.historyView.update();
    }

    function walletsFound() {
        if (persistentSettings.wallet_path.length > 0) {
            if(isIOS)
                return walletManager.walletExists(appWindow.accountsDir + persistentSettings.wallet_path);
            else
                return walletManager.walletExists(persistentSettings.wallet_path);
        }
        return false;
    }

    function onTransactionCreated(pendingTransaction, addresses, paymentId, mixinCount, requestId) {
        console.log("Transaction created");
        if (scheduledRequestId !== 0 && requestId === scheduledRequestId) {
            onScheduledCreated(pendingTransaction);
            return;
        }
        if (requestId !== activeTransactionRequestId) {
            console.log("Discarding stale transaction");
            currentWallet.disposeTransaction(pendingTransaction);
            return;
        }

        activeTransactionRequestId = 0;
        txConfirmationPopup.bottomText.text = "";
        transaction = pendingTransaction;
        // validate address;
        if (transaction.status !== PendingTransaction.Status_Ok) {
            console.error("Can't create transaction: ", transaction.errorString);
            if (currentWallet.connected() == Wallet.ConnectionStatus_WrongVersion) {
                txConfirmationPopup.errorText.text  = qsTr("Can't create transaction: Wrong daemon version: ") + transaction.errorString
            } else {
                txConfirmationPopup.errorText.text  = qsTr("Can't create transaction: ") + transaction.errorString
            }
            // deleting transaction object, we don't want memleaks
            currentWallet.disposeTransaction(transaction);
            transaction = null;

        } else if (transaction.txCount == 0) {
            console.error("Can't create transaction: ", transaction.errorString);
            txConfirmationPopup.errorText.text   = qsTr("No unmixable outputs to sweep") + translationManager.emptyString
            // deleting transaction object, we don't want memleaks
            currentWallet.disposeTransaction(transaction);
            transaction = null;
        } else {
            console.log("Transaction created, amount: " + walletManager.displayAmount(transaction.amount)
                    + ", fee: " + walletManager.displayAmount(transaction.fee));

            // here we update txConfirmationPopup
            txConfirmationPopup.transactionAmount = Utils.removeTrailingZeros(walletManager.displayAmount(transaction.amount));
            txConfirmationPopup.transactionFee = Utils.removeTrailingZeros(walletManager.displayAmount(transaction.fee));
        }
    }

    function getDisplayAmountTotal(recipients) {
        const amounts = recipients.map(function (recipient) {
            return recipient.amount;
        });
        const total = walletManager.amountsSumFromStrings(amounts);
        return Utils.removeTrailingZeros(walletManager.displayAmount(total));
    }

    // ---- scheduled sends (Send page, "Schedule the send") ----
    // Encrypted wallet cache: [{ id, wallet, account, when (ms), recipients [{address, amount}], paymentId,
    //   mixin, priority, description, error }]. The transaction is created and sent at that moment (not before:
    //   fees, ring members and spendable outputs change), only while the app is open with that wallet.
    function scheduledPaymentsAllowed() {
        return !!currentWallet && !currentWallet.isHwBacked();
    }
    property var scheduledSends: []
    property var scheduledWalletCounts: ({})
    property var scheduledLatePrompted: ({})
    property bool scheduledExitApproved: false
    property int activeTransactionSourceAccount: -1
    readonly property int scheduledReserveMs: 25 * 60 * 1000

    function rememberScheduledCount() {
        var counts = Object.assign({}, scheduledWalletCounts);
        counts[persistentSettings.wallet_path] = scheduledPaymentsAllowed() ? scheduledSends.length : 0;
        scheduledWalletCounts = counts;
    }
    function requestScheduledExit(callback) {
        if (scheduledRunningId !== "" || scheduledSaving) {
            showStatusMessage(qsTr("Wait for the payment or save to finish before closing or switching wallets."), 5);
            return false;
        }
        var pending = Object.keys(scheduledWalletCounts).some(function(k) { return scheduledWalletCounts[k] > 0; })
                      || jsonList(persistentSettings.scheduledSends).some(function(s) { return scheduledWalletCounts[s.wallet] !== 0; });
        if (scheduledExitApproved || !pending) return true;
        scheduledExitDialog.open(qsTr("Scheduled payments pending"),
            qsTr("Payments cannot be sent while the app is closed. Your schedules will be kept. Any payment that becomes due while the app or its wallet is closed will require your confirmation when you reopen the wallet."),
            qsTr("Keep open"), qsTr("Close anyway"), function() { scheduledExitApproved = true; callback(); });
        return false;
    }
    function scheduledReservation(account, exceptId) {
        if (!scheduledPaymentsAllowed()) return undefined;
        var now = Date.now();
        return walletScheduledSends.find(function(s) {
            return s.id !== exceptId && !s.error && s.state !== "broadcasting"
                && (s.account === undefined || s.account === account)
                && s.when >= now && s.when - now <= scheduledReserveMs;
        });
    }
    function blockReservedSpend(account, exceptId) {
        if (!scheduledReservation(account, exceptId)) return false;
        showStatusMessage(qsTr("This source account is reserved for a scheduled payment in the next 25 minutes. Cancel that schedule before making another send."), 8);
        return true;
    }
    function promptLateScheduledSend() {
        if (!scheduledPaymentsAllowed()) return;
        if (!currentWallet || !walletSynced || !daemonSynced || !approvedRoute() || currentWallet.isBackgroundSyncing() || scheduledSaving || scheduledRunningId !== "" || passwordDialog.visible || modalDialogs > 0 || isQuitting) return;
        var entry = walletScheduledSends.find(function(s) { return s.error === "late" && !scheduledLatePrompted[s.id]; });
        if (!entry) return;
        var seen = Object.assign({}, scheduledLatePrompted); seen[entry.id] = true; scheduledLatePrompted = seen;
        var owner = currentWallet;
        scheduledLateDialog.open(qsTr("Confirm overdue payment"),
            qsTr("This payment became due while the wallet was closed. Send %1 now? It will not be sent without your confirmation.").arg(scheduledAmountText(entry)),
            qsTr("Keep pending"), qsTr("Send now"), function() { if (currentWallet === owner) runScheduledSend(entry.id); });
    }

    property int scheduledSaving: 0
    property bool scheduledLoadFailed: false

    function loadScheduledSends(wallet) {
        scheduledSends = [];
        scheduledLoadFailed = false;
        if (wallet.isHwBacked()) {
            rememberScheduledCount();
            return; // Keep old schedules on disk, but never load or execute them on hardware wallets.
        }
        var saved;
        try {
            saved = JSON.parse(wallet.getCacheAttribute("wplus.scheduledSends") || "[]");
            if (!Array.isArray(saved) || !saved.every(function(s) {
                return s && typeof s.id === "string" && Number.isFinite(s.when)
                    && Array.isArray(s.recipients) && s.recipients.length > 0
                    && s.recipients.every(function(r) { return r && typeof r.address === "string" && typeof r.amount === "string"; });
            })) throw new Error("invalid schedule");
        } catch (e) {
            scheduledLoadFailed = true;
            showStatusMessage(qsTr("Could not read scheduled payments. Automatic sends are disabled."), 8);
            return;
        }
        var walletPath = persistentSettings.wallet_path;
        saved = saved.map(function(entry) { return Object.assign({}, entry, {wallet: walletPath}); });
        var legacy = jsonList(persistentSettings.scheduledSends).filter(function(s) { return s.wallet === walletPath; });
        legacy.forEach(function(entry) {
            if (!saved.some(function(s) { return s.id === entry.id; })) saved.push(entry);
        });
        var overdue = false;
        saved = saved.map(function(entry) {
            if (!entry.error && entry.state !== "broadcasting" && entry.when <= Date.now()) {
                overdue = true;
                return Object.assign({}, entry, {error: "late"});
            }
            return entry;
        });
        scheduledSends = saved;
        rememberScheduledCount();
        if (legacy.length || overdue) {
            setScheduledSends(saved, function(ok) {
                if (ok) {
                    persistentSettings.scheduledSends = JSON.stringify(jsonList(persistentSettings.scheduledSends).filter(function(s) { return s.wallet !== walletPath; }));
                    persistentSettings.sync();
                }
            });
        }
    }
    readonly property var walletScheduledSends: scheduledSends.filter(function(s) { return s.wallet === persistentSettings.wallet_path; })
                                                              .sort(function(a, b) { return a.when - b.when; })
    property string scheduledRunningId: ""     // entry being created / committed
    property int scheduledRequestId: 0
    property bool scheduledCommitting: false

    function setScheduledSends(list, callback) {
        if (!currentWallet || scheduledLoadFailed) { if (callback) callback(false); return; }
        var wallet = currentWallet;
        if (!wallet.setCacheAttribute("wplus.scheduledSends", JSON.stringify(list))) {
            scheduledLoadFailed = true;
            if (callback) callback(false);
            showStatusMessage(qsTr("Could not save scheduled payments."), 8);
            return;
        }
        scheduledSends = list;
        rememberScheduledCount();
        scheduledSaving++;
        wallet.storeAsync(function(ok) {
            scheduledSaving--;
            if (!ok) {
                scheduledLoadFailed = true;
                showStatusMessage(qsTr("Could not save scheduled payments. Automatic sends are blocked until you reopen the wallet."), 8);
            }
            if (callback) callback(ok);
        });
    }
    function scheduledEntry(id) {
        return scheduledSends.find(function(s) { return s.id === id; }) || null;
    }
    function updateScheduledSend(id, changes, callback) {
        setScheduledSends(scheduledSends.map(function(s) {
            if (s.id !== id) return s;
            var c = Object.assign({}, s);
            for (var k in changes) c[k] = changes[k];
            return c;
        }), callback);
    }
    function removeScheduledSend(id) {
        setScheduledSends(scheduledSends.filter(function(s) { return s.id !== id; }));
    }
    function scheduledAmountText(entry) {
        var all = entry.recipients.some(function(r) { return r.amount === "(all)"; });
        return all ? qsTr("All") + translationManager.emptyString : getDisplayAmountTotal(entry.recipients) + " XMR";
    }

    // "Schedule" on the Send page: same password check as a normal send, then the entry is stored
    function scheduleSend(recipients, paymentId, mixinCount, priority, description, when) {
        if (!scheduledPaymentsAllowed()) return;
        if (scheduledLoadFailed || scheduledSaving || scheduledRunningId !== "") return;
        var owner = currentWallet;
        var account = owner.currentSubaddressAccount;
        if (walletScheduledSends.some(function(s) { return !s.error && (s.account === undefined || s.account === account) && Math.abs(s.when - when) < scheduledReserveMs; })) {
            showStatusMessage(qsTr("Leave at least 25 minutes between scheduled payments from the same account."), 8);
            return;
        }
        var add = function() {
            if (currentWallet !== owner || scheduledLoadFailed || scheduledSaving || scheduledRunningId !== "") return;
            var list = scheduledSends.slice();
            list.push({ id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6), wallet: persistentSettings.wallet_path,
                        account: account, when: when, recipients: recipients, paymentId: paymentId, mixin: mixinCount, priority: priority,
                        description: description, error: "" });
            setScheduledSends(list, function(ok) {
                if (!ok) return;
                middlePanel.transferView.clearFields();
                showStatusMessage(qsTr("Send scheduled for %1").arg(new Date(when).toLocaleString(Qt.locale(), "dd/MM/yyyy HH:mm")) + translationManager.emptyString, 5);
            });
        };
        if (!persistentSettings.askPasswordBeforeSending) {
            add();
            return;
        }
        passwordDialog.onAcceptedCallback = function() {
            if (walletPassword === passwordDialog.password) {
                add();
            } else {
                passwordDialog.showError(qsTr("Wrong password") + translationManager.emptyString);
            }
        };
        passwordDialog.onRejectedCallback = null;
        passwordDialog.open("", "", qsTr("Schedule the send") + translationManager.emptyString, FontAwesome.clockO);
    }

    function runScheduledSend(id) {
        if (!scheduledPaymentsAllowed()) return;
        var s = scheduledEntry(id);
        if (!s || !currentWallet || scheduledRunningId !== "" || scheduledSaving || scheduledLoadFailed
                || s.wallet !== persistentSettings.wallet_path || s.state === "broadcasting"
                || viewOnly || currentWallet.isBackgroundSyncing() || !walletSynced || !daemonSynced || !approvedRoute()
                || activeTransactionRequestId !== 0 || transaction || minedSpend || minedAccountActive)
            return;
        if (s.account !== undefined && s.account !== currentWallet.currentSubaddressAccount) {
            updateScheduledSend(id, {error: qsTr("Select the payment source account before sending.")});
            return;
        }
        if (blockReservedSpend(currentWallet.currentSubaddressAccount, id)) return;
        console.log("Creating scheduled transaction");
        scheduledRunningId = id;
        updateScheduledSend(id, { error: "" });
        var requestId = ++transactionRequestId;
        scheduledRequestId = requestId;
        var all = s.recipients.find(function(r) { return r.amount === "(all)"; });
        if (all) {
            currentWallet.createTransactionAllAsync(all.address, s.paymentId, s.mixin, s.priority, requestId);
        } else {
            currentWallet.createTransactionAsync(s.recipients.map(function(r) { return r.address; }), s.paymentId,
                                                 s.recipients.map(function(r) { return r.amount; }), s.mixin, s.priority, requestId);
        }
    }

    function onScheduledCreated(pendingTransaction) {
        var id = scheduledRunningId;
        scheduledRequestId = 0;
        if (pendingTransaction.status !== PendingTransaction.Status_Ok || pendingTransaction.txCount == 0) {
            var err = pendingTransaction.status !== PendingTransaction.Status_Ok ? pendingTransaction.errorString : qsTr("No outputs to send") + translationManager.emptyString;
            console.error("Scheduled transaction creation failed");
            updateScheduledSend(id, { error: err });
            currentWallet.disposeTransaction(pendingTransaction);
            scheduledRunningId = "";
            showStatusMessage(qsTr("The scheduled send could not be made: %1").arg(err) + translationManager.emptyString, 8);
            return;
        }
        // Persist the uncertainty BEFORE broadcasting. A crash must never auto-send again.
        updateScheduledSend(id, { state: "broadcasting", txids: pendingTransaction.txid, error: qsTr("Broadcast result unverified. Check transaction history before creating another payment.") }, function(ok) {
            if (!ok || !approvedRoute()) {
                currentWallet.disposeTransaction(pendingTransaction);
                scheduledRunningId = "";
                return;
            }
            scheduledCommitting = true;
            currentWallet.commitTransactionAsync(pendingTransaction);
        });
    }

    function onScheduledCommitted(success, pendingTransaction, txid) {
        var id = scheduledRunningId;
        var s = scheduledEntry(id);
        scheduledCommitting = false;
        scheduledRunningId = "";
        if (!success) {
            console.error("Scheduled transaction broadcast failed");
            updateScheduledSend(id, { error: pendingTransaction.errorString });
            showStatusMessage(qsTr("The scheduled send could not be made: %1").arg(pendingTransaction.errorString) + translationManager.emptyString, 8);
        } else {
            if (s && s.description)
                for (var i = 0; i < txid.length; ++i)
                    currentWallet.setUserNote(txid[i], s.description);
            removeScheduledSend(id);
            txBroadcastFx.play(function() { successfulTxPopup.open(txid) });
        }
        currentWallet.refresh();
        currentWallet.disposeTransaction(pendingTransaction);
        currentWallet.storeAsync(function(ok) {
            if (!ok) appWindow.showStatusMessage(qsTr("Failed to store the wallet"), 3);
        });
    }

    function scheduledCheck() {
        if (!scheduledPaymentsAllowed()) return;
        promptLateScheduledSend();
        if (modalDialogs > 0) return;
        // a mined address is being spent on the Send page: the wallet's spend source is set to it
        if (!currentWallet || viewOnly || scheduledSaving || scheduledLoadFailed || scheduledRunningId !== "" || walletScheduledSends.length === 0 || minedSpend || minedAccountActive)
            return;
        var now = Date.now();
        var due = walletScheduledSends.filter(function(s) { return !s.error && s.state !== "broadcasting" && s.when <= now; });
        if (due.length === 0)
            return;
        var s = due[0];
        // wait for the wallet to be synced and for no send of the user in progress
        if (!walletSynced || !daemonSynced || activeTransactionRequestId !== 0 || transaction)
            return;
        runScheduledSend(s.id);
    }

    Timer {
        interval: 10000
        running: !!appWindow.currentWallet && appWindow.walletScheduledSends.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: appWindow.scheduledCheck()
    }

    // called on "transfer"
    function handlePayment(recipients, paymentId, mixinCount, priority, description, createFile) {
        var sourceAccount = minedSpend ? minedSpend.account : currentWallet.currentSubaddressAccount;
        if (blockReservedSpend(sourceAccount, "")) return;
        activeTransactionSourceAccount = sourceAccount;
        const recipientAll = recipients.find(function (recipient) {
            return recipient.amount == "(all)";
        });
        if (recipientAll && recipients.length > 1) {
            throw "Sending all requires one destination address";
        }
        // a scheduled send is being made right now: both would share the confirmation flow
        if (scheduledRunningId !== "") {
            showStatusMessage(qsTr("A scheduled send is being made, try again in a few seconds") + translationManager.emptyString, 5);
            return;
        }

        txConfirmationPopup.clearFields();
        txConfirmationPopup.bottomTextAnimation.running = false;
        txConfirmationPopup.bottomText.text  = qsTr("Creating transaction...") + translationManager.emptyString;
        txConfirmationPopup.recipients = recipients;
        txConfirmationPopup.transactionAmount = recipientAll ? "(all)" : getDisplayAmountTotal(recipients);
        txConfirmationPopup.transactionPriority = priority;
        txConfirmationPopup.transactionDescription = description;
        txConfirmationPopup.open();

        const requestId = ++transactionRequestId;
        activeTransactionRequestId = requestId;

        if (recipientAll) {
            currentWallet.createTransactionAllAsync(recipientAll.address, paymentId, mixinCount, priority, requestId);
        } else {
            const addresses = recipients.map(function (recipient) {
                return recipient.address;
            });
            const amountsxmr = recipients.map(function (recipient) {
                return recipient.amount;
            });
            currentWallet.createTransactionAsync(addresses, paymentId, amountsxmr, mixinCount, priority, requestId);
        }
    }

    function rejectPendingTransaction() {
        activeTransactionRequestId = 0;
        txConfirmationPopup.bottomTextAnimation.running = false;
        txConfirmationPopup.bottomText.text = "";
        if (transaction) {
            currentWallet.disposeTransaction(transaction);
            transaction = null;
        }
    }

    //Choose where to save transaction
    FileDialog {
        id: saveTxDialog
        title: "Please choose a location"
        currentFolder: "file://" + appWindow.accountsDir
        fileMode: FileDialog.SaveFile

        onAccepted: {
            handleTransactionConfirmed()
        }
        onRejected: {
            rejectPendingTransaction()
        }

    }


    function handleSweepUnmixable() {
        if (scheduledRunningId !== "" || blockReservedSpend(currentWallet.currentSubaddressAccount, "")) return;
        activeTransactionSourceAccount = currentWallet.currentSubaddressAccount;
        console.log("Creating transaction: ")

        txConfirmationPopup.clearFields();
        txConfirmationPopup.sweepUnmixable = true;
        transaction = currentWallet.createSweepUnmixableTransaction();
        txConfirmationPopup.open();
        if (transaction.status !== PendingTransaction.Status_Ok) {
            console.error("Can't create transaction: ", transaction.errorString);
            txConfirmationPopup.errorText.text  = qsTr("Can't create transaction: ") + transaction.errorString + translationManager.emptyString
            // deleting transaction object, we don't want memleaks
            currentWallet.disposeTransaction(transaction);
            transaction = null;

        } else if (transaction.txCount == 0) {
            console.error("No unmixable outputs to sweep");
            txConfirmationPopup.errorText.text  = qsTr("No unmixable outputs to sweep") + translationManager.emptyString
            // deleting transaction object, we don't want memleaks
            currentWallet.disposeTransaction(transaction);
            transaction = null;
        } else {
            console.log("Transaction created, amount: " + walletManager.displayAmount(transaction.amount)
                    + ", fee: " + walletManager.displayAmount(transaction.fee));
            txConfirmationPopup.transactionAmount = Utils.removeTrailingZeros(walletManager.displayAmount(transaction.amount));
            txConfirmationPopup.transactionFee = Utils.removeTrailingZeros(walletManager.displayAmount(transaction.fee));
            // committing transaction
        }
    }

    // called after user confirms transaction
    function handleTransactionConfirmed(fileName) {
        if (blockReservedSpend(activeTransactionSourceAccount, "")) {
            rejectPendingTransaction();
            return;
        }
        // View only wallet - we save the tx
        if(viewOnly){
            // No file specified - abort
            if(!saveTxDialog.selectedFile.toString()) {
                rejectPendingTransaction()
                return;
            }

            var path = walletManager.urlToLocalPath(saveTxDialog.selectedFile)

            // Store to file
            transaction.setFilename(path);
        }
        appWindow.showProcessingSplash(qsTr("Sending transaction ..."));
        const pendingTransaction = transaction;
        transaction = null;
        currentWallet.commitTransactionAsync(pendingTransaction);
    }

    function onTransactionCommitted(success, transaction, txid) {
        if (scheduledCommitting) {
            onScheduledCommitted(success, transaction, txid);
            return;
        }
        hideProcessingSplash();
        if (!success) {
            console.log("Error committing transaction: " + transaction.errorString);
            informationPopup.title = qsTr("Error") + translationManager.emptyString
            informationPopup.text  = qsTr("Couldn't send the money: ") + transaction.errorString
            informationPopup.onCloseCallback = null;
            informationPopup.open();
        } else {
            // sent from a mined address: its change went to 0:1, the note says so
            var note = txConfirmationPopup.transactionDescription;
            if (minedSpend || minedAccountActive)
                note = (note.length > 0 ? note + " " : "") + qsTr("(mined address change)") + translationManager.emptyString;
            if (note.length > 0) {
                for (var i = 0; i < txid.length; ++i)
                    currentWallet.setUserNote(txid[i], note);
            }

            // Clear tx fields
            middlePanel.transferView.clearFields()
            txConfirmationPopup.clearFields()
            stopMinedSpend()
            txBroadcastFx.play(function() { successfulTxPopup.open(txid) })
        }
        currentWallet.refresh()
        currentWallet.disposeTransaction(transaction)
        currentWallet.storeAsync(function(success) {
            if (!success) {
                appWindow.showStatusMessage(qsTr("Failed to store the wallet"), 3);
            }
        });
    }

    function doSearchInHistory(searchTerm) {
        middlePanel.searchInHistory(searchTerm);
        leftPanel.selectItem(middlePanel.state)
    }

    // called on "getProof"
    function handleGetProof(txid, address, message, amount) {
        var owner = currentWallet;
        function completed(id, result) {
            if (currentWallet === owner) txProofComputed(id, result);
        }
        if (amount !== null && amount.length > 0) {
            var result = currentWallet.getReserveProof(false, currentWallet.currentSubaddressAccount, amount, message)
            txProofComputed(null, result)
        } else {
            console.log("Getting payment proof: ")
            console.log("\ttxid: ", txid,
                        ", address: ", address,
                        ", message: ", message);
            function spendProofFallback(txid, result){
                if (currentWallet !== owner) return;
                if (!result || result.indexOf("error|") === 0) {
                    owner.getSpendProofAsync(txid, message, completed);
                } else {
                    completed(txid, result);
                }
            }
            if (address.length > 0)
                currentWallet.getTxProofAsync(txid, address, message, spendProofFallback);
            else
                spendProofFallback(txid, null);
        }
        informationPopup.open()
    }

    function txProofComputed(txid, result){
        if (result.indexOf("error|") === 0) {
            var errorString = result.split("|")[1];
            informationPopup.text = qsTr("Couldn't generate a proof because of the following reason: \n") + errorString + translationManager.emptyString;
        } else {
            informationPopup.text  = result;
        }
    }

    // called on "checkProof"
    function handleCheckProof(txid, address, message, signature) {
        console.log("Checking payment proof: ")
        console.log("\ttxid: ", txid,
                    ", address: ", address,
                    ", message: ", message,
                    ", signature: ", signature);

        var result;
        var isReserveProof = signature.indexOf("ReserveProofV") === 0;
        if (address.length > 0 && !isReserveProof) {
            result = currentWallet.checkTxProof(txid, address, message, signature);
        } 
        else if (isReserveProof) {
            result = currentWallet.checkReserveProof(address, message, signature);
        } 
        else {
            result = currentWallet.checkSpendProof(txid, message, signature);
        }
        var results = result.split("|");
        if (address.length > 0 && results.length == 5 && results[0] === "true" && !isReserveProof) {
            var good = results[1] === "true";
            var received = results[2];
            var in_pool = results[3] === "true";
            var confirmations = results[4];

            informationPopup.title  = qsTr("Payment proof check") + translationManager.emptyString;
            if (!good) {
                informationPopup.text = qsTr("Bad signature");
            } else if (received > 0) {
                if (in_pool) {
                    informationPopup.text = qsTr("This address received %1 monero, but the transaction is not yet mined").arg(walletManager.displayAmount(received));
                }
                else {
                    informationPopup.text = qsTr("This address received %1 monero, with %2 confirmation(s).").arg(walletManager.displayAmount(received)).arg(confirmations);
                }
            }
            else {
                informationPopup.text = qsTr("This address received nothing");
            }
        }
        else if (results.length == 2 && results[0] === "true") {
            var good = results[1] === "true";
            informationPopup.title = qsTr("Payment proof check") + translationManager.emptyString;
            informationPopup.text = good ? qsTr("Good signature") : qsTr("Bad signature");
        } 
        else if (isReserveProof && results[0] === "true") {
            var good = results[1] === "true";
            informationPopup.title = qsTr("Reserve proof check") + translationManager.emptyString;
            informationPopup.text = good ? qsTr("Good signature on %1 total and %2 spent.").arg(walletManager.displayAmount(results[2])).arg(walletManager.displayAmount(results[3])) : qsTr("Bad signature");
        }
        else {
            informationPopup.title  = qsTr("Error") + translationManager.emptyString;
            informationPopup.text = currentWallet.errorString;
        }
        informationPopup.onCloseCallback = null
        informationPopup.open()
    }

    // Matrix FX: optional UI sounds
    function playFx(name) {
        if (persistentSettings.fxSounds && soundFxLoader.item)
            soundFxLoader.item.play(name);
    }

    function showProcessingSplash(message) {
        console.log("Displaying processing splash")
        if (typeof message != 'undefined') {
            splash.messageText = message
        }

        leftPanel.enabled = false;
        middlePanel.enabled = false;
        titleBar.enabled = false;
        splash.show();
    }

    // Cancel on the Trezor splash: the core gives up the wait and tells the device; if the
    // operation does not end on its own (Trezor unplugged or frozen) the splash closes anyway
    function cancelDeviceConfirmation() {
        splash.cancelling = true;
        walletManager.cancelDeviceConfirmation();
        deviceCancelFallback.restart();
    }

    function hideProcessingSplash() {
        devicePrompt.hide();
        deviceCancelFallback.stop();
        splash.deviceMode = false;
        splash.cancelling = false;
        deviceShowAddress = "";
        console.log("Hiding processing splash")
        splash.close();

        if (!passwordDialog.visible) {
            leftPanel.enabled = true
            middlePanel.enabled = true
            titleBar.enabled = true
        }
    }

    // close wallet and show wizard
    function showWizard(){
        walletInitialized = false;
        closeWallet(function() {
            wizard.restart();
            wizard.wizardState = "wizardHome";
            rootItem.state = "wizard"
            // reset balance, clear spendable funds message
            clearMoneroCardLabelText();
            leftPanel.minutesToUnlock = "";
            // reset fields
            middlePanel.addressBookView.clearFields();
            middlePanel.transferView.clearFields();
            middlePanel.receiveView.clearFields();
            middlePanel.historyView.clearFields();
            middlePanel.advancedView.clearFields();
            // disable timers
            userInActivityTimer.running = false;
        }, isUnlockedWallet(persistentSettings.wallet_path) ? "park" : true);
    }

    objectName: "appWindow"
    visible: true
    width: (isAndroid || isIOS)
        ? Math.min(screenAvailableWidth, 800)
        : Math.max(minimumWidth, Math.min(1320, screenAvailableWidth - 40))
    height: (isAndroid || isIOS)
        ? Math.min(screenAvailableHeight, maxWindowHeight)
        : Math.max(minimumHeight, Math.min(880, screenAvailableHeight - 40))
    color: MoneroComponents.Style.appWindowBackgroundColor
    flags: persistentSettings.customDecorations ? Windows.flagsCustomDecorations : Windows.flags
    // custom decorations resize the window from QML, so the minimum is enforced here too
    onWidthChanged: if (visibility === Window.Windowed && width < minimumWidth) width = minimumWidth
    onHeightChanged: if (visibility === Window.Windowed && height < minimumHeight) height = minimumHeight

    Timer {
        id: fiatPriceTimer
        // only the ticker is asked every minute: FX rates, history and the Wagyu quote keep their own ages
        interval: 1000 * 60;
        running: persistentSettings.fiatPriceEnabled && currentWallet !== undefined
        repeat: true
        onTriggered: appWindow.fiatApiRefresh()
        triggeredOnStart: true
    }

    function getKeyFromCurrency(currency) {
        if (currency.length !== 6 || currency.substring(0, 3) !== "xmr") return undefined;
        return currency.substring(3);
    }

    function fiatApiParseTicker(url, resp){
        if (url.startsWith("https://api.coingecko.com/")) {
            var points = resp.prices || [];
            return points.length ? Number(points[points.length-1][1]) : 0;
        }
        if(url.startsWith("https://api.kraken.com/0/")){
            if(resp.hasOwnProperty("error") && resp.error.length > 0 || !resp.hasOwnProperty("result")){
                appWindow.fiatApiError("Kraken API has error(s)");
                return;
            }

            var key = "XXMRZUSD";
            if(!resp.result.hasOwnProperty(key)){
                appWindow.fiatApiError("Kraken API has error(s)");
                return;
            }
            return parseFloat(resp.result[key]["c"][0]);
        } else if(url.startsWith("https://api.coinpaprika.com/v1/")){
            if(!resp.hasOwnProperty("quotes") || !resp.quotes.hasOwnProperty("USD") || !resp.quotes["USD"].hasOwnProperty("price")){
                appWindow.fiatApiError("CoinPaprika API has error(s)");
                return;
            }
            const pct7d = Number(resp.quotes["USD"]["percent_change_7d"]);
            if (isFinite(pct7d) && pct7d > -100)
                appWindow.fiatPriceUSD7d = resp.quotes["USD"]["price"] / (1 + pct7d / 100);
            const pct24h = Number(resp.quotes["USD"]["percent_change_24h"]);
            if (isFinite(pct24h) && pct24h > -100)
                appWindow.fiatPriceUSD24h = resp.quotes["USD"]["price"] / (1 + pct24h / 100);
            return resp.quotes["USD"]["price"];
        }
    }

    // Keep providers isolated while allowing immediate switches back to a known quote.
    property var fiatTickers: ({})
    function rememberFiatTicker() {
        if (!(fiatPriceUSD > 0)) return;
        var copy = Object.assign({}, fiatTickers);
        copy[persistentSettings.fiatPriceProvider] = {
            usd: fiatPriceUSD, week: fiatPriceUSD7d, day: fiatPriceUSD24h
        };
        fiatTickers = copy;
    }
    function restoreFiatTicker() {
        var cached = fiatTickers[persistentSettings.fiatPriceProvider];
        fiatPriceUSD = cached ? cached.usd : 0;
        fiatPriceUSD7d = cached ? cached.week : 0;
        fiatPriceUSD24h = cached ? cached.day : 0;
        fiatHistoryTimestamp = 0;
    }

    function fiatApiJsonReceived(url, resp, error) {
        if (url !== appWindow.fiatPriceAPIs[persistentSettings.fiatPriceProvider]) return;
        if (error) {
            appWindow.fiatApiError(error);
            return;
        }

        try {
            resp = JSON.parse(resp);
        } catch (e) {
            appWindow.fiatApiError("bad JSON: " + e);
            return;
        }

        var ticker = appWindow.fiatApiParseTicker(url, resp);
        if(!(ticker > 0)){
            appWindow.fiatApiError("could not get ticker");
            return;
        }

        appWindow.fiatPriceUSD = ticker;
        appWindow.rememberFiatTicker();
        appWindow.fiatApiUpdatePrice();
    }

    function fiatApiRatesReceived(url, resp, error) {
        if (error) {
            appWindow.fiatApiError(error);
            return;
        }

        try {
            resp = JSON.parse(resp);
        } catch (e) {
            appWindow.fiatApiError("bad JSON: " + e);
            return;
        }

        if(resp.base !== "USD" || typeof resp.rates !== "object" || resp.rates === null){
            appWindow.fiatApiError("fiat rates API has error(s)");
            return;
        }

        var rates = {"USD": 1};
        for (var code in resp.rates){
            if (!resp.rates.hasOwnProperty(code)) continue;

            const rate = Number(resp.rates[code]);
            if (isFinite(rate) && rate > 0)
                rates[code] = rate;
        }

        appWindow.fiatRates = rates;
        appWindow.fiatRatesTimestamp = Date.now();
        appWindow.fiatApiUpdatePrice();
    }

    function fiatApiHistoryReceived(url, resp, error) {
        // An earlier request must not overwrite the newly selected provider's changes.
        if (persistentSettings.fiatPriceProvider !== "kraken" || !priceSourceEnabled("kraken")) return;
        if (error) {
            appWindow.fiatApiError(error);
            return;
        }

        try {
            resp = JSON.parse(resp);
        } catch (e) {
            appWindow.fiatApiError("bad JSON: " + e);
            return;
        }

        // Kraken hourly OHLC: [time, open, high, low, close, vwap, volume, count]
        const candles = (resp.result && resp.result["XXMRZUSD"]) || [];
        function closeAt(secondsAgo) {
            const target = Date.now() / 1000 - secondsAgo;
            for (var i = candles.length - 1; i >= 0; i--) {
                if (candles[i][0] <= target)
                    return parseFloat(candles[i][4]);
            }
            return 0;
        }
        const price7d = closeAt(7 * 24 * 3600);
        const price24h = closeAt(24 * 3600);
        if (!(price7d > 0) || !(price24h > 0)) {
            appWindow.fiatApiError("Kraken OHLC has no price from 7 days / 24 hours ago");
            return;
        }

        appWindow.fiatPriceUSD7d = price7d;
        appWindow.fiatPriceUSD24h = price24h;
        appWindow.fiatHistoryTimestamp = Date.now();
        appWindow.rememberFiatTicker();
        appWindow.fiatApiUpdatePrice();
    }

    function fiatApiRates7dReceived(url, resp, error) {
        if (error) {
            appWindow.fiatApiError(error);
            return;
        }

        try {
            resp = JSON.parse(resp);
        } catch (e) {
            appWindow.fiatApiError("bad JSON: " + e);
            return;
        }

        if (resp.base !== "USD" || typeof resp.rates !== "object" || resp.rates === null) {
            appWindow.fiatApiError("fiat rates API has error(s)");
            return;
        }

        var rates = {"USD": 1};
        for (var code in resp.rates) {
            const rate = Number(resp.rates[code]);
            if (isFinite(rate) && rate > 0)
                rates[code] = rate;
        }

        appWindow.fiatRates7d = rates;
        appWindow.fiatRates7dDate = url.split("/").pop().split("?")[0];
        appWindow.fiatApiUpdatePrice();
    }

    function fiatApiUpdatePrice() {
        const symbol = appWindow.fiatApiCurrencySymbol();
        if (symbol === "BTC" && (!middlePanel || !middlePanel.tradingView)) return;
        const rate = appWindow.fiatRates.hasOwnProperty(symbol) ? appWindow.fiatRates[symbol] : 0;
        appWindow.fiatPrice = (appWindow.fiatPriceUSD > 0 && rate > 0) ? appWindow.fiatPriceUSD * rate : 0;
        if (symbol === "BTC") {
            var market = middlePanel.tradingView;
            var latest = TransactionPrices.compare(market.cache, "btc", 0, Date.now()/1000, historicalPriceSource("btc")).latest;
            appWindow.fiatPrice = latest ? latest[1] : 0;
        }

        const rate7d = appWindow.fiatRates7d.hasOwnProperty(symbol) ? appWindow.fiatRates7d[symbol] : 0;
        appWindow.fiatChange7d = (appWindow.fiatPrice > 0 && appWindow.fiatPriceUSD7d > 0 && rate7d > 0)
            ? (appWindow.fiatPrice / (appWindow.fiatPriceUSD7d * rate7d) - 1) * 100
            : NaN;
        // FX moves little in a day: the 24h change uses today's rate on both sides
        appWindow.fiatChange24h = (appWindow.fiatPriceUSD > 0 && appWindow.fiatPriceUSD24h > 0)
            ? (appWindow.fiatPriceUSD / appWindow.fiatPriceUSD24h - 1) * 100
            : NaN;

        if (symbol === "BTC") {
            var source = historicalPriceSource("btc");
            var now = Date.now()/1000;
            var data = middlePanel.tradingView.cache;
            var week = TransactionPrices.compare(data, "btc", now - 7*86400, now, source).change;
            var day = TransactionPrices.compare(data, "btc", now - 86400, now, source).change;
            appWindow.fiatChange7d = week === null ? NaN : week;
            appWindow.fiatChange24h = day === null ? NaN : day;
        }
        appWindow.updateBalance();
        appWindow.fiatCacheSave();
    }

    // last known prices in a CSV (precio-actual.csv next to the other Wallet+ CSVs), read at start so the
    // balance shows a value right away instead of "?.??" until the price services answer
    property bool fiatCacheLoading: false
    property string fiatCacheText: ""

    function fiatCachePath() {
        if (typeof oshelper === "undefined" || !oshelper.swapsLogPath)
            return "";
        var p = oshelper.swapsLogPath();
        return p.substring(0, p.lastIndexOf("/")) + "/precio-actual.csv";
    }

    function fiatCacheSave() {
        if (appWindow.fiatCacheLoading || appWindow.fiatPriceUSD <= 0)
            return;
        var rows = [
            "fecha_utc," + new Date().toISOString(),
            "provider," + persistentSettings.fiatPriceProvider,
            "usd," + appWindow.fiatPriceUSD,
            "usd_7d," + appWindow.fiatPriceUSD7d,
            "usd_24h," + appWindow.fiatPriceUSD24h,
            "btc," + appWindow.priceBtc,
            "fx_7d_fecha," + appWindow.fiatRates7dDate
        ];
        var k;
        for (k in appWindow.fiatRates)
            rows.push("fx_" + k + "," + appWindow.fiatRates[k]);
        for (k in appWindow.fiatRates7d)
            rows.push("fx7d_" + k + "," + appWindow.fiatRates7d[k]);
        // the date alone changes on every save: only write when a price or rate changed
        var body = rows.slice(1).join("\n");
        if (body === appWindow.fiatCacheText)
            return;
        appWindow.fiatCacheText = body;
        var path = appWindow.fiatCachePath();
        if (path !== "")
            oshelper.writeTextFile(path, "clave,valor\n" + rows.join("\n") + "\n");
    }

    function fiatCacheLoad() {
        var path = appWindow.fiatCachePath();
        if (path === "")
            return;
        var text = oshelper.readTextFile(path);
        if (!text)
            return;
        var v = {};
        text.split("\n").forEach(function(line) {
            var i = line.indexOf(",");
            if (i > 0)
                v[line.substring(0, i)] = line.substring(i + 1).trim();
        });
        if (v.provider !== persistentSettings.fiatPriceProvider) return;
        var usd = parseFloat(v.usd);
        if (!(usd > 0))
            return;
        var rates = {"USD": 1}, rates7d = {"USD": 1};
        for (var key in v) {
            var n = parseFloat(v[key]);
            if (!(n > 0))
                continue;
            if (key.indexOf("fx7d_") === 0)
                rates7d[key.substring(5)] = n;
            else if (key.indexOf("fx_") === 0)
                rates[key.substring(3)] = n;
        }
        appWindow.fiatCacheLoading = true;
        appWindow.fiatPriceUSD = usd;
        appWindow.fiatPriceUSD7d = parseFloat(v.usd_7d) || 0;
        appWindow.fiatPriceUSD24h = parseFloat(v.usd_24h) || 0;
        if (parseFloat(v.btc) > 0)
            appWindow.priceBtc = parseFloat(v.btc);
        appWindow.fiatRates = rates;
        appWindow.fiatRates7d = rates7d;
        appWindow.rememberFiatTicker();
        // timestamps stay 0, so the first refresh still asks the services for fresh prices
        appWindow.fiatApiUpdatePrice();
        appWindow.fiatCacheLoading = false;
        console.log("fiat price: last known values from " + (v.fecha_utc || path));
    }

    function priceBtcReceived(url, resp, error) {
        console.log("Wagyu quote: " + (error ? "error " + error : "") + " " + String(resp).substring(0, 400));
        if (error) {
            appWindow.fiatApiError(error);
            return;
        }
        try {
            var q = JSON.parse(resp);
            var p = parseFloat(q.toAmount) / 1e8;    // satoshis -> BTC
            if (p > 0) {
                appWindow.priceBtc = p;
                appWindow.priceBtcTimestamp = Date.now();
            }
        } catch (e) {
            appWindow.fiatApiError("bad Wagyu quote: " + e);
        }
    }

    function fiatApiRefresh(){
        // trigger API call
        if(!persistentSettings.fiatPriceEnabled)
            return;

        var userProvider = persistentSettings.fiatPriceProvider;
        if (!userProvider || !priceSourceEnabled(userProvider)) return;
        if (!appWindow.fiatPriceAPIs.hasOwnProperty(userProvider)){
            appWindow.fiatApiError("provider \"" + userProvider + "\" not implemented");
            return;
        }

        appWindow.priceGetJSON(appWindow.fiatPriceAPIs[userProvider], fiatApiJsonReceived);
        // XMR/BTC last trade for the title bar chip, every minute too (its own request: if Kraken stops
        // listing the pair, the USD price above is not affected)
        if (priceSourceEnabled("kraken")) appWindow.priceGetJSON("https://api.kraken.com/0/public/Ticker?pair=XMRXBT", function(url, resp, error) {
            if (error) return;
            try {
                var j = JSON.parse(resp);
                for (var k in j.result) {
                    var btc = parseFloat(j.result[k]["c"][0]);
                    if (btc > 0) {
                        appWindow.priceBtcLive = btc;
                        appWindow.priceBtcLiveTime = Date.now();
                    }
                    break;
                }
            } catch (e) {}
        });
        // XMR -> BTC quote for 1 XMR from Wagyu (no API key), at most every 5 minutes
        if (priceSourceEnabled("wagyu") && Date.now() - appWindow.priceBtcTimestamp > 5 * 60 * 1000)
            appWindow.pricePostJSON("https://api-beta.wagyu.xyz/v2/swaps/quote",
                             JSON.stringify({ fromChainId: 0, fromToken: "XMR",
                                              toChainId: 20000000000001, toToken: "bitcoin",
                                              fromAmount: "1000000000000" }),
                             priceBtcReceived);

        // price from 7 days ago (CoinPaprika sends it with the ticker)
        if (userProvider === "kraken" && Date.now() - appWindow.fiatHistoryTimestamp > 15 * 60 * 1000)
            appWindow.priceGetJSON("https://api.kraken.com/0/public/OHLC?pair=XMRUSD&interval=60", fiatApiHistoryReceived);
        if (userProvider !== "kraken")
            appWindow.fiatHistoryTimestamp = 0;

        if (priceSourceEnabled("frankfurter") && ["USD", "BTC"].indexOf(appWindow.fiatApiCurrencySymbol()) < 0) {
            if(!persistentSettings.fiatRatesConsentGiven){
                appWindow.fiatApiError("exchange rate provider consent not given for non-USD currency");
                return;
            }

            if(Date.now() - appWindow.fiatRatesTimestamp > appWindow.fiatRatesMaxAge)
                appWindow.priceGetJSON(appWindow.fiatRatesAPI, fiatApiRatesReceived);

            const date7d = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString().slice(0, 10);
            if (appWindow.fiatRates7dDate !== date7d)
                appWindow.priceGetJSON("https://api.frankfurter.dev/v1/" + date7d + "?base=USD", fiatApiRates7dReceived);
        }
    }

    function fiatApiCurrencySymbol() {
        const key = getKeyFromCurrency(persistentSettings.fiatPriceCurrency);
        if (key === undefined) {
            console.error("unsupported currency", persistentSettings.fiatPriceCurrency);
            return "UNSUPPORTED";
        }
        return key.toUpperCase();
    }

    function fiatApiConvertToFiat(amount) {
        const ticker = appWindow.fiatPrice;
        if(ticker <= 0){
            fiatApiError("Invalid ticker value: " + ticker);
            return "?.??";
        }
        return (amount * ticker).toFixed(fiatApiCurrencySymbol() === "BTC" ? 8 : 2);
    }

    function fiatApiConvertToXMR(amount) {
        const ticker = appWindow.fiatPrice;
        if(ticker <= 0){
            fiatApiError("Invalid ticker value: " + ticker);
            return "?.??";
        }
        return (amount / ticker).toFixed(12);
    }

    function fiatApiUpdateBalance(balance){
        // update balance card
        var bFiat = "?.??"
        if (!hideBalanceForced && !persistentSettings.hideBalance && appWindow.fiatPrice > 0) {
            bFiat = fiatApiConvertToFiat(balance);
        }
        leftPanel.balanceFiatString = bFiat;
    }

    // same as picking the currency in Settings: USD <-> last non-USD currency
    function fiatApiToggleUsd() {
        var index = favoriteCurrencies.indexOf(fiatApiCurrencySymbol());
        persistentSettings.fiatPriceCurrency = "xmr" + favoriteCurrencies[(index+1) % favoriteCurrencies.length].toLowerCase();
    }

    function fiatApiError(msg){
        console.log("fiatPriceError: " + msg);
        // try again soon instead of waiting for the next minute (the route may have just come up)
        if (persistentSettings.fiatPriceEnabled && currentWallet !== undefined && !fiatRetryTimer.running)
            fiatRetryTimer.start();
        // through Nym, a failed request is a hint that the mixnet route may be stuck
        if (persistentSettings.netWallet === "nym" && nymVpnProxyUp())
            nymWatchProbe();
    }
    Timer {
        id: fiatRetryTimer
        interval: 20000
        onTriggered: appWindow.fiatApiRefresh()
    }

    // the wallet's network (Nym or Tor) just came up: ask for prices and retry the failed market series now
    readonly property bool walletRouteUp: persistentSettings.netWallet === "nym" ? nymVpnProxyUp() : torProxyUp()
    onWalletRouteUpChanged: {
        if (!walletRouteUp || !persistentSettings.fiatPriceEnabled) return;
        if (currentWallet !== undefined) Qt.callLater(fiatApiRefresh);
        if (middlePanel && middlePanel.tradingView) middlePanel.tradingView.retryFailed();
    }

    Component.onCompleted: {
        if (favoriteCurrencies.indexOf(fiatApiCurrencySymbol()) < 0)
            setFavoriteCurrency(fiatApiCurrencySymbol(), true);
        logger.resetLogFilePath(portableSettings.portable);
        if (persistentSettings.logLevel == 5)
            walletManager.setLogCategories(persistentSettings.logCategories)
        else
            walletManager.setLogLevel(persistentSettings.logLevel)

        if (screenAvailableWidth > width) {
            x = (screenAvailableWidth - width) / 2;
        }
        if (screenAvailableHeight > height) {
            y = (screenAvailableHeight - height) / 2;
        }

        translationManager.setLanguage(persistentSettings.locale.split("_")[0]);

        applyWalletMode(persistentSettings.walletMode);

        // last known XMR price until the price services answer
        if (persistentSettings.fiatPriceEnabled)
            fiatCacheLoad();

        // the networks the Network configuration uses (and any other one that was on last time)
        if (torNeeded || persistentSettings.torEnabled)
            torConnect();
        if (nymNeeded || persistentSettings.nymVpnEnabled)
            nymVpnConnect();
        if (i2pNeeded || persistentSettings.i2pEnabled)
            i2pConnect();

        //
        walletManager.walletOpened.connect(onWalletOpened);
        walletManager.deviceButtonRequest.connect(onDeviceButtonRequest);
        walletManager.deviceButtonPressed.connect(onDeviceButtonPressed);
        walletManager.checkUpdatesComplete.connect(onWalletCheckUpdatesComplete);
        walletManager.walletPassphraseNeeded.connect(onWalletPassphraseNeededManager);
        walletManager.walletPairingCodeNeeded.connect(onWalletPairingCodeNeededManager);
        IPC.uriHandler.connect(onUriHandler);

        if(typeof daemonManager != "undefined") {
            daemonManager.daemonStarted.connect(onDaemonStarted);
            daemonManager.daemonStartFailure.connect(onDaemonStartFailure);
            daemonManager.daemonStopped.connect(onDaemonStopped);
        }

        // Connect app exit to qml window exit handling
        mainApp.closing.connect(appWindow.close);

        if( appWindow.qrScannerEnabled ){
            var component = Qt.createComponent("components/QRCodeScanner.qml");
            if (component.status == Component.Ready) {
                cameraUi = component.createObject(appWindow);
            } else {
                console.error("QR scanner component not ready:", component.errorString());
                appWindow.qrScannerEnabled = false;
            }
        }

        if(!walletsFound()) {
            wizard.wizardState = "wizardLanguage";
            rootItem.state = "wizard"
        } else {
            wizard.wizardState = "wizardHome";
            rootItem.state = "normal"
            openWallet("wizard");
        }

        const desktopEntryEnabled = (typeof builtWithDesktopEntry != "undefined") && builtWithDesktopEntry;
        if (persistentSettings.askDesktopShortcut && !portableSettings.portable && desktopEntryEnabled) {
            persistentSettings.askDesktopShortcut = false;

            if (isTails) {
                oshelper.createDesktopEntry();
            } else if (isLinux) {
                confirmationDialog.title = qsTr("Desktop entry") + translationManager.emptyString;
                confirmationDialog.text  = qsTr("Would you like to register Monero GUI Desktop entry?") + translationManager.emptyString;
                confirmationDialog.cancelText = qsTr("No") + translationManager.emptyString;
                confirmationDialog.okText = qsTr("Yes") + translationManager.emptyString;
                confirmationDialog.onAcceptedCallback = function() {
                    oshelper.createDesktopEntry();
                };
                confirmationDialog.onRejectedCallback = null;
                confirmationDialog.open();
            }
        }

        remoteNodesModel.initialize();
    }

    PortableSettings {
        id: portableSettings
        settings: persistentSettings
        unportableFileName: {
            if(isTails && tailsUsePersistence)
                return homePath + "/Persistent/Monero/monero-core.conf";
            return "";
        }
    }

    Settings {
        id: persistentSettings
        location: portableSettings.location

        property bool askDesktopShortcut: isLinux
        property bool askStopLocalNode: true
        property string language: 'English (US)'
        property string language_wallet: 'English'
        property string locale: 'en_US'
        property string account_name
        property string wallet_path
        property bool   allow_background_mining : false
        property bool   allow_p2pool_mining : false
        property bool   allowRemoteNodeMining : false
        property bool   miningIgnoreBattery : true
        property int    miningModeSelected: 0
        property int    chainDropdownSelected: 0
        property var    nettype: NetworkType.MAINNET
        property int    restore_height : 0
        property bool   is_trusted_daemon : false  // TODO: drop after v0.17.2.0 release
        property bool   is_recovering : false
        property bool   is_recovering_from_device : false
        property bool   customDecorations : true
        property string daemonFlags
        property string p2poolFlags
        property int logLevel: 0
        property string logCategories: ""
        property string daemonUsername: "" // TODO: drop after v0.17.2.0 release
        property string daemonPassword: "" // TODO: drop after v0.17.2.0 release
        property bool transferShowAdvanced: false
        property bool receiveShowAdvanced: false
        property bool historyShowAdvanced: false
        property bool historyHumanDates: true
        property string blockchainDataDir: ""
        property bool useRemoteNode: isAndroid
        property string remoteNodeAddress: "" // TODO: drop after v0.17.2.0 release
        property string remoteNodesSerialized: JSON.stringify({
                selected: 0,
                nodes: remoteNodeAddress != ""
                    ? [{
                        address: remoteNodeAddress,
                        username: daemonUsername,
                        password: daemonPassword,
                        trusted: is_trusted_daemon,
                    }]
                    : [],
            })
        property string bootstrapNodeAddress: ""
        property bool segregatePreForkOutputs: true
        property bool keyReuseMitigation2: true
        property int segregationHeight: 0
        property int kdfRounds: 1
        property bool displayWalletNameInTitleBar: true
        property bool hideBalance: false
        property bool priceTicker: true
        property bool accountPriceOpen: false   // Account page: price and balance chart unfolded

        // Matrix FX
        property bool fxMatrixRain: true
        property bool fxBootScreen: true
        property bool fxPageGlitch: true
        property bool fxSounds: false

        // macOS menu bar item
        property bool menuBarEnabled: false
        property bool menuBarPrice: true
        property string menuBarPriceUnit: "BTC"
        property bool menuBarChange: true
        property bool menuBarBalance: false
        property bool menuBarSync: true
        property bool menuBarNym: false

        // quick wallet switch (passwords of unlocked wallets kept in memory for the session)
        property bool quickWalletSwitch: true

        // macOS desktop widget
        property bool desktopWidgetEnabled: false
        property string desktopWidgetUnit: "EUR"
        property bool desktopWidgetChart: true
        property bool desktopWidgetBalance: false
        property bool desktopWidgetNode: true
        property bool desktopWidgetNym: true
        property real desktopWidgetOpacity: 0.75
        property int desktopWidgetX: -1
        property int desktopWidgetY: -1
        property bool askPasswordBeforeSending: true
        property bool lockOnUserInActivity: true
        property int walletMode: 2
        property int lockOnUserInActivityInterval: 10  // minutes
        property bool blackTheme: MoneroComponents.Style.blackTheme
        property string themePalette: "matrix"   // colour palette (Style.palettes), chosen from the title bar
        property bool themePastel: false         // pastel (soft) colours instead of neon
        property string trezorLabels: "{}"       // JSON wallet path -> Trezor name, for the device prompt before the wallet opens
        property string trezorDevices: "{}"      // JSON Trezor transport path -> {label, model}, for the Trezor list
        property string trezorWallets: "{}"      // JSON wallet path -> transport path of its Trezor (marks Trezor wallets)
        property bool checkForUpdates: true
        property bool autosave: true
        property int autosaveMinutes: 10
        property bool pruneBlockchain: false

        property bool fiatPriceEnabled: false
        property string priceAlerts: "[]"       // Trading data alerts: [{ pair, above, price, fired, firedAt, firedPrice }]
        property bool tradingShowBalance: true   // Trading data: chart of the wallet's value
        property bool fiatPriceToggle: false
        property string fiatPriceCurrencyOther: "xmreur" // restored when leaving USD
        property string favoriteCurrenciesJson: '["USD","EUR","BTC"]'
        property string priceSourcesJson: "{}"
        property string fiatPriceProvider: "kraken"
        property string fiatPriceCurrency: "xmrusd"
        property bool fiatRatesConsentGiven: false

        property string proxyAddress: "127.0.0.1:9050"
        property bool proxyEnabled: isTails
        property bool nymVpnEnabled: false
        property bool nymVpnRequired: false   // "Nym required": nothing leaves the app outside NymVPN
        readonly property string nymVpnSocksAddress: oshelper.nymClient.address
        property bool nymVpnPrevProxyEnabled: false
        property bool torEnabled: false
        property bool i2pEnabled: false
        property string scheduledSends: "[]"      // JSON: sends scheduled on the Send page (see scheduleSend)
        property string exclusiveNodes: "[]"      // JSON "host:port" list: monerod --add-exclusive-node
        property string extraPeers: "[]"          // JSON "host:port" list: monerod --add-peer
        property bool netCardOpen: true            // Network configuration card unfolded
        property bool nodeCardOpen: true           // Node card unfolded
        property bool connCardOpen: false          // Connection check card unfolded
        property bool nodeAddrOpen: false          // Network configuration > Node addresses unfolded
        property string anonPeers: "[]"           // JSON list of "host:port" .onion / .b32.i2p P2P peers
        property bool i2pRequired: false      // "I2P required": .i2p remote nodes only, I2P connects at startup
        property bool torRequired: false      // unused since the Network configuration (kept so old settings load)
        property string netWallet: "tor"      // Network configuration: wallet connections "tor" | "nym"
        property string netSync: "tor"        //   local node sync (--proxy) "tor" | "nym" | "i2p"
        property string netTx: "both"         //   local node transactions (--tx-proxy) "tor" | "i2p" | "both"
        property bool torPrevProxyEnabled: false
        property string torPrevProxyAddress: "127.0.0.1:9050"
        property string nymVpnPrevProxyAddress: "127.0.0.1:9050"
        // Security page
        property bool extremePrivacy: false        // only through an approved route (NymVPN or the SOCKS5 proxy)
        property string extremePrivacyPrev: "{}"   // settings to restore when it is turned off
        property string securityNodes: "[]"        // node manager: [{ address, favorite, mine, samples: [{ t, ok, ms, height, version }] }]
        property string securityBackups: "{}"
        property bool hideEmptyAccounts: false     // Accounts: hide accounts with no balance (the first and the selected one stay)
        property bool hideUsedAddresses: false     // Receive: hide subaddresses that already received a transaction      // per wallet path: { seed, keys } (dates of the confirmations / copies)
        function getProxyAddress() {
            // Network configuration: wallet connections only through the chosen network; while it is not
            // connected every proxied request fails (there is no "normal network" choice)
            if (netWallet === "nym") {
                if (appWindow.nymVpnRestarting) return "socks5://127.0.0.1:0";
                return appWindow.nymVpnProxyUp() ? "socks5://" + nymVpnSocksAddress : "socks5://127.0.0.1:0";
            }
            return appWindow.torProxyUp() ? "socks5://" + oshelper.torClient.address : "socks5://127.0.0.1:0";
        }
        function getWalletProxyAddress() {
            if (!useRemoteNode) {
                return "";
            } else {
                const remoteAddress = remoteNodesModel.currentRemoteNode().address;
                // skip proxy when using localhost remote node
                if (/^(127\.0\.0\.1|localhost):[0-9]+$/i.test(remoteAddress)) {
                    return "";
                } else if (appWindow.isI2pNode(remoteAddress)) {
                    // .b32.i2p nodes only through the bundled I2P router
                    return appWindow.i2pProxyUp() ? "socks5://" + oshelper.i2pClient.address : "socks5://127.0.0.1:0";
                } else if (appWindow.isOnionNode(remoteAddress)) {
                    // .onion nodes through Tor, also when the wallet's other connections go through Nym
                    return appWindow.torProxyUp() ? "socks5://" + oshelper.torClient.address : "socks5://127.0.0.1:0";
                } else {
                    return getProxyAddress();
                }
            }
        }

        Component.onCompleted: {
            MoneroComponents.Style.blackTheme = persistentSettings.blackTheme
            MoneroComponents.Style.themePalette = persistentSettings.themePalette
            MoneroComponents.Style.pastel = persistentSettings.themePastel
            // the custom title bar holds the theme, wallet switch and lock buttons: always on
            customDecorations = true
            // I2P is no longer offered for the local node sync (it never synced): back to Tor
            if (netSync === "i2p")
                netSync = "tor"

            if (fiatPriceProvider !== "" && !appWindow.fiatPriceAPIs.hasOwnProperty(fiatPriceProvider)) {
                console.warn("unsupported fiat price provider \"" + fiatPriceProvider + "\", resetting");
                fiatPriceProvider = "kraken";
                fiatPriceEnabled = false;
            }
            Utils.finishSettingsLoad(persistentSettings)
        }
    }

    ListModel {
        id: remoteNodesModel

        property int selected: 0
        // true once the saved list is loaded (the node manager waits for it before syncing)
        property bool ready: false

        signal store()

        function initialize() {
            var duplicates = false;
            try {
                const remoteNodes = JSON.parse(persistentSettings.remoteNodesSerialized);
                // one entry per address (older builds could save the same node several times)
                var seenAddress = {};
                var selectedAddress = remoteNodes.nodes[remoteNodes.selected] ? remoteNodes.nodes[remoteNodes.selected].address : "";
                for (var index = 0; index < remoteNodes.nodes.length; ++index) {
                    const remoteNode = remoteNodes.nodes[index];
                    if (seenAddress[remoteNode.address]) { duplicates = true; continue; }
                    seenAddress[remoteNode.address] = true;
                    remoteNodesModel.append(remoteNode);
                }
                selected = 0;
                for (var s = 0; s < remoteNodesModel.count; ++s)
                    if (remoteNodesModel.get(s).address === selectedAddress) selected = s;
            } catch (e) {
                console.error('failed to parse remoteNodesSerialized', e);
            }

            store.connect(function() {
                var remoteNodes = [];
                for (var index = 0; index < remoteNodesModel.count; ++index) {
                    remoteNodes.push(remoteNodesModel.get(index));
                }
                persistentSettings.remoteNodesSerialized = JSON.stringify({
                    selected: selected,
                    nodes: remoteNodes
                });
            });
            if (duplicates) store();
            ready = true;
        }

        function appendIfNotExists(newRemoteNode) {
            for (var index = 0; index < remoteNodesModel.count; ++index) {
                const remoteNode = remoteNodesModel.get(index);
                if (remoteNode.address == newRemoteNode.address &&
                    remoteNode.username == newRemoteNode.username &&
                    remoteNode.password == newRemoteNode.password &&
                    remoteNode.trusted == newRemoteNode.trusted) {
                        return index;
                }
            }
            remoteNodesModel.append(newRemoteNode);
            return remoteNodesModel.count - 1;
        }

        function applyRemoteNode(index) {
            if (index < count && !appWindow.remoteNodeAllowed(get(index).address)) {
                appWindow.showNodeNotAllowed(get(index).address);
                return;
            }
            selected = index;
            persistentSettings.useRemoteNode = true;
            if (currentWallet) {
                appWindow.connectRemoteNode();
            }
        }

        function currentRemoteNode() {
            if (selected < remoteNodesModel.count) {
                return remoteNodesModel.get(selected);
            }
            return {
                address: "",
                username: "",
                password: "",
                trusted: false,
            };
        }

        function removeSelectNextIfNeeded(index) {
            remoteNodesModel.remove(index);
            if (selected == index) {
                applyRemoteNode(selected % remoteNodesModel.count || 0);
            } else if (selected > index) {
                selected = selected - 1;
            }
        }

        onCountChanged: store()
        onDataChanged: store()
        onSelectedChanged: store()
    }

    // Information dialog
    StandardDialog {
        // dynamically change onclose handler
        property var onCloseCallback
        id: informationPopup
        anchors.fill: parent
        z: parent.z + 1
        cancelVisible: false
        onAccepted:  {
            if (onCloseCallback) {
                onCloseCallback()
            }
        }
    }

    // Transaction confirmation popup
    TxConfirmationDialog {
        // dynamically change onclose handler
        id: txConfirmationPopup
        z: parent.z + 1
        confirmButton.text: (viewOnly ? qsTr("Save as file") : qsTr("Confirm")) + translationManager.emptyString
        confirmButton.rightIcon: viewOnly ? "" : "qrc:///images/icons/rightArrow.png"
        onAccepted: {
            var handleAccepted = function() {
                // Save transaction to file if view only wallet
                if (viewOnly) {
                    saveTxDialog.open();
                } else {
                    handleTransactionConfirmed()
                }
            }
            close();
            passwordDialog.onAcceptedCallback = function() {
                if(walletPassword === passwordDialog.password){
                    handleAccepted()
                } else {
                    passwordDialog.showError(qsTr("Wrong password") + translationManager.emptyString);
                }
            }
            passwordDialog.onRejectedCallback = rejectPendingTransaction;
            if(!persistentSettings.askPasswordBeforeSending) {
                handleAccepted()
            } else {
                passwordDialog.open(
                    "",
                    "",
                    (appWindow.viewOnly ? qsTr("Save transaction file") : qsTr("Send transaction")) + translationManager.emptyString,
                    appWindow.viewOnly ? "" : FontAwesome.arrowCircleRight);
            }
        }
        onRejected: rejectPendingTransaction()
    }

    // Transaction successfully sent popup
    SuccessfulTxDialog {
        id: successfulTxPopup
        z: parent.z + 1
    }

    MoneroComponents.DaemonRunningDialog {
        id: daemonRunningDialog
    }

    StandardDialog {
        z: parent.z + 1
        id: confirmationDialog
        anchors.fill: parent
        property var onAcceptedCallback
        property var onRejectedCallback
        onAccepted:  {
            if (onAcceptedCallback)
                onAcceptedCallback()
        }
        onRejected: {
            if (onRejectedCallback)
                onRejectedCallback();
        }
    }

    MoneroComponents.UpdateDialog {
        id: updateDialog

        allowed: !passwordDialog.visible && !inputDialog.visible && !splash.visible && !devicePassphraseDialog.visible
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
    }

    MoneroComponents.RemoteNodeDialog {
        id: remoteNodeDialog
    }

    // Choose blockchain folder
    FolderDialog {
        id: blockchainFileDialog
        property string directory: ""
        signal changed();

        title: "Please choose a folder"
        currentFolder: "file://" + persistentSettings.blockchainDataDir

        onRejected: console.log("data dir selection canceled")
        onAccepted: {
            var dataDir = walletManager.urlToLocalPath(blockchainFileDialog.selectedFolder)
            var validator = daemonManager.validateDataDir(dataDir, estimatedBlockchainSize);
            if(validator.valid) {
                persistentSettings.blockchainDataDir = dataDir;
            } else {
                confirmationDialog.title = qsTr("Warning") + translationManager.emptyString;
                confirmationDialog.text = "";
                if(validator.readOnly)
                    confirmationDialog.text  += qsTr("Error: Filesystem is read only") + "\n\n"
                if(validator.storageAvailable < estimatedBlockchainSize)
                    confirmationDialog.text  += qsTr("Warning: There's only %1 GB available on the device. Blockchain requires ~%2 GB of data.").arg(validator.storageAvailable).arg(estimatedBlockchainSize) + "\n\n"
                else
                    confirmationDialog.text  += qsTr("Note: There's %1 GB available on the device. Blockchain requires ~%2 GB of data.").arg(validator.storageAvailable).arg(estimatedBlockchainSize) + "\n\n"
                if(!validator.lmdbExists)
                    confirmationDialog.text  += qsTr("Note: lmdb folder not found. A new folder will be created.") + "\n\n"

                // Continue
                confirmationDialog.onAcceptedCallback = function() {
                    persistentSettings.blockchainDataDir = dataDir
                }

                // Cancel
                confirmationDialog.onRejectedCallback = function() { };
                confirmationDialog.open()
            }

            blockchainFileDialog.directory = blockchainFileDialog.selectedFolder;
            delete validator;
        }
    }

    PasswordDialog {
        id: passwordDialog
        visible: false
        z: parent.z + 2
        anchors.fill: parent
        property var onAcceptedCallback
        property var onRejectedCallback
        onAccepted: {
            if (onAcceptedCallback)
                onAcceptedCallback();
        }
        onRejected: {
            if (onRejectedCallback)
                onRejectedCallback();
        }
        onAcceptedNewPassword: {
            if (currentWallet.setPassword(passwordDialog.password)) {
                appWindow.walletPassword = passwordDialog.password;
                informationPopup.title = qsTr("Information") + translationManager.emptyString;
                informationPopup.text  = qsTr("Password changed successfully") + translationManager.emptyString;
            } else {
                informationPopup.title  = qsTr("Error") + translationManager.emptyString;
                informationPopup.text  = qsTr("Error: ") + currentWallet.errorString;
            }
            informationPopup.onCloseCallback = null;
            informationPopup.open();
        }
        onRejectedNewPassword: {}
        Keys.enabled: !passwordDialog.visible && informationPopup.visible
        Keys.onEnterPressed: informationPopup.close()
        Keys.onReturnPressed: informationPopup.close()
    }

    DevicePassphraseDialog {
        id: devicePassphraseDialog
        visible: false
        z: parent.z + 1
        anchors.fill: parent
    }

    ScheduledPaymentDialog { id: scheduledExitDialog; anchors.fill: parent; z: 30 }
    ScheduledPaymentDialog { id: scheduledLateDialog; anchors.fill: parent; z: 30 }

    NymAccountDialog {
        id: nymAccountDialog
        anchors.fill: parent
        z: 20
    }

    TrezorPicker {
        id: trezorPicker
        anchors.fill: parent
        z: 20
    }

    InputDialog {
        id: inputDialog
        visible: false
        z: parent.z + 1
        anchors.fill: parent
        property var onAcceptedCallback
        property var onRejectedCallback
        onAccepted:  {
            if (onAcceptedCallback)
                onAcceptedCallback()
        }
        onRejected:  {
            if (onRejectedCallback)
                onRejectedCallback()
        }
    }

    DaemonManagerDialog {
        id: daemonManagerDialog
        onRejected: {
            middlePanel.settingsView.settingsStateViewState = "Node";
            loadPage("Settings");
        }

    }

    ProcessingSplash {
        id: splash
        width: Math.min(deviceMode ? 540 : 460, appWindow.width - 40)
        height: contentHeight + 56
        x: (appWindow.width - width) / 2
        y: (appWindow.height - height) / 2
        messageText: qsTr("Please wait...") + translationManager.emptyString
        // wallet being opened or used, and its Trezor (shown while waiting on the device)
        walletLabel: persistentSettings.wallet_path ? appWindow.usefulName(String(persistentSettings.wallet_path).replace(/.*[\/\\]/, "").replace(/\.keys$/, "")) : ""
        deviceLabel: deviceMode ? (currentWallet && currentWallet.isTrezor() ? walletDeviceLabel : openingTrezorLabel) : ""
        onCancelRequested: appWindow.cancelDeviceConfirmation()
    }

    Timer {
        id: deviceCancelFallback
        interval: 8000
        onTriggered: if (splash.visible && splash.cancelling) hideProcessingSplash()
    }

    Item {
        id: rootItem
        anchors.fill: parent
        clip: true

        state: "wizard"
        states: [
            State {
                name: "wizard"
                PropertyChanges { target: middlePanel; visible: false }
                PropertyChanges { target: wizard; visible: true }
                PropertyChanges { target: resizeArea; visible: true }
                PropertyChanges { target: titleBar; state: "essentials" }
            }, State {
                name: "normal"
                PropertyChanges { target: middlePanel; visible: true }
                PropertyChanges { target: wizard; visible: false }
                PropertyChanges { target: resizeArea; visible: true }
                PropertyChanges { target: titleBar; state: "default" }
            }
        ]

        Item {
            id: blurredArea
            anchors.fill: parent

            LeftPanel {
                id: leftPanel
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.bottom: priceTicker.top
                visible: rootItem.state == "normal" && middlePanel.state != "Merchant"
                currentAccountIndex: currentWallet ? currentWallet.currentSubaddressAccount : 0
                minedActive: appWindow.minedAccountActive
                currentAccountLabel: {
                    appWindow.accountLabelsRevision;
                    if (appWindow.minedAccountActive)
                        return qsTr("Mined addresses") + translationManager.emptyString;
                    if (currentWallet) {
                        return currentWallet.getSubaddressLabel(currentWallet.currentSubaddressAccount, 0);
                    }
                    return qsTr("Primary account") + translationManager.emptyString;
                }

                onTransferClicked: {
                    middlePanel.state = "Transfer";
                    middlePanel.flickable.contentY = 0;
                    updateBalance();
                }

                onReceiveClicked: {
                    // the mined account's addresses are on its own page
                    middlePanel.state = appWindow.minedAccountActive ? "CustomAddresses" : "Receive";
                    middlePanel.flickable.contentY = 0;
                    updateBalance();
                }

                onHistoryClicked: {
                    middlePanel.state = "History";
                    middlePanel.flickable.contentY = 0;
                    updateBalance();
                }

                onAddressBookClicked: {
                    middlePanel.state = "AddressBook";
                    middlePanel.flickable.contentY = 0;
                    updateBalance();
                }

                onAdvancedClicked: {
                    middlePanel.state = "Advanced";
                    middlePanel.flickable.contentY = 0;
                    updateBalance();
                }

                onSettingsClicked: {
                    middlePanel.state = "Settings";
                    middlePanel.flickable.contentY = 0;
                    updateBalance();
                }

                onAccountClicked: {
                    middlePanel.state = "Account";
                    middlePanel.flickable.contentY = 0;
                    updateBalance();
                }

                onSwapsClicked: {
                    if (!persistentSettings.fiatPriceEnabled)
                        return;
                    middlePanel.state = "Swaps";
                    middlePanel.flickable.contentY = 0;
                }

                onTradingClicked: {
                    if (!persistentSettings.fiatPriceEnabled)
                        return;
                    middlePanel.state = "Trading";
                    middlePanel.flickable.contentY = 0;
                }

                onNotesClicked: {
                    middlePanel.state = "Notes";
                    middlePanel.flickable.contentY = 0;
                }

                onCustomAddressesClicked: {
                    middlePanel.state = "CustomAddresses";
                    middlePanel.flickable.contentY = 0;
                }

                onWalletPlusClicked: {
                    middlePanel.state = "WalletPlus";
                    middlePanel.flickable.contentY = 0;
                }

                onSecurityClicked: {
                    middlePanel.state = "Security";
                    middlePanel.flickable.contentY = 0;
                }

                onTrezorClicked: {
                    middlePanel.state = "Trezor";
                    middlePanel.flickable.contentY = 0;
                }
            }

            MiddlePanel {
                id: middlePanel
                accountView.currentAccountIndex: currentWallet ? currentWallet.currentSubaddressAccount : 0
                anchors.top: parent.top
                anchors.bottom: priceTicker.top
                anchors.left: leftPanel.visible ? leftPanel.right : parent.left
                anchors.right: parent.right
                state: "Transfer"
            }

            // scrolling XMR quotes at the bottom (Settings > Interface)
            MoneroComponents.PriceTicker {
                id: priceTicker
                readonly property bool shown: persistentSettings.priceTicker && persistentSettings.fiatPriceEnabled
                                              && rootItem.state == "normal" && middlePanel.state != "Merchant"
                                              && quotes.length > 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: shown
                height: shown ? 28 : 0
            }

            WizardController {
                id: wizard
                anchors.fill: parent
                onUseMoneroClicked: {
                    rootItem.state = "normal";
                    appWindow.openWallet("wizard");
                }
            }
        }

        MultiEffect {
            id: blur
            anchors.fill: blurredArea
            source: blurredArea
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            autoPaddingEnabled: false
            visible: passwordDialog.visible || inputDialog.visible || splash.visible || updateDialog.visible ||
                devicePassphraseDialog.visible || txConfirmationPopup.visible || successfulTxPopup.visible ||
                remoteNodeDialog.visible || daemonRunningDialog.visible || modalDialogs > 0
        }


        property int minWidth: appWindow.minimumWidth
        property int minHeight: appWindow.minimumHeight
        MouseArea {
            id: resizeArea
            enabled: persistentSettings.customDecorations
            hoverEnabled: true
            cursorShape: persistentSettings.customDecorations ? Qt.PointingHandCursor : Qt.ArrowCursor
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 34
            width: 34

            MoneroEffects.ImageMask {
                anchors.centerIn: parent
                visible: persistentSettings.customDecorations
                image: "qrc:///images/window/resize.png"
                color: MoneroComponents.Style.defaultFontColor
                width: 12
                height: 12
                opacity: (parent.containsMouse || parent.pressed) ? 0.5 : 1.0
            }

            property var previousPosition

            onPressed: {
                previousPosition = globalCursor.getPosition()
            }

            onPositionChanged: {
                if(!pressed) return
                var pos = globalCursor.getPosition()
                //var delta = previousPosition - pos
                var dx = previousPosition.x - pos.x
                var dy = previousPosition.y - pos.y

                if(appWindow.width - dx > parent.minWidth)
                    appWindow.width -= dx
                else appWindow.width = parent.minWidth

                if(appWindow.height - dy > parent.minHeight)
                    appWindow.height -= dy
                else appWindow.height = parent.minHeight
                previousPosition = pos
            }
        }

        TitleBar {
            id: titleBar
            visible: persistentSettings.customDecorations && middlePanel.state !== "Merchant"
            walletName: persistentSettings.displayWalletNameInTitleBar && rootItem.state != "wizard" ? appWindow.walletName : ""
            deviceLabel: appWindow.walletDeviceLabel
            hardwareWallet: currentWallet !== undefined && currentWallet !== null && currentWallet.isTrezor()
            removableWallet: currentWallet !== undefined && currentWallet !== null && appWindow.isRemovablePath(currentWallet.path)
            anchors.left: parent.left
            anchors.right: parent.right
            onCloseClicked: appWindow.close();
            onLockWalletClicked: appWindow.lock();
            onLanguageClicked: appWindow.toggleLanguageView();
            onCloseWalletClicked: appWindow.showWizard();
            onMaximizeClicked: appWindow.visibility = appWindow.visibility !== Window.Maximized ? Window.Maximized : Window.Windowed
            onMinimizeClicked: appWindow.visibility = Window.Minimized
        }

        MoneroMerchant.MerchantTitlebar {
            id: titleBarOrange
            visible: persistentSettings.customDecorations && middlePanel.state === "Merchant"
            anchors.left: parent.left
            anchors.right: parent.right
            onCloseClicked: appWindow.close();
            onMaximizeClicked: appWindow.visibility = appWindow.visibility !== Window.Maximized ? Window.Maximized : Window.Windowed
            onMinimizeClicked: appWindow.visibility = Window.Minimized
        }

        // new ToolTip
        Rectangle {
            id: toolTip
            property alias text: content.text
            width: content.width + 12
            height: content.height + 17
            color: "#FF6C3C"
            //radius: 3
            visible:false;

            Image {
                id: tip
                anchors.top: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: 5
                source: "qrc:///images/icons/tip.png"
            }

            MoneroComponents.TextPlain {
                id: content
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                lineHeight: 0.7
                font.family: "Arial"
                font.pixelSize: 12
                color: "#FFFFFF"
            }
        }
    }

    function toggleLanguageView(){
        languageSidebar.visible ? languageSidebar.close() : languageSidebar.open();
        languageSidebar.selectCurrentLanguage()
        resetLanguageFields()
    }

    Timer {
        id: autosaveTimer
        interval: persistentSettings.autosaveMinutes * 60 * 1000
        repeat: true
        running: persistentSettings.autosave
        onTriggered: {
            if (currentWallet && !currentWallet.refreshing) {
                currentWallet.storeAsync(function(success) {
                    if (success) {
                        appWindow.showStatusMessage(qsTr("Autosaved the wallet"), 3);
                    } else {
                        appWindow.showStatusMessage(qsTr("Failed to autosave the wallet"), 3);
                    }
                });
            }
        }
    }

    // TODO: Make the callback dynamic
    Timer {
        id: statusMessageTimer
        interval: 5;
        running: false;
        repeat: false
        onTriggered: resetAndroidClose()
        triggeredOnStart: false
    }

    Timer {
        id: userInActivityTimer
        interval: 2000; running: false; repeat: true
        onTriggered: checkInUserActivity()
    }

    Timer {
        // enables theme transition animations after 500ms
        id: appThemeTransition
        running: true
        repeat: false
        interval: 500
        onTriggered: appWindow.themeTransition = true;
    }

    function checkNoSyncFlag() {
        if (!appWindow.daemonRunning) {
            return true;
        }
        if (appWindow.walletMode == 0 && !daemonManager.noSync()) {
            return false;
        }
        if (appWindow.walletMode == 1 && daemonManager.noSync()) {
            return false;
        }
        return true;
    }

    function checkSimpleModeConnection(){
        const disconnectedTimeoutSec = 30;
        const firstCheckDelaySec = 2;

        const firstRun = appWindow.disconnectedEpoch == 0;
        if (firstRun) {
            appWindow.disconnectedEpoch = Utils.epoch() + firstCheckDelaySec - disconnectedTimeoutSec;
        } else if (!disconnected) {
            appWindow.disconnectedEpoch = Utils.epoch();
        }

        const sinceLastConnect = Utils.epoch() - appWindow.disconnectedEpoch;
        if (sinceLastConnect < disconnectedTimeoutSec && checkNoSyncFlag()) {
            return;
        }

        const simpleModeFlags = "--enable-dns-blocklist --out-peers 16 --no-igd";
        if (appWindow.daemonRunning) {
            appWindow.stopDaemon(function() {
                appWindow.startDaemon(simpleModeFlags)
            });
        } else {
            appWindow.startDaemon(simpleModeFlags);
        }
    }

    Timer {
        // Simple mode connection check timer
        id: simpleModeConnectionTimer
        interval: 2000
        running: appWindow.walletMode < 2 && currentWallet != undefined && daemonStartStopInProgress == 0
        repeat: true
        onTriggered: appWindow.checkSimpleModeConnection()
    }

    MoneroComponents.StatusToast {
        id: statusMessage
    }

    function resetAndroidClose() {
        console.log("resetting android close");
        androidCloseTapped = false;
        statusMessage.visible = false
    }

    function showStatusMessage(msg,timeout) {
        console.log("showing status message")
        statusMessageTimer.interval = timeout * 1000;
        statusMessageTimer.start()
        statusMessage.text = msg;
        statusMessage.duration = timeout * 1000;
        if (statusMessage.visible) statusMessage.flash();
        statusMessage.visible = true
    }

    function showDaemonIsRunningDialog(onClose) {
        // small card with "Force stop" / "Keep it running" (Cancel or Esc keeps the app open)
        daemonRunningDialog.open(function() { stopDaemon(onClose); },
                                 function() { onClose(); });
    }

    onClosing: function(close) {
        close.accepted = false;
        console.log("blocking close event");
        if(isAndroid) {
            console.log("blocking android exit");
            if(qrScannerEnabled)
                cameraUi.state = "Stopped"

            if(!androidCloseTapped) {
                androidCloseTapped = true;
                appWindow.showStatusMessage(qsTr("Tap again to close..."),3)

                // first close
                return;
            }


        }

        if (!requestScheduledExit(function() { continueApplicationClose(); })) return;
        continueApplicationClose();
    }

    function continueApplicationClose() {
        scheduledExitApproved = false;
        // If daemon is running - prompt user before exiting
        if(daemonManager == undefined || persistentSettings.useRemoteNode) {
            closeAccepted();
        } else if (appWindow.walletMode == 0) {
            stopDaemon(closeAccepted, true);
        } else {
            showProcessingSplash(qsTr("Checking local node status..."));
            const handler = function(running) {
                hideProcessingSplash();
                if (running && persistentSettings.askStopLocalNode) {
                    showDaemonIsRunningDialog(closeAccepted);
                } else {
                    closeAccepted();
                }
            };

            if (currentWallet) {
                handler(!currentWallet.disconnected);
            } else {
                daemonManager.runningAsync(persistentSettings.nettype, persistentSettings.blockchainDataDir, handler);
            }
        }
    }

    function closeAccepted(){
        if (scheduledRunningId !== "" || scheduledSaving) {
            showStatusMessage(qsTr("Wait for the payment or save to finish before closing or switching wallets."), 5);
            return;
        }
        if (isQuitting)
            return;
        isQuitting = true;
        console.log("close accepted");
        // closing never waits more than 20 s (slow requests through the Nym mixnet)
        oshelper.armShutdownWatchdog(20);
        // Stop only the wallet-owned helper, never the official VPN service.
        oshelper.nymClient.stop();
        oshelper.torClient.stop();
        oshelper.i2pClient.stop();
        cancelConnectionTest();
        daemonManager.exit();
        p2poolManager.exit();
        closeWallet(function() {
            console.log("wallet closed, requesting final application quit");
            gracefulShutdownComplete();
        });
    }

    function onWalletCheckUpdatesComplete(version, downloadUrl, hash, firstSigner, secondSigner) {
        const alreadyAsked = updateDialog.url == downloadUrl && updateDialog.hash == hash;
        if (!alreadyAsked)
        {
            updateDialog.show(version, isMac || isWindows || isLinux ? downloadUrl : "", hash);
        }
    }

    function getBuildTag() {
        if (isMac) {
            return isARM ? "mac-armv8" : "mac-x64";
        }
        if (isWindows) {
            return oshelper.installed ? "install-win-x64" : "win-x64";
        }
        if (isLinux) {
            return "linux-x64";
        }
        return "source";
    }

    function checkUpdates() {
        const version = Version.GUI_VERSION.match(/\d+\.\d+\.\d+\.\d+/);
        if (version) {
            walletManager.checkUpdatesAsync(
                "monero-gui", "gui", getBuildTag(), version[0], persistentSettings.getProxyAddress());
        } else {
            console.error("failed to parse version number", Version.GUI_VERSION);
        }
    }

    Timer {
        id: updatesTimer
        interval: 3600 * 1000
        repeat: true
        running: !disableCheckUpdatesFlag && persistentSettings.checkForUpdates
        triggeredOnStart: true
        onTriggered: checkUpdates()
    }

    function releaseFocus() {
        // Workaround to release focus from textfield when scrolling (https://bugreports.qt.io/browse/QTBUG-34867)
        if(isAndroid) {
            console.log("releasing focus")
            middlePanel.focus = true
            middlePanel.focus = false
        }
    }

    // reset label text. othewise potential privacy leak showing unlock time when switching wallets
    function clearMoneroCardLabelText(){
        leftPanel.balanceString = "?.??"
        leftPanel.balanceFiatString = "?.??"
    }

    // some fields need an extra nudge when changing languages
    function resetLanguageFields(){
        clearMoneroCardLabelText()
        if (currentWallet) {
            onWalletRefresh();
        }
    }

    function userActivity() {
        // register user activity
        appWindow.userLastActive = Utils.epoch();
    }

    function checkInUserActivity() {
        if(rootItem.state !== "normal") return;
        if(!persistentSettings.lockOnUserInActivity) return;
        if(passwordDialog.visible) return;
        var inputDialogVisible = inputDialog && inputDialog.visible
        var successfulTxPopupVisible = successfulTxPopup && successfulTxPopup.visible
        var informationPopupVisible = informationPopup && informationPopup.visible

        // prompt password after X seconds of inactivity
        var inactivity = Utils.epoch() - appWindow.userLastActive;
        if(inactivity < (persistentSettings.lockOnUserInActivityInterval * 60)) return;

        if (inputDialogVisible) inputDialog.close()
        forgetOtherUnlockedWallets();
        remoteNodeDialog.close();
        informationPopup.close()
        if (txConfirmationPopup.visible) {
            txConfirmationPopup.close()
            txConfirmationPopup.clearFields()
            txConfirmationPopup.rejected()
        }
        successfulTxPopup.close();

        if (currentWallet && currentWallet.getBackgroundSyncType() != Wallet.BackgroundSync_Off) {
            appWindow.showProcessingSplash(qsTr("Locking..."));
            currentWallet.startBackgroundSync()
            return;
        }

        passwordDialog.onAcceptedCallback = function() {
            if(walletPassword === passwordDialog.password){
                passwordDialog.close();
                if (inputDialogVisible) inputDialog.open(inputDialog.inputText)
                if (successfulTxPopupVisible) successfulTxPopup.open(successfulTxPopup.transactionID)
                if (informationPopupVisible) informationPopup.open()
            } else {
                passwordDialog.showError(qsTr("Wrong password"));
            }
        }

        passwordDialog.onRejectedCallback = function() { appWindow.showWizard(); }
        passwordDialog.open();
    }

    function getDefaultDaemonRpcPort(networkType) {
        switch (parseInt(networkType)) {
            case NetworkType.STAGENET:
                return 38081;
            case NetworkType.TESTNET:
                return 28081;
            default:
                return 18081;
        }
    }

    function changeWalletMode(mode){
        appWindow.disconnectedEpoch = 0;
        persistentSettings.walletMode = mode;
        applyWalletMode(mode);
    }

    function applyWalletMode(mode){
        if (mode < 2) {
            persistentSettings.useRemoteNode = false;

            if (middlePanel.settingsView.settingsStateViewState === "Node") {
                middlePanel.settingsView.settingsStateViewState = "Wallet"
            }
        }
        console.log("walletMode: " + (mode === 0 ? "simple": mode === 1 ? "simple (bootstrap)" : "Advanced"));
    }

    Rectangle {
        id: inactiveOverlay
        visible: blur.visible
        anchors.fill: parent
        anchors.topMargin: titleBar.height
        color: MoneroComponents.Style.blackTheme ? "black" : "white"
        opacity: GraphicsInfo.api !== GraphicsInfo.Software ? 0.3 : inputDialog.visible || splash.visible ? 0.7 : 1.0

        MoneroEffects.ColorTransition {
            targetObj: parent
            blackColor: "black"
            whiteColor: "white"
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    // neonWindowFrame: thin neon border + resize from every edge and corner
    Item {
        id: neonWindowFrame
        anchors.fill: parent
        z: 10000
        readonly property bool canResize: persistentSettings.customDecorations &&
            appWindow.visibility !== Window.Maximized && appWindow.visibility !== Window.FullScreen
        readonly property int grip: 6

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: MoneroComponents.Style.orange
            opacity: 0.75
        }

        component Grip: MouseArea {
            property bool l: false
            property bool r: false
            property bool t: false
            property bool b: false
            property point start
            property rect geo
            enabled: neonWindowFrame.canResize
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: (l && t) || (r && b) ? Qt.SizeFDiagCursor
                       : (r && t) || (l && b) ? Qt.SizeBDiagCursor
                       : (l || r) ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onPressed: {
                start = globalCursor.getPosition();
                geo = Qt.rect(appWindow.x, appWindow.y, appWindow.width, appWindow.height);
            }
            onPositionChanged: {
                if (!pressed) return;
                var p = globalCursor.getPosition();
                var dx = p.x - start.x, dy = p.y - start.y;
                var minW = appWindow.minimumWidth, minH = appWindow.minimumHeight;
                if (r) appWindow.width = Math.max(minW, geo.width + dx);
                if (b) appWindow.height = Math.max(minH, geo.height + dy);
                if (l) {
                    var w = Math.max(minW, geo.width - dx);
                    appWindow.x = geo.x + geo.width - w;
                    appWindow.width = w;
                }
                if (t) {
                    var h = Math.max(minH, geo.height - dy);
                    appWindow.y = geo.y + geo.height - h;
                    appWindow.height = h;
                }
            }
        }

        Grip { l: true; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: 12; anchors.bottomMargin: 12; width: neonWindowFrame.grip }
        Grip { r: true; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: 12; anchors.bottomMargin: 12; width: neonWindowFrame.grip }
        Grip { t: true; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 12; anchors.rightMargin: 12; height: 4 }
        Grip { b: true; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 12; anchors.rightMargin: 12; height: neonWindowFrame.grip }
        Grip { l: true; t: true; anchors.left: parent.left; anchors.top: parent.top; width: 12; height: 12 }
        Grip { r: true; t: true; anchors.right: parent.right; anchors.top: parent.top; width: 12; height: 12 }
        Grip { l: true; b: true; anchors.left: parent.left; anchors.bottom: parent.bottom; width: 12; height: 12 }
        Grip { r: true; b: true; anchors.right: parent.right; anchors.bottom: parent.bottom; width: 12; height: 12 }
    }

    // Matrix FX overlays
    Loader {
        id: soundFxLoader
        active: persistentSettings.fxSounds
        source: "components/SoundFx.qml"
    }

    MoneroComponents.TxBroadcastFx {
        id: txBroadcastFx
        anchors.fill: parent
        z: 9000
    }

    MoneroComponents.DevicePrompt {
        id: devicePrompt
        anchors.fill: parent
        z: 9001
    }

    MoneroComponents.BootScreen {
        id: bootScreen
        anchors.fill: parent
        z: 20000
        active: true   // the start screen always shows (its option was removed)
        versionNumber: Version.GUI_VERSION_NUMBER
        versionTag: Version.GUI_VERSION_TAG
        Component.onCompleted: Qt.callLater(start)
        onFinished: {
            // The intro takes focus after the startup password dialog has opened.
            // Restore it only once the intro has fully disappeared.
            if (passwordDialog.visible)
                Qt.callLater(passwordDialog.focusPassword);
        }
    }

    // borders on white theme + linux
    Rectangle {
        visible: isLinux && !MoneroComponents.Style.blackTheme && middlePanel.state !== "Merchant"
        z: parent.z + 1
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: MoneroComponents.Style.appWindowBorderColor

        MoneroEffects.ColorTransition {
            targetObj: parent
            blackColor: MoneroComponents.Style._b_appWindowBorderColor
            whiteColor: MoneroComponents.Style._w_appWindowBorderColor
        }
    }

    Rectangle {
        visible: isLinux && !MoneroComponents.Style.blackTheme && middlePanel.state !== "Merchant"
        z: parent.z + 1
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: MoneroComponents.Style.appWindowBorderColor

        MoneroEffects.ColorTransition {
            targetObj: parent
            blackColor: MoneroComponents.Style._b_appWindowBorderColor
            whiteColor: MoneroComponents.Style._w_appWindowBorderColor
        }
    }

    Rectangle {
        visible: isLinux && !MoneroComponents.Style.blackTheme && middlePanel.state !== "Merchant"
        z: parent.z + 1
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.left: parent.left
        height: 1
        color: MoneroComponents.Style.appWindowBorderColor

        MoneroEffects.ColorTransition {
            targetObj: parent
            blackColor: MoneroComponents.Style._b_appWindowBorderColor
            whiteColor: MoneroComponents.Style._w_appWindowBorderColor
        }
    }

    Rectangle {
        visible: isLinux && !MoneroComponents.Style.blackTheme && middlePanel.state !== "Merchant"
        z: parent.z + 1
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 1
        color: MoneroComponents.Style.appWindowBorderColor

        MoneroEffects.ColorTransition {
            targetObj: parent
            blackColor: MoneroComponents.Style._b_appWindowBorderColor
            whiteColor: MoneroComponents.Style._w_appWindowBorderColor
        }
    }

    MoneroComponents.LanguageSidebar {
        id: languageSidebar
        dragMargin: 0
        onAboutToShow: previousActiveFocusItem = activeFocusItem;
        onClosed: { if (previousActiveFocusItem) previousActiveFocusItem.forceActiveFocus() }
    }

    Loader {
        active: isMac
        sourceComponent: MoneroComponents.MenuBar {}
    }

    Network {
        id: network
        proxyAddress: persistentSettings.getProxyAddress()
    }

    WalletManager {
        id: walletManager
        proxyAddress: persistentSettings.getProxyAddress()
    }
}
