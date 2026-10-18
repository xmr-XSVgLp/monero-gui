import QtQuick
import QtQuick.Layouts

import "../../components" as MoneroComponents

// One line of the Security page: status dot, title, detail text and optional controls on the right.
RowLayout {
    id: row
    default property alias controls: side.data
    property string title: ""
    property string detail: ""
    property string tag: ""
    property color dot: MoneroComponents.Style.dimmedFontColor
    Layout.fillWidth: true
    spacing: 14

    Rectangle {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 6
        width: 8; height: 8; radius: 4
        color: row.dot
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MoneroComponents.TextPlain {
                text: row.title
                font.pixelSize: 14
                font.bold: true
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                visible: row.tag !== ""
                text: row.tag
                font.pixelSize: 11
                font.family: MoneroComponents.Style.fontMonoRegular.name
                color: row.dot
                themeTransition: false
            }
            Item { Layout.fillWidth: true }
        }
        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            visible: row.detail !== ""
            text: row.detail
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }
    }

    RowLayout {
        id: side
        Layout.alignment: Qt.AlignTop
        spacing: 8
    }
}
