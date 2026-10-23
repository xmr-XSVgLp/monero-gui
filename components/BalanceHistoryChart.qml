import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents
import "../js/Utils.js" as Utils

// Value of the whole wallet (all accounts) over time, like Markets > "Your wallet's value":
// balance at time t = balance now - every movement after t; value = balance(t) x price(t).
// Prices come from the CoinGecko CSVs the Markets page keeps in ~/Monero/xmr-wallet-plus/markets/coingecko/.
ColumnLayout {
    id: chartRoot
    spacing: 10

    property string currency: "USD"            // fiat code of the app (EUR, USD, BTC…)
    readonly property string pair: currency.toLowerCase()
    readonly property int digits: currency === "BTC" ? 8 : 2
    readonly property string prefix: currency === "EUR" ? "€" : currency === "USD" ? "$" : currency === "BTC" ? "₿" : currency
    readonly property color upColor: "#3DDC84"
    readonly property color downColor: "#FF5A5A"
    readonly property color neutral: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"

    readonly property var ranges: [
        { key: "24H", days: 1, file: "24h" },
        { key: "7D", days: 7, file: "7d" },
        { key: "30D", days: 30, file: "30d" },
        { key: "90D", days: 90, file: "90d" },
        { key: "1A", days: 365, file: "1a" }
    ]
    property int rangeIndex: 1

    readonly property bool walletOpen: typeof appWindow !== "undefined" && !!appWindow.currentWallet
    readonly property bool balanceHidden: persistentSettings.hideBalance
                                          || (typeof appWindow !== "undefined" && appWindow.hideBalanceForced === true)
    property var balanceEvents: []   // [[t seconds, delta XMR], ...] oldest first
    property real balanceNow: 0
    property var points: []          // [[t, value, balance], ...]
    property int hoverIndex: -1
    readonly property real valueLast: points.length > 0 ? points[points.length - 1][1] : 0
    readonly property real valueFirst: points.length > 0 ? points[0][1] : 0
    readonly property real changePct: valueFirst > 0 ? (valueLast / valueFirst - 1) * 100 : 0
    readonly property bool hovering: hoverIndex >= 0 && hoverIndex < points.length

    function fmt(v) {
        return prefix + " " + Utils.prettyAmount(v.toFixed(digits));
    }

    function fmtDate(t) {
        var d = new Date(t * 1000);
        return ranges[rangeIndex].days <= 30 ? Qt.formatDateTime(d, "dd/MM hh:mm") : Qt.formatDate(d, "dd/MM/yyyy");
    }

    function csvPath() {
        if (typeof oshelper === "undefined" || !oshelper.swapsLogPath) return "";
        var p = oshelper.swapsLogPath();
        return p.substring(0, p.lastIndexOf("/")) + "/markets/coingecko/xmr-" + pair + "-" + ranges[rangeIndex].file + ".csv";
    }

    function readPrices() {
        var path = csvPath();
        if (path === "") return [];
        var lines = oshelper.readTextFile(path).split("\n");
        var out = [];
        var from = Date.now() / 1000 - ranges[rangeIndex].days * 24 * 3600;
        for (var i = 1; i < lines.length; i++) {
            var f = lines[i].split(",");
            if (f.length >= 3 && parseFloat(f[2]) > 0 && parseInt(f[1]) >= from)
                out.push([parseInt(f[1]), parseFloat(f[2])]);
        }
        return out;
    }

    function loadBalanceEvents() {
        var ev = [];
        balanceNow = 0;
        if (walletOpen) {
            var w = appWindow.currentWallet;
            balanceNow = parseFloat(walletManager.displayAmount(w.balanceAll())) || 0;
            // every account: the history model only holds the selected one
            ev = w.history.balanceEventsAll();
        }
        ev.sort(function(a, b) { return a[0] - b[0]; });
        balanceEvents = ev;
        update();
    }

    function update() {
        var prices = walletOpen && !balanceHidden && visible ? readPrices() : [];
        var out = [];
        var b = balanceNow;
        var j = balanceEvents.length - 1;
        for (var i = prices.length - 1; i >= 0; i--) {
            while (j >= 0 && balanceEvents[j][0] > prices[i][0]) {
                b -= balanceEvents[j][1];
                j--;
            }
            out.push([prices[i][0], Math.max(0, b) * prices[i][1], Math.max(0, b)]);
        }
        out.reverse();
        points = out.length >= 2 ? out : [];
        hoverIndex = -1;
        chart.requestPaint();
    }

    onRangeIndexChanged: update()
    onCurrencyChanged: update()
    onBalanceHiddenChanged: update()
    onVisibleChanged: if (visible) loadBalanceEvents()
    Component.onCompleted: loadBalanceEvents()

    // the Markets page rewrites the CSVs in the background
    Timer {
        interval: 5 * 60 * 1000
        running: chartRoot.visible
        repeat: true
        onTriggered: chartRoot.loadBalanceEvents()
    }

    Connections {
        target: typeof appWindow !== "undefined" ? appWindow : null
        function onCurrentWalletChanged() { chartRoot.loadBalanceEvents(); }
    }

    Connections {
        target: chartRoot.walletOpen ? appWindow.currentWallet.historyModel : null
        function onModelReset() { Qt.callLater(chartRoot.loadBalanceEvents); }
    }

    Connections {
        target: chartRoot.walletOpen ? appWindow.currentWallet : null
        ignoreUnknownSignals: true
        function onMoneyReceived() { chartRoot.loadBalanceEvents(); }
        function onMoneySpent() { chartRoot.loadBalanceEvents(); }
    }

    // ---- header: stats on the left, ranges on the right ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 24

        component Stat: ColumnLayout {
            property string label: ""
            property string value: ""
            property color valueColor: MoneroComponents.Style.defaultFontColor
            spacing: 2
            MoneroComponents.TextPlain {
                text: parent.label
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 11
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                text: parent.value
                textFormat: Text.RichText
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 15
                color: parent.valueColor
                themeTransition: false
            }
        }

        Stat {
            label: (chartRoot.hovering ? qsTr("VALUE") : qsTr("NOW")) + translationManager.emptyString
            value: chartRoot.points.length === 0 ? "–"
                   : chartRoot.fmt(chartRoot.hovering ? chartRoot.points[chartRoot.hoverIndex][1] : chartRoot.valueLast)
        }
        Stat {
            label: qsTr("CHANGE") + translationManager.emptyString
            value: chartRoot.valueFirst > 0 ? (chartRoot.changePct >= 0 ? "+" : "") + chartRoot.changePct.toFixed(2) + " %" : "–"
            valueColor: chartRoot.changePct >= 0 ? chartRoot.upColor : chartRoot.downColor
        }
        Stat {
            label: qsTr("BALANCE") + translationManager.emptyString
            value: Utils.prettyAmount((chartRoot.hovering ? chartRoot.points[chartRoot.hoverIndex][2] : chartRoot.balanceNow).toFixed(4))
                   + " <span style=\"font-family:'" + MoneroComponents.Style.fontXmrRegular.name + "'\">Ɱ</span>"
        }
        Stat {
            visible: chartRoot.hovering
            label: qsTr("DATE") + translationManager.emptyString
            value: visible ? chartRoot.fmtDate(chartRoot.points[chartRoot.hoverIndex][0]) : ""
        }
        Item { Layout.fillWidth: true }

        Row {
            spacing: 4
            Repeater {
                model: chartRoot.ranges
                delegate: Rectangle {
                    width: 40
                    height: 24
                    radius: 5
                    readonly property bool active: index === chartRoot.rangeIndex
                    color: active ? (MoneroComponents.Style.blackTheme ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12))
                                  : rangeArea.containsMouse ? (MoneroComponents.Style.blackTheme ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
                    border.width: active ? 1 : 0
                    border.color: chartRoot.neutral
                    MoneroComponents.TextPlain {
                        anchors.centerIn: parent
                        text: modelData.key
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 11
                        color: parent.active ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                    MouseArea {
                        id: rangeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: chartRoot.rangeIndex = index
                    }
                }
            }
        }
    }

    MoneroComponents.TextPlain {
        Layout.fillWidth: true
        visible: chartRoot.points.length === 0
        wrapMode: Text.WordWrap
        font.pixelSize: 13
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: (chartRoot.balanceHidden ? qsTr("Balance hidden")
               : qsTr("No price history for %1 yet. Open Wallet+ > Markets once to download it.").arg("XMR/" + chartRoot.currency))
              + translationManager.emptyString
    }

    // same look as the Markets chart: grid with labels, dates below, crosshair on hover
    Canvas {
        id: chart
        Layout.fillWidth: true
        Layout.preferredHeight: chartRoot.points.length > 0 ? 200 : 0
        visible: chartRoot.points.length > 0
        readonly property int padL: 8
        readonly property int padR: 84
        readonly property int padT: 10
        readonly property int padB: 26
        property color lineColor: chartRoot.changePct >= 0 ? chartRoot.upColor : chartRoot.downColor
        property color neutralColor: chartRoot.neutral
        property color gridColor: MoneroComponents.Style.blackTheme ? "#33FFFFFF" : "#22000000"
        property color labelColor: MoneroComponents.Style.dimmedFontColor
        onLineColorChanged: requestPaint()
        onLabelColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function range() {
            var pts = chartRoot.points;
            var lo = Infinity, hi = 0;
            for (var i = 0; i < pts.length; i++) { lo = Math.min(lo, pts[i][1]); hi = Math.max(hi, pts[i][1]); }
            var span = hi - lo || hi * 0.01 || 1;
            return { lo: lo - span * 0.08, hi: hi + span * 0.08 };
        }
        function xAt(i) {
            var n = chartRoot.points.length;
            return padL + (n > 1 ? i / (n - 1) : 0) * (width - padL - padR);
        }
        function yAt(v, r) {
            return padT + (1 - (v - r.lo) / (r.hi - r.lo)) * (height - padT - padB);
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var pts = chartRoot.points;
            if (pts.length < 2) return;
            var w = width, h = height;
            var r = range();
            ctx.font = "11px monospace";

            ctx.lineWidth = 1;
            for (var g = 0; g <= 4; g++) {
                var gy = Math.round(padT + g * (h - padT - padB) / 4) + 0.5;
                ctx.strokeStyle = gridColor;
                ctx.setLineDash([2, 4]);
                ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(w - padR, gy); ctx.stroke();
                var v = r.hi - (gy - padT) / (h - padT - padB) * (r.hi - r.lo);
                ctx.fillStyle = labelColor;
                ctx.fillText(Math.max(0, v).toFixed(chartRoot.digits), w - padR + 8, gy + 4);
            }
            ctx.setLineDash([]);

            ctx.fillStyle = labelColor;
            for (var d = 0; d <= 4; d++) {
                var di = Math.round(d * (pts.length - 1) / 4);
                var tx = xAt(di);
                var lbl = chartRoot.fmtDate(pts[di][0]);
                var tw = ctx.measureText(lbl).width;
                ctx.fillText(lbl, Math.max(padL, Math.min(tx - tw / 2, w - padR - tw)), h - 8);
            }

            var grad = ctx.createLinearGradient(0, padT, 0, h - padB);
            grad.addColorStop(0, Qt.rgba(neutralColor.r, neutralColor.g, neutralColor.b, 0.10));
            grad.addColorStop(1, Qt.rgba(neutralColor.r, neutralColor.g, neutralColor.b, 0.0));
            ctx.beginPath();
            ctx.moveTo(xAt(0), h - padB);
            for (var i = 0; i < pts.length; i++) ctx.lineTo(xAt(i), yAt(pts[i][1], r));
            ctx.lineTo(xAt(pts.length - 1), h - padB);
            ctx.closePath();
            ctx.fillStyle = grad;
            ctx.fill();
            ctx.beginPath();
            for (i = 0; i < pts.length; i++) i === 0 ? ctx.moveTo(xAt(i), yAt(pts[i][1], r)) : ctx.lineTo(xAt(i), yAt(pts[i][1], r));
            ctx.lineJoin = "round";
            ctx.strokeStyle = lineColor;
            ctx.lineWidth = 2;
            ctx.stroke();

            ctx.fillStyle = lineColor;
            ctx.beginPath(); ctx.arc(xAt(pts.length - 1), yAt(pts[pts.length - 1][1], r), 3.5, 0, Math.PI * 2); ctx.fill();

            var hi2 = chartRoot.hoverIndex;
            if (hi2 >= 0 && hi2 < pts.length) {
                var cx = Math.round(xAt(hi2)) + 0.5, cy = yAt(pts[hi2][1], r);
                ctx.strokeStyle = Qt.rgba(neutralColor.r, neutralColor.g, neutralColor.b, 0.5);
                ctx.lineWidth = 1;
                ctx.setLineDash([3, 3]);
                ctx.beginPath(); ctx.moveTo(cx, padT); ctx.lineTo(cx, h - padB); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(padL, cy); ctx.lineTo(w - padR, cy); ctx.stroke();
                ctx.setLineDash([]);
                ctx.fillStyle = MoneroComponents.Style.blackTheme ? "#0C130E" : "#FFFFFF";
                ctx.strokeStyle = lineColor;
                ctx.lineWidth = 2;
                ctx.beginPath(); ctx.arc(cx, cy, 5, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: (mouse) => {
                var n = chartRoot.points.length;
                if (n < 2) return;
                var f = (mouse.x - chart.padL) / (chart.width - chart.padL - chart.padR);
                chartRoot.hoverIndex = Math.max(0, Math.min(n - 1, Math.round(f * (n - 1))));
                chart.requestPaint();
            }
            onExited: { chartRoot.hoverIndex = -1; chart.requestPaint(); }
        }
    }
}
