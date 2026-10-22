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


// One connection check of Settings > Node / Network > Connection check, for one anonymous network
// (net: nym | tor | i2p): what the network is used for, then its checks. Nym and Tor: exit IP, proxy,
// web latency and speed, Monero P2P ping and the node they carry. I2P (no exit to the internet): router
// state, monerod's built-in I2P seed nodes and the .i2p remote node or the local node. Results live in
// main.qml (runConnectionTest(net)); only one check runs at a time and only when requested.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

ColumnLayout {
    id: check
    property string net: "tor"
    spacing: 8

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property var test: appWindow.connTests[net] || ({})
    readonly property bool testing: appWindow.connTestingNet === net
    readonly property bool busy: appWindow.connTestingNet !== ""
    readonly property bool up: appWindow.netUp(net)
    readonly property var uses: appWindow.netUses(net)
    readonly property var node: (persistentSettings.useRemoteNode, persistentSettings.netSync, persistentSettings.netWallet,
                                 remoteNodesModel.selected, appWindow.connTestNode(net))
    readonly property bool hasResults: Object.keys(test).length > 0
    readonly property color goodColor: dark ? "#5FD08F" : "#1E8E4E"
    readonly property color warnColor: dark ? "#FFC23D" : "#A86F00"
    readonly property color badColor: dark ? "#FF5C5C" : "#C62828"

    function seconds(ms) {
        return (ms / 1000).toFixed(ms < 10000 ? 1 : 0) + " s";
    }

    // [text, colour] of one row
    function testRow(key) {
        var r = test[key];
        if (!r)
            return [testing ? "…" : "—", MoneroComponents.Style.dimmedFontColor];
        switch (key) {
        case "router":
            if (!r.ok)
                return [qsTr("Not connected (%1)").arg(r.state) + translationManager.emptyString, badColor];
            return [qsTr("%1 routers · %2 tunnels · %3 % tunnel success").arg(r.routers).arg(r.tunnels).arg(r.rate)
                    + (r.status ? " · " + r.status : "") + translationManager.emptyString, goodColor];
        case "ip":
            return r.ok ? [r.ip + (r.place ? " · " + r.place : ""), goodColor]
                        : [qsTr("Unknown: %1").arg(r.error) + translationManager.emptyString, warnColor];
        case "socks":
            if (r.direct)
                return [qsTr("No proxy: direct connection") + translationManager.emptyString, MoneroComponents.Style.dimmedFontColor];
            return r.ok ? [qsTr("Answers (%1 ms)").arg(r.ms) + translationManager.emptyString, goodColor]
                        : [qsTr("Does not answer: %1").arg(r.error) + translationManager.emptyString, badColor];
        case "latency":
            if (!r.ok)
                return [qsTr("No answer: %1").arg(r.error) + translationManager.emptyString, badColor];
            var sum = 0, min = r.times[0], max = r.times[0];
            for (var i = 0; i < r.times.length; ++i) {
                sum += r.times[i];
                min = Math.min(min, r.times[i]);
                max = Math.max(max, r.times[i]);
            }
            var avg = sum / r.times.length;
            return [qsTr("%1 on average (%2 to %3), %4 of 3 answered").arg(seconds(avg)).arg(seconds(min)).arg(seconds(max)).arg(r.times.length) + translationManager.emptyString,
                    r.failed > 0 || avg > 8000 ? badColor : avg > 3000 ? warnColor : goodColor];
        case "speed":
            if (r.bytes === undefined || r.bytes === 0)
                return [r.error || qsTr("No download data received") + translationManager.emptyString, badColor];
            var text = qsTr("%1 kB/s").arg(r.kBps < 10 ? r.kBps.toFixed(1) : Math.round(r.kBps)) + translationManager.emptyString;
            text += " · " + qsTr("%1 of %2 kB in %3 s").arg(Math.round(r.bytes / 1000)).arg(Math.round(r.requestedBytes / 1000)).arg(Math.round(r.ms / 1000)) + translationManager.emptyString;
            if (!r.ok) text += " · " + qsTr("Partial download: %1").arg(r.error) + translationManager.emptyString;
            return [text, !r.ok || r.kBps < 20 ? warnColor : goodColor];
        case "p2p":
            var pings = [], errors = [];
            for (var j = 0; j < r.peers.length; ++j) {
                if (r.peers[j].ok)
                    pings.push(seconds(r.peers[j].pingMs));
                else if (errors.indexOf(r.peers[j].error) < 0)
                    errors.push(r.peers[j].error);
            }
            return [qsTr("%1 of %2 answer").arg(r.reached).arg(r.total) + translationManager.emptyString
                    + (pings.length ? " · ping " + pings.join(", ") : "")
                    + (errors.length ? " · " + errors.join(", ") : ""),
                    r.reached === 0 ? badColor : r.reached < r.total ? warnColor : goodColor];
        case "node":
            if (!r.ok)
                return persistentSettings.useRemoteNode
                       ? [qsTr("No answer (%1)").arg(r.error) + translationManager.emptyString, badColor]
                       : [qsTr("Not running (%1)").arg(r.error) + translationManager.emptyString, MoneroComponents.Style.dimmedFontColor];
            if (r.states === undefined && r.outgoing_connections_count === undefined)
                return [qsTr("Block %1").arg(r.height) + translationManager.emptyString, goodColor];
            var behind = r.target_height > r.height ? r.target_height - r.height : 0;
            var states = [];
            for (var st in r.states)
                states.push(st + " " + r.states[st]);
            return [(behind > 0 ? qsTr("Block %1, %2 behind").arg(r.height).arg(behind) : qsTr("Block %1, synchronized").arg(r.height)) + translationManager.emptyString
                    + " · " + qsTr("%1 out, %2 in").arg(r.outgoing_connections_count).arg(r.incoming_connections_count) + translationManager.emptyString
                    + (r.downloadKBps !== undefined ? " · " + qsTr("Receiving %1 kB/s").arg(r.downloadKBps.toFixed(1)) + translationManager.emptyString : "")
                    + (states.length ? " · " + states.join(", ") : ""),
                    behind === 0 ? goodColor : behind > 30 ? badColor : warnColor];
        }
        return ["", MoneroComponents.Style.dimmedFontColor];
    }

    // one-line conclusion once every check has finished
    readonly property string verdict: {
        if (testing || !hasResults)
            return "";
        if (net === "i2p") {
            if (!test.router || !test.router.ok)
                return qsTr("I2P is not connected: connect it in the I2P NETWORK panel.") + translationManager.emptyString;
            if (test.p2p && test.p2p.reached === 0)
                return qsTr("None of monerod's I2P seed nodes answered. Fresh I2P routers need some minutes to build tunnels: try again later.") + translationManager.emptyString;
            return qsTr("I2P works: Monero nodes answer through it.") + translationManager.emptyString;
        }
        var name = appWindow.netDisplayName(net);
        if (!test.socks)
            return "";
        if (!test.socks.ok)
            return qsTr("%1 is not answering: what goes through it waits until it is back.").arg(name) + translationManager.emptyString;
        if (test.p2p && test.p2p.reached === 0 && !(test.node && test.node.ok && test.node.outgoing_connections_count > 0))
            return qsTr("The test peers did not reply through %1. This alone does not prove that port 18080 is blocked; check the node below.").arg(name) + translationManager.emptyString;
        if (test.node && test.node.ok && test.node.target_height > test.node.height + 30)
            return qsTr("The node is still syncing through %1. Web download speed is not blockchain speed.").arg(name) + translationManager.emptyString;
        if (test.latency && test.latency.ok && test.speed && test.speed.ok)
            return (net === "nym" ? qsTr("Nym works. Expect a few seconds per request: that is normal for a mixnet.")
                                  : qsTr("Tor works.")) + translationManager.emptyString;
        return qsTr("Some checks failed: try again in a while.") + translationManager.emptyString;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        MoneroComponents.NetIcon {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            net: check.net
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            MoneroComponents.TextPlain {
                text: appWindow.netDisplayName(check.net) + "  ·  " + (check.up ? qsTr("connected") : qsTr("not connected")) + translationManager.emptyString
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 13
                font.bold: true
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: (check.uses.length ? qsTr("Used for: %1").arg(check.uses.join(" · ")) : qsTr("Not used by the Network configuration"))
                      + (!check.testing && check.hasResults && appWindow.connTestTimes[check.net]
                         ? " · " + qsTr("checked at %1").arg(Qt.formatTime(appWindow.connTestTimes[check.net], "HH:mm")) : "")
                      + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
        }
        MoneroComponents.StandardButton {
            small: true
            enabled: !check.busy && check.up
            text: check.testing ? qsTr("Checking…") + translationManager.emptyString
                                : qsTr("Check now") + translationManager.emptyString
            tooltip: !check.up ? qsTr("Connect it first in its panel below") + translationManager.emptyString : ""
            onClicked: appWindow.runConnectionTest(check.net)
        }
    }

    Repeater {
        model: !(check.testing || check.hasResults) ? []
               : check.net === "i2p" ? [
                   { key: "router", label: qsTr("I2P router") + translationManager.emptyString },
                   { key: "p2p", label: qsTr("I2P Monero nodes") + translationManager.emptyString }
               ].concat(check.node ? [{ key: "node", label: (persistentSettings.useRemoteNode ? qsTr("Remote node") : qsTr("Local node")) + translationManager.emptyString }] : [])
               : [
                   { key: "ip", label: qsTr("Current IP") + translationManager.emptyString },
                   { key: "socks", label: qsTr("Proxy") + translationManager.emptyString },
                   { key: "latency", label: qsTr("Response time") + translationManager.emptyString },
                   { key: "speed", label: qsTr("Download") + translationManager.emptyString },
                   { key: "p2p", label: qsTr("Monero nodes") + translationManager.emptyString }
               ].concat(check.node ? [{ key: "node", label: (persistentSettings.useRemoteNode ? qsTr("Remote node") : qsTr("Local node")) + translationManager.emptyString }] : [])
        delegate: RowLayout {
            readonly property var row: check.testRow(modelData.key)
            Layout.fillWidth: true
            spacing: 14
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 5
                width: 7; height: 7; radius: 3.5
                color: row[1]
            }
            MoneroComponents.TextPlain {
                Layout.preferredWidth: 140
                Layout.alignment: Qt.AlignTop
                text: modelData.label
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.8
                font.capitalization: Font.AllUppercase
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: row[0]
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
        }
    }

    MoneroComponents.TextPlain {
        visible: check.verdict !== ""
        Layout.fillWidth: true
        Layout.topMargin: 2
        wrapMode: Text.WordWrap
        text: check.verdict
        font.pixelSize: 13
        color: MoneroComponents.Style.defaultFontColor
        themeTransition: false
    }
}
