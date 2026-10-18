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


// Connection check of Settings > Node / Network: the proxy in use (NymVPN, another SOCKS5 or none), web latency
// and speed, Monero P2P ping and the local node. Results live in main.qml (runConnectionTest), which runs it
// when asked, and once 20 seconds after NymVPN connects or restarts.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

ColumnLayout {
    id: check
    spacing: 8

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property var test: appWindow.connTest
    readonly property bool testing: appWindow.connTesting
    readonly property string via: appWindow.connTestVia
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
        case "ip":
            return r.ok ? [r.ip + (r.place ? " · " + r.place : ""), check.via === "direct" ? MoneroComponents.Style.defaultFontColor : goodColor]
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
            if (!r.ok && r.bytes === undefined)
                return [r.error, badColor];
            var text = qsTr("%1 kB/s").arg(Math.round(r.kBps)) + translationManager.emptyString;
            if (!r.ok)
                text += " · " + qsTr("only %1 kB of 1000 arrived (%2)").arg(Math.round(r.bytes / 1000)).arg(r.error) + translationManager.emptyString;
            return [text, !r.ok || r.kBps < 20 ? badColor : r.kBps < 100 ? warnColor : goodColor];
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
                return [qsTr("Not running (%1)").arg(r.error) + translationManager.emptyString, MoneroComponents.Style.dimmedFontColor];
            var behind = r.target_height > r.height ? r.target_height - r.height : 0;
            var states = [];
            for (var st in r.states)
                states.push(st + " " + r.states[st]);
            return [(behind > 0 ? qsTr("Block %1, %2 behind").arg(r.height).arg(behind) : qsTr("Block %1, synchronized").arg(r.height)) + translationManager.emptyString
                    + " · " + qsTr("%1 out, %2 in").arg(r.outgoing_connections_count).arg(r.incoming_connections_count) + translationManager.emptyString
                    + (states.length ? " · " + states.join(", ") : ""),
                    behind === 0 ? goodColor : behind > 30 ? badColor : warnColor];
        }
        return ["", MoneroComponents.Style.dimmedFontColor];
    }

    // one-line conclusion once every check has finished
    readonly property string verdict: {
        if (testing || !test.socks)
            return "";
        var nym = via === "nym";
        if (!test.socks.ok)
            return (nym ? qsTr("The NymVPN SOCKS5 proxy is not answering: press Restart in NYM VPN.")
                        : qsTr("The SOCKS5 proxy is not answering: nothing can go out until it is back.")) + translationManager.emptyString;
        if (test.p2p && test.p2p.reached === 0)
            return (nym ? qsTr("The Nym exit does not let Monero's P2P connections (port 18080) through, so the local node cannot sync through Nym. Press Restart in NYM VPN to get another exit.")
                        : qsTr("No Monero node answers on port 18080: check the internet connection or the firewall.")) + translationManager.emptyString;
        if (test.node && test.node.ok && test.node.target_height > test.node.height + 30)
            return (nym ? qsTr("Monero nodes answer through Nym but the local node is behind: block downloads through the mixnet are slow. Give it time, or press Restart in NYM VPN for another route.")
                        : qsTr("Monero nodes answer but the local node is behind: it is still syncing.")) + translationManager.emptyString;
        if (test.latency && test.latency.ok && test.speed && test.speed.ok)
            return (nym ? qsTr("Nym works. Expect a few seconds per request: that is normal for a mixnet.")
                        : qsTr("The connection works.")) + translationManager.emptyString;
        return qsTr("Some checks failed: try again in a while.") + translationManager.emptyString;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            MoneroComponents.TextPlain {
                text: qsTr("Connection check") + translationManager.emptyString
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.8
                font.capitalization: Font.AllUppercase
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                visible: text !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: [check.via === "nym" ? qsTr("Through NymVPN") : check.via === "proxy" ? qsTr("Through the SOCKS5 proxy") : check.via === "direct" ? qsTr("Direct connection") : "",
                       !check.testing && check.test.socks ? qsTr("checked at %1").arg(Qt.formatTime(appWindow.connTestTime, "HH:mm")) : ""].filter(function(t) { return t !== ""; }).join(" · ") + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
        }
        MoneroComponents.StandardButton {
            small: true
            enabled: !check.testing
            text: check.testing ? qsTr("Checking…") + translationManager.emptyString
                                : qsTr("Check now") + translationManager.emptyString
            onClicked: appWindow.runConnectionTest()
        }
    }

    MoneroComponents.TextPlain {
        visible: !check.testing && !check.test.socks
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Measures the proxy in use, the response time and speed, whether Monero nodes answer and how the local node is doing. It runs when you press the button, and by itself 20 seconds after NymVPN connects or restarts; through Nym it can take a few minutes.") + translationManager.emptyString
        font.pixelSize: 12
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
    }

    Repeater {
        model: (check.testing || check.test.socks) ? [
            { key: "ip", label: qsTr("Current IP") + translationManager.emptyString },
            { key: "socks", label: qsTr("Proxy") + translationManager.emptyString },
            { key: "latency", label: qsTr("Response time") + translationManager.emptyString },
            { key: "speed", label: qsTr("Download") + translationManager.emptyString },
            { key: "p2p", label: qsTr("Monero nodes") + translationManager.emptyString },
            { key: "node", label: qsTr("Local node") + translationManager.emptyString }
        ] : []
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
                Layout.preferredWidth: 120
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
