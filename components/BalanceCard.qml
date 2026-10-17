import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents
import "../js/Utils.js" as Utils

// Total balance of all accounts, drawn like the wallet card: chamfered neon panel,
// XMR amounts in mono with their fiat value, and the XMR price with its 7-day change.
Item {
    id: root
    property string titleText: ""
    property string unlockedLabel: ""
    property string balanceText: ""
    property string unlockedText: ""
    property bool fiatEnabled: false
    property string fiatSymbol: ""
    property string fiatTotal: "?.??"
    property string fiatUnlocked: "?.??"
    property string priceText: "?.??"   // fiat value of 1 XMR
    property string priceBtcText: ""    // BTC for 1 XMR (Wagyu quote), empty to hide
    property real change7d: NaN         // percent
    property real change24h: NaN        // percent
    property string change24hLabel: ""
    property string priceLabel: ""
    property string changeLabel: ""
    property string chipTotal: fiatTotal     // amount in the top-right chip
    property string chipSymbol: fiatSymbol
    property bool chipToggleable: false      // click switches the chip currency
    property string btcTotal: ""             // total in BTC (Wagyu quote), empty to hide the BTC chip
    readonly property color btcOrange: MoneroComponents.Style.blackTheme ? "#F7931A" : "#D9780A"
    signal copyRequested(string amount)
    signal chipClicked()

    implicitHeight: content.implicitHeight + 40

    readonly property bool compact: width < 620
    // muted green accents and white borders (the theme neon green is too strong here)
    readonly property color accent: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
    readonly property color border: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"

    // price change cell: label over trend arrow + percent
    component ChangeCell: ColumnLayout {
        property real value: NaN
        property string label: ""
        spacing: 2
        readonly property bool known: !isNaN(value)
        readonly property bool up: known && value >= 0
        readonly property color trend: !known ? MoneroComponents.Style.dimmedFontColor
                                      : up ? (MoneroComponents.Style.blackTheme ? "#5FD08F" : "#1E8E4E")
                                      : (MoneroComponents.Style.blackTheme ? "#FF6B6B" : "#C62828")
        id: cell

        MoneroComponents.TextPlain {
            Layout.alignment: Qt.AlignRight
            text: cell.label
            font.family: MoneroComponents.Style.fontRegular.name
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 6

            // trend arrow
            Canvas {
                visible: cell.known
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                property bool up: cell.up
                property color c: cell.trend
                onUpChanged: requestPaint()
                onCChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = c;
                    ctx.lineWidth = 1.8;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    if (up) {
                        ctx.moveTo(2, 12); ctx.lineTo(12, 2);
                        ctx.moveTo(5, 2); ctx.lineTo(12, 2); ctx.lineTo(12, 9);
                    } else {
                        ctx.moveTo(2, 2); ctx.lineTo(12, 12);
                        ctx.moveTo(5, 12); ctx.lineTo(12, 12); ctx.lineTo(12, 5);
                    }
                    ctx.stroke();
                }
            }

            MoneroComponents.TextPlain {
                text: cell.known
                      ? (cell.value > 0 ? "+" : "") + cell.value.toFixed(1) + " %"
                      : "—"
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 15
                color: cell.trend
                themeTransition: false
            }
        }
    }

    // panel
    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 16
        accent: root.border
        lineOpacity: 0.85
        fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#EEF4EF"
        fillOpacity: MoneroComponents.Style.blackTheme ? 0.95 : 0.92
        glow: 0.25
    }

    // faint scanlines over the panel
    Canvas {
        anchors.fill: parent
        anchors.margins: 2
        opacity: MoneroComponents.Style.blackTheme ? 0.07 : 0.05
        property color c: root.accent
        onCChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = c;
            for (var y = 0; y < height; y += 3)
                ctx.fillRect(0, y, width, 1);
        }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 22

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // title + fiat total next to it
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 6; height: 6
                    color: root.accent
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 900 }
                        NumberAnimation { to: 1.0; duration: 900 }
                    }
                }

                MoneroComponents.TextPlain {
                    text: root.titleText.toUpperCase()
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 14
                    font.letterSpacing: 2
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }

                Item {
                    visible: root.fiatEnabled
                    implicitWidth: fiatTotalText.implicitWidth + 28
                    implicitHeight: fiatTotalText.implicitHeight + 12

                    MoneroComponents.NeonFrame {
                        anchors.fill: parent
                        cut: 7
                        accent: root.border
                        fillColor: root.accent
                        lineOpacity: chipMouse.containsMouse ? 1.0 : 0.7
                        fillOpacity: chipMouse.containsMouse ? 0.18 : 0.10
                        glow: chipMouse.containsMouse ? 0.6 : 0.0
                        ticks: false
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        enabled: root.chipToggleable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chipClicked()
                    }

                    MoneroComponents.TextPlain {
                        id: fiatTotalText
                        anchors.centerIn: parent
                        text: "≈ " + Utils.prettyAmount(root.chipTotal) + " " + root.chipSymbol
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 18
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                    }
                }

                // total in BTC, Bitcoin orange
                Item {
                    visible: root.btcTotal !== ""
                    Layout.leftMargin: 8
                    implicitWidth: btcTotalText.implicitWidth + 28
                    implicitHeight: btcTotalText.implicitHeight + 12

                    MoneroComponents.NeonFrame {
                        anchors.fill: parent
                        cut: 7
                        accent: root.btcOrange
                        fillColor: root.btcOrange
                        lineOpacity: 0.9
                        fillOpacity: 0.16
                        glow: 0.35
                        ticks: false
                    }

                    MoneroComponents.TextPlain {
                        id: btcTotalText
                        anchors.centerIn: parent
                        text: "≈ " + Utils.prettyAmountRich(root.btcTotal, Math.round(font.pixelSize * 0.65)) + " BTC"
                        textFormat: Text.RichText
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 18
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                    }
                }
            }

            // total balance (XMR)
            MoneroComponents.TextPlain {
                id: balanceValue
                Layout.topMargin: 4
                Layout.fillWidth: true
                text: Utils.prettyAmountRich(root.balanceText, Math.round(font.pixelSize * 0.65))
                textFormat: Text.RichText
                elide: Text.ElideRight
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: root.compact ? 22 : 28
                color: balanceMouse.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.defaultFontColor
                themeTransition: false

                MouseArea {
                    id: balanceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyRequested(root.balanceText.slice(0, -4))
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 4
                height: 1
                color: root.accent
                opacity: 0.3
            }

            // unlocked balance
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                MoneroComponents.TextPlain {
                    text: root.unlockedLabel
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 15
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    id: unlockedValue
                    text: Utils.prettyAmountRich(root.unlockedText, Math.round(font.pixelSize * 0.65))
                    textFormat: Text.RichText
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 15
                    color: unlockedMouse.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.defaultFontColor
                    themeTransition: false

                    MouseArea {
                        id: unlockedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyRequested(root.unlockedText.slice(0, -4))
                    }
                }

                MoneroComponents.TextPlain {
                    visible: root.fiatEnabled
                    text: "≈ " + Utils.prettyAmount(root.fiatUnlocked) + " " + root.fiatSymbol
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 15
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            // XMR price and 7-day change
            Item {
                visible: root.fiatEnabled
                Layout.fillWidth: true
                Layout.topMargin: 12
                implicitHeight: ticker.implicitHeight + 20

                MoneroComponents.NeonFrame {
                    anchors.fill: parent
                    cut: 10
                    accent: root.border
                    lineOpacity: 0.45
                    fillColor: MoneroComponents.Style.blackTheme ? "#16231A" : "#DDE9E0"
                    fillOpacity: MoneroComponents.Style.blackTheme ? 0.9 : 0.9
                    ticks: false
                }

                RowLayout {
                    id: ticker
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 14

                    Image {
                        // round app-icon logo with its glowing ring (the glow takes the outer margin)
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.leftMargin: -6
                        Layout.rightMargin: -6
                        source: "qrc:///images/xmr-ticker.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }

                    ColumnLayout {
                        spacing: 2
                        MoneroComponents.TextPlain {
                            text: "Monero"
                            font.family: MoneroComponents.Style.fontMedium.name
                            font.pixelSize: 15
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            text: "XMR"
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            font.pixelSize: 12
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                    }

                    Item { Layout.preferredWidth: 6 }

                    ColumnLayout {
                        spacing: 2
                        MoneroComponents.TextPlain {
                            text: root.priceLabel
                            font.family: MoneroComponents.Style.fontRegular.name
                            font.pixelSize: 12
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            text: "1 XMR = " + Utils.prettyAmount(root.priceText) + " " + root.fiatSymbol
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 15
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                    }

                    Item { Layout.preferredWidth: 18; visible: root.priceBtcText !== "" }

                    ColumnLayout {
                        spacing: 2
                        visible: root.priceBtcText !== ""
                        MoneroComponents.TextPlain {
                            text: "XMR/BTC · Wagyu"
                            font.family: MoneroComponents.Style.fontRegular.name
                            font.pixelSize: 12
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            text: Utils.prettyAmountRich(root.priceBtcText, Math.round(font.pixelSize * 0.65)) + " BTC"
                            textFormat: Text.RichText
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 15
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ChangeCell {
                        value: root.change24h
                        label: root.change24hLabel
                    }

                    Item { Layout.preferredWidth: 18 }

                    ChangeCell {
                        value: root.change7d
                        label: root.changeLabel
                    }
                }
            }
        }
    }
}
