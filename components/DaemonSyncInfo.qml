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

import "../components" as MoneroComponents

// Local node sync figures (blocks left, last block time, progress, rate, time left), read from monerod every 10 s
GridLayout {
    id: info
    columns: 2
    columnSpacing: 10
    rowSpacing: 4

    property bool active: true
    property bool showBlockNumber: false   // adds a "Last block" row (height of the top block)
    property int lastBlock: 0
    property bool pollHidden: false        // keep reading while hidden (inside a closed popup)
    property var samples: []        // [{t: ms, h: height}] of the last hour
    property int nodeHeight: 0
    property int target: 0
    property double lastBlockTime: 0
    property bool ok: false

    readonly property int blocksLeft: Math.max(0, target - nodeHeight)
    readonly property bool synced: ok && blocksLeft === 0
    readonly property double progress: target > 0 ? Math.min(100, nodeHeight * 100 / target) : 0
    readonly property double blocksPerHour: {
        if (samples.length < 2) return 0;
        var a = samples[0], b = samples[samples.length - 1];
        var hours = (b.t - a.t) / 3600000;
        return hours > 0.01 ? Math.max(0, (b.h - a.h) / hours) : 0;
    }

    function duration(hours) {
        if (hours < 1 / 60) return qsTr("less than a minute") + translationManager.emptyString;
        if (hours < 1) return qsTr("%1 minutes").arg(Math.round(hours * 60)) + translationManager.emptyString;
        if (hours < 48) return qsTr("%1 hours").arg(Math.round(hours)) + translationManager.emptyString;
        if (hours < 24 * 14) return qsTr("%1 days").arg(Math.round(hours / 24)) + translationManager.emptyString;
        return qsTr("%1 weeks").arg(Math.round(hours / 168)) + translationManager.emptyString;
    }

    function load() {
        if (!active || persistentSettings.useRemoteNode) { ok = false; return; }
        oshelper.nodeRpc(appWindow.localDaemonAddress, "", "/get_info", "", 8000, function(success, ms, body, error) {
            if (!success) { ok = false; return; }
            try {
                var r = JSON.parse(body);
                nodeHeight = r.height || 0;
                target = Math.max(r.target_height || 0, nodeHeight);
                ok = nodeHeight > 0;
                var now = Date.now();
                var s = samples.filter(function(x) { return now - x.t <= 3600000 && x.h <= nodeHeight; });
                s.push({t: now, h: nodeHeight});
                samples = s;
            } catch (e) { ok = false; }
        });
        oshelper.nodeRpc(appWindow.localDaemonAddress, "", "/json_rpc",
                         "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_last_block_header\"}", 8000,
                         function(success, ms, body, error) {
            if (!success) return;
            try {
                var header = JSON.parse(body).result.block_header;
                lastBlockTime = header.timestamp * 1000;
                lastBlock = header.height;
            } catch (e) {}
        });
    }

    Timer {
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: info.active && (info.visible || info.pollHidden) && !persistentSettings.useRemoteNode
        onTriggered: info.load()
    }

    readonly property var allRows: [
        [qsTr("Blocks left"), ok ? String(blocksLeft) : "—"],
        [showBlockNumber ? qsTr("Last block") : "", lastBlock > 0 ? String(lastBlock) : "—"],
        [qsTr("Last block time"), ok && lastBlockTime > 0 ? Qt.formatDateTime(new Date(lastBlockTime), "d/M/yy hh:mm") : "—"],
        [qsTr("Progress"), ok ? progress.toFixed(2) + "%" : "—"],
        [qsTr("Progress per hour"), ok && blocksPerHour > 0 && target > 0 ? (blocksPerHour * 100 / target).toFixed(2) + "%" : "—"],
        [qsTr("Estimated time left"), !ok ? "—" : blocksLeft === 0 ? qsTr("Synchronized") : blocksPerHour > 0 ? duration(blocksLeft / blocksPerHour) : qsTr("calculating…")]
    ]

    readonly property var rows: allRows.filter(function(r) { return r[0] !== ""; })

    Repeater {
        model: info.rows.length * 2
        Text {
            readonly property bool isLabel: index % 2 === 0
            Layout.alignment: isLabel ? Qt.AlignRight : Qt.AlignLeft
            text: info.rows[Math.floor(index / 2)][isLabel ? 0 : 1] + translationManager.emptyString
            font.family: isLabel ? MoneroComponents.Style.fontMedium.name : MoneroComponents.Style.fontRegular.name
            font.bold: isLabel
            font.pixelSize: 13
            color: MoneroComponents.Style.defaultFontColor
        }
    }
}
