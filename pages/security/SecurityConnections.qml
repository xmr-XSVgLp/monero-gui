import QtQuick
import QtQuick.Layouts

import "../../components" as MoneroComponents

// Security > Connections: every outside service the app talks to, the route each one takes, the local node's
// peers and what a remote node can learn.
ColumnLayout {
    id: tab
    spacing: 16

    readonly property var monerodRoute: {
        if (persistentSettings.extremePrivacy) {
            var r = appWindow.approvedRoute();
            return r !== "" ? { text: qsTr("through %1 (extreme privacy)").arg(r) + translationManager.emptyString, color: securityPage.goodColor }
                            : { text: qsTr("blocked until there is an approved route") + translationManager.emptyString, color: securityPage.badColor };
        }
        if (persistentSettings.netSync === "nym")
            return { text: qsTr("through NymVPN (--proxy)") + translationManager.emptyString, color: securityPage.goodColor };
        if (persistentSettings.netSync === "i2p")
            return { text: qsTr("through I2P (--proxy): it does not sync blocks") + translationManager.emptyString, color: securityPage.warnColor };
        if (persistentSettings.netSync === "tor")
            return { text: qsTr("through Tor (--proxy)") + translationManager.emptyString, color: securityPage.goodColor };
        if ((persistentSettings.daemonFlags || "").indexOf("--proxy") >= 0)
            return { text: qsTr("through the --proxy of the startup flags") + translationManager.emptyString, color: securityPage.goodColor };
        return { text: qsTr("direct, with your real IP") + translationManager.emptyString, color: securityPage.warnColor };
    }

    function appRoute(active) {
        if (!active)
            return { text: qsTr("off") + translationManager.emptyString, color: securityPage.offColor };
        return { text: securityPage.route.text, color: securityPage.route.color };
    }

    readonly property var services: {
        var list = [];
        var remote = persistentSettings.useRemoteNode;
        var app = appRoute(true);
        if (!remote) {
            list.push({ name: qsTr("Local node (monerod)") + translationManager.emptyString,
                        hosts: "127.0.0.1:" + appWindow.localDaemonAddress.split(":").pop(),
                        when: qsTr("all the time; the wallet talks to it inside this computer") + translationManager.emptyString,
                        via: { text: qsTr("does not leave the computer") + translationManager.emptyString, color: securityPage.goodColor } });
            list.push({ name: qsTr("Peers of the local node") + translationManager.emptyString,
                        hosts: qsTr("other Monero nodes, port 18080") + translationManager.emptyString,
                        when: qsTr("while monerod runs: blocks, transactions and peer lists") + translationManager.emptyString,
                        via: monerodRoute });
        } else {
            var node = remoteNodesModel.currentRemoteNode();
            var wp = persistentSettings.getWalletProxyAddress();
            list.push({ name: qsTr("Remote node") + translationManager.emptyString,
                        hosts: node.address || "—",
                        when: qsTr("all the time: sync, balances, sending") + translationManager.emptyString,
                        via: wp === "" ? (/^(127\.0\.0\.1|localhost):/i.test(node.address) ? { text: qsTr("does not leave the computer") + translationManager.emptyString, color: securityPage.goodColor }
                                                                                    : { text: qsTr("Direct: your real IP") + translationManager.emptyString, color: securityPage.badColor })
                                        : wp === "socks5://127.0.0.1:0" ? { text: qsTr("Blocked: nothing goes out") + translationManager.emptyString, color: securityPage.badColor }
                                        : app });
        }
        var prices = persistentSettings.fiatPriceEnabled;
        var provider = persistentSettings.fiatPriceProvider === "coinpaprika" ? "api.coinpaprika.com" : "api.kraken.com";
        list.push({ name: qsTr("XMR price") + translationManager.emptyString,
                    hosts: provider + ", api.frankfurter.dev, api-beta.wagyu.xyz",
                    when: qsTr("every few minutes while price conversion is on") + translationManager.emptyString,
                    via: appRoute(prices) });
        list.push({ name: qsTr("Markets") + translationManager.emptyString,
                    hosts: "api.coingecko.com",
                    when: qsTr("when the page opens and every 15 minutes, with price conversion on") + translationManager.emptyString,
                    via: appRoute(prices) });
        list.push({ name: qsTr("Swaps") + translationManager.emptyString,
                    hosts: "api-beta.wagyu.xyz, api.nonkyc.io, api.changenow.io",
                    when: qsTr("only when the Swaps page opens or refreshes") + translationManager.emptyString,
                    via: appRoute(prices) });
        list.push({ name: qsTr("Update check") + translationManager.emptyString,
                    hosts: "updates.moneropulse.org (DNS), downloads.getmonero.org",
                    when: qsTr("at start and every hour. The DNS lookup is made by Monero's resolver and does not use the SOCKS5 proxy.") + translationManager.emptyString,
                    via: persistentSettings.checkForUpdates ? { text: qsTr("DNS outside the proxy") + translationManager.emptyString, color: securityPage.warnColor } : appRoute(false) });
        list.push({ name: "NymVPN",
                    hosts: "nymvpn.com, ipwho.is, ipinfo.io, api.ipify.org",
                    when: qsTr("when Nym connects: gateway names and the exit IP") + translationManager.emptyString,
                    via: persistentSettings.nymVpnEnabled ? app : appRoute(false) });
        list.push({ name: qsTr("Connection check") + translationManager.emptyString,
                    hosts: "speed.cloudflare.com, ipwho.is, ipinfo.io, check.torproject.org, api.ipify.org, " + qsTr("4 Monero seed nodes") + translationManager.emptyString,
                    when: qsTr("when you press the button, and 20 seconds after Nym connects") + translationManager.emptyString,
                    via: app });
        list.push({ name: qsTr("Node manager") + translationManager.emptyString,
                    hosts: qsTr("the nodes in the list") + translationManager.emptyString,
                    when: qsTr("only when you measure or rotate nodes") + translationManager.emptyString,
                    via: app });
        list.push({ name: qsTr("Links in Wallet+") + translationManager.emptyString,
                    hosts: qsTr("your browser") + translationManager.emptyString,
                    when: qsTr("only if you click one; they open in the browser, outside the app and outside Nym") + translationManager.emptyString,
                    via: { text: qsTr("outside the app") + translationManager.emptyString, color: securityPage.warnColor } });
        list.push({ name: "Trezor",
                    hosts: "USB / Bluetooth",
                    when: qsTr("a local connection to the device; it does not use the internet") + translationManager.emptyString,
                    via: { text: qsTr("does not leave the computer") + translationManager.emptyString, color: securityPage.goodColor } });
        return list;
    }

    // ---- peers of the local node ----
    MoneroComponents.SectionTitle {
        Layout.fillWidth: true
        visible: !persistentSettings.useRemoteNode
        text: qsTr("External IPs of the local node") + translationManager.emptyString
    }

    MoneroComponents.SettingsCard {
        visible: !persistentSettings.useRemoteNode
        padding: 18
        spacing: 10

        MoneroComponents.NodePeers {
            Layout.fillWidth: true
        }
    }

    MoneroComponents.SectionTitle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("Connections of the app") + translationManager.emptyString
    }

    MoneroComponents.TextPlain {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: qsTr("Every service this wallet connects to, when it does and which way it goes out. The app's own requests now leave:") + translationManager.emptyString
              + " <font color=\"" + securityPage.route.color + "\">" + securityPage.route.text + "</font>"
        textFormat: Text.StyledText
    }

    MoneroComponents.SettingsCard {
        padding: 18
        spacing: 14
        Repeater {
            model: tab.services
            delegate: SecRow {
                title: modelData.name
                tag: modelData.via.text
                dot: modelData.via.color
                detail: "<font face=\"" + MoneroComponents.Style.fontMonoRegular.name + "\">" + modelData.hosts + "</font><br>" + modelData.when
            }
        }
    }

    // ---- what a remote node can learn ----
    MoneroComponents.SectionTitle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("What the nodes can learn about you") + translationManager.emptyString
    }

    MoneroComponents.SettingsCard {
        id: learnCard
        padding: 18
        spacing: 12

        readonly property string nodeAddress: remoteNodesModel.currentRemoteNode().address || ""
        readonly property bool plainHttp: persistentSettings.useRemoteNode && !/^https:\/\//i.test(nodeAddress) && !/:443$/.test(nodeAddress)
                                          && !/^(127\.0\.0\.1|localhost):/i.test(nodeAddress)

        SecRow {
            visible: !persistentSettings.useRemoteNode
            dot: securityPage.goodColor
            title: qsTr("You use your own node") + translationManager.emptyString
            detail: qsTr("No remote node sees the wallet's requests: balances, history and outputs are read from your own copy of the blockchain. Peers only see the IP monerod leaves with and the transactions it relays, mixed by Dandelion++.") + translationManager.emptyString
        }
        SecRow {
            visible: persistentSettings.useRemoteNode
            dot: securityPage.route.kind === "direct" ? securityPage.badColor : securityPage.goodColor
            title: qsTr("Your IP") + translationManager.emptyString
            detail: securityPage.route.kind === "direct"
                    ? qsTr("The node sees your real IP and can link it to everything below.") + translationManager.emptyString
                    : qsTr("The node sees the IP of the proxy or the Nym exit, not yours.") + translationManager.emptyString
        }
        SecRow {
            visible: persistentSettings.useRemoteNode
            dot: securityPage.warnColor
            title: qsTr("When you use the wallet") + translationManager.emptyString
            detail: qsTr("When the wallet is open, how long it stays connected and from which block it syncs, which hints at the wallet's age.") + translationManager.emptyString
        }
        SecRow {
            visible: persistentSettings.useRemoteNode
            dot: securityPage.warnColor
            title: qsTr("The transactions you send") + translationManager.emptyString
            detail: qsTr("The node receives your transaction first and knows it came from this connection, and which outputs were asked for as ring decoys.") + translationManager.emptyString
        }
        SecRow {
            visible: learnCard.plainHttp
            dot: securityPage.warnColor
            title: qsTr("Unencrypted connection") + translationManager.emptyString
            detail: qsTr("This node is reached over plain HTTP: whoever is in the middle (including the proxy or Nym exit) can see the same as the node.") + translationManager.emptyString
        }
        SecRow {
            dot: securityPage.goodColor
            title: qsTr("What they never see") + translationManager.emptyString
            detail: qsTr("Your keys, your seed, your balance or your addresses: blocks are scanned on this computer and the keys never leave it (or the Trezor).") + translationManager.emptyString
        }
    }
}
