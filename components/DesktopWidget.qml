// Copyright (c) 2014-2024, The Monero Project
//
// All rights reserved.
//
// XMR Wallet+: panel pinned to the desktop (behind every window, on all Spaces) with the XMR
// price, a 24 h chart, the wallet balance, the node and NYM. Drag to move, double click opens
// the wallet. Options in Settings > Interface.

import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import "." as MoneroComponents

Window {
    id: widget
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.NoDropShadowWindowHint
    color: "transparent"
    transientParent: null
    title: "XMR Wallet+ widget"
    width: 270
    height: panel.implicitHeight
    x: persistentSettings.desktopWidgetX >= 0 ? persistentSettings.desktopWidgetX : Screen.desktopAvailableWidth - width - 40
    y: persistentSettings.desktopWidgetY >= 0 ? persistentSettings.desktopWidgetY : 60

    readonly property color upColor: "#3DDC84"
    readonly property color downColor: "#FF5A5A"
    readonly property color accent: "#00FF41"
    readonly property color dim: "#9DB3A2"
    readonly property string unit: persistentSettings.desktopWidgetUnit

    property var series: []
    property string priceText: "—"
    property real change: NaN
    property string balanceText: ""
    property string nodeText: ""
    property bool nodeOk: false
    property string nymText: ""
    property bool nymOk: false

    readonly property string dataDir: {
        var p = oshelper.swapsLogPath();
        return p.substring(0, p.lastIndexOf("/")) + "/trading";
    }

    function readSeries() {
        var lines = oshelper.readTextFile(dataDir + "/xmr-" + unit.toLowerCase() + "-24h.csv").split("\n");
        var pts = [];
        for (var i = 1; i < lines.length; i++) {
            var f = lines[i].split(",");
            if (f.length >= 3 && parseFloat(f[2]) > 0)
                pts.push([parseInt(f[1]), parseFloat(f[2])]);
        }
        if (pts.length === 0) return [];
        var from = pts[pts.length - 1][0] - 86400;
        return pts.filter(function(p) { return p[0] >= from; });
    }

    function refresh() {
        var chip = titleBar.priceChip;
        var q = chip.quotes[unit];
        priceText = q && q.price > 0 ? chip.fmtPrice(unit, q.price) : "—";
        change = q ? q.change : NaN;
        series = persistentSettings.desktopWidgetChart ? readSeries() : [];

        if (currentWallet && persistentSettings.desktopWidgetBalance) {
            var hidden = hideBalanceForced || persistentSettings.hideBalance;
            balanceText = hidden ? "••••• XMR" : Number(walletManager.displayAmount(currentWallet.balance())).toFixed(4) + " XMR";
        } else {
            balanceText = "";
        }

        if (daemonTarget > 1) {
            nodeOk = daemonSynced;
            nodeText = daemonSynced
                ? qsTr("Synchronized · %1").arg(daemonHeight.toFixed(0))
                : qsTr("Synchronizing · %1%").arg((daemonHeight / daemonTarget * 100).toFixed(1));
        } else {
            nodeOk = false;
            nodeText = qsTr("No data");
        }

        nymOk = nymVpnProxyUp();
        nymText = nymOk ? qsTr("Connected") : persistentSettings.nymVpnEnabled ? qsTr("Connecting…") : qsTr("Off");
        chart.requestPaint();
    }

    Timer {
        interval: 15000
        repeat: true
        running: widget.visible
        triggeredOnStart: true
        onTriggered: widget.refresh()
    }
    Connections {
        target: titleBar.priceChip
        function onQuotesChanged() { widget.refresh(); }
    }
    Connections {
        target: persistentSettings
        function onDesktopWidgetUnitChanged() { widget.refresh(); }
        function onDesktopWidgetChartChanged() { widget.refresh(); }
        function onDesktopWidgetBalanceChanged() { widget.refresh(); }
    }

    // keep it on the wallpaper after it is shown (Qt sets the normal window level on show)
    onVisibleChanged: if (visible) Qt.callLater(function() { oshelper.pinToDesktop(widget); })
    Component.onCompleted: Qt.callLater(function() { oshelper.pinToDesktop(widget); })

    // save the position a moment after a move
    onXChanged: savePos.restart()
    onYChanged: savePos.restart()
    Timer {
        id: savePos
        interval: 800
        onTriggered: {
            persistentSettings.desktopWidgetX = widget.x;
            persistentSettings.desktopWidgetY = widget.y;
        }
    }

    Item {
        id: panel
        width: widget.width
        implicitHeight: content.implicitHeight + 28

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "#000000"
            opacity: persistentSettings.desktopWidgetOpacity
        }
        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 10
            accent: widget.accent
            lineOpacity: area.containsMouse ? 0.9 : 0.5
            glow: area.containsMouse ? 0.6 : 0.25
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: widget.startSystemMove()
            onDoubleClicked: {
                appWindow.show();
                appWindow.raise();
                appWindow.requestActivate();
            }
        }

        ColumnLayout {
            id: content
            x: 14
            y: 14
            width: panel.width - 28
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Image {
                    // app icon (moneroLogo_white.png is a wide wordmark, squeezed it looked like bars)
                    source: "qrc:///images/appicon-matrix.png"
                    sourceSize.width: 40
                    sourceSize.height: 40
                    smooth: true
                    mipmap: true
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    visible: status === Image.Ready
                }
                Text {
                    text: "XMR WALLET+"
                    color: widget.accent
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: qsTr("1 XMR · 24 h")
                    color: widget.dim
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: widget.priceText
                    color: "#FFFFFF"
                    font.family: MoneroComponents.Style.fontBold.name
                    font.pixelSize: 24
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: !isNaN(widget.change)
                    text: (widget.change >= 0 ? "▲ +" : "▼ ") + widget.change.toFixed(2) + "%"
                    color: widget.change >= 0 ? widget.upColor : widget.downColor
                    font.family: MoneroComponents.Style.fontBold.name
                    font.pixelSize: 14
                }
            }

            Canvas {
                id: chart
                visible: persistentSettings.desktopWidgetChart && widget.series.length > 1
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var s = widget.series;
                    if (s.length < 2) return;
                    var t0 = s[0][0], t1 = s[s.length - 1][0];
                    var lo = s[0][1], hi = s[0][1];
                    for (var i = 1; i < s.length; i++) { lo = Math.min(lo, s[i][1]); hi = Math.max(hi, s[i][1]); }
                    if (hi === lo) { hi += 1; lo -= 1; }
                    var w = width, h = height - 4;
                    function px(p) { return [(p[0] - t0) / Math.max(1, t1 - t0) * w, 2 + (hi - p[1]) / (hi - lo) * h]; }
                    var col = s[s.length - 1][1] >= s[0][1] ? widget.upColor : widget.downColor;
                    ctx.beginPath();
                    for (var j = 0; j < s.length; j++) {
                        var p = px(s[j]);
                        if (j === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]);
                    }
                    ctx.strokeStyle = col;
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                    ctx.lineTo(w, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    var g = ctx.createLinearGradient(0, 0, 0, height);
                    g.addColorStop(0, Qt.rgba(Qt.color(col).r, Qt.color(col).g, Qt.color(col).b, 0.25));
                    g.addColorStop(1, "transparent");
                    ctx.fillStyle = g;
                    ctx.fill();
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: widget.accent
                opacity: 0.25
            }

            component InfoRow: RowLayout {
                property string label
                property string value
                property color dot: "transparent"
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    color: dot
                    visible: dot != "transparent"
                }
                Text {
                    text: label
                    color: widget.dim
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: value
                    color: "#FFFFFF"
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                }
            }

            InfoRow {
                visible: widget.balanceText !== ""
                label: qsTr("Balance")
                value: widget.balanceText
            }
            InfoRow {
                visible: persistentSettings.desktopWidgetNode
                label: qsTr("Node")
                value: widget.nodeText
                dot: widget.nodeOk ? "#3B9EFF" : "#FFD60A"
            }
            InfoRow {
                visible: persistentSettings.desktopWidgetNym
                label: "NYM"
                value: widget.nymText
                dot: widget.nymOk ? widget.upColor : "#5C6B60"
            }
        }
    }
}
