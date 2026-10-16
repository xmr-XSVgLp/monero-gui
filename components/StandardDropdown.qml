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
import QtQuick.Effects

import FontAwesome

import "../components" as MoneroComponents
import "../components/effects/" as MoneroEffects

ColumnLayout {
    id: dropdown
    Layout.fillWidth: true

    property int itemTopMargin: 0
    property alias dataModel: repeater.model
    property string shadowPressedColor
    property string shadowReleasedColor
    property string pressedColor: MoneroComponents.Style.blackTheme ? "#000000" : "#FFFFFF"
    property string releasedColor: Qt.rgba(dropdown.accent.r, dropdown.accent.g, dropdown.accent.b, 0.16)
    property string textColor: MoneroComponents.Style.defaultFontColor
    property alias currentIndex: columnid.currentIndex
    readonly property alias expanded: popup.visible
    property alias labelText: dropdownLabel.text
    property alias labelColor: dropdownLabel.color
    property alias labelTextFormat: dropdownLabel.textFormat
    property alias labelWrapMode: dropdownLabel.wrapMode
    property alias labelHorizontalAlignment: dropdownLabel.horizontalAlignment
    property bool showingHeader: dropdownLabel.text !== ""
    property int labelFontSize: 14
    property bool labelFontBold: false
    property int dropdownHeight: 39
    property int maxDropdownItems: 0
    property int fontSize: 14
    property int fontItemSize: 14
    property string colorBorder: MoneroComponents.Style.inputBorderColorInActive
    property string colorHeaderBackground: "transparent"
    property bool headerBorder: true
    property bool headerFontBold: false

    readonly property color accent: MoneroComponents.Style.orange
    readonly property bool lit: dropArea.containsMouse || dropdown.expanded

    property real maxAvailableDropdownHeight: Number.POSITIVE_INFINITY

    function updateMaxAvailableDropdownHeight() {
        var itemCap = dropdown.maxDropdownItems > 0 ? dropdown.maxDropdownItems * dropdown.dropdownHeight * 0.75 : Number.POSITIVE_INFINITY
        var win = dropdown.Window.window
        if (!win) {
            maxAvailableDropdownHeight = itemCap
            return
        }
        var headBottom = head.mapToItem(null, 0, head.height).y
        var spaceCap = Math.max(dropdown.dropdownHeight * 0.75, win.height - headBottom - 8)
        maxAvailableDropdownHeight = Math.min(itemCap, spaceCap)
    }

    signal changed();

    onExpandedChanged: if(expanded) appWindow.currentItem = dropdown

    spacing: 0
    Rectangle {
        id: dropdownLabelRect
        color: "transparent"
        Layout.fillWidth: true
        height: (dropdownLabel.height + 10)
        visible: showingHeader ? true : false

        MoneroComponents.TextPlain {
            id: dropdownLabel
            anchors.top: parent.top
            anchors.left: parent.left
            font.family: MoneroComponents.Style.fontRegular.name
            font.pixelSize: labelFontSize
            font.bold: labelFontBold
            textFormat: Text.RichText
            color: MoneroComponents.Style.defaultFontColor
        }
    }

    Item {
        id: head
        Layout.fillWidth: true
        Layout.preferredHeight: dropdownHeight

        // Cypherpunk frame: chamfered corners, neon border, glow when hovered/open
        Canvas {
            id: headFrame
            anchors.fill: parent
            visible: dropdown.headerBorder
            property color fillColor: Qt.rgba(dropdown.accent.r, dropdown.accent.g, dropdown.accent.b, dropdown.lit ? 0.14 : 0.06)
            property color lineColor: dropdown.lit ? dropdown.accent : Qt.rgba(dropdown.accent.r, dropdown.accent.g, dropdown.accent.b, 0.6)
            onFillColorChanged: requestPaint()
            onLineColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                var c = 9, w = width, h = height;
                ctx.reset();
                ctx.beginPath();
                ctx.moveTo(c + 0.5, 0.5);
                ctx.lineTo(w - 0.5, 0.5);
                ctx.lineTo(w - 0.5, h - c - 0.5);
                ctx.lineTo(w - c - 0.5, h - 0.5);
                ctx.lineTo(0.5, h - 0.5);
                ctx.lineTo(0.5, c + 0.5);
                ctx.closePath();
                ctx.fillStyle = fillColor;
                ctx.fill();
                ctx.lineWidth = 1;
                ctx.strokeStyle = lineColor;
                ctx.stroke();
                ctx.fillStyle = lineColor;
                ctx.fillRect(w - 6, 2.5, 3, 1);
                ctx.fillRect(3, h - 3.5, 3, 1);
            }
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                blurMax: 24
                shadowEnabled: true
                shadowColor: dropdown.accent
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowBlur: dropdown.lit ? 0.9 : 0.5
                shadowOpacity: dropdown.lit ? 0.8 : 0.25
            }
        }

        MoneroComponents.TextPlain {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: dropIndicator.left
            anchors.rightMargin: 12
            width: droplist.width
            elide: Text.ElideRight
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.bold: dropdown.headerFontBold
            font.pixelSize: dropdown.fontSize
            color: dropdown.lit ? MoneroComponents.Style.textAccent : dropdown.textColor
            text: "> " + (columnid.currentIndex < repeater.model.count ? qsTr(repeater.model.get(columnid.currentIndex).column1) + translationManager.emptyString : "")
        }

        Item {
            id: dropIndicator
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: 12
            width: dropdownIcon.width

            Canvas {
                id: dropdownIcon
                anchors.centerIn: parent
                width: 12
                height: 8
                rotation: dropdown.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 120 } }
                property color c: dropdown.accent
                onCChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.lineWidth = 2;
                    ctx.lineCap = "square";
                    ctx.strokeStyle = c;
                    ctx.beginPath();
                    ctx.moveTo(1.5, 1.5);
                    ctx.lineTo(6, 6);
                    ctx.lineTo(10.5, 1.5);
                    ctx.stroke();
                }
            }
        }

        MouseArea {
            id: dropArea
            anchors.fill: parent
            onClicked: {
                if (dropdown.expanded) {
                    popup.close()
                } else {
                    dropdown.updateMaxAvailableDropdownHeight()
                    popup.open()
                }
            }
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
        }
    }

    Popup {
        id: popup
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        Rectangle {
            id: droplist
            anchors.left: parent.left
            width: dropdown.width
            y: head.y + head.height
            clip: true
            height: dropdown.expanded ? Math.min(columnid.height + 2, dropdown.maxAvailableDropdownHeight) : 0
            color: dropdown.pressedColor
            border.width: 1
            border.color: dropdown.accent

            Behavior on height {
                NumberAnimation { duration: 100; easing.type: Easing.InQuad }
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 1
                contentHeight: columnid.height
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: MoneroComponents.NeonScrollBar { }

                Column {
                    id: columnid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    property int currentIndex: 0

                    Repeater {
                        id: repeater

                        property string stringAutomatic: qsTr("Automatic") + translationManager.emptyString
                        property string stringSlow: qsTr("Slow (x0.2 fee)") + translationManager.emptyString
                        property string stringNormal: qsTr("Normal (x1 fee)")  + translationManager.emptyString
                        property string stringFast: qsTr("Fast (x5 fee)")  + translationManager.emptyString
                        property string stringFastest: qsTr("Fastest (x200 fee)") + translationManager.emptyString

                        delegate: Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: (dropdown.dropdownHeight * 0.75)
                            //radius: index === repeater.count - 1 ? 4 : 0
                            color: itemArea.containsMouse || index === columnid.currentIndex ? dropdown.releasedColor : "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 3
                                color: dropdown.accent
                                visible: itemArea.containsMouse || index === columnid.currentIndex
                            }

                            MoneroComponents.TextPlain {
                                id: col1Text
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: col2Text.left
                                anchors.leftMargin: 12
                                anchors.rightMargin: 0
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.bold: false
                                font.pixelSize: fontItemSize
                                color: itemArea.containsMouse || index === columnid.currentIndex ? MoneroComponents.Style.textAccent : MoneroComponents.Style.defaultFontColor
                                text: (index === columnid.currentIndex ? "> " : "  ") + qsTr(column1) + translationManager.emptyString
                            }

                            MoneroComponents.TextPlain {
                                id: col2Text
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 45
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 14
                                color: MoneroComponents.Style.defaultFontColor
                                text: ""
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.ArrowCursor

                                onClicked: {
                                    popup.close()
                                    columnid.currentIndex = index
                                    changed();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
