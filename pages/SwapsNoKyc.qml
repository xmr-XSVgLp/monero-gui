import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

// SWAPS NO-KYC: the XMR price on every no-KYC exchange, from moneropricenow.com (one request) plus
// NonKYC's own order book, like the board on moneropricenow.com
Rectangle {
    id: page
    color: "transparent"

    property alias swapsNoKycHeight: mainLayout.height

    // pairs: USD and EUR come from the XMR/USDT board (EUR converted with the app's exchange rates)
    readonly property var pairs: [
        { key: "usd", label: "XMR / USD", quote: "USDTTRC", nonKyc: "XMR_USDT", symbol: "$", suffix: "", decimals: 2, unit: qsTr("$ por XMR") },
        { key: "eur", label: "XMR / EUR", quote: "USDTTRC", nonKyc: "XMR_USDT", symbol: "€", suffix: "", decimals: 2, unit: qsTr("€ por XMR") },
        { key: "btc", label: "XMR / BTC", quote: "BTC",     nonKyc: "XMR_BTC",  symbol: "", suffix: " BTC", decimals: 6, unit: qsTr("BTC por XMR") }
    ]
    property int pairIndex: 0
    readonly property var pair: pairs[pairIndex]
    onPairIndexChanged: refresh(false)

    readonly property string mpnUrl: "https://moneropricenow.com/api/prices/two-way?base=XMR&quote="
    readonly property string nonKycUrl: "https://api.nonkyc.io/api/v2/tickers"

    // asking the exchanges shows the IP address like the other price sources: only with price conversion on
    readonly property bool pricesEnabled: persistentSettings.fiatPriceEnabled

    // raw answers, per MoneroPriceNow quote ("USDTTRC" / "BTC"), kept for a minute
    property var mpnRows: ({})
    property var mpnTime: ({})
    property var nonKycTickers: null
    property real nonKycTime: 0
    property string mpnError: ""
    property string nonKycError: ""
    property int pending: 0
    property string lastUpdate: ""

    // sorting like moneropricenow.com: tightest spread first; a click on a column header changes it
    property string sortKey: "spread"
    property bool sortAsc: true

    // EUR per USD (USDT is taken as 1 USD)
    readonly property real eurRate: appWindow.fiatRates && appWindow.fiatRates["EUR"] ? appWindow.fiatRates["EUR"] : 0
    readonly property real factor: pair.key === "eur" ? eurRate : 1
    readonly property bool unavailable: pair.key === "eur" && !(eurRate > 0)

    function field(o, name) {
        if (o[name] !== undefined) return o[name];
        var cap = name.charAt(0).toUpperCase() + name.slice(1);
        return o[cap];
    }
    function num(v) {
        var n = parseFloat(v);
        return isFinite(n) && n > 0 ? n : NaN;
    }

    function refresh(force) {
        if (!pricesEnabled) return;
        var now = Date.now();
        // both quotes at once (in parallel), so switching USD / EUR / BTC shows numbers right away
        ["USDTTRC", "BTC"].forEach(function(quote) {
        if (force || !(mpnTime[quote] > now - 60000)) {
            pending++;
            network.getJSON(mpnUrl + quote, function(url, resp, error) {
                pending--;
                if (error) {
                    mpnError = error;
                } else {
                    try {
                        var list = JSON.parse(resp);
                        if (!Array.isArray(list)) throw "bad answer";
                        var r = Object.assign({}, mpnRows); r[quote] = list; mpnRows = r;
                        var t = Object.assign({}, mpnTime); t[quote] = Date.now(); mpnTime = t;
                        mpnError = "";
                    } catch (e) {
                        mpnError = "bad JSON";
                    }
                }
                finished();
            });
        }
        });
        if (force || !(nonKycTime > now - 60000)) {
            pending++;
            network.getJSON(nonKycUrl, function(url, resp, error) {
                pending--;
                if (error) {
                    nonKycError = error;
                } else {
                    try {
                        var map = {};
                        var list = JSON.parse(resp);
                        for (var i = 0; i < list.length; i++)
                            if (list[i].ticker_id === "XMR_USDT" || list[i].ticker_id === "XMR_BTC")
                                map[list[i].ticker_id] = list[i];
                        nonKycTickers = map;
                        nonKycTime = Date.now();
                        nonKycError = "";
                    } catch (e) {
                        nonKycError = "bad JSON";
                    }
                }
                finished();
            });
        }
        if (pending === 0) finished();
    }

    function finished() {
        if (pending === 0)
            lastUpdate = new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss");
    }

    function timeText(ts) {
        var d = ts ? new Date(ts) : null;
        return d && !isNaN(d.getTime()) ? Qt.formatTime(d, "HH:mm:ss") : "—";
    }

    // the rows of the selected pair: float-rate quotes of MoneroPriceNow + NonKYC
    readonly property var rows: {
        var out = [];
        var list = mpnRows[pair.quote] || [];
        var f = factor;
        for (var i = 0; i < list.length; i++) {
            var r = list[i];
            var rateType = field(r, "rateType") || "float";
            if (rateType !== "float") continue;
            var buy = num(field(r, "buy")), sell = num(field(r, "sell"));
            if (isNaN(buy) && isNaN(sell)) continue;
            var minUsd = num(field(r, "minAmountUsd"));
            out.push({ name: field(r, "siteName") || field(r, "exchange") || "?",
                       url: field(r, "siteUrl") || "",
                       privacy: String(field(r, "privacyLevel") || "").toUpperCase().charAt(0),
                       buy: buy * f, sell: sell * f,
                       min: pair.key === "btc" ? minUsd : minUsd * f,
                       time: timeText(field(r, "tsUtc")),
                       nonKyc: false });
        }
        var t = nonKycTickers ? nonKycTickers[pair.nonKyc] : null;
        if (t) {
            var ask = num(t.ask), bid = num(t.bid);
            if (!isNaN(ask) || !isNaN(bid))
                out.push({ name: "NonKYC", url: "https://nonkyc.io/market/" + pair.nonKyc,
                           privacy: "", buy: ask * f, sell: bid * f, min: NaN,
                           time: timeText(nonKycTime), nonKyc: true });
        }
        for (var k = 0; k < out.length; k++) {
            var o = out[k];
            o.spread = (o.buy > 0 && o.sell > 0 && o.buy >= o.sell) ? (o.buy - o.sell) / o.buy * 100 : NaN;
        }
        var key = sortKey, asc = sortAsc;
        out.sort(function(a, b) {
            var x = key === "name" ? a.name.toLowerCase() : a[key];
            var y = key === "name" ? b.name.toLowerCase() : b[key];
            var xm = x === undefined || (typeof x === "number" && isNaN(x));
            var ym = y === undefined || (typeof y === "number" && isNaN(y));
            if (xm !== ym) return xm ? 1 : -1;      // rows without a value go last
            if (x < y) return asc ? -1 : 1;
            if (x > y) return asc ? 1 : -1;
            return 0;
        });
        return out;
    }

    readonly property var stats: {
        var buys = [], sells = [];
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].buy > 0) buys.push(rows[i].buy);
            if (rows[i].sell > 0) sells.push(rows[i].sell);
        }
        function avg(a) { return a.length ? a.reduce(function(s, v) { return s + v; }, 0) / a.length : NaN; }
        var all = buys.concat(sells);
        return { avgBuy: avg(buys), avgSell: avg(sells), mid: avg(all), count: all.length,
                 bestBuy: buys.length ? Math.min.apply(null, buys) : NaN,
                 bestSell: sells.length ? Math.max.apply(null, sells) : NaN };
    }

    function money(v, decimals) {
        if (!(v > 0)) return "—";
        return pair.symbol + Number(v).toLocaleString(Qt.locale("en_US"), "f", decimals === undefined ? pair.decimals : decimals) + pair.suffix;
    }
    function minText(v) {
        if (!(v > 0)) return "—";
        return (pair.key === "eur" ? "€" : "$") + Number(v).toLocaleString(Qt.locale("en_US"), "f", 2);
    }

    function onPageCompleted() {
        refresh(false);
    }

    Timer {
        // while the page is open the board refreshes every minute
        interval: 60000
        repeat: true
        running: page.visible && page.pricesEnabled
        onTriggered: page.refresh(true)
    }

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color good: dark ? "#5FD08F" : "#1E8E4E"
    readonly property color sellColor: dark ? "#FF9A4D" : "#C25A00"

    function badgeColors(p) {
        switch (p) {
        case "A": return { fill: dark ? "#1A3A26" : "#D6EEDD", line: dark ? "#3E8A5A" : "#2E7D4A", text: dark ? "#6FE09A" : "#1E6E3E" };
        case "B": return { fill: dark ? "#1A2A44" : "#D8E4F6", line: dark ? "#3E6AAA" : "#2F5FA8", text: dark ? "#8DB6FF" : "#244E92" };
        case "C": return { fill: dark ? "#3A2E10" : "#F6EAC8", line: dark ? "#9A7A28" : "#A87A10", text: dark ? "#FFC23D" : "#7A5600" };
        default:  return { fill: dark ? "#2A2C30" : "#E2E4E6", line: dark ? "#45484E" : "#9A9EA4", text: dark ? "#C8CCD2" : "#3A3E44" };
        }
    }

    // column widths shared by the header and the rows
    readonly property int nameW: 190
    readonly property int privW: 70
    readonly property int spreadW: 80
    readonly property int minW: 100
    readonly property int timeW: 80

    component HeaderCell: MoneroComponents.TextPlain {
        property string key: ""
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        horizontalAlignment: Text.AlignRight
        text: ""
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: page.sortKey === key ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        MouseArea {
            anchors.fill: parent
            enabled: parent.key !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (page.sortKey === parent.key) page.sortAsc = !page.sortAsc;
                else { page.sortKey = parent.key; page.sortAsc = parent.key !== "sell"; }
            }
        }
    }

    component Cell: MoneroComponents.TextPlain {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        horizontalAlignment: Text.AlignRight
        font.family: MoneroComponents.Style.fontMonoMedium.name
        font.pixelSize: 15
        color: MoneroComponents.Style.defaultFontColor
        themeTransition: false
    }

    function arrow(key) { return sortKey === key ? (sortAsc ? " ▲" : " ▼") : ""; }

    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 20

        MoneroComponents.MarketsNavbar { current: "SwapsNoKyc" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            MoneroComponents.LabelSubheader {
                Layout.fillWidth: true
                fontSize: 24
                text: "Swaps No-KYC"
            }
            MoneroComponents.TextPlain {
                text: page.pending > 0 ? qsTr("Actualizando…") : (page.lastUpdate !== "" ? qsTr("Actualizado %1").arg(page.lastUpdate) : "")
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.StandardButton {
                small: true
                enabled: page.pending === 0 && page.pricesEnabled
                text: qsTr("Actualizar")
                onClicked: page.refresh(true)
            }
        }

        // price conversion off: nothing is asked
        RowLayout {
            visible: !page.pricesEnabled
            Layout.fillWidth: true
            spacing: 16
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Los precios están apagados. Se encienden junto con la conversión de precio en Ajustes > Nodo / Red.")
                font.pixelSize: 14
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
            MoneroComponents.StandardButton {
                small: true
                text: qsTr("Abrir ajustes")
                onClicked: {
                    middlePanel.settingsView.settingsStateViewState = "Node";
                    appWindow.showPageRequest("Settings");
                }
            }
        }

        // pair selector
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Repeater {
                model: page.pairs
                delegate: Rectangle {
                    readonly property bool active: index === page.pairIndex
                    width: pairText.implicitWidth + 40
                    height: 36
                    radius: 18
                    color: active ? MoneroComponents.Style.orange : "transparent"
                    border.width: 1
                    border.color: active || pairArea.containsMouse ? MoneroComponents.Style.orange : MoneroComponents.Style.dimmedFontColor
                    MoneroComponents.TextPlain {
                        id: pairText
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 15
                        color: parent.active ? (page.dark ? "#000000" : "#FFFFFF") : MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                    }
                    MouseArea {
                        id: pairArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.pairIndex = index
                    }
                }
            }
        }

        // average buy | market price | average sell
        Item {
            Layout.fillWidth: true
            implicitHeight: hero.implicitHeight + 36
            MoneroComponents.CardPanel { anchors.fill: parent }
            RowLayout {
                id: hero
                anchors.fill: parent
                anchors.margins: 18
                spacing: 18
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 4
                    MoneroComponents.TextPlain {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("Precio medio de compra")
                        font.pixelSize: 11; font.letterSpacing: 1; font.capitalization: Font.AllUppercase
                        color: MoneroComponents.Style.dimmedFontColor; themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        Layout.alignment: Qt.AlignRight
                        text: page.unavailable ? "—" : page.money(page.stats.avgBuy)
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 26
                        color: page.good; themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("%1 → XMR · pagas por XMR").arg(page.pair.key === "btc" ? "BTC" : (page.pair.key === "eur" ? "EUR" : "USD"))
                        font.pixelSize: 11; color: MoneroComponents.Style.dimmedFontColor; themeTransition: false
                    }
                }
                Rectangle { Layout.fillHeight: true; width: 1; color: MoneroComponents.Style.orange; opacity: 0.35 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1.4
                    spacing: 4
                    MoneroComponents.TextPlain {
                        Layout.alignment: Qt.AlignHCenter
                        text: page.pair.label
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 12; font.letterSpacing: 2
                        color: MoneroComponents.Style.orange; themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        Layout.alignment: Qt.AlignHCenter
                        text: page.unavailable ? "—" : page.money(page.stats.mid)
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 40
                        color: MoneroComponents.Style.defaultFontColor; themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        Layout.alignment: Qt.AlignHCenter
                        text: page.unavailable ? qsTr("Falta el cambio USD → EUR (conversión de precio en Ajustes)")
                                               : qsTr("precio de mercado · media de %1 precios · %2 exchanges").arg(page.stats.count).arg(page.rows.length)
                        font.pixelSize: 11; color: MoneroComponents.Style.dimmedFontColor; themeTransition: false
                    }
                }
                Rectangle { Layout.fillHeight: true; width: 1; color: MoneroComponents.Style.orange; opacity: 0.35 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 4
                    MoneroComponents.TextPlain {
                        text: qsTr("Precio medio de venta")
                        font.pixelSize: 11; font.letterSpacing: 1; font.capitalization: Font.AllUppercase
                        color: MoneroComponents.Style.dimmedFontColor; themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        text: page.unavailable ? "—" : page.money(page.stats.avgSell)
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 26
                        color: page.sellColor; themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        text: qsTr("XMR → %1 · recibes por XMR").arg(page.pair.key === "btc" ? "BTC" : (page.pair.key === "eur" ? "EUR" : "USD"))
                        font.pixelSize: 11; color: MoneroComponents.Style.dimmedFontColor; themeTransition: false
                    }
                }
            }
        }

        // the board
        Item {
            Layout.fillWidth: true
            implicitHeight: board.implicitHeight + 16
            MoneroComponents.CardPanel { anchors.fill: parent }
            ColumnLayout {
                id: board
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 8
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: page.dark ? "#0DFFFFFF" : "#0A000000"
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                        height: 1; color: MoneroComponents.Style.orange; opacity: 0.45
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 12
                        HeaderCell { key: "name"; Layout.fillWidth: false; Layout.preferredWidth: page.nameW; horizontalAlignment: Text.AlignLeft; text: qsTr("Exchange") + page.arrow("name") }
                        HeaderCell { Layout.fillWidth: false; Layout.preferredWidth: page.privW; horizontalAlignment: Text.AlignHCenter; text: qsTr("Privacidad") }
                        HeaderCell { key: "buy"; text: qsTr("Compra (%1)").arg(page.pair.unit) + page.arrow("buy") }
                        HeaderCell { key: "sell"; text: qsTr("Venta (%1)").arg(page.pair.unit) + page.arrow("sell") }
                        HeaderCell { key: "spread"; Layout.fillWidth: false; Layout.preferredWidth: page.spreadW; text: qsTr("Spread") + page.arrow("spread") }
                        HeaderCell { key: "min"; Layout.fillWidth: false; Layout.preferredWidth: page.minW; text: qsTr("Mínimo") + page.arrow("min") }
                        HeaderCell { Layout.fillWidth: false; Layout.preferredWidth: page.timeW; text: qsTr("Hora") }
                    }
                }

                Repeater {
                    model: page.unavailable ? [] : page.rows
                    delegate: Rectangle {
                        id: row
                        Layout.fillWidth: true
                        implicitHeight: 54
                        color: rowArea.containsMouse ? (page.dark ? "#10FFFFFF" : "#0C000000")
                               : (index % 2 === 1 ? (page.dark ? "#06FFFFFF" : "#05000000") : "transparent")
                        // NonKYC (order book, not a swap service) stands out with an orange edge
                        Rectangle {
                            visible: modelData.nonKyc
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: 3; color: MoneroComponents.Style.orange
                        }
                        MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 12
                            RowLayout {
                                Layout.preferredWidth: page.nameW
                                Layout.maximumWidth: page.nameW
                                spacing: 8
                                MoneroComponents.TextPlain {
                                    Layout.maximumWidth: page.nameW - 26
                                    elide: Text.ElideRight
                                    text: modelData.name
                                    font.family: MoneroComponents.Style.fontMonoMedium.name
                                    font.pixelSize: 16
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }
                                MoneroComponents.TextPlain {
                                    visible: modelData.url !== ""
                                    text: "↗"
                                    font.pixelSize: 16
                                    color: linkArea.containsMouse ? MoneroComponents.Style.orange : MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                    MouseArea {
                                        id: linkArea
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally(modelData.url)
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Item {
                                Layout.preferredWidth: page.privW
                                implicitHeight: 30
                                Rectangle {
                                    readonly property var c: page.badgeColors(modelData.privacy)
                                    anchors.centerIn: parent
                                    width: 34; height: 26; radius: 5
                                    color: c.fill
                                    border.width: 1
                                    border.color: c.line
                                    MoneroComponents.TextPlain {
                                        anchors.centerIn: parent
                                        text: modelData.privacy !== "" ? modelData.privacy : "—"
                                        font.family: MoneroComponents.Style.fontMonoBold.name
                                        font.pixelSize: 14
                                        color: parent.c.text
                                        themeTransition: false
                                    }
                                }
                            }
                            Cell {
                                text: page.money(modelData.buy)
                                color: Math.abs(modelData.buy - page.stats.bestBuy) < 1e-12 ? page.good : MoneroComponents.Style.defaultFontColor
                                font.bold: Math.abs(modelData.buy - page.stats.bestBuy) < 1e-12
                            }
                            Cell {
                                text: page.money(modelData.sell)
                                color: Math.abs(modelData.sell - page.stats.bestSell) < 1e-12 ? page.good : MoneroComponents.Style.defaultFontColor
                                font.bold: Math.abs(modelData.sell - page.stats.bestSell) < 1e-12
                            }
                            Cell {
                                Layout.fillWidth: false
                                Layout.preferredWidth: page.spreadW
                                text: isNaN(modelData.spread) ? "—" : modelData.spread.toFixed(2) + "%"
                                color: MoneroComponents.Style.dimmedFontColor
                            }
                            Cell {
                                Layout.fillWidth: false
                                Layout.preferredWidth: page.minW
                                text: page.minText(modelData.min)
                            }
                            Cell {
                                Layout.fillWidth: false
                                Layout.preferredWidth: page.timeW
                                text: modelData.time
                                font.pixelSize: 12
                                color: MoneroComponents.Style.dimmedFontColor
                            }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                            height: 1; color: MoneroComponents.Style.defaultFontColor; opacity: 0.07
                        }
                    }
                }

                MoneroComponents.TextPlain {
                    visible: page.rows.length === 0 || page.unavailable
                    Layout.leftMargin: 18
                    Layout.topMargin: 14
                    Layout.bottomMargin: 6
                    text: page.unavailable ? qsTr("Sin el cambio USD → EUR no se puede mostrar en euros.")
                          : page.pending > 0 ? qsTr("Cargando…")
                          : page.mpnError !== "" ? qsTr("No se pudo leer MoneroPriceNow: %1").arg(page.mpnError)
                          : qsTr("Sin precios todavía.")
                    font.pixelSize: 13
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    Layout.leftMargin: 18
                    Layout.rightMargin: 18
                    Layout.topMargin: 12
                    Layout.bottomMargin: 8
                    wrapMode: Text.WordWrap
                    text: qsTr("Compra: lo que pagas por 1 XMR. Venta: lo que recibes por 1 XMR. En verde el mejor de cada columna. Privacidad según MoneroPriceNow: A sin registros y nunca KYC, B pocos registros y KYC solo si algo es sospechoso, C algunos registros y KYC probable en cantidades grandes, V depende del proveedor (agregadores). NonKYC es un exchange con libro de órdenes: su compra y venta son el mejor ask y bid, sin comisiones. Los precios en EUR son los de USDT convertidos con el cambio de la app.")
                          + (page.nonKycError !== "" ? " " + qsTr("NonKYC: %1").arg(page.nonKycError) : "")
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                MoneroComponents.TextPlain {
                    Layout.leftMargin: 18
                    Layout.bottomMargin: 10
                    text: qsTr("Datos de moneropricenow.com y nonkyc.io · 2 peticiones por actualización")
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }
        }
    }
}
