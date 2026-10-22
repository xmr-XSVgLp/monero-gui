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

// TOR NETWORK panel (Settings > Node / Network, below NYM MIXNET): the app's own bundled Tor.
// Connect routes the wallet, price requests and the local node (monerod --proxy) through Tor.
Item {
    id: torPanel
    property bool checked: false
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color requiredColor: dark ? "#FF4D4D" : "#C62828"
    readonly property color requiredTextColor: dark ? "#E08A8A" : "#B04848"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    readonly property color torPurple: dark ? "#B48CFF" : "#6B3FA0"
    readonly property bool hovered: headerMouse.containsMouse
    readonly property var client: oshelper.torClient
    readonly property string state_: persistentSettings.torEnabled ? client.state : "off"
    readonly property bool active: state_ === "connected"
    readonly property bool working: state_ === "starting"
    readonly property bool installed: client.available()

    // exit IP as seen by check.torproject.org (through Tor itself)
    property string exitIp: ""
    property bool exitIsTor: false
    property bool exitLoading: false
    property int exitGen: 0

    function loadExit() {
        if (!active) return;
        exitGen++;
        var gen = exitGen;
        exitLoading = true;
        exitIp = "";
        // always through Tor's own SOCKS port: the app's general proxy can be Nym (Network configuration)
        oshelper.nodeRpc("https://check.torproject.org:443", oshelper.torClient.address, "/api/ip", "", 60000, function(ok, ms, resp, error) {
            if (gen !== torPanel.exitGen) return;
            exitLoading = false;
            try {
                var j = JSON.parse(resp);
                exitIp = j.IP || "";
                exitIsTor = !!j.IsTor;
            } catch (e) {
                exitIp = "";
            }
        });
    }

    // .onion remote nodes (Monero's docs: the wallet reaches a daemon's RPC hidden service through the
    // proxy). monerod cannot sync over hidden services and through Tor exits it syncs very slowly, so
    // with Tor the wallet does better against an onion node. Candidates come from the xmr.ditatompel.com
    // and monero.fail monitors (asked through Tor); each one is then checked here, through Tor, with
    // /get_info: only nodes that answer and are at the tip are listed, fastest first.
    readonly property var onionSources: [
        "https://xmr.ditatompel.com/api/v1/nodes?page=1&limit=100&nettype=mainnet&protocol=tor&status=1&cors=-1",
        "https://monero.fail/nodes.json"
    ]
    property var onionNodes: []
    property bool onionLoading: false
    property string onionError: ""
    property int onionGen: 0
    property int onionChecked: 0
    property int onionTotal: 0

    // "abc.onion:18089" from any of the shapes the monitors return
    function onionAddress(v, port) {
        var h = String(v || "").trim().replace(/^[a-z]+:\/\//i, "").replace(/\/.*$/, "");
        if (!/^[a-z2-7]{56}\.onion(:\d+)?$/i.test(h)) return "";
        return /:\d+$/.test(h) ? h : h + ":" + (port || 18081);
    }

    function onionCandidates(url, j) {
        var out = [];
        if (url.indexOf("monero.fail") >= 0) {
            var list = (j && j.monero && j.monero.onion) || [];
            for (var i = 0; i < list.length; ++i) out.push(onionAddress(list[i]));
            return out;
        }
        var d = j && j.data !== undefined ? j.data : j;
        var rows = Array.isArray(d) ? d : (d && (d.items || d.rows || d.nodes)) || [];
        for (var k = 0; k < rows.length; ++k) {
            var r = rows[k];
            if (r.is_available === false || r.is_available === 0) continue;
            if ((r.nettype || "mainnet") !== "mainnet") continue;
            out.push(onionAddress(r.hostname || r.host, r.port));
        }
        return out;
    }

    function loadOnionNodes() {
        if (!active) return;
        onionGen++;
        var gen = onionGen;
        onionLoading = true;
        onionError = "";
        onionChecked = 0;
        onionTotal = 0;
        var seen = {}, candidates = [], pending = onionSources.length, failed = [];
        onionSources.forEach(function(url) {
            network.getJSON(url, function(u, resp, error) {
                if (gen !== torPanel.onionGen) return;
                var got = [];
                try { got = onionCandidates(url, JSON.parse(resp)); } catch (e) {}
                if (got.length === 0) failed.push(url.split("/")[2]);
                for (var i = 0; i < got.length; ++i)
                    if (got[i] !== "" && !seen[got[i]]) { seen[got[i]] = true; candidates.push(got[i]); }
                if (--pending === 0) probeOnion(gen, candidates, failed);
            });
        });
    }

    // /get_info on every candidate through Tor, 4 at a time (at most 30)
    function probeOnion(gen, candidates, failed) {
        candidates = candidates.sort(function() { return Math.random() - 0.5; }).slice(0, 30);
        onionTotal = candidates.length;
        if (candidates.length === 0) {
            onionLoading = false;
            onionError = qsTr("No .onion nodes could be read from the monitors (%1).").arg(failed.join(", ")) + translationManager.emptyString;
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
            if (good.length > 0) onionNodes = good.slice(0, 12);
            return good;
        }
        function finish() {
            var good = publish();
            onionLoading = false;
            saveNodes(onionNodes);
            if (good.length === 0)
                onionError = qsTr("None of the %1 .onion nodes answered through Tor. Try again in a moment.").arg(candidates.length) + translationManager.emptyString;
        }
        function launch() {
            while (running < 4 && next < candidates.length) {
                var address = candidates[next++];
                running++;
                (function(address) {
                    oshelper.nodeRpc(address, oshelper.torClient.address, "/get_info", "", 30000, function(ok, ms, body, error) {
                        if (gen !== torPanel.onionGen) return;
                        running--;
                        onionChecked++;
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
        oshelper.nodeP2pProbe(host, oshelper.torClient.address, [18083, 18084, 18080], 90000, function(json) {
            var r = {};
            try { r = JSON.parse(json); } catch (e) {}
            var st2 = Object.assign({}, torPanel.p2pState);
            if (r.ok) {
                appWindow.addAnonPeer(host + ":" + r.port);
                st2[address] = "added";
            } else {
                st2[address] = qsTr("No Monero P2P port answered (%1)").arg(r.error || "?") + translationManager.emptyString;
            }
            torPanel.p2pState = st2;
        });
    }
    readonly property var p2pPeers: appWindow.anonPeers.filter(function(a) { return appWindow.anonPeerNet(a) === "tor"; })

    function useNode(address) {
        var i = remoteNodesModel.appendIfNotExists({ address: address, username: "", password: "", trusted: false });
        remoteNodesModel.applyRemoteNode(i);
    }

    // a random node among the 5 fastest, not always the first one
    function useBest() {
        if (onionNodes.length === 0) return;
        var n = Math.min(5, onionNodes.length);
        useNode(onionNodes[Math.floor(Math.random() * n)].address);
    }

    // the last good list is kept in ~/Monero/xmr-wallet-plus/nodes/tor.json, so the app does not search
    // again on every start; a new search runs by itself only when the list is older than a day
    readonly property string nodesFile: {
        if (typeof oshelper === "undefined" || !oshelper.swapsLogPath) return "";
        var p = oshelper.swapsLogPath();
        return p.substring(0, p.lastIndexOf("/")) + "/nodes/tor.json";
    }
    property double nodesSavedTime: 0
    function loadSavedNodes() {
        if (nodesFile === "") return;
        try {
            var j = JSON.parse(oshelper.readTextFile(nodesFile));
            if (Array.isArray(j.nodes) && j.nodes.length > 0) { onionNodes = j.nodes; nodesSavedTime = j.time || 0; }
        } catch (e) {}
    }
    function saveNodes(list) {
        if (nodesFile === "" || list.length === 0) return;
        nodesSavedTime = Date.now();
        oshelper.writeTextFile(nodesFile, JSON.stringify({ time: nodesSavedTime, nodes: list }, null, 1));
    }
    Component.onCompleted: loadSavedNodes()

    readonly property string currentNode: persistentSettings.useRemoteNode ? remoteNodesModel.currentRemoteNode().address : ""

    onActiveChanged: if (active) { loadExit(); if (onionNodes.length === 0 || Date.now() - nodesSavedTime > 86400000) loadOnionNodes(); }
                     else { exitIp = ""; exitGen++; exitLoading = false; onionGen++; onionLoading = false; }
    Connections {
        target: oshelper.torClient
        function onNewIdentityDone(ok, error) { if (ok) exitTimer.restart(); }
    }
    // new circuits are only used by new connections: give Tor a moment before asking again
    Timer { id: exitTimer; interval: 1500; onTriggered: torPanel.loadExit() }

    readonly property color stateColor: active ? (dark ? "#5FD08F" : "#1E8E4E")
                                      : working ? (dark ? "#FFC23D" : "#A86F00")
                                      : state_ === "error" ? (dark ? "#FF5C5C" : "#C62828")
                                      : MoneroComponents.Style.dimmedFontColor
    readonly property string stateText: {
        if (!installed) return qsTr("Not installed") + translationManager.emptyString;
        switch (state_) {
        case "connected": return qsTr("Connected · Tor") + translationManager.emptyString;
        case "starting": return qsTr("Connecting… %1%").arg(client.progress) + translationManager.emptyString;
        case "error": return qsTr("Error") + translationManager.emptyString;
        default: return appWindow.torNeeded ? qsTr("Blocked · Tor required") + translationManager.emptyString
                                                       : qsTr("Off") + translationManager.emptyString;
        }
    }

    implicitHeight: column.implicitHeight

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 10
        accent: torPanel.border
        lineOpacity: torPanel.checked ? 0.6 : (torPanel.hovered ? 0.6 : 0.25)
        fillColor: torPanel.dark ? "#0C130E" : "#DADFDB"
        fillOpacity: torPanel.dark ? 0.92 : 0.9
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // header row: chevron, onion, title, state
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
                    rotation: torPanel.checked ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    property color c: torPanel.accent
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

                MoneroComponents.NetIcon { net: "tor" }

                MoneroComponents.TextPlain {
                    text: "TOR NETWORK"
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: torPanel.checked || torPanel.hovered
                           ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    visible: torPanel.active && torPanel.client.version !== ""
                    text: "Tor " + torPanel.client.version
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: torPanel.stateColor
                    SequentialAnimation on opacity {
                        running: torPanel.working
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.opacity = 1
                        NumberAnimation { to: 0.2; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }

                MoneroComponents.TextPlain {
                    text: torPanel.stateText
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: torPanel.active ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: torPanel.checked = !torPanel.checked
            }
        }

        Rectangle {
            visible: torPanel.checked
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 1
            color: torPanel.accent
            opacity: 0.3
        }

        ColumnLayout {
            visible: torPanel.checked
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.topMargin: 14
            spacing: 12

            // first line: Tor required and the connection buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // what the Network configuration uses this network for (replaces the old "required" option)
                MoneroComponents.TextPlain {
                    Layout.alignment: Qt.AlignVCenter
                    readonly property var uses: appWindow.netUses("tor")
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
                    visible: !torPanel.active && !torPanel.working && torPanel.installed
                    text: qsTr("Connect") + translationManager.emptyString
                    onClicked: appWindow.torConnect()
                }

                // blue: new circuits (NEWNYM), the exit IP changes for new connections
                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: torPanel.active
                    enabled: !appWindow.torNewIdentityBusy
                    accent: torPanel.dark ? "#3D8BFF" : "#1F5FD1"
                    textColor: torPanel.dark ? "#CFE0FF" : "#1F5FD1"
                    text: qsTr("New identity") + translationManager.emptyString
                    onClicked: appWindow.torNewIdentity()
                }

                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: torPanel.active || torPanel.working
                    accent: torPanel.dark ? "#FF4D4D" : "#C62828"
                    textColor: torPanel.dark ? "#FFD6D6" : "#C62828"
                    text: (torPanel.working ? qsTr("Cancel") : qsTr("Disconnect")) + translationManager.emptyString
                    onClicked: appWindow.torDisconnect()
                }
            }

            MoneroComponents.Label {
                Layout.rightMargin: 24
                text: qsTr("Traffic and privacy · Tor circuits") + translationManager.emptyString
                fontSize: 13
                tooltipIconVisible: true
                tooltip: [
                    qsTr("The wallet starts its own Tor (client only, SOCKS5 %1). Tor Browser or another Tor on this Mac are not used or changed.").arg(torPanel.client.address),
                    qsTr("Through Tor go the connections that the Network configuration (top of this page) assigns to Tor: wallet requests, the local node sync and/or its transactions. .onion remote nodes always use Tor. If the node was running it restarts by itself."),
                    qsTr("New identity asks Tor for new circuits: new connections leave through another exit. Tor, Nym and I2P can be on at the same time."),
                    qsTr("Tor closes with the app.")
                ].join("<br><br>") + translationManager.emptyString
            }

            MoneroComponents.TextPlain {
                visible: !torPanel.installed
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Tor is not in this build. Rebuild the app with compilar-macos.sh (it downloads the Tor Expert Bundle) or install it with: brew install tor") + translationManager.emptyString
                color: torPanel.dark ? "#FF5C5C" : "#C62828"
                themeTransition: false
            }

            // bootstrap progress
            ColumnLayout {
                visible: torPanel.working
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: torPanel.dark ? "#1A221C" : "#C3CAC5"
                    Rectangle {
                        width: parent.width * Math.max(0.02, torPanel.client.progress / 100)
                        height: parent.height
                        radius: 2
                        color: torPanel.torPurple
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: torPanel.client.progress + "% · " + torPanel.client.message
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            // what went wrong
            MoneroComponents.TextPlain {
                visible: torPanel.state_ === "error" && torPanel.client.message !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: torPanel.client.message
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                color: torPanel.stateColor
                themeTransition: false
            }

            // exit: IP seen by check.torproject.org
            Rectangle {
                visible: torPanel.active
                Layout.fillWidth: true
                implicitHeight: exitRow.implicitHeight + 24
                color: torPanel.dark ? "#08FFFFFF" : "#08000000"
                border.width: 1
                border.color: Qt.rgba(torPanel.border.r, torPanel.border.g, torPanel.border.b, 0.15)

                RowLayout {
                    id: exitRow
                    anchors.left: parent.left
                    anchors.right: refreshButton.left
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 14
                    MoneroComponents.TextPlain {
                        Layout.preferredWidth: 110
                        Layout.alignment: Qt.AlignTop
                        text: qsTr("Exit IP") + translationManager.emptyString
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 0.8
                        font.capitalization: Font.AllUppercase
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: torPanel.exitIp !== "" ? torPanel.exitIp : (torPanel.exitLoading ? "…" : "—")
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 14
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: torPanel.exitIp === "" ? " "
                                  : torPanel.exitIsTor ? qsTr("✓ Confirmed by check.torproject.org") + translationManager.emptyString
                                                       : qsTr("⚠ check.torproject.org says this is not Tor") + translationManager.emptyString
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            font.pixelSize: 11
                            color: torPanel.exitIsTor ? (torPanel.dark ? "#5FD08F" : "#1E8E4E") : (torPanel.dark ? "#FF5C5C" : "#C62828")
                            themeTransition: false
                        }
                    }
                }

                MoneroComponents.StandardButton {
                    id: refreshButton
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    small: true
                    text: (torPanel.exitLoading ? "… " : "") + qsTr("Refresh") + translationManager.emptyString
                    onClicked: torPanel.loadExit()
                }
            }

            // .onion remote nodes
            ColumnLayout {
                visible: torPanel.active
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    MoneroComponents.Label {
                        Layout.fillWidth: true
                        text: qsTr("Remote .onion nodes") + translationManager.emptyString
                        fontSize: 13
                        tooltipIconVisible: true
                        tooltip: [
                            qsTr("Through Tor a local node syncs very slowly: its peers are reached through Tor exits, and many nodes refuse or drop them."),
                            qsTr("A remote node with a .onion address is reached inside the Tor network, without exits: the wallet syncs at a good speed and neither the node nor your connection sees who you are."),
                            qsTr("Candidates come from the xmr.ditatompel.com and monero.fail monitors (asked through Tor). The app then asks each one for /get_info through Tor and only lists those that answer and are at the current height, fastest first."),
                            qsTr("The node only sees a Tor connection. Like any remote node it learns which blocks and outputs your wallet asks for, never your keys.")
                        ].join("<br><br>") + translationManager.emptyString
                    }
                    MoneroComponents.StandardButton {
                        small: true
                        visible: torPanel.onionNodes.length > 0
                        accent: torPanel.dark ? "#B48CFF" : "#6B3FA0"
                        text: qsTr("Use a good one") + translationManager.emptyString
                        onClicked: torPanel.useBest()
                    }
                    MoneroComponents.StandardButton {
                        small: true
                        text: (torPanel.onionLoading ? (torPanel.onionTotal > 0 ? torPanel.onionChecked + "/" + torPanel.onionTotal + " " : "… ") : "")
                              + qsTr("Find nodes") + translationManager.emptyString
                        onClicked: torPanel.loadOnionNodes()
                    }
                }

                MoneroComponents.TextPlain {
                    visible: torPanel.onionError !== "" && !torPanel.onionLoading
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: torPanel.onionError
                    font.pixelSize: 12
                    color: torPanel.dark ? "#FFC23D" : "#A86F00"
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    visible: torPanel.onionNodes.length > 0 && torPanel.nodesSavedTime > 0 && !torPanel.onionLoading
                    Layout.fillWidth: true
                    text: qsTr("Saved list from %1. \"Find nodes\" checks them again.").arg(Qt.formatDateTime(new Date(torPanel.nodesSavedTime), "dd/MM hh:mm")) + translationManager.emptyString
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Repeater {
                    model: torPanel.onionNodes
                    delegate: Rectangle {
                        readonly property bool current: torPanel.currentNode === modelData.address
                        readonly property string p2p: torPanel.p2pState[modelData.address] || ""
                        Layout.fillWidth: true
                        implicitHeight: rowColumn.implicitHeight + 12
                        color: rowHover.hovered ? (torPanel.dark ? "#10FFFFFF" : "#10000000") : "transparent"
                        border.width: current ? 1 : 0
                        border.color: torPanel.torPurple
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
                                    color: current ? torPanel.torPurple : (remoteMouse.containsMouse ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor)
                                    themeTransition: false
                                    MouseArea {
                                        id: remoteMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: torPanel.useNode(modelData.address)
                                    }
                                }
                                MoneroComponents.TextPlain {
                                    text: p2p === "probing" ? qsTr("Looking for P2P…") + translationManager.emptyString
                                          : p2p === "added" ? qsTr("✓ P2P peer") + translationManager.emptyString
                                          : qsTr("P2P peer") + translationManager.emptyString
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.underline: p2pMouse.containsMouse && p2p !== "probing" && p2p !== "added"
                                    color: p2p === "added" ? torPanel.torPurple : (p2pMouse.containsMouse ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor)
                                    themeTransition: false
                                    MouseArea {
                                        id: p2pMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        enabled: p2p !== "probing" && p2p !== "added"
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: torPanel.addP2p(modelData.address)
                                    }
                                }
                            }
                            MoneroComponents.TextPlain {
                                visible: p2p !== "" && p2p !== "probing" && p2p !== "added"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: p2p
                                font.pixelSize: 11
                                color: torPanel.dark ? "#FFC23D" : "#A86F00"
                                themeTransition: false
                            }
                        }
                    }
                }

                // peers of the local node on this network (--add-priority-node), with a remove button
                MoneroComponents.TextPlain {
                    visible: torPanel.p2pPeers.length > 0
                    Layout.topMargin: 6
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("P2P peers of the local node (--add-priority-node). Your own transactions go to them through --tx-proxy; the blocks still come from normal peers.") + translationManager.emptyString
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                Repeater {
                    model: torPanel.p2pPeers
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
                            color: removeMouse.containsMouse ? (torPanel.dark ? "#FF5C5C" : "#C62828") : MoneroComponents.Style.dimmedFontColor
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
