// Copyright (c) 2026, XMR Wallet+
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

import moneroComponents.TransactionHistoryModel 1.0

import "../components" as MoneroComponents
import "../js/SwapHistory.js" as SwapHistory

// XMR price chart (CoinGecko public market_chart, no key) in EUR, USD or BTC.
// Like Swaps, it is only reachable with "Price conversion" on. Every series is saved as CSV and
// downloaded again every 15 minutes, one request at a time. Below the chart: the wallet's value
// over time, a quick converter (prices + last swap quotes) and price alerts.
Rectangle {
    id: pageTrading
    color: "transparent"

    property alias tradingHeight: mainLayout.height

    readonly property bool pricesEnabled: persistentSettings.fiatPriceEnabled
    // neutral frame and controls (like the other cards); only the price line is coloured
    readonly property color neutral: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
    readonly property color upColor: "#3DDC84"
    readonly property color downColor: "#FF5A5A"

    readonly property var pairs: [
        { key: "EUR", pair: "eur", digits: 2, prefix: "€" },
        { key: "USD", pair: "usd", digits: 2, prefix: "$" },
        { key: "BTC", pair: "btc", digits: 6, prefix: "₿" }
    ]
    // CoinGecko picks the step from the range asked: 5 minutes for 1 day, hourly up to 90 days,
    // daily beyond (the free API gives at most 365 days). So each currency needs 3 downloads
    // (1, 90 and 365 days); 7D and 30D are cut from the 90-day one
    readonly property var ranges: [
        { key: "24H", days: 1,   fetch: 1,   file: "24h" },
        { key: "7D",  days: 7,   fetch: 90,  file: "7d" },
        { key: "30D", days: 30,  fetch: 90,  file: "30d" },
        { key: "90D", days: 90,  fetch: 90,  file: "90d" },
        { key: "1Y",  days: 365, fetch: 365, file: "1a" },
        // everything recorded: the 1-year series plus the older rows kept in xmr-<cur>-1a.csv
        { key: "MAX", days: 0,   fetch: 365, file: "" }
    ]
    readonly property var downloads: [1, 90, 365]
    readonly property int refreshMs: 15 * 60 * 1000   // every series is downloaded again after 15 minutes
    readonly property int retryMs: 2 * 60 * 1000      // after a failure (usually CoinGecko's rate limit)

    // every download is saved as CSV, one file per currency and range:
    // ~/Monero/xmr-wallet-plus/trading/xmr-eur-24h.csv … xmr-btc-1a.csv
    readonly property string dataDir: {
        if (typeof oshelper === "undefined" || !oshelper.swapsLogPath) return "";
        var p = oshelper.swapsLogPath();
        return p.substring(0, p.lastIndexOf("/")) + "/trading";
    }

    property int pairIndex: 0
    property int rangeIndex: 1
    // bindings for the page; the functions below read pairs[pairIndex] / ranges[rangeIndex]
    // directly because onPairIndexChanged runs before these bindings are updated
    readonly property var pairInfo: pairs[pairIndex]
    readonly property var rangeInfo: ranges[rangeIndex]

    property var cache: ({})          // "eur/90" -> { time: ms, prices: [[t, price], ...] } (t in seconds)
    property var failed: ({})         // "eur/90" -> { time: ms, error: "..." }
    property var queue: []            // keys waiting for download, one request at a time
    property string busyKey: ""       // key being downloaded
    property string selKey: ""        // key of the series on screen
    property var points: []           // [[t, price], ...] for the selected pair and range
    readonly property bool loading: selKey !== "" && (busyKey === selKey || queue.indexOf(selKey) >= 0)
    readonly property string error: failed[selKey] ? failed[selKey].error : ""
    readonly property string lastUpdate: cache[selKey] ? Qt.formatDateTime(new Date(cache[selKey].time), "dd/MM hh:mm") : ""
    property int hoverIndex: -1

    readonly property real lastPrice: points.length > 0 ? points[points.length - 1][1] : 0
    readonly property real firstPrice: points.length > 0 ? points[0][1] : 0
    readonly property real changePct: firstPrice > 0 ? (lastPrice / firstPrice - 1) * 100 : 0
    readonly property real highPrice: { var m = 0; for (var i = 0; i < points.length; i++) m = Math.max(m, points[i][1]); return m; }
    readonly property real lowPrice: { var m = Infinity; for (var i = 0; i < points.length; i++) m = Math.min(m, points[i][1]); return m === Infinity ? 0 : m; }

    function fmt(v) {
        if (!(v > 0)) return "–";
        return pairInfo.prefix + " " + v.toFixed(pairInfo.digits);
    }

    function fmtDate(t) {
        var d = new Date(t * 1000);
        if (rangeInfo.days > 0 && rangeInfo.days <= 30)
            return Qt.formatDateTime(d, "dd/MM hh:mm");
        return Qt.formatDate(d, "dd/MM/yyyy");
    }

    function csvPath(pair, file) {
        return dataDir + "/xmr-" + pair + "-" + file + ".csv";
    }

    function readCsv(path) {
        var text = oshelper.readTextFile(path);
        var out = [];
        var lines = text.split("\n");
        for (var i = 1; i < lines.length; i++) {
            var f = lines[i].split(",");
            if (f.length >= 3 && parseFloat(f[2]) > 0)
                out.push([parseInt(f[1]), parseFloat(f[2])]);
        }
        return out;
    }

    function writeCsv(path, pair, prices) {
        var text = "fecha_utc,timestamp,precio_" + pair + "\n";
        for (var i = 0; i < prices.length; i++)
            text += new Date(prices[i][0] * 1000).toISOString().replace("T", " ").substring(0, 19)
                    + "," + prices[i][0] + "," + prices[i][1] + "\n";
        oshelper.writeTextFile(path, text);
    }

    // after a download: one CSV per range served by it. The 1-year file keeps its older rows,
    // so it keeps growing past CoinGecko's 365 days
    function saveSeries(pair, days, prices) {
        if (dataDir === "" || prices.length === 0)
            return;
        var now = Date.now() / 1000;
        for (var i = 0; i < ranges.length; i++) {
            var r = ranges[i];
            if (r.fetch !== days || r.file === "") continue;
            var path = csvPath(pair, r.file);
            var rows = prices.filter(function(p) { return p[0] >= now - r.days * 24 * 3600; });
            if (r.file === "1a") {
                var first = prices[0][0];
                rows = readCsv(path).filter(function(p) { return p[0] < first; }).concat(prices);
            }
            writeCsv(path, pair, rows);
        }
    }

    // at start the chart comes from the CSV files, without asking anything
    function loadSaved() {
        if (dataDir === "")
            return;
        var c = Object.assign({}, cache);
        for (var i = 0; i < pairs.length; i++) {
            for (var d = 0; d < downloads.length; d++) {
                var file = downloads[d] === 1 ? "24h" : downloads[d] === 90 ? "90d" : "1a";
                var prices = readCsv(csvPath(pairs[i].pair, file));
                if (prices.length > 1)
                    // the last point is the download time (CoinGecko's newest price is "now")
                    c[pairs[i].pair + "/" + downloads[d]] = { time: prices[prices.length - 1][0] * 1000, prices: prices };
            }
        }
        cache = c;
    }

    function isStale(key) {
        var c = cache[key];
        if (c && Date.now() - c.time < refreshMs) return false;
        var f = failed[key];
        if (f && Date.now() - f.time < retryMs) return false;
        return true;
    }

    // draws the selected pair/range from the cache (never another currency's data) and
    // asks for it first if it is missing or older than 15 minutes
    function select() {
        var pi = pairs[pairIndex], ri = ranges[rangeIndex];
        selKey = pi.pair + "/" + ri.fetch;
        var c = cache[selKey];
        if (c) {
            var from = ri.days > 0 ? Date.now() / 1000 - ri.days * 24 * 3600 : 0;
            points = c.prices.filter(function(p) { return p[0] >= from; });
        } else {
            points = [];
        }
        hoverIndex = -1;
        chart.requestPaint();
        updateValue();
        if (!c || Date.now() - c.time > refreshMs)
            enqueue(selKey, true);
    }

    function enqueue(key, first) {
        if (!pricesEnabled || key === busyKey)
            return;
        var q = queue.filter(function(k) { return k !== key; });
        if (first) q.unshift(key); else q.push(key);
        queue = q;
        pump();
    }

    function pump() {
        if (!pricesEnabled) {
            queue = [];
            return;
        }
        if (busyKey !== "" || queue.length === 0 || gapTimer.running)
            return;
        var key = queue[0];
        queue = queue.slice(1);
        busyKey = key;
        var pair = key.split("/")[0], days = parseInt(key.split("/")[1]);

        network.getJSON("https://api.coingecko.com/api/v3/coins/monero/market_chart?vs_currency=" + pair + "&days=" + days,
                        function(url, resp, err) {
            var failure = err;
            if (!failure) {
                try {
                    var j = JSON.parse(resp);
                    // errors come as {"error": "..."} or {"status": {"error_code": 429, ...}} (rate limit)
                    if (!j.prices) {
                        failure = j.error ? String(j.error)
                                : (j.status && j.status.error_code === 429) ? qsTr("too many requests, try again in a minute") + translationManager.emptyString
                                : (j.status && j.status.error_message) ? j.status.error_message : "no prices";
                    } else {
                        // prices: [[time ms, price], ...]
                        var prices = j.prices.map(function(r) { return [Math.round(r[0] / 1000), r[1]]; })
                                             .filter(function(p) { return p[1] > 0; });
                        // the 1-year series keeps the older rows already recorded (for MAX.)
                        if (days === 365 && cache[key] && prices.length > 0) {
                            var first = prices[0][0];
                            prices = cache[key].prices.filter(function(p) { return p[0] < first; }).concat(prices);
                        }
                        var c = Object.assign({}, cache);
                        c[key] = { time: Date.now(), prices: prices };
                        cache = c;
                        var f = Object.assign({}, failed); delete f[key]; failed = f;
                        saveSeries(pair, days, prices);
                        if (prices.length > 0)
                            checkAlerts(pair, prices[prices.length - 1][1]);
                    }
                } catch (ex) {
                    failure = "bad JSON";
                }
            }
            if (failure) {
                var f2 = Object.assign({}, failed); f2[key] = { time: Date.now(), error: failure }; failed = f2;
                console.log("TradingData: " + key + " failed: " + failure);
            }
            busyKey = "";
            if (key === selKey && !failure)
                select();
            gapTimer.restart();
        });
    }

    // a few seconds between requests: CoinGecko's free API allows only a few a minute
    Timer {
        id: gapTimer
        interval: 4000
        onTriggered: pageTrading.pump()
    }

    // every minute, queue the series older than 15 minutes (all currencies and ranges),
    // also when the page is not open. Nothing runs with "Price conversion" off
    Timer {
        interval: 60 * 1000
        repeat: true
        running: pageTrading.pricesEnabled
        onTriggered: {
            for (var i = 0; i < pageTrading.pairs.length; i++)
                for (var d = 0; d < pageTrading.downloads.length; d++) {
                    var key = pageTrading.pairs[i].pair + "/" + pageTrading.downloads[d];
                    if (pageTrading.isStale(key) && pageTrading.queue.indexOf(key) < 0)
                        pageTrading.enqueue(key, false);
                }
        }
    }

    onPricesEnabledChanged: if (!pricesEnabled) queue = []
    onPairIndexChanged: select()
    onRangeIndexChanged: select()
    Component.onCompleted: loadSaved()

    function onPageCompleted() {
        loadBalanceEvents();
        loadSwapSnapshot();
        select();
    }

    // Refresh: the series on screen, now (after the request in progress, if any)
    function refreshNow() {
        var f = Object.assign({}, failed); delete f[selKey]; failed = f;
        enqueue(selKey, true);
    }


    function pairByKey(pair) {
        for (var i = 0; i < pairs.length; i++)
            if (pairs[i].pair === pair) return pairs[i];
        return pairs[0];
    }

    function fmtIn(pair, v) {
        var info = pairByKey(pair);
        return info.prefix + " " + v.toFixed(info.digits);
    }

    // newest price we have of a currency (any downloaded series)
    function latestPrice(pair) {
        var best = null;
        for (var d = 0; d < downloads.length; d++) {
            var c = cache[pair + "/" + downloads[d]];
            if (c && c.prices.length > 0) {
                var p = c.prices[c.prices.length - 1];
                if (!best || p[0] > best[0]) best = p;
            }
        }
        return best ? best[1] : 0;
    }

    // ---------- price alerts (persistentSettings.priceAlerts, checked on every download) ----------
    readonly property var alerts: {
        try { return JSON.parse(persistentSettings.priceAlerts) || []; } catch (e) { return []; }
    }

    function saveAlerts(list) {
        persistentSettings.priceAlerts = JSON.stringify(list);
    }

    function addAlert(pair, above, price) {
        if (!(price > 0)) return;
        var l = alerts.slice();
        l.push({ pair: pair, above: above, price: price, fired: false });
        saveAlerts(l);
        // already past the target? it fires with the price we have now
        var now = latestPrice(pair);
        if (now > 0) checkAlerts(pair, now);
    }

    function removeAlert(index) {
        var l = alerts.slice();
        l.splice(index, 1);
        saveAlerts(l);
    }

    function rearmAlert(index) {
        var l = alerts.slice();
        l[index] = { pair: l[index].pair, above: l[index].above, price: l[index].price, fired: false };
        saveAlerts(l);
    }

    function checkAlerts(pair, price) {
        var l = alerts.slice();
        var changed = false;
        for (var i = 0; i < l.length; i++) {
            var a = l[i];
            if (a.fired || a.pair !== pair) continue;
            if ((a.above && price >= a.price) || (!a.above && price <= a.price)) {
                l[i] = Object.assign({}, a, { fired: true, firedAt: Date.now(), firedPrice: price });
                changed = true;
                var msg = qsTr("XMR/%1 is at %2 (alert: %3 %4)").arg(pairByKey(pair).key).arg(fmtIn(pair, price))
                          .arg(a.above ? "≥" : "≤").arg(fmtIn(pair, a.price)) + translationManager.emptyString;
                console.log("TradingData: alert fired: " + msg);
                if (typeof appWindow !== "undefined" && appWindow.showStatusMessage) {
                    appWindow.showStatusMessage(msg, 10);
                    appWindow.playFx("alert");
                }
                if (typeof oshelper !== "undefined" && oshelper.notify)
                    oshelper.notify("XMR Wallet+", msg);
            }
        }
        if (changed)
            saveAlerts(l);
    }

    // ---------- wallet value over time ----------
    // balance at time t = balance now - every movement after t; value = balance(t) x price(t)
    property var balanceEvents: []    // [[t seconds, delta XMR], ...] oldest first
    property real balanceNow: 0
    property var valuePoints: []      // [[t, value, balance], ...] matching `points`
    readonly property bool walletOpen: typeof appWindow !== "undefined" && !!appWindow.currentWallet
    readonly property bool balanceHidden: persistentSettings.hideBalance
                                          || (typeof appWindow !== "undefined" && appWindow.hideBalanceForced === true)
    readonly property bool showValue: walletOpen && !balanceHidden
    readonly property real valueLast: valuePoints.length > 0 ? valuePoints[valuePoints.length - 1][1] : 0
    readonly property real valueFirst: valuePoints.length > 0 ? valuePoints[0][1] : 0
    readonly property real valueChangePct: valueFirst > 0 ? (valueLast / valueFirst - 1) * 100 : 0

    function loadBalanceEvents() {
        var ev = [];
        balanceNow = 0;
        if (walletOpen) {
            var w = appWindow.currentWallet;
            balanceNow = parseFloat(walletManager.displayAmount(w.balance())) || 0;
            var m = w.historyModel;
            var account = w.currentSubaddressAccount;
            for (var i = 0; m && i < m.rowCount(); i++) {
                var idx = m.index(i, 0);
                if (m.data(idx, TransactionHistoryModel.TransactionFailedRole)) continue;
                if (m.data(idx, TransactionHistoryModel.TransactionPendingRole)) continue;
                if (m.data(idx, TransactionHistoryModel.TransactionSubaddrAccountRole) !== account) continue;
                var amount = Number(m.data(idx, TransactionHistoryModel.TransactionAmountRole)) || 0;
                var fee = parseFloat(m.data(idx, TransactionHistoryModel.TransactionFeeRole)) || 0;
                var out = m.data(idx, TransactionHistoryModel.TransactionIsOutRole);
                var ts = m.data(idx, TransactionHistoryModel.TransactionTimeStampRole);
                var t = ts ? new Date(ts).getTime() / 1000 : 0;
                if (!(t > 0)) continue;
                ev.push([t, out ? -(amount + fee) : amount]);
            }
        }
        ev.sort(function(a, b) { return a[0] - b[0]; });
        balanceEvents = ev;
        updateValue();
    }

    function updateValue() {
        if (!showValue || points.length < 2) {
            valuePoints = [];
            valueChart.requestPaint();
            return;
        }
        var out = [];
        var b = balanceNow;
        var j = balanceEvents.length - 1;
        for (var i = points.length - 1; i >= 0; i--) {
            while (j >= 0 && balanceEvents[j][0] > points[i][0]) {
                b -= balanceEvents[j][1];
                j--;
            }
            out.push([points[i][0], Math.max(0, b) * points[i][1], Math.max(0, b)]);
        }
        out.reverse();
        valuePoints = out;
        valueChart.requestPaint();
    }

    onShowValueChanged: updateValue()

    // ---------- quick converter ----------
    property string calcText: "1"
    readonly property real calcAmount: parseFloat(calcText.replace(",", ".")) || 0
    property var swapRows: []          // newest swap quotes saved by the Swaps page
    property string swapTime: ""
    readonly property var swapCoins: {
        var list = [];
        for (var i = 0; i < swapRows.length; i++)
            if (list.indexOf(swapRows[i].coin) < 0) list.push(swapRows[i].coin);
        return list;
    }

    function loadSwapSnapshot() {
        if (typeof oshelper === "undefined" || !oshelper.swapsLogPath) return;
        var h = SwapHistory.parse(oshelper.readTextFile(oshelper.swapsLogPath()));
        if (h.times.length === 0) { swapRows = []; swapTime = ""; return; }
        var t = h.times[h.times.length - 1];
        swapRows = h.byTime[t];
        swapTime = Qt.formatDateTime(new Date(t), "dd/MM hh:mm");
    }

    function swapOut(src, coin) {
        for (var i = 0; i < swapRows.length; i++)
            if (swapRows[i].src === src && swapRows[i].coin === coin && swapRows[i].out > 0)
                return swapRows[i].out * calcAmount;
        return 0;
    }

    function fmtAmount(v) {
        if (!(v > 0)) return "–";
        var digits = v >= 1000 ? 2 : v >= 1 ? 4 : 8;
        return v.toFixed(digits);
    }

    // the wallet's history changes (new transaction, other account): value chart again
    Connections {
        target: typeof appWindow !== "undefined" && appWindow.currentWallet ? appWindow.currentWallet : null
        ignoreUnknownSignals: true
        function onHistoryModelChanged() { pageTrading.loadBalanceEvents(); }
        function onCurrentSubaddressAccountChanged() { pageTrading.loadBalanceEvents(); }
        function onMoneyReceived() { pageTrading.loadBalanceEvents(); }
        function onMoneySpent() { pageTrading.loadBalanceEvents(); }
    }


    // card in the style of the chart's frame, with a title
    component Card: Item {
        id: card
        default property alias content: cardBody.data
        property string title: ""
        property string subtitle: ""
        implicitHeight: cardBody.implicitHeight + 36
        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 12
            accent: pageTrading.neutral
            lineOpacity: 0.35
            fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#DADFDB"
            fillOpacity: 0.92
            glow: 0.0
        }
        ColumnLayout {
            id: cardBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MoneroComponents.TextPlain {
                    text: card.title
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 1
                    font.capitalization: Font.AllUppercase
                    color: MoneroComponents.Style.textAccent
                    themeTransition: false
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: card.subtitle
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }
        }
    }

    // small number field with a neon frame
    component Field: Item {
        id: field
        property alias text: fieldInput.text
        property string suffix: ""
        signal accepted()
        implicitWidth: 170
        implicitHeight: 34
        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 6
            accent: pageTrading.neutral
            lineOpacity: fieldInput.activeFocus ? 0.9 : 0.4
            fillColor: pageTrading.neutral
            fillOpacity: 0.04
            ticks: false
        }
        TextInput {
            id: fieldInput
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: suffixText.implicitWidth + 18
            verticalAlignment: TextInput.AlignVCenter
            color: MoneroComponents.Style.defaultFontColor
            selectionColor: Qt.rgba(0.5, 0.5, 0.5, 0.4)
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 14
            selectByMouse: true
            clip: true
            validator: RegularExpressionValidator { regularExpression: /[0-9]{0,12}([.,][0-9]{0,12})?/ }
            onAccepted: field.accepted()
        }
        MoneroComponents.TextPlain {
            id: suffixText
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: field.suffix
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }
    }

    // one cell of the converter table
    component Cell: MoneroComponents.TextPlain {
        property bool head: false
        property bool best: false
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        font.family: MoneroComponents.Style.fontMonoMedium.name
        font.pixelSize: head ? 11 : 13
        font.bold: best
        color: head ? MoneroComponents.Style.dimmedFontColor : best ? pageTrading.upColor : MoneroComponents.Style.defaultFontColor
        themeTransition: false
    }

    // segmented selector (EUR / USD / BTC, 24H / 7D …)
    component Segments: Row {
        id: seg
        property var labels: []
        property int current: 0
        signal picked(int index)
        spacing: 6
        Repeater {
            model: seg.labels
            delegate: Item {
                width: Math.max(52, segText.implicitWidth + 22)
                height: 30
                readonly property bool on: index === seg.current
                MoneroComponents.NeonFrame {
                    anchors.fill: parent
                    cut: 6
                    accent: pageTrading.neutral
                    lineOpacity: parent.on ? 0.95 : (segArea.containsMouse ? 0.6 : 0.3)
                    fillColor: pageTrading.neutral
                    fillOpacity: parent.on ? 0.12 : 0.0
                    glow: parent.on ? 0.2 : 0.0
                    ticks: false
                }
                MoneroComponents.TextPlain {
                    id: segText
                    anchors.centerIn: parent
                    text: modelData
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 12
                    font.bold: true
                    color: parent.on ? MoneroComponents.Style.textAccent : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                MouseArea {
                    id: segArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(index)
                }
            }
        }
    }

    // one figure under the chart header
    component Stat: ColumnLayout {
        property string label: ""
        property string value: ""
        property color valueColor: MoneroComponents.Style.defaultFontColor
        spacing: 2
        MoneroComponents.TextPlain {
            text: parent.label
            font.pixelSize: 11
            font.family: MoneroComponents.Style.fontMonoMedium.name
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }
        MoneroComponents.TextPlain {
            text: parent.value
            font.pixelSize: 16
            font.bold: true
            font.family: MoneroComponents.Style.fontMonoMedium.name
            color: parent.valueColor
            themeTransition: false
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 20

        MoneroComponents.MarketsNavbar { current: "Trading" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MoneroComponents.LabelSubheader {
                Layout.fillWidth: true
                fontSize: 24
                text: qsTr("Markets") + translationManager.emptyString
            }

            MoneroComponents.TextPlain {
                text: pageTrading.loading ? (qsTr("Updating…") + translationManager.emptyString)
                                          : pageTrading.error !== "" ? "error: " + pageTrading.error
                                          : (pageTrading.lastUpdate !== "" ? qsTr("Updated %1").arg(pageTrading.lastUpdate) + translationManager.emptyString : "")
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.StandardButton {
                small: true
                enabled: !pageTrading.loading && pageTrading.pricesEnabled
                text: qsTr("Refresh") + translationManager.emptyString
                onClicked: pageTrading.refreshNow()
            }

            MoneroComponents.StandardButton {
                small: true
                visible: pageTrading.dataDir !== ""
                text: qsTr("Open folder") + translationManager.emptyString
                onClicked: oshelper.openFolder(pageTrading.dataDir)
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: cardCol.implicitHeight + 36

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 12
                accent: pageTrading.neutral
                lineOpacity: 0.35
                fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#DADFDB"
                fillOpacity: 0.92
                glow: 0.0
            }

            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Segments {
                        labels: pageTrading.pairs.map(function(p) { return "XMR/" + p.key; })
                        current: pageTrading.pairIndex
                        onPicked: (i) => pageTrading.pairIndex = i
                    }

                    Item { Layout.fillWidth: true }

                    Segments {
                        labels: [qsTr("24H"), qsTr("7D"), qsTr("30D"), qsTr("90D"), qsTr("1Y"), qsTr("MAX.")].map(function(s) { return s + translationManager.emptyString; })
                        current: pageTrading.rangeIndex
                        onPicked: (i) => pageTrading.rangeIndex = i
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 36

                    Stat {
                        label: qsTr("PRICE") + translationManager.emptyString
                        value: pageTrading.fmt(pageTrading.hoverIndex >= 0 ? pageTrading.points[pageTrading.hoverIndex][1] : pageTrading.lastPrice)
                        valueColor: MoneroComponents.Style.textAccent
                    }
                    Stat {
                        label: qsTr("CHANGE") + translationManager.emptyString
                        value: pageTrading.points.length > 1 ? (pageTrading.changePct >= 0 ? "+" : "") + pageTrading.changePct.toFixed(2) + " %" : "–"
                        valueColor: pageTrading.changePct >= 0 ? pageTrading.upColor : pageTrading.downColor
                    }
                    Stat {
                        label: qsTr("HIGH") + translationManager.emptyString
                        value: pageTrading.fmt(pageTrading.highPrice)
                    }
                    Stat {
                        label: qsTr("LOW") + translationManager.emptyString
                        value: pageTrading.fmt(pageTrading.lowPrice)
                    }
                    Item { Layout.fillWidth: true }
                    Stat {
                        visible: pageTrading.hoverIndex >= 0
                        label: qsTr("DATE") + translationManager.emptyString
                        value: pageTrading.hoverIndex >= 0 ? pageTrading.fmtDate(pageTrading.points[pageTrading.hoverIndex][0]) : ""
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 340

                    Canvas {
                        id: chart
                        anchors.fill: parent
                        readonly property int padL: 8
                        readonly property int padR: 84     // price labels on the right
                        readonly property int padT: 10
                        readonly property int padB: 26     // date labels
                        // green when the price went up over the range, red when it went down
                        property color lineColor: pageTrading.changePct >= 0 ? pageTrading.upColor : pageTrading.downColor
                        property color neutralColor: pageTrading.neutral
                        onLineColorChanged: requestPaint()
                        property color gridColor: MoneroComponents.Style.blackTheme ? "#33FFFFFF" : "#22000000"
                        property color labelColor: MoneroComponents.Style.dimmedFontColor
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onLabelColorChanged: requestPaint()

                        function xAt(i) {
                            var n = pageTrading.points.length;
                            return padL + (n > 1 ? i / (n - 1) : 0) * (width - padL - padR);
                        }
                        function yAt(v) {
                            var lo = pageTrading.lowPrice, hi = pageTrading.highPrice;
                            var span = hi - lo || hi * 0.01 || 1;
                            lo -= span * 0.06; hi += span * 0.06;
                            return padT + (1 - (v - lo) / (hi - lo)) * (height - padT - padB);
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var pts = pageTrading.points;
                            var w = width, h = height;
                            ctx.font = "11px monospace";

                            // grid + price labels
                            var lo = pageTrading.lowPrice, hi = pageTrading.highPrice;
                            ctx.lineWidth = 1;
                            for (var g = 0; g <= 4; g++) {
                                var gy = Math.round(padT + g * (h - padT - padB) / 4) + 0.5;
                                ctx.strokeStyle = gridColor;
                                ctx.setLineDash([2, 4]);
                                ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(w - padR, gy); ctx.stroke();
                                if (pts.length > 1) {
                                    // invert yAt for the label at this grid line
                                    var span = hi - lo || hi * 0.01 || 1;
                                    var l2 = lo - span * 0.06, h2 = hi + span * 0.06;
                                    var v = h2 - (gy - padT) / (h - padT - padB) * (h2 - l2);
                                    ctx.fillStyle = labelColor;
                                    ctx.fillText(v.toFixed(pageTrading.pairInfo.digits), w - padR + 8, gy + 4);
                                }
                            }
                            ctx.setLineDash([]);
                            if (pts.length < 2)
                                return;

                            // date labels
                            ctx.fillStyle = labelColor;
                            for (var d = 0; d <= 4; d++) {
                                var di = Math.round(d * (pts.length - 1) / 4);
                                var tx = xAt(di);
                                var lbl = pageTrading.fmtDate(pts[di][0]);
                                var tw = ctx.measureText(lbl).width;
                                ctx.fillText(lbl, Math.max(padL, Math.min(tx - tw / 2, w - padR - tw)), h - 8);
                            }

                            // area under the line
                            var grad = ctx.createLinearGradient(0, padT, 0, h - padB);
                            grad.addColorStop(0, Qt.rgba(neutralColor.r, neutralColor.g, neutralColor.b, 0.12));
                            grad.addColorStop(1, Qt.rgba(neutralColor.r, neutralColor.g, neutralColor.b, 0.0));
                            ctx.beginPath();
                            ctx.moveTo(xAt(0), h - padB);
                            for (var i = 0; i < pts.length; i++) ctx.lineTo(xAt(i), yAt(pts[i][1]));
                            ctx.lineTo(xAt(pts.length - 1), h - padB);
                            ctx.closePath();
                            ctx.fillStyle = grad;
                            ctx.fill();

                            // glow + line
                            ctx.lineJoin = "round";
                            ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.25);
                            ctx.lineWidth = 6;
                            ctx.beginPath();
                            for (i = 0; i < pts.length; i++) i === 0 ? ctx.moveTo(xAt(i), yAt(pts[i][1])) : ctx.lineTo(xAt(i), yAt(pts[i][1]));
                            ctx.stroke();
                            ctx.strokeStyle = lineColor;
                            ctx.lineWidth = 2;
                            ctx.stroke();

                            // last price marker
                            var lx = xAt(pts.length - 1), ly = yAt(pts[pts.length - 1][1]);
                            ctx.fillStyle = lineColor;
                            ctx.beginPath(); ctx.arc(lx, ly, 3.5, 0, Math.PI * 2); ctx.fill();

                            // crosshair
                            var hi2 = pageTrading.hoverIndex;
                            if (hi2 >= 0 && hi2 < pts.length) {
                                var cx = Math.round(xAt(hi2)) + 0.5, cy = yAt(pts[hi2][1]);
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
                                var n = pageTrading.points.length;
                                if (n < 2) return;
                                var f = (mouse.x - chart.padL) / (chart.width - chart.padL - chart.padR);
                                var i = Math.round(Math.max(0, Math.min(1, f)) * (n - 1));
                                if (i !== pageTrading.hoverIndex) {
                                    pageTrading.hoverIndex = i;
                                    chart.requestPaint();
                                    valueChart.requestPaint();
                                }
                            }
                            onExited: { pageTrading.hoverIndex = -1; chart.requestPaint(); valueChart.requestPaint(); }
                        }
                    }

                    MoneroComponents.TextPlain {
                        anchors.centerIn: parent
                        visible: pageTrading.points.length < 2
                        text: !pageTrading.pricesEnabled ? qsTr("Prices are off (Settings > Node / Network).") + translationManager.emptyString
                              : pageTrading.error !== "" ? "error: " + pageTrading.error
                              : pageTrading.loading ? qsTr("Updating…") + translationManager.emptyString : "…"
                        font.pixelSize: 13
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                }
            }
        }


        // ---------- wallet value over the selected range ----------
        Card {
            Layout.fillWidth: true
            visible: pageTrading.walletOpen
            title: qsTr("Your wallet's value") + translationManager.emptyString
            subtitle: pageTrading.balanceHidden ? qsTr("Balance hidden") + translationManager.emptyString
                      : qsTr("Balance of this account × price of each moment, %1").arg("XMR/" + pageTrading.pairInfo.key) + translationManager.emptyString

            RowLayout {
                Layout.fillWidth: true
                spacing: 36
                visible: pageTrading.showValue
                Stat {
                    readonly property bool hovering: pageTrading.hoverIndex >= 0 && pageTrading.hoverIndex < pageTrading.valuePoints.length
                    label: (hovering ? qsTr("VALUE") : qsTr("NOW")) + translationManager.emptyString
                    value: hovering ? pageTrading.fmt(pageTrading.valuePoints[pageTrading.hoverIndex][1])
                                    : pageTrading.valueLast > 0 ? pageTrading.fmt(pageTrading.valueLast) : "–"
                    valueColor: MoneroComponents.Style.textAccent
                }
                Stat {
                    label: qsTr("CHANGE") + translationManager.emptyString
                    value: pageTrading.valueFirst > 0 ? (pageTrading.valueChangePct >= 0 ? "+" : "") + pageTrading.valueChangePct.toFixed(2) + " %" : "–"
                    valueColor: pageTrading.valueChangePct >= 0 ? pageTrading.upColor : pageTrading.downColor
                }
                Stat {
                    label: qsTr("BALANCE") + translationManager.emptyString
                    // the balance at the hovered moment, like the value
                    value: (pageTrading.hoverIndex >= 0 && pageTrading.hoverIndex < pageTrading.valuePoints.length
                            ? pageTrading.valuePoints[pageTrading.hoverIndex][2] : pageTrading.balanceNow).toFixed(4) + " XMR"
                }
                Item { Layout.fillWidth: true }
                Stat {
                    visible: pageTrading.hoverIndex >= 0 && pageTrading.hoverIndex < pageTrading.valuePoints.length
                    label: qsTr("DATE") + translationManager.emptyString
                    value: visible ? pageTrading.fmtDate(pageTrading.valuePoints[pageTrading.hoverIndex][0]) : ""
                }
            }

            // same look as the price chart: grid with labels, dates below, crosshair on hover
            // (the hover is shared with the price chart: both point at the same moment)
            Canvas {
                id: valueChart
                Layout.fillWidth: true
                Layout.preferredHeight: pageTrading.showValue ? 220 : 0
                visible: pageTrading.showValue
                readonly property int padL: 8
                readonly property int padR: 84
                readonly property int padT: 10
                readonly property int padB: 26
                property color lineColor: pageTrading.valueChangePct >= 0 ? pageTrading.upColor : pageTrading.downColor
                property color neutralColor: pageTrading.neutral
                property color gridColor: MoneroComponents.Style.blackTheme ? "#33FFFFFF" : "#22000000"
                property color labelColor: MoneroComponents.Style.dimmedFontColor
                onLineColorChanged: requestPaint()
                onLabelColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                function range() {
                    var pts = pageTrading.valuePoints;
                    var lo = Infinity, hi = 0;
                    for (var i = 0; i < pts.length; i++) { lo = Math.min(lo, pts[i][1]); hi = Math.max(hi, pts[i][1]); }
                    var span = hi - lo || hi * 0.01 || 1;
                    return { lo: lo - span * 0.08, hi: hi + span * 0.08 };
                }
                function xAt(i) {
                    var n = pageTrading.valuePoints.length;
                    return padL + (n > 1 ? i / (n - 1) : 0) * (width - padL - padR);
                }
                function yAt(v, r) {
                    return padT + (1 - (v - r.lo) / (r.hi - r.lo)) * (height - padT - padB);
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var pts = pageTrading.valuePoints;
                    if (pts.length < 2) return;
                    var w = width, h = height;
                    var r = range();
                    var info = pageTrading.pairInfo;
                    ctx.font = "11px monospace";

                    // grid + value labels
                    ctx.lineWidth = 1;
                    for (var g = 0; g <= 4; g++) {
                        var gy = Math.round(padT + g * (h - padT - padB) / 4) + 0.5;
                        ctx.strokeStyle = gridColor;
                        ctx.setLineDash([2, 4]);
                        ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(w - padR, gy); ctx.stroke();
                        var v = r.hi - (gy - padT) / (h - padT - padB) * (r.hi - r.lo);
                        ctx.fillStyle = labelColor;
                        ctx.fillText(Math.max(0, v).toFixed(info.digits), w - padR + 8, gy + 4);
                    }
                    ctx.setLineDash([]);

                    // date labels
                    ctx.fillStyle = labelColor;
                    for (var d = 0; d <= 4; d++) {
                        var di = Math.round(d * (pts.length - 1) / 4);
                        var tx = xAt(di);
                        var lbl = pageTrading.fmtDate(pts[di][0]);
                        var tw = ctx.measureText(lbl).width;
                        ctx.fillText(lbl, Math.max(padL, Math.min(tx - tw / 2, w - padR - tw)), h - 8);
                    }

                    // area + line
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

                    // last value marker
                    ctx.fillStyle = lineColor;
                    ctx.beginPath(); ctx.arc(xAt(pts.length - 1), yAt(pts[pts.length - 1][1], r), 3.5, 0, Math.PI * 2); ctx.fill();

                    // crosshair
                    var hi2 = pageTrading.hoverIndex;
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
                        var n = pageTrading.valuePoints.length;
                        if (n < 2) return;
                        var f = (mouse.x - valueChart.padL) / (valueChart.width - valueChart.padL - valueChart.padR);
                        var i = Math.round(Math.max(0, Math.min(1, f)) * (n - 1));
                        if (i !== pageTrading.hoverIndex) {
                            pageTrading.hoverIndex = i;
                            valueChart.requestPaint();
                            chart.requestPaint();
                        }
                    }
                    onExited: { pageTrading.hoverIndex = -1; valueChart.requestPaint(); chart.requestPaint(); }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: mainLayout.width > 900 ? 2 : 1
            columnSpacing: 20
            rowSpacing: 20

            // ---------- quick converter ----------
            Card {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 1
                title: qsTr("Converter") + translationManager.emptyString
                subtitle: pageTrading.swapTime !== "" ? qsTr("swaps of %1, approx.").arg(pageTrading.swapTime) + translationManager.emptyString : ""

                Field {
                    Layout.fillWidth: true
                    text: pageTrading.calcText
                    suffix: "XMR"
                    onTextChanged: pageTrading.calcText = text
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 12
                    rowSpacing: 6
                    Repeater {
                        model: pageTrading.pairs
                        delegate: Item {
                            Layout.columnSpan: 1
                            Layout.fillWidth: true
                            implicitHeight: convCol.implicitHeight
                            ColumnLayout {
                                id: convCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 2
                                MoneroComponents.TextPlain {
                                    text: modelData.key
                                    font.family: MoneroComponents.Style.fontMonoMedium.name
                                    font.pixelSize: 11
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                                MoneroComponents.TextPlain {
                                    readonly property real p: pageTrading.latestPrice(modelData.pair)
                                    text: p > 0 ? modelData.prefix + " " + (p * pageTrading.calcAmount).toFixed(modelData.digits) : "–"
                                    font.family: MoneroComponents.Style.fontMonoMedium.name
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: MoneroComponents.Style.textAccent
                                    themeTransition: false
                                }
                            }
                        }
                    }
                }

                // XMR -> coin on each exchange, best one in green
                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: pageTrading.swapCoins.length > 0
                    columns: 4
                    columnSpacing: 10
                    rowSpacing: 5
                    Cell { head: true; horizontalAlignment: Text.AlignLeft; text: qsTr("XMR →") + translationManager.emptyString }
                    Cell { head: true; text: "Wagyu" }
                    Cell { head: true; text: "NonKYC" }
                    Cell { head: true; text: "ChangeNOW" }
                    Repeater {
                        model: pageTrading.swapCoins
                        delegate: Cell {
                            Layout.row: index + 1
                            Layout.column: 0
                            horizontalAlignment: Text.AlignLeft
                            text: modelData
                        }
                    }
                    Repeater {
                        model: pageTrading.swapCoins.length * 3
                        delegate: Cell {
                            readonly property string coin: pageTrading.swapCoins[Math.floor(index / 3)]
                            readonly property string src: ["wagyu", "nonkyc", "changenow"][index % 3]
                            readonly property real v: pageTrading.swapOut(src, coin)
                            readonly property real bestV: Math.max(pageTrading.swapOut("wagyu", coin), pageTrading.swapOut("nonkyc", coin), pageTrading.swapOut("changenow", coin))
                            Layout.row: Math.floor(index / 3) + 1
                            Layout.column: index % 3 + 1
                            best: v > 0 && v === bestV
                            text: pageTrading.fmtAmount(v)
                        }
                    }
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    visible: pageTrading.swapCoins.length === 0
                    wrapMode: Text.WordWrap
                    text: qsTr("Open Swaps once to add the exchanges' quotes here.") + translationManager.emptyString
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            // ---------- price alerts ----------
            Card {
                id: alertsCard
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 1
                title: qsTr("Price alerts") + translationManager.emptyString
                subtitle: qsTr("checked every 15 minutes") + translationManager.emptyString
                property int newPair: 0
                property bool newAbove: true
                property string newPrice: ""

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Segments {
                        labels: pageTrading.pairs.map(function(p) { return p.key; })
                        current: alertsCard.newPair
                        onPicked: (i) => alertsCard.newPair = i
                    }
                    Segments {
                        labels: ["≥", "≤"]
                        current: alertsCard.newAbove ? 0 : 1
                        onPicked: (i) => alertsCard.newAbove = (i === 0)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Field {
                        id: alertPrice
                        Layout.fillWidth: true
                        suffix: pageTrading.pairs[alertsCard.newPair].key
                        onAccepted: addAlertButton.clicked()
                    }
                    MoneroComponents.StandardButton {
                        id: addAlertButton
                        small: true
                        enabled: parseFloat(alertPrice.text.replace(",", ".")) > 0
                        text: qsTr("Add") + translationManager.emptyString
                        onClicked: {
                            pageTrading.addAlert(pageTrading.pairs[alertsCard.newPair].pair, alertsCard.newAbove,
                                                 parseFloat(alertPrice.text.replace(",", ".")));
                            alertPrice.text = "";
                        }
                    }
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    visible: pageTrading.alerts.length === 0
                    wrapMode: Text.WordWrap
                    text: qsTr("No alerts. You get a notification and a sound when XMR crosses the price.") + translationManager.emptyString
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Repeater {
                    model: pageTrading.alerts
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: modelData.fired ? pageTrading.downColor : pageTrading.upColor
                            opacity: modelData.fired ? 0.6 : 1
                        }
                        MoneroComponents.TextPlain {
                            text: "XMR/" + pageTrading.pairByKey(modelData.pair).key + " " + (modelData.above ? "≥" : "≤") + " " + pageTrading.fmtIn(modelData.pair, modelData.price)
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 13
                            color: modelData.fired ? MoneroComponents.Style.dimmedFontColor : MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.fired ? qsTr("reached %1 at %2").arg(Qt.formatDateTime(new Date(modelData.firedAt), "dd/MM hh:mm"))
                                                    .arg(pageTrading.fmtIn(modelData.pair, modelData.firedPrice)) + translationManager.emptyString
                                                  : qsTr("active") + translationManager.emptyString
                            font.pixelSize: 11
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                        MoneroComponents.StandardButton {
                            small: true
                            visible: modelData.fired
                            text: qsTr("Re-arm") + translationManager.emptyString
                            onClicked: pageTrading.rearmAlert(index)
                        }
                        MoneroComponents.StandardButton {
                            small: true
                            primary: false
                            text: qsTr("Remove") + translationManager.emptyString
                            onClicked: pageTrading.removeAlert(index)
                        }
                    }
                }
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Prices from CoinGecko (public data, no account). Every currency and range is saved as CSV in ~/Monero/xmr-wallet-plus/trading and downloaded again every 15 minutes, one request at a time, also with this page closed. With NymVPN on, the requests go through Nym.") + translationManager.emptyString
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }
    }
}
