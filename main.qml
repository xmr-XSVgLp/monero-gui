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
    property int maxWindowHeight: (isAndroid || isIOS)? screenAvailableHeight : (screenAvailableHeight < 900)? 720 : 800;
    property bool daemonRunning: !persistentSettings.useRemoteNode && !disconnected
    property int daemonStartStopInProgress: 0
    property alias toolTip: toolTip
    property string walletName
    property string walletDeviceLabel: ""   // Trezor name shown in the title bar
    property string deviceShowAddress: ""   // address sent to the Trezor screen, shown in the splash to compare

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
    // Connection diagnostics are manual: never compete with initial blockchain sync.
    property var connTest: ({})
    property bool connTesting: false
    property int connTestGen: 0
    function cancelConnectionTest() {
        connTestGen++;
        connTesting = false;
        connTest = ({});
        oshelper.cancelConnectionTest();
    }
    property string connTestVia: ""     // "nym", "proxy" or "direct"
    property date connTestTime
    function runConnectionTest() {
        if (connTesting)
            return;
        var proxy = persistentSettings.getProxyAddress().replace(/^socks5:\/\//, "");
        connTestVia = proxy === "" ? "direct" : (proxy === persistentSettings.nymVpnSocksAddress && nymVpnProxyUp() ? "nym" : "proxy");
        connTesting = true;
        var gen = ++connTestGen;
        connTest = ({});
        oshelper.nymVpnTest(proxy, localDaemonAddress, function(json) {
            if (gen !== connTestGen) return;
            var r = JSON.parse(json);
            if (r.key === "done") {
                connTesting = false;
                connTestTime = new Date();
                return;
            }
            var t = Object.assign({}, connTest);
            t[r.key] = r;
            connTest = t;
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
            } else if (client.state === "connected") {
                nymVpnState = "connected";
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
            }
        }
    }

    // extreme privacy: the SOCKS5 address of an approved route (NymVPN up, or the SOCKS5 proxy turned on), "" if none
    function approvedRoute() {
        if (nymVpnProxyUp())
            return persistentSettings.nymVpnSocksAddress;
        if (!persistentSettings.nymVpnRequired && persistentSettings.proxyEnabled && persistentSettings.proxyAddress !== "")
            return persistentSettings.proxyAddress;
        return "";
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
    property var fiatPriceAPIs: {
        return {
            "kraken": "https://api.kraken.com/0/public/Ticker?pair=XMRUSD",
            "coinpaprika": "https://api.coinpaprika.com/v1/tickers/xmr-monero"
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
        // console.log("opening wallet at: ", wallet_path, "with password: ", appWindow.walletPassword);
        console.log("opening wallet at: ", wallet_path, ", network type: ", persistentSettings.nettype == NetworkType.MAINNET ? "mainnet" : persistentSettings.nettype == NetworkType.TESTNET ? "testnet" : "stagenet");

        this.onWalletOpening();
        walletManager.openWalletAsync(
            wallet_path,
            walletPassword,
            persistentSettings.nettype,
            persistentSettings.kdfRounds);
    }

    function gracefulQuit() {
        if (isQuitting)
            return;
        isQuitting = true;
        closeWallet(function() {
            gracefulShutdownComplete();
        })
    }

    function closeWallet(callback) {

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
        middlePanel.paymentClicked.disconnect(handlePayment);
        middlePanel.sweepUnmixableClicked.disconnect(handleSweepUnmixable);
        middlePanel.getProofClicked.disconnect(handleGetProof);
        middlePanel.checkProofClicked.disconnect(handleCheckProof);

        appWindow.walletName = "";
        appWindow.walletDeviceLabel = "";
        currentWallet = undefined;

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

        walletName = usefulName(wallet.path)
        walletDeviceLabel = wallet.isTrezor() ? wallet.deviceLabel() : ""

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
            const remoteNode = remoteNodesModel.currentRemoteNode();
            currentDaemonAddress = remoteNode.address;
            currentWallet.setDaemonLogin(remoteNode.username, remoteNode.password);
        } else {
            currentDaemonAddress = localDaemonAddress;
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
            appWindow.showProcessingSplash(qsTr("Please proceed to the device..."));
        }
    }

    function onDeviceButtonPressed(){
        devicePrompt.hide();
        splash.deviceMode = false;
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

    function onWalletOpened(wallet) {
        hideProcessingSplash();
        walletName = usefulName(wallet.path)
        console.log(">>> wallet opened: " + wallet)
        if (wallet.status !== Wallet.Status_Ok) {
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
                    console.log("closing wallet async : " + wallet.address)
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

        // the start page (Account) was shown before the wallet existed: fill it now
        if (middlePanel.state === "Account")
            middlePanel.accountView.onPageCompleted();

        // Force switch normal view
        rootItem.state = "normal";

        // Process queued IPC command
        if(typeof IPC !== "undefined" && IPC.queuedCmd().length > 0){
            var queuedCmd = IPC.queuedCmd();
            if(/^\w+:\/\/(.*)$/.test(queuedCmd)) appWindow.onUriHandler(queuedCmd); // uri
        }
    }

    function onWalletPassphraseNeededManager(on_device){
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

    function startDaemon(flags){
        daemonStartStopInProgress = 1;

        // Pause refresh while starting daemon
        currentWallet.pauseRefresh();

        // with NymVPN on (or "Nym required") monerod also reaches its peers through the Nym SOCKS5 proxy
        flags = (flags || "").trim();
        if (persistentSettings.extremePrivacy) {
            // extreme privacy: no sync without an approved route, peers only through it, no UPnP, port hidden
            var route = approvedRoute();
            if (route === "") {
                daemonStartStopInProgress = 0;
                currentWallet.startRefresh();
                informationPopup.title = qsTr("Extreme privacy") + translationManager.emptyString;
                informationPopup.text = qsTr("The local node does not start until NymVPN is connected or the SOCKS5 proxy is turned on.") + translationManager.emptyString;
                informationPopup.onCloseCallback = null;
                informationPopup.open();
                return;
            }
            if (flags.indexOf("--proxy") < 0)
                flags = (flags !== "" ? flags + " " : "") + "--proxy " + route;
            if (flags.indexOf("--no-igd") < 0)
                flags += " --no-igd";
            if (flags.indexOf("--hide-my-port") < 0)
                flags += " --hide-my-port";
        } else if ((persistentSettings.nymVpnEnabled || persistentSettings.nymVpnRequired) && flags.indexOf("--proxy") < 0)
            flags = (flags !== "" ? flags + " " : "") + "--proxy " + persistentSettings.nymVpnSocksAddress;

        if ((persistentSettings.nymVpnEnabled || persistentSettings.nymVpnRequired) && flags.indexOf("--proxy") >= 0) {
            if (!/(^|\s)--out-peers(?:=|\s)/.test(flags)) flags += " --out-peers 4";
            if (!/(^|\s)--block-sync-size(?:=|\s)/.test(flags)) flags += " --block-sync-size 5";
        }

        const noSync = appWindow.walletMode === 0;
        // extreme privacy: no bootstrap node (it would answer for the wallet while monerod syncs)
        const bootstrapNodeAddress = persistentSettings.extremePrivacy ? "" : persistentSettings.walletMode < 2 ? "auto" : persistentSettings.bootstrapNodeAddress
        daemonManager.start(flags, persistentSettings.nettype, persistentSettings.blockchainDataDir, bootstrapNodeAddress, noSync, persistentSettings.pruneBlockchain);
    }

    function stopDaemon(callback, splash){
        daemonStartStopInProgress = 2;
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

    // called on "transfer"
    function handlePayment(recipients, paymentId, mixinCount, priority, description, createFile) {
        console.log("Creating transaction: ")
        console.log("\trecipients: ", recipients,
                    ", payment_id: ", paymentId,
                    ", mixins: ", mixinCount,
                    ", priority: ", priority,
                    ", description: ", description);

        const recipientAll = recipients.find(function (recipient) {
            return recipient.amount == "(all)";
        });
        if (recipientAll && recipients.length > 1) {
            throw "Sending all requires one destination address";
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
        hideProcessingSplash();
        if (!success) {
            console.log("Error committing transaction: " + transaction.errorString);
            informationPopup.title = qsTr("Error") + translationManager.emptyString
            informationPopup.text  = qsTr("Couldn't send the money: ") + transaction.errorString
            informationPopup.onCloseCallback = null;
            informationPopup.open();
        } else {
            if (txConfirmationPopup.transactionDescription.length > 0) {
                for (var i = 0; i < txid.length; ++i)
                    currentWallet.setUserNote(txid[i], txConfirmationPopup.transactionDescription);
            }

            // Clear tx fields
            middlePanel.transferView.clearFields()
            txConfirmationPopup.clearFields()
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
        if (amount !== null && amount.length > 0) {
            var result = currentWallet.getReserveProof(false, currentWallet.currentSubaddressAccount, amount, message)
            txProofComputed(null, result)
        } else {
            console.log("Getting payment proof: ")
            console.log("\ttxid: ", txid,
                        ", address: ", address,
                        ", message: ", message);
            function spendProofFallback(txid, result){
                if (!result || result.indexOf("error|") === 0) {
                    currentWallet.getSpendProofAsync(txid, message, txProofComputed);
                } else {
                    txProofComputed(txid, result);
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

    function hideProcessingSplash() {
        devicePrompt.hide();
        splash.deviceMode = false;
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
        });
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
        interval: 1000 * 60 * 5;
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

    function fiatApiJsonReceived(url, resp, error) {
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
        const rate = appWindow.fiatRates.hasOwnProperty(symbol) ? appWindow.fiatRates[symbol] : 0;
        appWindow.fiatPrice = (appWindow.fiatPriceUSD > 0 && rate > 0) ? appWindow.fiatPriceUSD * rate : 0;

        const rate7d = appWindow.fiatRates7d.hasOwnProperty(symbol) ? appWindow.fiatRates7d[symbol] : 0;
        appWindow.fiatChange7d = (appWindow.fiatPrice > 0 && appWindow.fiatPriceUSD7d > 0 && rate7d > 0)
            ? (appWindow.fiatPrice / (appWindow.fiatPriceUSD7d * rate7d) - 1) * 100
            : NaN;
        // FX moves little in a day: the 24h change uses today's rate on both sides
        appWindow.fiatChange24h = (appWindow.fiatPriceUSD > 0 && appWindow.fiatPriceUSD24h > 0)
            ? (appWindow.fiatPriceUSD / appWindow.fiatPriceUSD24h - 1) * 100
            : NaN;

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
        if(!appWindow.fiatPriceAPIs.hasOwnProperty(userProvider)){
            appWindow.fiatApiError("provider \"" + userProvider + "\" not implemented");
            return;
        }

        network.getJSON(appWindow.fiatPriceAPIs[userProvider], fiatApiJsonReceived);
        // XMR -> BTC quote for 1 XMR from Wagyu (no API key), at most every 5 minutes
        if (Date.now() - appWindow.priceBtcTimestamp > 5 * 60 * 1000)
            network.postJSON("https://api-beta.wagyu.xyz/v2/swaps/quote",
                             JSON.stringify({ fromChainId: 0, fromToken: "XMR",
                                              toChainId: 20000000000001, toToken: "bitcoin",
                                              fromAmount: "1000000000000" }),
                             priceBtcReceived);

        // price from 7 days ago (CoinPaprika sends it with the ticker)
        if (userProvider === "kraken" && Date.now() - appWindow.fiatHistoryTimestamp > 15 * 60 * 1000)
            network.getJSON("https://api.kraken.com/0/public/OHLC?pair=XMRUSD&interval=60", fiatApiHistoryReceived);
        if (userProvider !== "kraken")
            appWindow.fiatHistoryTimestamp = 0;

        if(appWindow.fiatApiCurrencySymbol() !== "USD"){
            if(!persistentSettings.fiatRatesConsentGiven){
                appWindow.fiatApiError("exchange rate provider consent not given for non-USD currency");
                return;
            }

            if(Date.now() - appWindow.fiatRatesTimestamp > appWindow.fiatRatesMaxAge)
                network.getJSON(appWindow.fiatRatesAPI, fiatApiRatesReceived);

            const date7d = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString().slice(0, 10);
            if (appWindow.fiatRates7dDate !== date7d)
                network.getJSON("https://api.frankfurter.dev/v1/" + date7d + "?base=USD", fiatApiRates7dReceived);
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
        return (amount * ticker).toFixed(2);
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
        if (persistentSettings.fiatPriceCurrency === "xmrusd") {
            persistentSettings.fiatPriceCurrency = persistentSettings.fiatPriceCurrencyOther;
        } else {
            persistentSettings.fiatPriceCurrencyOther = persistentSettings.fiatPriceCurrency;
            persistentSettings.fiatPriceCurrency = "xmrusd";
        }

        if (persistentSettings.fiatPriceEnabled) {
            appWindow.fiatApiUpdatePrice();
            appWindow.fiatApiRefresh();
        }
    }

    function fiatApiError(msg){
        console.log("fiatPriceError: " + msg);
    }

    Component.onCompleted: {
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

        // NymVPN was on last time, or is required: make sure its SOCKS5 proxy is running again
        if (persistentSettings.nymVpnEnabled || persistentSettings.nymVpnRequired)
            nymVpnConnect();

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

        // Matrix FX
        property bool fxMatrixRain: true
        property bool fxBootScreen: true
        property bool fxPageGlitch: true
        property bool fxSounds: false
        property bool askPasswordBeforeSending: true
        property bool lockOnUserInActivity: true
        property int walletMode: 2
        property int lockOnUserInActivityInterval: 10  // minutes
        property bool blackTheme: MoneroComponents.Style.blackTheme
        property bool checkForUpdates: true
        property bool autosave: true
        property int autosaveMinutes: 10
        property bool pruneBlockchain: false

        property bool fiatPriceEnabled: false
        property string priceAlerts: "[]"       // Trading data alerts: [{ pair, above, price, fired, firedAt, firedPrice }]
        property bool tradingShowBalance: true   // Trading data: chart of the wallet's value
        property bool fiatPriceToggle: false
        property string fiatPriceCurrencyOther: "xmreur" // restored when leaving USD
        property string fiatPriceProvider: "kraken"
        property string fiatPriceCurrency: "xmrusd"
        property bool fiatRatesConsentGiven: false

        property string proxyAddress: "127.0.0.1:9050"
        property bool proxyEnabled: isTails
        property bool nymVpnEnabled: false
        property bool nymVpnRequired: false   // "Nym required": nothing leaves the app outside NymVPN
        readonly property string nymVpnSocksAddress: oshelper.nymClient.address
        property bool nymVpnPrevProxyEnabled: false
        property string nymVpnPrevProxyAddress: "127.0.0.1:9050"
        // Security page
        property bool extremePrivacy: false        // only through an approved route (NymVPN or the SOCKS5 proxy)
        property string extremePrivacyPrev: "{}"   // settings to restore when it is turned off
        property string securityNodes: "[]"        // node manager: [{ address, favorite, mine, samples: [{ t, ok, ms, height, version }] }]
        property string securityBackups: "{}"
        property bool hideUsedAddresses: false     // Receive: hide subaddresses that already received a transaction      // per wallet path: { seed, keys } (dates of the confirmations / copies)
        function getProxyAddress() {
            if (extremePrivacy) {
                // extreme privacy: an approved route or nothing at all
                var route = appWindow.approvedRoute();
                return route !== "" ? "socks5://" + route : "socks5://127.0.0.1:0";
            }
            if (nymVpnRequired) {
                // only through NymVPN; while it is not up every proxied request fails
                return appWindow.nymVpnProxyUp() ? "socks5://" + nymVpnSocksAddress : "socks5://127.0.0.1:0";
            }
            if (appWindow.nymVpnRestarting) {
                return "socks5://127.0.0.1:0";   // NymVPN restarting: block everything
            }
            if (nymVpnEnabled) {
                return appWindow.nymVpnProxyUp() ? "socks5://" + nymVpnSocksAddress : "socks5://127.0.0.1:0";
            }
            if (socksProxyFlagSet) {
                return socksProxyFlag == "" ? "" : "socks5://" + socksProxyFlag;
            }
            if (!proxyEnabled) {
                return "";
            }
            if (proxyAddress == "") {
                return "socks5://127.0.0.1:0";
            }
            return "socks5://" + proxyAddress;
        }
        function getWalletProxyAddress() {
            if (!useRemoteNode) {
                return "";
            } else {
                const remoteAddress = remoteNodesModel.currentRemoteNode().address;
                // skip proxy when using localhost remote node
                if (/^(127\.0\.0\.1|localhost):[0-9]+$/i.test(remoteAddress)) {
                    return "";
                } else {
                    return getProxyAddress();
                }
            }
        }

        Component.onCompleted: {
            MoneroComponents.Style.blackTheme = persistentSettings.blackTheme

            if (!appWindow.fiatPriceAPIs.hasOwnProperty(fiatPriceProvider)) {
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

        signal store()

        function initialize() {
            try {
                const remoteNodes = JSON.parse(persistentSettings.remoteNodesSerialized);
                for (var index = 0; index < remoteNodes.nodes.length; ++index) {
                    const remoteNode = remoteNodes.nodes[index];
                    remoteNodesModel.append(remoteNode);
                }
                selected = remoteNodes.selected % remoteNodesModel.count || 0;
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
        confirmButton.rightIcon: viewOnly ? "" : "qrc:///images/rightArrow.png"
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

    NymAccountDialog {
        id: nymAccountDialog
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
        width: appWindow.width / 2
        height: deviceMode ? Math.max(appWindow.height / 2.66, contentHeight + 70) : appWindow.height / 2.66
        x: (appWindow.width - width) / 2
        y: (appWindow.height - height) / 2
        messageText: qsTr("Please wait...") + translationManager.emptyString
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
                anchors.bottom: parent.bottom
                visible: rootItem.state == "normal" && middlePanel.state != "Merchant"
                currentAccountIndex: currentWallet ? currentWallet.currentSubaddressAccount : 0
                currentAccountLabel: {
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
                    middlePanel.state = "Receive";
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
                anchors.bottom: parent.bottom
                anchors.left: leftPanel.visible ? leftPanel.right : parent.left
                anchors.right: parent.right
                state: "Transfer"
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
                image: "qrc:///images/resize.png"
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
                source: "qrc:///images/tip.png"
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
        if (isQuitting)
            return;
        isQuitting = true;
        console.log("close accepted");
        // closing never waits more than 20 s (slow requests through the Nym mixnet)
        oshelper.armShutdownWatchdog(20);
        // Stop only the wallet-owned helper, never the official VPN service.
        oshelper.nymClient.stop();
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
