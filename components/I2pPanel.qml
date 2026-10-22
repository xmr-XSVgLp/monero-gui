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
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import "../components" as MoneroComponents

// I2P NETWORK panel (Settings > Node / Network, below TOR NETWORK): the app's own bundled i2pd.
// I2P has no exits to the normal internet: it is used to reach .b32.i2p remote nodes and by the
// local node to send its transactions only to .i2p peers (monerod --tx-proxy i2p). It works next
// to Tor or Nym, which keep carrying the rest of the traffic.
Item {
    id: i2pPanel
    property bool checked: false
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color requiredColor: dark ? "#FF4D4D" : "#C62828"
    readonly property color requiredTextColor: dark ? "#E08A8A" : "#B04848"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    readonly property color i2pBlue: dark ? "#5EC8FF" : "#1F6FA8"
    readonly property bool hovered: headerMouse.containsMouse
    readonly property var client: oshelper.i2pClient
    readonly property string state_: persistentSettings.i2pEnabled ? client.state : "off"
    readonly property bool active: state_ === "connected"
    readonly property bool waitingTor: persistentSettings.i2pEnabled && appWindow.i2pWaitingTor
    readonly property bool working: state_ === "starting" || waitingTor
    readonly property bool installed: client.available()

    // .b32.i2p remote nodes: candidates from the xmr.ditatompel.com and monero.fail monitors (asked
    // through the app's normal route), then each one is asked for /get_info through I2P: only the
    // nodes that answer and are at the tip are listed, fastest first.
    // few monitors can check I2P nodes, so they are often marked down there: ask for all of them
    // (not only the "available" ones) and let the probe through our own I2P decide
    readonly property var i2pSources: [
        "https://xmr.ditatompel.com/api/v1/nodes?page=1&limit=100&nettype=mainnet&protocol=i2p",
        "https://monero.fail/api/v1/nodes/?type=i2p&healthy=all&per_page=100",
        "https://monero.fail/nodes.json"
    ]
    property var i2pNodes: []
    property bool nodesLoading: false
    property string nodesError: ""
    property int nodesGen: 0
    property int nodesChecked: 0
    property int nodesTotal: 0

    // "abc….b32.i2p:18089" from any of the shapes the monitors return
    function i2pAddress(v, port) {
        var h = String(v || "").trim().replace(/^[a-z]+:\/\//i, "").replace(/\/.*$/, "");
        if (!/^[a-z2-7]{52,}\.b32\.i2p(:\d+)?$/i.test(h)) return "";
        return /:\d+$/.test(h) ? h : h + ":" + (port || 18081);
    }

    function i2pCandidates(url, j) {
        var out = [];
        if (url.indexOf("monero.fail/api") >= 0) {
            var nodes = (j && j.nodes) || [];
            for (var n = 0; n < nodes.length; ++n)
                if (nodes[n].crypto !== "wownero") out.push(i2pAddress(nodes[n].url));
            return out;
        }
        if (url.indexOf("monero.fail") >= 0) {
            var list = (j && j.monero && j.monero.i2p) || [];
            for (var i = 0; i < list.length; ++i) out.push(i2pAddress(list[i]));
            return out;
        }
        var d = j && j.data !== undefined ? j.data : j;
        var rows = Array.isArray(d) ? d : (d && (d.items || d.rows || d.nodes)) || [];
        for (var k = 0; k < rows.length; ++k) {
            var r = rows[k];
            if ((r.nettype || "mainnet") !== "mainnet") continue;
            out.push(i2pAddress(r.hostname || r.host, r.port));
        }
        return out;
    }

    function loadI2pNodes() {
        if (!active) return;
        nodesGen++;
        var gen = nodesGen;
        nodesLoading = true;
        nodesError = "";
        nodesChecked = 0;
        nodesTotal = 0;
        var seen = {}, candidates = [], pending = i2pSources.length, failed = [];
        i2pSources.forEach(function(url) {
            network.getJSON(url, function(u, resp, error) {
                if (gen !== i2pPanel.nodesGen) return;
                var got = [], host = url.split("/")[2];
                try {
                    got = i2pCandidates(url, JSON.parse(resp));
                    if (got.length === 0) failed.push(qsTr("%1: no .i2p nodes listed").arg(host) + translationManager.emptyString);
                } catch (e) {
                    failed.push(qsTr("%1: could not download (%2)").arg(host).arg(error || qsTr("unexpected answer")) + translationManager.emptyString);
                }
                for (var i = 0; i < got.length; ++i)
                    if (got[i] !== "" && !seen[got[i]]) { seen[got[i]] = true; candidates.push(got[i]); }
                if (--pending === 0) probeNodes(gen, candidates, failed);
            });
        });
    }

    // /get_info on every candidate through I2P, 4 at a time (at most 40); a first I2P lookup is slow
    function probeNodes(gen, candidates, failed) {
        candidates = candidates.sort(function() { return Math.random() - 0.5; }).slice(0, 40);
        nodesTotal = candidates.length;
        if (candidates.length === 0) {
            nodesLoading = false;
            nodesError = qsTr("No .i2p nodes could be read from the monitors: %1.").arg(failed.join(" · ")) + translationManager.emptyString;
            return;
        }
        var results = [], next = 0, running = 0;
        // the list fills in while the probe runs: every node that answers shows up right away
        function publish() {
            var top = 0;
            for (var i = 0; i < results.length; ++i) top = Math.max(top, results[i].height);
            var good = results.filter(function(r) { return top - r.height <= 3; });
            good.sort(function(a, b) { return a.ms - b.ms; });
            // the saved list stays on screen until the first node of the new search answers
            if (good.length > 0) i2pNodes = good.slice(0, 12);
            return good;
        }
        function finish() {
            var good = publish();
            nodesLoading = false;
            saveNodes(i2pNodes);
            if (good.length === 0)
                nodesError = qsTr("None of the %1 .i2p nodes answered through I2P. Tunnels take a while after connecting: try again in a few minutes.").arg(candidates.length) + translationManager.emptyString;
        }
        function launch() {
            while (running < 4 && next < candidates.length) {
                var address = candidates[next++];
                running++;
                (function(address) {
                    oshelper.nodeRpc(address, oshelper.i2pClient.address, "/get_info", "", 60000, function(ok, ms, body, error) {
                        if (gen !== i2pPanel.nodesGen) return;
                        running--;
                        nodesChecked++;
                        if (ok) {
                            try {
                                var info = JSON.parse(body);
                                if (info.status === "OK" && !info.offline && info.nettype !== "testnet" && info.nettype !== "stagenet"
                                        && (info.synchronized === true || (info.target_height || 0) <= (info.height || 0)))
                                    { results.push({ address: address, height: info.height || 0, ms: ms }); publish(); }
                            } catch (e) {}
                        }
                        if (next < candidates.length) launch();
                        else if (running === 0) finish();
                    });
                })(address);
            }
        }
        launch();
    }

    // P2P side of a hidden-service node (docs/ANONYMITY_NETWORKS.md): the monitors list its RPC address;
    // its P2P port for --tx-proxy is looked for with a Monero handshake through the proxy, then it is
    // added to the local node as --add-priority-node (no --add-exclusive-node: that would stop the sync)
    property var p2pState: ({})   // address -> "probing" | "added" | error text
    function addP2p(address) {
        var host = address.replace(/:\d+$/, "");
        var st = Object.assign({}, p2pState); st[address] = "probing"; p2pState = st;
        oshelper.nodeP2pProbe(host, oshelper.i2pClient.address, [18080, 18085, 18083, 18084], 90000, function(json) {
            var r = {};
            try { r = JSON.parse(json); } catch (e) {}
            var st2 = Object.assign({}, i2pPanel.p2pState);
            if (r.ok) {
                appWindow.addAnonPeer(host + ":" + r.port);
                st2[address] = "added";
            } else {
                st2[address] = qsTr("No Monero P2P port answered (%1)").arg(r.error || "?") + translationManager.emptyString;
            }
            i2pPanel.p2pState = st2;
        });
    }
    readonly property var p2pPeers: appWindow.anonPeers.filter(function(a) { return appWindow.anonPeerNet(a) === "i2p"; })

    function useNode(address) {
        var i = remoteNodesModel.appendIfNotExists({ address: address, username: "", password: "", trusted: false });
        remoteNodesModel.applyRemoteNode(i);
    }

    // a random node among the 5 fastest, not always the first one
    function useBest() {
        if (i2pNodes.length === 0) return;
        var n = Math.min(5, i2pNodes.length);
        useNode(i2pNodes[Math.floor(Math.random() * n)].address);
    }

    // the last good list is kept in ~/Monero/xmr-wallet-plus/nodes/i2p.json, so the app does not search
    // again on every start; a new search runs by itself only when the list is older than a day
    readonly property string nodesFile: {
        if (typeof oshelper === "undefined" || !oshelper.swapsLogPath) return "";
        var p = oshelper.swapsLogPath();
        return p.substring(0, p.lastIndexOf("/")) + "/nodes/i2p.json";
    }
    property double nodesSavedTime: 0
    function loadSavedNodes() {
        if (nodesFile === "") return;
        try {
            var j = JSON.parse(oshelper.readTextFile(nodesFile));
            if (Array.isArray(j.nodes) && j.nodes.length > 0) { i2pNodes = j.nodes; nodesSavedTime = j.time || 0; }
        } catch (e) {}
    }
    function saveNodes(list) {
        if (nodesFile === "" || list.length === 0) return;
        nodesSavedTime = Date.now();
        oshelper.writeTextFile(nodesFile, JSON.stringify({ time: nodesSavedTime, nodes: list }, null, 1));
    }
    Component.onCompleted: loadSavedNodes()

    readonly property string currentNode: persistentSettings.useRemoteNode ? remoteNodesModel.currentRemoteNode().address : ""

    onActiveChanged: if (active) { if (i2pNodes.length === 0 || Date.now() - nodesSavedTime > 86400000) loadI2pNodes(); }
                     else { nodesGen++; nodesLoading = false; }

    readonly property color stateColor: active ? (dark ? "#5FD08F" : "#1E8E4E")
                                      : working ? (dark ? "#FFC23D" : "#A86F00")
                                      : state_ === "error" ? (dark ? "#FF5C5C" : "#C62828")
                                      : MoneroComponents.Style.dimmedFontColor
    readonly property string stateText: {
        if (!installed) return qsTr("Not installed") + translationManager.emptyString;
        if (waitingTor) return qsTr("Waiting for Tor…") + translationManager.emptyString;
        switch (state_) {
        case "connected": return qsTr("Connected · I2P") + translationManager.emptyString;
        case "starting": return qsTr("Connecting… %1%").arg(client.progress) + translationManager.emptyString;
        case "error": return qsTr("Error") + translationManager.emptyString;
        default: return appWindow.i2pNeeded ? qsTr("Waiting · I2P for the node required") + translationManager.emptyString
                                                       : qsTr("Off") + translationManager.emptyString;
        }
    }

    implicitHeight: column.implicitHeight

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 10
        accent: i2pPanel.border
        lineOpacity: i2pPanel.checked ? 0.6 : (i2pPanel.hovered ? 0.6 : 0.25)
        fillColor: i2pPanel.dark ? "#0C130E" : "#DADFDB"
        fillOpacity: i2pPanel.dark ? 0.92 : 0.9
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // header row: chevron, garlic, title, state
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            RowLayout {
                z: 1
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Canvas {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    rotation: i2pPanel.checked ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    property color c: i2pPanel.accent
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

                MoneroComponents.NetIcon { net: "i2p" }

                MoneroComponents.TextPlain {
                    text: "I2P NETWORK"
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: i2pPanel.checked || i2pPanel.hovered
                           ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    visible: i2pPanel.active && i2pPanel.client.version !== ""
                    text: "i2pd " + i2pPanel.client.version
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: i2pPanel.stateColor
                    SequentialAnimation on opacity {
                        running: i2pPanel.working
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.opacity = 1
                        NumberAnimation { to: 0.2; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }

                MoneroComponents.TextPlain {
                    text: i2pPanel.stateText
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: i2pPanel.active ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: i2pPanel.checked = !i2pPanel.checked
            }
        }

        Rectangle {
            visible: i2pPanel.checked
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 1
            color: i2pPanel.accent
            opacity: 0.3
        }

        ColumnLayout {
            visible: i2pPanel.checked
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.topMargin: 14
            spacing: 12

            // first line: I2P required and the connection buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // what the Network configuration uses this network for (replaces the old "required" option)
                MoneroComponents.TextPlain {
                    Layout.alignment: Qt.AlignVCenter
                    readonly property var uses: appWindow.netUses("i2p")
                    text: (uses.length > 0 ? qsTr("Used for: %1").arg(uses.join(" · ")) : qsTr("Not used by the Network configuration")) + translationManager.emptyString
                    font.pixelSize: 13
                    font.bold: uses.length > 0
                    color: uses.length > 0 ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: !i2pPanel.active && !i2pPanel.working && i2pPanel.installed
                    text: qsTr("Connect") + translationManager.emptyString
                    onClicked: appWindow.i2pConnect()
                }

                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: i2pPanel.active || i2pPanel.working
                    accent: i2pPanel.dark ? "#FF4D4D" : "#C62828"
                    textColor: i2pPanel.dark ? "#FFD6D6" : "#C62828"
                    text: (i2pPanel.working ? qsTr("Cancel") : qsTr("Disconnect")) + translationManager.emptyString
                    onClicked: appWindow.i2pDisconnect()
                }
            }

            MoneroComponents.Label {
                Layout.rightMargin: 24
                text: qsTr("Traffic and privacy · I2P tunnels") + translationManager.emptyString
                fontSize: 13
                tooltipIconVisible: true
                tooltip: [
                    qsTr("The wallet starts its own I2P router (i2pd, SOCKS5 %1, no outproxy). Another I2P router on this Mac is not used or changed.").arg(i2pPanel.client.address),
                    qsTr("Through I2P go the connection to .b32.i2p remote nodes and, when the Network configuration says so, the transactions of the local node (monerod --tx-proxy i2p: they are only sent to .i2p peers, monerod has built-in I2P seed nodes). If the node was running it restarts by itself."),
                    qsTr("I2P has no exits to the normal internet, so it can be on together with Tor or Nym: they keep carrying prices, clearnet nodes and the local node's sync."),
                    qsTr("A new router needs a few minutes to learn the network and build its tunnels. It closes with the app.")
                ].join("<br><br>") + translationManager.emptyString
            }

            MoneroComponents.TextPlain {
                visible: !i2pPanel.installed
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("I2P is not in this build. Install it once with: brew install i2pd, then rebuild the app with compilar-macos.sh (it copies i2pd into the app).") + translationManager.emptyString
                color: i2pPanel.dark ? "#FF5C5C" : "#C62828"
                themeTransition: false
            }

            // startup progress (estimated from the web console: routers known, client tunnels)
            ColumnLayout {
                visible: i2pPanel.working
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: i2pPanel.dark ? "#1A221C" : "#C3CAC5"
                    Rectangle {
                        width: parent.width * Math.max(0.02, i2pPanel.client.progress / 100)
                        height: parent.height
                        radius: 2
                        color: i2pPanel.i2pBlue
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: i2pPanel.waitingTor ? qsTr("I2P starts when Tor is connected (its first routers are fetched through Tor).") + translationManager.emptyString
                                              : i2pPanel.client.progress + "% · " + i2pPanel.client.message
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            // what went wrong
            MoneroComponents.TextPlain {
                visible: i2pPanel.state_ === "error" && i2pPanel.client.message !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i2pPanel.client.message
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                color: i2pPanel.stateColor
                themeTransition: false
            }

            // router status: network, routers, tunnels, success rate
            Rectangle {
                visible: i2pPanel.active || (i2pPanel.working && i2pPanel.client.routers > 0)
                Layout.fillWidth: true
                implicitHeight: statusGrid.implicitHeight + 24
                color: i2pPanel.dark ? "#08FFFFFF" : "#08000000"
                border.width: 1
                border.color: Qt.rgba(i2pPanel.border.r, i2pPanel.border.g, i2pPanel.border.b, 0.15)

                GridLayout {
                    id: statusGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    columns: 4
                    columnSpacing: 18
                    rowSpacing: 4
                    Repeater {
                        model: [
                            [qsTr("Network") + translationManager.emptyString, i2pPanel.client.networkStatus || "—"],
                            [qsTr("Routers") + translationManager.emptyString, String(i2pPanel.client.routers)],
                            [qsTr("Tunnels") + translationManager.emptyString, String(i2pPanel.client.clientTunnels)],
                            [qsTr("Tunnel success") + translationManager.emptyString, i2pPanel.client.successRate + "%"]
                        ]
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            MoneroComponents.TextPlain {
                                text: modelData[0]
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 0.8
                                font.capitalization: Font.AllUppercase
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: modelData[1]
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 14
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                            }
                        }
                    }
                }
            }

            // .b32.i2p remote nodes
            ColumnLayout {
                visible: i2pPanel.active
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    MoneroComponents.Label {
                        Layout.fillWidth: true
                        text: qsTr("Remote .i2p nodes") + translationManager.emptyString
                        fontSize: 13
                        tooltipIconVisible: true
                        tooltip: [
                            qsTr("A remote node with a .b32.i2p address is reached inside the I2P network: neither the node nor your connection sees who you are."),
                            qsTr("Candidates come from the xmr.ditatompel.com and monero.fail monitors. The app then asks each one for /get_info through I2P and only lists those that answer and are at the current height, fastest first."),
                            qsTr("I2P is slower than Tor: the first sync of a wallet takes longer. Like any remote node it learns which blocks and outputs your wallet asks for, never your keys.")
                        ].join("<br><br>") + translationManager.emptyString
                    }
                    MoneroComponents.StandardButton {
                        small: true
                        visible: i2pPanel.i2pNodes.length > 0
                        accent: i2pPanel.i2pBlue
                        text: qsTr("Use a good one") + translationManager.emptyString
                        onClicked: i2pPanel.useBest()
                    }
                    MoneroComponents.StandardButton {
                        small: true
                        text: (i2pPanel.nodesLoading ? (i2pPanel.nodesTotal > 0 ? i2pPanel.nodesChecked + "/" + i2pPanel.nodesTotal + " " : "… ") : "")
                              + qsTr("Find nodes") + translationManager.emptyString
                        onClicked: i2pPanel.loadI2pNodes()
                    }
                }

                MoneroComponents.TextPlain {
                    visible: i2pPanel.nodesError !== "" && !i2pPanel.nodesLoading
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i2pPanel.nodesError
                    font.pixelSize: 12
                    color: i2pPanel.dark ? "#FFC23D" : "#A86F00"
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    visible: i2pPanel.i2pNodes.length > 0 && i2pPanel.nodesSavedTime > 0 && !i2pPanel.nodesLoading
                    Layout.fillWidth: true
                    text: qsTr("Saved list from %1. \"Find nodes\" checks them again.").arg(Qt.formatDateTime(new Date(i2pPanel.nodesSavedTime), "dd/MM hh:mm")) + translationManager.emptyString
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Repeater {
                    model: i2pPanel.i2pNodes
                    delegate: Rectangle {
                        readonly property bool current: i2pPanel.currentNode === modelData.address
                        readonly property string p2p: i2pPanel.p2pState[modelData.address] || ""
                        Layout.fillWidth: true
                        implicitHeight: rowColumn.implicitHeight + 12
                        color: rowHover.hovered ? (i2pPanel.dark ? "#10FFFFFF" : "#10000000") : "transparent"
                        border.width: current ? 1 : 0
                        border.color: i2pPanel.i2pBlue
                        HoverHandler { id: rowHover }
                        ColumnLayout {
                            id: rowColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                    text: modelData.address
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 12
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }
                                MoneroComponents.TextPlain {
                                    text: (modelData.ms / 1000).toFixed(1) + " s · " + modelData.height
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 11
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                                // the user chooses: wallet against it (remote node) or local node peer (P2P)
                                MoneroComponents.TextPlain {
                                    text: current ? qsTr("✓ Remote node") + translationManager.emptyString : qsTr("Remote node") + translationManager.emptyString
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.underline: remoteMouse.containsMouse && !current
                                    color: current ? i2pPanel.i2pBlue : (remoteMouse.containsMouse ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor)
                                    themeTransition: false
                                    MouseArea {
                                        id: remoteMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: i2pPanel.useNode(modelData.address)
                                    }
                                }
                                MoneroComponents.TextPlain {
                                    text: p2p === "probing" ? qsTr("Looking for P2P…") + translationManager.emptyString
                                          : p2p === "added" ? qsTr("✓ P2P peer") + translationManager.emptyString
                                          : qsTr("P2P peer") + translationManager.emptyString
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.underline: p2pMouse.containsMouse && p2p !== "probing" && p2p !== "added"
                                    color: p2p === "added" ? i2pPanel.i2pBlue : (p2pMouse.containsMouse ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor)
                                    themeTransition: false
                                    MouseArea {
                                        id: p2pMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        enabled: p2p !== "probing" && p2p !== "added"
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: i2pPanel.addP2p(modelData.address)
                                    }
                                }
                            }
                            MoneroComponents.TextPlain {
                                visible: p2p !== "" && p2p !== "probing" && p2p !== "added"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: p2p
                                font.pixelSize: 11
                                color: i2pPanel.dark ? "#FFC23D" : "#A86F00"
                                themeTransition: false
                            }
                        }
                    }
                }

                // peers of the local node on this network (--add-priority-node), with a remove button
                MoneroComponents.TextPlain {
                    visible: i2pPanel.p2pPeers.length > 0
                    Layout.topMargin: 6
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("P2P peers of the local node (--add-priority-node). Your own transactions go to them through --tx-proxy; the blocks still come from normal peers.") + translationManager.emptyString
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                Repeater {
                    model: i2pPanel.p2pPeers
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            elide: Text.ElideMiddle
                            text: modelData
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            font.pixelSize: 12
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            Layout.rightMargin: 10
                            text: qsTr("Remove") + translationManager.emptyString
                            font.pixelSize: 12
                            font.bold: true
                            font.underline: removeMouse.containsMouse
                            color: removeMouse.containsMouse ? (i2pPanel.dark ? "#FF5C5C" : "#C62828") : MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                            MouseArea {
                                id: removeMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appWindow.removeAnonPeer(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
