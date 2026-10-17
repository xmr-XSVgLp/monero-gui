import QtQuick

import FontAwesome

import "../components" as MoneroComponents

// Small chamfered icon button for card rows (address book, transaction history).
// Shows either an image (`image`) or a FontAwesome glyph (`icon` + `iconFamily`).
// With interactive: false it draws only; put your own MouseArea inside and drive `hovered`.
Item {
    id: btn
    property string image: ""
    property string icon: ""
    property string iconFamily: FontAwesome.fontFamily
    property string iconStyle: ""
    property int iconSize: 14
    property real imageScale: 0.62
    property string tooltip: ""
    property bool tooltipLeft: true
    property bool interactive: true
    property bool hovered: interactive && mouse.containsMouse
    property alias tooltipPopup: tip.tooltipPopup
    signal clicked()

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"

    implicitWidth: 30
    implicitHeight: 30
    opacity: enabled ? 1.0 : 0.35

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 6
        accent: btn.border
        lineOpacity: btn.hovered ? 0.9 : 0.28
        fillColor: btn.accent
        fillOpacity: btn.hovered ? 0.22 : 0.0
        glow: btn.hovered ? 0.4 : 0.0
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 120 } }
    }

    Image {
        visible: btn.image !== ""
        anchors.centerIn: parent
        source: btn.image
        height: Math.round(parent.height * btn.imageScale)
        width: sourceSize.height > 0 ? Math.round(height * sourceSize.width / sourceSize.height) : height
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: btn.hovered ? 1.0 : 0.85
    }

    MoneroComponents.TextPlain {
        visible: btn.image === "" && btn.icon !== ""
        anchors.centerIn: parent
        text: btn.icon
        font.family: btn.iconFamily
        font.styleName: btn.iconStyle
        font.pixelSize: btn.iconSize
        color: btn.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
        themeTransition: false
    }

    MouseArea {
        id: mouse
        visible: btn.interactive
        enabled: btn.interactive
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
        onEntered: if (btn.tooltip) tip.tooltipPopup.open()
        onExited: tip.tooltipPopup.close()
    }

    MoneroComponents.Tooltip {
        id: tip
        anchors.fill: parent
        tooltipLeft: btn.tooltipLeft
        text: btn.tooltip
    }
}
