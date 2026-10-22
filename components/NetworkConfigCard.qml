// Wallet+: "Network configuration" card (which anonymous network the wallet, the node sync and the transactions
// use, plus the node address lists). Shared by Settings → Node / Network and the welcome page.
// There is no "normal network" choice: while the chosen network is not connected, that traffic waits.

import QtQuick
import FontAwesome
import QtQuick.Layouts
import QtQuick.Controls

import "../components" as MoneroComponents

ColumnLayout {
    id: networkConfigCard
    Layout.fillWidth: true
    spacing: 12

    // ---- Network configuration helpers (the "Network configuration" card in the main layout)
    component NetOption: Rectangle {
        id: netOption
        property string label: ""
        property bool selected: false
        property bool available: true
        property string unavailableTip: ""
        signal picked()
        readonly property bool dark: MoneroComponents.Style.blackTheme
        readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
        property var icons: []              // networks drawn before the label ("Tor + I2P": both)
        implicitWidth: Math.max(64, optionRow.implicitWidth + 28)
        implicitHeight: 30
        radius: 3
        color: selected ? Qt.rgba(accent.r, accent.g, accent.b, 0.22) : (optionMouse.containsMouse && available ? (dark ? "#14FFFFFF" : "#14000000") : "transparent")
        border.width: 1
        border.color: selected ? accent : Qt.rgba(MoneroComponents.Style.defaultFontColor.r, MoneroComponents.Style.defaultFontColor.g, MoneroComponents.Style.defaultFontColor.b, 0.25)
        opacity: available ? 1 : 0.4
        Row {
            id: optionRow
            anchors.centerIn: parent
            spacing: 7
            Repeater {
                model: netOption.icons
                delegate: MoneroComponents.NetIcon {
                    net: modelData
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        MoneroComponents.TextPlain {
            id: optionText
            anchors.verticalCenter: parent.verticalCenter
            text: netOption.label
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 13
            font.bold: netOption.selected
            color: MoneroComponents.Style.defaultFontColor
            themeTransition: false
        }
        }
        MouseArea {
            id: optionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: netOption.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (netOption.available && !netOption.selected) netOption.picked()
        }
        MoneroComponents.Tooltip {
            id: optionTip
            text: netOption.unavailableTip
        }
        HoverHandler {
            onHoveredChanged: if (!netOption.available && netOption.unavailableTip !== "") { if (hovered) optionTip.tooltipPopup.open(); else optionTip.tooltipPopup.close(); }
        }
    }

    component NetChoice: RowLayout {
        id: netChoice
        property string title: ""
        property string detail: ""
        property string kind: ""            // wallet | sync | tx
        property string value: ""
        property var options: []            // [{ net, label, available, tip }]
        property string warning: ""         // shown in red under the detail
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: netChoice.title
                font.pixelSize: 14
                font.bold: true
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: netChoice.detail
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                visible: netChoice.warning !== ""
                wrapMode: Text.WordWrap
                text: netChoice.warning
                font.pixelSize: 12
                color: "#FF5C5C"
                themeTransition: false
            }
        }
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
            Repeater {
                model: netChoice.options
                delegate: NetOption {
                    label: modelData.label
                    icons: modelData.net === "both" ? ["tor", "i2p"] : [modelData.net]
                    selected: netChoice.value === modelData.net
                    available: modelData.available !== false
                    unavailableTip: modelData.tip || ""
                    onPicked: appWindow.setNetwork(netChoice.kind, modelData.net)
                }
            }
        }
    }

        MoneroComponents.CollapsibleCard {
            icon: FontAwesome.networkWired
                title: qsTr("Network configuration") + translationManager.emptyString
            summary: qsTr("Wallet: %1 · Sync: %2 · Transactions: %3")
                         .arg(netLabel(persistentSettings.netWallet)).arg(netLabel(persistentSettings.netSync))
                         .arg(netLabel(persistentSettings.netTx)) + translationManager.emptyString
            checked: persistentSettings.netCardOpen
            onCheckedChanged: persistentSettings.netCardOpen = checked
            // the chosen networks as icons: wallet · sync · transactions
            summaryDelegate: Component {
                Row {
                    spacing: 8
                    Repeater {
                        model: [
                            { label: qsTr("Wallet") + translationManager.emptyString, nets: [persistentSettings.netWallet] },
                            { label: qsTr("Sync") + translationManager.emptyString, nets: [persistentSettings.netSync] },
                            { label: qsTr("Transactions") + translationManager.emptyString,
                              nets: persistentSettings.netTx === "both" ? ["tor", "i2p"] : [persistentSettings.netTx] }
                        ]
                        delegate: Row {
                            spacing: 5
                            MoneroComponents.TextPlain {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (index > 0 ? "·  " : "") + modelData.label
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 12
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                            Repeater {
                                model: modelData.nets
                                delegate: MoneroComponents.NetIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    net: modelData
                                }
                            }
                        }
                    }
                }
            }
            function netLabel(n) { return n === "nym" ? "Nym" : n === "i2p" ? "I2P" : n === "both" ? "Tor + I2P" : "Tor"; }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 16
                spacing: 16

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Every connection is anonymous: choose the network each one goes through. The app never uses your normal connection; while the chosen network is not connected, that traffic waits.") + translationManager.emptyString
                    font.pixelSize: 13
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                NetChoice {
                    kind: "wallet"
                    value: persistentSettings.netWallet
                    title: qsTr("Wallet connections") + translationManager.emptyString
                    detail: qsTr("Markets, swaps, prices, updates and the remote node.") + translationManager.emptyString
                    options: [{ net: "tor", label: "Tor" }, { net: "nym", label: "Nym" }]
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: MoneroComponents.Style.dividerColor; opacity: MoneroComponents.Style.dividerOpacity }

                MoneroComponents.TextPlain {
                    text: qsTr("Local node connections") + translationManager.emptyString
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                    font.capitalization: Font.AllUppercase
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                NetChoice {
                    kind: "sync"
                    value: persistentSettings.netSync
                    title: qsTr("Sync the blockchain") + translationManager.emptyString
                    detail: qsTr("Peers and blocks of monerod (--proxy, --p2p-bind-ip 127.0.0.1: it does not listen on your network).") + translationManager.emptyString
                    options: [{ net: "tor", label: "Tor" }, { net: "nym", label: "Nym" },
                              { net: "i2p", label: "I2P", available: false,
                                tip: qsTr("The local node cannot sync the blockchain over I2P: it is a closed network without exits to normal Monero nodes, and monerod does not download blocks from .i2p peers. You can use I2P with a remote node: add a .i2p node in Node > Remote node.") + translationManager.emptyString }]
                }

                NetChoice {
                    kind: "tx"
                    value: persistentSettings.netTx
                    title: qsTr("Send transactions") + translationManager.emptyString
                    detail: qsTr("Your own transactions only go to hidden-service peers (--tx-proxy), padded (--pad-transactions). Tor + I2P uses both networks at once.") + translationManager.emptyString
                    options: [{ net: "tor", label: "Tor" }, { net: "i2p", label: "I2P" }, { net: "both", label: "Tor + I2P" }]
                }

                // folding header: the four address lists below open and close together
                Item {
                    id: nodeAddrHeader
                    readonly property bool open: persistentSettings.nodeAddrOpen
                    Layout.topMargin: 4
                    Layout.fillWidth: true
                    implicitHeight: nodeAddrRow.implicitHeight + 8
                RowLayout {
                    id: nodeAddrRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Canvas {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        rotation: nodeAddrHeader.open ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        property color c: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
                        onCChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = c;
                            ctx.lineWidth = 1.8;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.beginPath();
                            ctx.moveTo(3.5, 1.5); ctx.lineTo(8.5, 6); ctx.lineTo(3.5, 10.5);
                            ctx.stroke();
                        }
                    }
                    MoneroComponents.TextPlain {
                        text: qsTr("Node addresses") + translationManager.emptyString
                        font.pixelSize: 14
                        font.bold: true
                        font.letterSpacing: 1
                        font.capitalization: Font.AllUppercase
                        color: nodeAddrMouse.containsMouse || nodeAddrHeader.open ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: qsTr("%1 exclusive · %2 priority · %3 peers · %4 remote")
                                  .arg(appWindow.exclusiveNodes.length).arg(appWindow.anonPeers.length)
                                  .arg(appWindow.extraPeers.length).arg(remoteNodesModel.count) + translationManager.emptyString
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 12
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                }
                MouseArea {
                    id: nodeAddrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: persistentSettings.nodeAddrOpen = !persistentSettings.nodeAddrOpen
                }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: persistentSettings.nodeAddrOpen
                    spacing: 16

                MoneroComponents.NodeAddressList {
                    title: qsTr("Exclusive nodes") + translationManager.emptyString
                    flag: "--add-exclusive-node"
                    help: qsTr("monerod connects only to these nodes and to no other peer.") + translationManager.emptyString
                    warning: model.length > 0 ? qsTr("Only these nodes give blocks: if they are .onion / .i2p or do not answer, the node does not sync.") + translationManager.emptyString : ""
                    model: appWindow.exclusiveNodes
                    isActive: appWindow.nodeAddressActive
                    addRequested: function(a) { return appWindow.addNodeAddress("exclusive", a); }
                    removeRequested: function(a) { appWindow.removeNodeAddress("exclusive", a); }
                }

                MoneroComponents.NodeAddressList {
                    title: qsTr("Priority nodes") + translationManager.emptyString
                    flag: "--add-priority-node"
                    help: qsTr("monerod always tries to stay connected to these nodes, plus the usual peers. The P2P peers added in TOR / I2P are here too.") + translationManager.emptyString
                    model: appWindow.anonPeers
                    isActive: appWindow.nodeAddressActive
                    addRequested: function(a) { return appWindow.addNodeAddress("priority", a); }
                    removeRequested: function(a) { appWindow.removeNodeAddress("priority", a); }
                }

                MoneroComponents.NodeAddressList {
                    title: qsTr("Peers") + translationManager.emptyString
                    flag: "--add-peer"
                    help: qsTr("Added to the peer list monerod picks from; it may or may not connect to them.") + translationManager.emptyString
                    model: appWindow.extraPeers
                    isActive: appWindow.nodeAddressActive
                    addRequested: function(a) { return appWindow.addNodeAddress("peer", a); }
                    removeRequested: function(a) { appWindow.removeNodeAddress("peer", a); }
                }

                // --daemon-address is the wallet's flag (monero-wallet-cli / wallet-rpc): the remote node list
                MoneroComponents.NodeAddressList {
                    id: daemonAddressList
                    title: qsTr("Remote nodes of the wallet") + translationManager.emptyString
                    flag: "--daemon-address"
                    help: qsTr("Not a monerod flag: it is the node the wallet connects to in remote mode. The same list as Node > Remote node.") + translationManager.emptyString
                    property int revision: 0
                    model: {
                        revision;
                        var l = [];
                        for (var i = 0; i < remoteNodesModel.count; i++) l.push(remoteNodesModel.get(i).address);
                        return l;
                    }
                    addRequested: function(a) {
                        a = (a || "").trim().replace(/\/+$/, "");
                        if (!/^(?:https?:\/\/)?(?:[A-Za-z0-9.-]+|\[[0-9A-Fa-f:]+\]):\d{1,5}$/.test(a))
                            return qsTr("Write host:port, for example abc…xyz.onion:18081 or node.example.org:18089") + translationManager.emptyString;
                        remoteNodesModel.appendIfNotExists({ address: a, username: "", password: "", trusted: false });
                        revision++;
                        return "";
                    }
                    removeRequested: function(a) {
                        for (var i = 0; i < remoteNodesModel.count; i++)
                            if (remoteNodesModel.get(i).address === a) { remoteNodesModel.removeSelectNextIfNeeded(i); break; }
                        revision++;
                    }
                    Connections {
                        target: remoteNodesModel
                        function onCountChanged() { daemonAddressList.revision++; }
                    }
                }
                }
            }
        }
    }
