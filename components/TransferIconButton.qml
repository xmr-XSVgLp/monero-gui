import QtQuick

import FontAwesome

import "../components" as MoneroComponents

// Small square icon button in the card style (Send page tools: QR, address book, send all, remove).
Item {
    id: root

    property alias text: icon.text
    property string fontFamily: FontAwesome.fontFamilySolid
    property string fontStyleName: "Solid"
    property int fontPixelSize: 14
    property alias tooltip: tip.text
    property alias tooltipLeft: tip.tooltipLeft
    readonly property bool hovered: mouse.containsMouse && root.enabled
    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    opacity: enabled ? 1 : 0.35

    function doClick() {
        if (tip.text) tip.tooltipPopup.close();
        root.clicked();
    }

    MoneroComponents.CardPanel {
        anchors.fill: parent
        cut: 6
        idleLine: 0.35
        selected: root.hovered || root.activeFocus
    }

    MoneroComponents.TextPlain {
        id: icon
        anchors.centerIn: parent
        font.family: root.fontStyleName === "Solid" ? FontAwesome.fontFamilySolid : root.fontFamily
        font.styleName: root.fontStyleName
        font.pixelSize: root.fontPixelSize
        color: MoneroComponents.Style.defaultFontColor
        opacity: root.hovered ? 1 : 0.8
        themeTransition: false
    }

    MoneroComponents.Tooltip {
        id: tip
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: if (tip.text) tip.tooltipPopup.open()
        onExited: if (tip.text) tip.tooltipPopup.close()
        onClicked: root.doClick()
    }

    Keys.enabled: root.visible
    Keys.onSpacePressed: doClick()
    Keys.onEnterPressed: doClick()
    Keys.onReturnPressed: doClick()
}
