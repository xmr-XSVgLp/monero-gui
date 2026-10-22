import QtQuick
import QtQuick.Layouts
import "." as UI
import "../js/TransactionPrices.js" as Prices
import "../js/Utils.js" as Utils

Rectangle {
    id: root
    property real transactionTime: 0
    property real transactionAmount: 0
    property string source: "coingecko"
    property string sourceName: "CoinGecko"
    property string pair: "usd"
    property var market
    property bool pricesEnabled: false
    property real now: Date.now() / 1000
    readonly property var quote: Prices.compare(market ? market.cache : {}, pair, transactionTime, now, source)
    readonly property bool fresh: pricesEnabled && quote.latest && now - quote.latest[0] <= 1800
    implicitHeight: content.implicitHeight + 20
    radius: 9
    color: UI.Style.blackTheme ? "#15221C" : "#D5DFD8"
    border.color: UI.Style.blackTheme ? "#2C4234" : "#B7C7BD"
    function price(point) { return point ? Utils.prettyAmount(point[1].toFixed(pair === "btc" ? 6 : 2)) + " " + pair.toUpperCase() : "—"; }
    function amountValue(point) {
        var value = Prices.value(point, transactionAmount);
        return value === null ? "—" : Utils.prettyAmount(value.toFixed(pair === "btc" ? 8 : 2)) + " " + pair.toUpperCase();
    }
    function date(point) { return point ? Qt.formatDateTime(new Date(point[0] * 1000), "dd/MM/yyyy HH:mm") : qsTr("No data available"); }
    function requestPrices() {
        if (!market || !pricesEnabled || !source) return;
        [1, 90, 365].forEach(function(days) {
            var key = market.keyFor(source, pair, days);
            if (market.isStale(key)) market.enqueue(key, false);
        });
    }
    Component.onCompleted: requestPrices()
    Connections {
        target: root.market || null
        function onCacheChanged() { root.now = Date.now() / 1000; }
    }
    onMarketChanged: { now = Date.now() / 1000; requestPrices(); }
    onTransactionTimeChanged: requestPrices()
    onPairChanged: requestPrices()
    onSourceChanged: requestPrices()
    onPricesEnabledChanged: requestPrices()
    Timer { interval: 60000; running: root.visible; repeat: true; onTriggered: root.now = Date.now() / 1000 }

    component Metric: ColumnLayout {
        property string caption
        property string amount
        property color valueColor: UI.Style.defaultFontColor
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        UI.TextPlain { Layout.fillWidth: true; text: caption; font.pixelSize: 12; color: UI.Style.dimmedFontColor; themeTransition: false; wrapMode: Text.WordWrap }
        UI.TextPlain { Layout.fillWidth: true; text: amount; font.pixelSize: 17; font.bold: true; color: valueColor; themeTransition: false; wrapMode: Text.WrapAnywhere }
    }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 8
        UI.TextPlain {
            Layout.fillWidth: true
            text: qsTr("XMR market price") + " · " + root.pair.toUpperCase()
            font.pixelSize: 13; font.bold: true
            color: UI.Style.defaultFontColor; themeTransition: false
        }
        UI.TextPlain {
            Layout.fillWidth: true
            text: "Histórico ≈ " + root.date(root.quote.historical) + "  ·  Última cotización: " + root.date(root.quote.latest)
            font.pixelSize: 11; color: UI.Style.dimmedFontColor; themeTransition: false; wrapMode: Text.WordWrap
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width < 560 ? 1 : 3
            columnSpacing: 16; rowSpacing: 8
            uniformCellWidths: true
            Metric { caption: qsTr("At transaction time ≈"); amount: root.price(root.quote.historical) }
            Metric { caption: root.fresh ? qsTr("Current price") : qsTr("Last available price"); amount: root.price(root.quote.latest) }
            Metric {
                caption: qsTr("Price change")
                amount: root.quote.change === null ? "—" : (root.quote.change > 0 ? "+" : "") + root.quote.change.toFixed(2) + "%"
                valueColor: root.quote.change === null || root.quote.change === 0 ? UI.Style.defaultFontColor
                    : root.quote.change > 0 ? (UI.Style.blackTheme ? "#65CA92" : "#21633D") : (UI.Style.blackTheme ? "#E38787" : "#A43535")
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width < 560 ? 1 : 3
            columnSpacing: 16; rowSpacing: 8
            uniformCellWidths: true
            Metric { caption: "Valor del importe entonces ≈"; amount: root.amountValue(root.quote.historical) }
            Metric { caption: root.fresh ? "Valor del importe hoy ≈" : "Valor con el último precio ≈"; amount: root.amountValue(root.quote.latest) }
            Metric { caption: "Importe de la transacción"; amount: Math.abs(root.transactionAmount).toFixed(12).replace(/0+$/, "").replace(/\.$/, "") + " XMR" }
        }
        UI.TextPlain {
            Layout.fillWidth: true
            text: root.sourceName + " · " + "Histórico aproximado · Importe sin comisión · La variación no representa ganancias ni pérdidas realizadas."
                + (root.pricesEnabled ? "" : " " + qsTr("Price connections are disabled; showing saved data."))
            font.pixelSize: 11; color: UI.Style.dimmedFontColor; themeTransition: false; wrapMode: Text.WordWrap
        }
    }
}
