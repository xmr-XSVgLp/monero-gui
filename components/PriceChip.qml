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
import QtQuick.Controls
import QtQuick.Layouts

import "." as MoneroComponents

// Title bar chip: XMR price in mBTC with a green ▲ / red ▼ for the last 24 hours. Hover: XMR in BTC,
// EUR and USD. Read from the Markets CSVs (~/Monero/xmr-wallet-plus/markets/coingecko/xmr-<cur>-24h.csv,
// refreshed every 15 min by the Markets page) and the fiat rates; no request of its own.
Item {
    id: chip
    // implicit size: inside the title bar RowLayout an explicit width is ignored (the frame came out
    // narrower than the text on some Macs)
    implicitWidth: chipRow.implicitWidth + 26
    implicitHeight: 30
    width: implicitWidth
    height: implicitHeight

    // currency -> { price, change } (change in %, NaN when unknown)
    property var quotes: ({})
    readonly property var btc: quotes["BTC"]
    readonly property bool hasPrice: btc !== undefined && btc.price > 0
    readonly property bool up: hasPrice && !(btc.change < 0)
    readonly property color upColor: "#3DDC84"
    readonly property color downColor: "#FF5A5A"

    readonly property string dataDir: {
        if (typeof oshelper === "undefined" || !oshelper.swapsLogPath) return "";
        var p = oshelper.swapsLogPath();
        return p.substring(0, p.lastIndexOf("/")) + "/markets";
    }

    // the 24 h CSVs change every 15 minutes: read them again at most every 2 minutes
    property var seriesCache: ({})
    property double seriesTime: 0

    // last price and change over the 24 h series in xmr-<pair>-24h.csv
    function readSeries(pair) {
        if (Date.now() - seriesTime < 120000 && seriesCache[pair] !== undefined)
            return seriesCache[pair];
        var s = readSeriesFile(pair);
        var c = Object.assign({}, seriesCache); c[pair] = s; seriesCache = c;
        return s;
    }
    function readSeriesFile(pair) {
        if (dataDir === "") return null;
        var lines = oshelper.readTextFile(dataDir + "/coingecko/xmr-" + pair + "-24h.csv").split("\n");
        var pts = [];
        for (var i = 1; i < lines.length; i++) {
            var f = lines[i].split(",");
            if (f.length >= 3 && parseFloat(f[2]) > 0)
                pts.push([parseInt(f[1]), parseFloat(f[2])]);
        }
        if (pts.length === 0) return null;
        var last = pts[pts.length - 1];
        var first = pts[0];
        for (var j = 0; j < pts.length; j++)
            if (pts[j][0] >= last[0] - 86400) { first = pts[j]; break; }
        return { price: last[1], change: first[1] > 0 && first !== last ? (last[1] / first[1] - 1) * 100 : NaN,
                 base: first[1] };
    }

    // the newest price wins: the live ticker (every minute) over the CSV (every 15 minutes); the 24 h change
    // compares it with the CSV price of 24 hours ago
    function withLive(series, live) {
        if (!(live > 0)) return series;
        var base = series && series.base > 0 ? series.base : 0;
        return { price: live, change: base > 0 ? (live / base - 1) * 100 : (series ? series.change : NaN), base: base };
    }

    function load() {
        if (dataDir !== "" && Date.now() - seriesTime >= 120000) {
            seriesCache = ({});
            seriesTime = Date.now();
        }
        var q = {};
        var liveBtc = Date.now() - appWindow.priceBtcLiveTime < 10 * 60000 ? appWindow.priceBtcLive : 0;
        var b = withLive(readSeries("btc"), liveBtc);
        if (b) q["BTC"] = b;
        else if (appWindow.priceBtc > 0) q["BTC"] = { price: appWindow.priceBtc, change: NaN };
        var usdSeries = readSeries("usd");
        var usd = withLive(usdSeries, appWindow.fiatPriceUSD);
        if (usd && !usdSeries) usd.change = appWindow.fiatChange24h;
        if (usd) q["USD"] = usd;
        var eurRate = appWindow.fiatRates && appWindow.fiatRates["EUR"] > 0 ? appWindow.fiatRates["EUR"] : 0;
        var eur = withLive(readSeries("eur"), appWindow.fiatPriceUSD > 0 && eurRate > 0 ? appWindow.fiatPriceUSD * eurRate : 0);
        if (eur) q["EUR"] = eur;
        quotes = q;
    }

    function fmtPrice(cur, p) {
        if (cur === "BTC") return (p * 1000).toFixed(3) + " mBTC";
        var digits = p >= 1000 ? 0 : 2;
        return Number(p).toLocaleString(Qt.locale(), "f", digits) + " " + cur;
    }

    function fmtChange(c) {
        if (isNaN(c)) return "";
        return (c >= 0 ? "▲ +" : "▼ ") + c.toFixed(2) + "%";
    }

    // currencies in the popup: only BTC, EUR and USD
    readonly property var order: ["BTC", "EUR", "USD"].filter(function(k) { return quotes[k] !== undefined; })

    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: chip.visible || persistentSettings.menuBarEnabled
        onTriggered: chip.load()
    }
    Connections {
        target: appWindow
        function onFiatPriceUSDChanged() { chip.load(); }
        function onPriceBtcChanged() { chip.load(); }
        function onPriceBtcLiveTimeChanged() { chip.load(); }
    }

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 7
        accent: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
        lineOpacity: chipArea.containsMouse ? 0.7 : 0.3
        fillColor: accent
        fillOpacity: chipArea.containsMouse ? 0.08 : 0.03
        ticks: false
    }
    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.hasPrice && !isNaN(chip.btc.change)
            text: chip.up ? "▲" : "▼"
            color: chip.up ? chip.upColor : chip.downColor
            font.pixelSize: 13
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.hasPrice ? (chip.btc.price * 1000).toFixed(2) + " mBTC" : "XMR —"
            color: MoneroComponents.Style.defaultFontColor
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 14
            font.bold: true
            font.letterSpacing: 1
        }
    }
    MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { chip.load(); pricePopup.open(); }
        onExited: pricePopup.close()
        onClicked: {
            pricePopup.close();
            if (persistentSettings.fiatPriceEnabled) {
                appWindow.showPageRequest("Trading");
                middlePanel.flickable.contentY = 0;
            }
        }
    }

    Popup {
        id: pricePopup
        y: chip.height + 6
        x: 0
        padding: 12
        closePolicy: Popup.CloseOnEscape
        background: MoneroComponents.NeonFrame {
            cut: 8
            accent: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
            lineOpacity: 0.5
            fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#EEF1EE"
            fillOpacity: 0.97
            ticks: false
        }
        contentItem: ColumnLayout {
            spacing: 8
            Text {
                text: qsTr("1 XMR · last 24 h") + translationManager.emptyString
                color: MoneroComponents.Style.dimmedFontColor
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 11
                font.letterSpacing: 1
            }
            GridLayout {
                columns: 3
                columnSpacing: 16
                rowSpacing: 4
                Repeater {
                    model: chip.order.length * 3
                    Text {
                        readonly property string cur: chip.order[Math.floor(index / 3)]
                        readonly property var q: chip.quotes[cur]
                        readonly property int col: index % 3
                        Layout.alignment: col === 0 ? Qt.AlignLeft : Qt.AlignRight
                        text: !q ? "" : col === 0 ? cur : col === 1 ? chip.fmtPrice(cur, q.price) : chip.fmtChange(q.change)
                        color: col === 2 && q && !isNaN(q.change) ? (q.change >= 0 ? chip.upColor : chip.downColor) : MoneroComponents.Style.defaultFontColor
                        font.family: col === 0 ? MoneroComponents.Style.fontMonoMedium.name : MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 12
                    }
                }
            }
            Text {
                visible: chip.order.length === 0
                text: qsTr("No prices yet: turn on External connections in Settings > Node / Network.") + translationManager.emptyString
                color: MoneroComponents.Style.dimmedFontColor
                font.pixelSize: 12
            }
            Text {
                visible: chip.order.length > 0
                // where the numbers come from: the live ticker when it answered in the last 10 minutes
                text: (Date.now() - appWindow.priceBtcLiveTime < 10 * 60000 || appWindow.fiatPriceUSD > 0
                       ? qsTr("Price: Kraken, every minute. 24 h change: Markets data (CoinGecko).")
                       : qsTr("From the Markets data.")) + translationManager.emptyString
                color: MoneroComponents.Style.dimmedFontColor
                font.pixelSize: 10
            }
        }
    }
}
