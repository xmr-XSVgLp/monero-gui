import QtQuick
import QtQuick.Layouts
import "." as UI

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 16
    UI.CheckBox {
        text: "Activar precios, mercados y cotizaciones de swaps"
        checked: persistentSettings.fiatPriceEnabled
        toggleOnClick: false
        enabled: !persistentSettings.extremePrivacy
        onClicked: {
            persistentSettings.fiatRatesConsentGiven = true;
            persistentSettings.fiatPriceEnabled = !persistentSettings.fiatPriceEnabled;
            if (persistentSettings.fiatPriceEnabled) appWindow.fiatApiRefresh();
        }
    }
    UI.TextPlain {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Las consultas usan la red elegida para la wallet (Tor o Nym). Desactivar una fuente impide nuevas consultas a ese servicio; las solicitudes ya enviadas pueden terminar. Los datos guardados se conservan."
        color: UI.Style.dimmedFontColor
        font.pixelSize: 12
    }
    UI.TextPlain { text: "Monedas principales"; font.bold: true; font.pixelSize: 16 }
    UI.TextPlain {
        Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12
        text: "Elige tus favoritas y la moneda principal para saldos, transacciones y mercados. Puedes conservar una sola favorita."
        color: UI.Style.dimmedFontColor
    }
    Flow {
        Layout.fillWidth: true
        spacing: 16
        Repeater {
            model: appWindow.fiatCurrencies.concat(["BTC"])
            delegate: UI.CheckBox {
                text: modelData
                checked: appWindow.favoriteCurrencies.indexOf(modelData) >= 0
                toggleOnClick: false
                enabled: !checked || appWindow.favoriteCurrencies.length > 1
                onClicked: appWindow.setFavoriteCurrency(modelData, !checked)
            }
        }
    }
    UI.StandardDropdown {
        id: currency
        Layout.preferredWidth: 240
        labelText: "Moneda principal"
        dataModel: favoriteModel
        onChanged: if (currentIndex >= 0 && currentIndex < favoriteModel.count)
            persistentSettings.fiatPriceCurrency = "xmr" + favoriteModel.get(currentIndex).column1.toLowerCase()
    }
    ListModel { id: favoriteModel }
    function updateCurrencies() {
        favoriteModel.clear();
        appWindow.favoriteCurrencies.forEach(function(c) { favoriteModel.append({column1:c}); });
        currency.currentIndex = Math.max(0, appWindow.favoriteCurrencies.indexOf(appWindow.fiatApiCurrencySymbol()));
    }
    Component.onCompleted: updateCurrencies()
    Connections {
        target: persistentSettings
        function onFavoriteCurrenciesJsonChanged() { root.updateCurrencies(); }
        function onFiatPriceCurrencyChanged() { root.updateCurrencies(); }
    }
    UI.TextPlain { text: "Fuentes de precios y servicios"; font.bold: true; font.pixelSize: 16 }
    Repeater {
        model: appWindow.priceSources
        delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                UI.CheckBox {
                    text: modelData.name
                    checked: appWindow.priceSourceEnabled(modelData.key)
                    toggleOnClick: false
                    onClicked: appWindow.setPriceSourceEnabled(modelData.key, !checked)
                }
                Item { Layout.fillWidth: true }
                UI.StandardButton {
                    visible: modelData.ticker
                    small: true
                    text: persistentSettings.fiatPriceProvider === modelData.key ? "PRINCIPAL" : "USAR COMO PRINCIPAL"
                    enabled: appWindow.priceSourceEnabled(modelData.key) && persistentSettings.fiatPriceProvider !== modelData.key
                    onClicked: persistentSettings.fiatPriceProvider = modelData.key
                }
            }
            UI.TextPlain {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12
                color: UI.Style.dimmedFontColor
                text: modelData.host + " · " + modelData.use
            }
        }
    }
    UI.TextPlain {
        Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12
        color: UI.Style.dimmedFontColor
        text: "La principal se usa para el precio actual. Si no ofrece el histórico de la moneda elegida, se usa otra fuente histórica activada y se indica su nombre. Sin una fuente compatible, se muestra «sin datos»."
    }
}
