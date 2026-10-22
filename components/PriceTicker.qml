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

import "." as MoneroComponents

// Bottom price ticker: 1 XMR in BTC and every fiat currency with a rate, scrolling right to left
// (pauses under the mouse). Uses the prices the app already has (fiatPriceUSD, fiatRates,
// fiatChange24h, priceBtc); no request of its own.
Rectangle {
    id: ticker
    readonly property bool dark: MoneroComponents.Style.blackTheme
    property real speed: 45   // px per second
    property var quotes: []

    height: 28
    clip: true
    color: dark ? "#0A0C0B" : "#D3D8D4"

    // first ones on the left: BTC, EUR, USD, then the rest in the app's currency order
    readonly property var order: ["BTC", "EUR", "USD", "GBP", "CHF", "JPY", "CNY", "CAD", "AUD", "BRL", "MXN", "INR", "KRW"]

    function fmtPrice(cur, p) {
        if (cur === "BTC") return Number(p).toLocaleString(Qt.locale(), "f", 6);
        var digits = p >= 1000 ? 0 : (p >= 1 ? 2 : 4);
        return Number(p).toLocaleString(Qt.locale(), "f", digits);
    }

    function load() {
        var q = [];
        var seen = {};
        var codes = order.concat(appWindow.fiatCurrencies);
        for (var i = 0; i < codes.length; i++) {
            var cur = codes[i];
            if (seen[cur]) continue;
            seen[cur] = true;
            if (cur === "BTC") {
                if (appWindow.priceBtc > 0) q.push({ code: cur, price: appWindow.priceBtc, change: NaN });
                continue;
            }
            var rate = appWindow.fiatRates.hasOwnProperty(cur) ? appWindow.fiatRates[cur] : 0;
            if (appWindow.fiatPriceUSD > 0 && rate > 0)
                // FX moves little in a day: every fiat uses the USD 24 h change
                q.push({ code: cur, price: appWindow.fiatPriceUSD * rate, change: appWindow.fiatChange24h });
        }
        quotes = q;
    }

    Component.onCompleted: load()
    Connections {
        target: appWindow
        function onFiatPriceUSDChanged() { ticker.load(); }
        function onFiatRatesChanged() { ticker.load(); }
        function onFiatChange24hChanged() { ticker.load(); }
        function onPriceBtcChanged() { ticker.load(); }
    }

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: MoneroComponents.Style.orange
        opacity: 0.5
    }

    // two copies side by side, moved by one copy's width so the loop has no seam
    Row {
        id: strip
        y: 1
        height: parent.height - 1
        property Item copyRef: null
        readonly property real copyWidth: copyRef ? copyRef.width : 0
        onCopyWidthChanged: scroll.restart()

        Repeater {
            model: 2
            Row {
                id: copy
                height: strip.height
                Component.onCompleted: if (index === 0) strip.copyRef = copy
                Repeater {
                    model: ticker.quotes
                    Item {
                        width: item.implicitWidth + 34
                        height: strip.height
                        Row {
                            id: item
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 5
                                rotation: 45
                                color: MoneroComponents.Style.orange
                                opacity: 0.8
                            }
                            Text {
                                text: "XMR/" + modelData.code
                                color: MoneroComponents.Style.dimmedFontColor
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 12
                            }
                            Text {
                                text: ticker.fmtPrice(modelData.code, modelData.price)
                                color: MoneroComponents.Style.defaultFontColor
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 12
                            }
                            Text {
                                visible: !isNaN(modelData.change)
                                text: (modelData.change >= 0 ? "▲ +" : "▼ ") + Number(modelData.change).toFixed(2) + "%"
                                color: modelData.change >= 0 ? (ticker.dark ? "#4CD964" : "#1E8E4E") : (ticker.dark ? "#FF5A5A" : "#C62828")
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }

    HoverHandler { id: hover }

    NumberAnimation {
        id: scroll
        target: strip
        property: "x"
        from: 0
        to: -strip.copyWidth
        duration: Math.max(1000, strip.copyWidth / ticker.speed * 1000)
        loops: Animation.Infinite
        running: ticker.visible && strip.copyWidth > 0
        paused: running && hover.hovered
    }
}
