// Formatting bar for a rich text TextEdit, laid out like the one in macOS TextEdit:
// B I U S, text colour, highlight, font, paragraph style, size, alignment, lists and line spacing.
// The work is done by a RichTextHelper bound to the editor; this file is only the controls.

import QtQuick
import QtQuick.Controls

import "../components" as MoneroComponents

Flow {
    id: bar

    property var helper
    property Item editor

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color ink: MoneroComponents.Style.defaultFontColor
    readonly property color groupColor: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color hoverColor: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.1)
    readonly property color lineColor: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.16)
    readonly property color activeColor: MoneroComponents.Style.orange
    readonly property color activeInk: dark ? "#000000" : "#FFFFFF"
    readonly property string defaultFamily: MoneroComponents.Style.fontRegular.name

    readonly property var palette: [
        "#FFFFFF", "#D9D9D9", "#A6A6A6", "#737373", "#404040", "#000000",
        "#FF5A5A", "#FF8A3D", "#F2C14E", "#3DDC84", "#00FF41", "#2EC4B6",
        "#3B9EFF", "#5B6CFF", "#9B5DE5", "#F15BB5", "#FF6600", "#8B5A2B",
        "#FFB3B3", "#FFE0A3", "#FFF6A3", "#C8F7C5", "#BDE0FE", "#E4C1F9"
    ]
    readonly property var families: {
        var wanted = ["XMR Sans", "Helvetica", "Helvetica Neue", "Arial", "Avenir Next", "Futura", "Gill Sans", "Verdana",
                      "Georgia", "Times New Roman", "Palatino", "Baskerville", "Menlo", "Courier New", "Marker Felt"];
        var installed = Qt.fontFamilies();
        var list = [{ value: "", label: defaultFamily, family: defaultFamily }];
        for (var i = 0; i < wanted.length; i++)
            if (installed.indexOf(wanted[i]) >= 0)
                list.push({ value: wanted[i], label: wanted[i], family: wanted[i] });
        return list;
    }

    spacing: 8

    function done() {
        if (editor)
            editor.forceActiveFocus();
    }

    function spacingLabel(v) {
        return v.toFixed(v === 1.15 ? 2 : 1).replace(".", Qt.locale().decimalPoint);
    }

    // ---- building blocks ----

    component Group: Rectangle {
        default property alias content: row.data
        width: row.width + 4
        height: 28
        radius: 7
        color: bar.groupColor
        Row {
            id: row
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
        }
    }

    component Tool: Rectangle {
        id: tool
        property bool active: false
        property string tip: ""
        default property alias content: inner.data
        signal clicked()
        width: 28
        height: 24
        radius: 5
        color: active ? bar.activeColor : toolArea.containsMouse ? bar.hoverColor : "transparent"
        Item { id: inner; anchors.fill: parent }
        MouseArea {
            id: toolArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: if (tool.tip !== "") toolTip.tooltipPopup.open()
            onExited: toolTip.tooltipPopup.close()
            onClicked: { toolTip.tooltipPopup.close(); tool.clicked(); }
        }
        MoneroComponents.Tooltip { id: toolTip; text: tool.tip }
    }

    component Glyph: Text {
        property bool active: false
        anchors.centerIn: parent
        color: active ? bar.activeInk : bar.ink
        font.pixelSize: 14
    }

    component Chevrons: Canvas {
        width: 8; height: 12
        property color ink: bar.ink
        onInkChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            c.strokeStyle = ink; c.lineWidth = 1.4; c.lineCap = "round"; c.lineJoin = "round";
            c.beginPath(); c.moveTo(1, 4.5); c.lineTo(4, 1.5); c.lineTo(7, 4.5); c.stroke();
            c.beginPath(); c.moveTo(1, 7.5); c.lineTo(4, 10.5); c.lineTo(7, 7.5); c.stroke();
        }
    }

    // icon made of horizontal lines: alignment ("left", "center", "right", "justify") or a list
    component Lines: Canvas {
        property string kind: "left"
        property color ink: bar.ink
        anchors.centerIn: parent
        width: 16; height: 14
        onInkChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            c.fillStyle = ink;
            var widths = [16, 11, 16, 9];
            for (var i = 0; i < 4; i++) {
                var y = 1 + i * 3.6;
                if (kind === "list") {
                    if (i === 3) break;
                    var yy = 1.5 + i * 5;
                    c.beginPath(); c.arc(2, yy + 1, 1.6, 0, 2 * Math.PI); c.fill();
                    c.fillRect(6, yy + 0.3, 10, 1.5);
                    continue;
                }
                var w = kind === "justify" ? 16 : widths[i];
                var x = kind === "center" ? (16 - w) / 2 : kind === "right" ? 16 - w : 0;
                c.fillRect(x, y, w, 1.5);
            }
        }
    }

    // button that opens a list of choices
    component Drop: Rectangle {
        id: drop
        property var model: []
        property var current
        property string display: ""
        property string displayFamily: ""
        property string tip: ""
        property Component face: null
        signal picked(var value)
        height: 28
        radius: 7
        color: dropArea.containsMouse || menu.visible ? bar.hoverColor : bar.groupColor

        Loader {
            id: faceLoader
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: drop.face
            active: drop.face !== null
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.right: chev.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: drop.face === null
            text: drop.display
            elide: Text.ElideRight
            color: bar.ink
            font.pixelSize: 13
            font.family: drop.displayFamily !== "" ? drop.displayFamily : bar.defaultFamily
        }
        Chevrons {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
        }
        MouseArea {
            id: dropArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: if (drop.tip !== "") dropTip.tooltipPopup.open()
            onExited: dropTip.tooltipPopup.close()
            onClicked: { dropTip.tooltipPopup.close(); menu.open(); }
        }
        MoneroComponents.Tooltip { id: dropTip; text: drop.tip }

        Popup {
            id: menu
            objectName: "dropMenu"
            y: drop.height + 4
            width: Math.max(drop.width, 170)
            height: Math.min(list.contentHeight + 12, 320)
            padding: 6
            background: Rectangle {
                radius: 8
                color: bar.dark ? "#161816" : "#F4F6F4"
                border.color: bar.lineColor
            }
            contentItem: ListView {
                id: list
                clip: true
                model: drop.model
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 26
                    radius: 5
                    readonly property bool chosen: modelData.value === drop.current
                    color: itemArea.containsMouse ? bar.activeColor : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        text: parent.chosen ? "✓" : ""
                        color: itemArea.containsMouse ? bar.activeInk : bar.ink
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        elide: Text.ElideRight
                        color: itemArea.containsMouse ? bar.activeInk : bar.ink
                        font.family: modelData.family !== undefined ? modelData.family : bar.defaultFamily
                        font.pixelSize: modelData.size !== undefined ? modelData.size : 13
                        font.bold: modelData.bold === true
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { menu.close(); drop.picked(modelData.value); bar.done(); }
                    }
                }
            }
        }
    }

    // colour button: a swatch that opens a palette ("none" crosses the swatch out)
    component ColorPick: Rectangle {
        id: pick
        property color current: "transparent"
        property bool none: false
        property string noneLabel: ""
        property string tip: ""
        property bool marker: false
        signal picked(color value)
        signal cleared()
        width: 40
        height: 28
        radius: 7
        color: pickArea.containsMouse || pal.visible ? bar.hoverColor : bar.groupColor

        Rectangle {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 4
            color: pick.none ? "transparent" : pick.current
            border.width: 1
            border.color: bar.lineColor
            Text {
                visible: pick.marker
                anchors.centerIn: parent
                text: "✎"
                font.pixelSize: 13
                color: pick.none ? bar.ink : (Qt.colorEqual(pick.current, "#000000") ? "#FFFFFF" : "#000000")
            }
            Rectangle {
                visible: pick.none
                anchors.centerIn: parent
                width: 22; height: 1.6
                rotation: -45
                color: "#FF5A5A"
            }
        }
        Chevrons {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
        }
        MouseArea {
            id: pickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: if (pick.tip !== "") pickTip.tooltipPopup.open()
            onExited: pickTip.tooltipPopup.close()
            onClicked: { pickTip.tooltipPopup.close(); pal.open(); }
        }
        MoneroComponents.Tooltip { id: pickTip; text: pick.tip }

        Popup {
            id: pal
            objectName: "palette"
            y: pick.height + 4
            padding: 8
            background: Rectangle {
                radius: 8
                color: bar.dark ? "#161816" : "#F4F6F4"
                border.color: bar.lineColor
            }
            contentItem: Column {
                spacing: 8
                Rectangle {
                    width: grid.width
                    height: 24
                    radius: 5
                    color: noneArea.containsMouse ? bar.hoverColor : "transparent"
                    border.color: bar.lineColor
                    Text {
                        anchors.centerIn: parent
                        text: pick.noneLabel
                        color: bar.ink
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: noneArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { pal.close(); pick.cleared(); bar.done(); }
                    }
                }
                Grid {
                    id: grid
                    columns: 6
                    spacing: 5
                    Repeater {
                        model: bar.palette
                        delegate: Rectangle {
                            width: 22; height: 22; radius: 4
                            color: modelData
                            border.width: swatchArea.containsMouse ? 2 : 1
                            border.color: swatchArea.containsMouse ? bar.activeColor : bar.lineColor
                            MouseArea {
                                id: swatchArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { pal.close(); pick.picked(modelData); bar.done(); }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- the bar ----

    Group {
        Tool {
            active: bar.helper.bold
            tip: qsTr("Bold") + " (⌘B)" + translationManager.emptyString
            onClicked: { bar.helper.setBold(!bar.helper.bold); bar.done(); }
            Glyph { text: "B"; font.bold: true; active: parent.parent.active }
        }
        Tool {
            active: bar.helper.italic
            tip: qsTr("Italic") + " (⌘I)" + translationManager.emptyString
            onClicked: { bar.helper.setItalic(!bar.helper.italic); bar.done(); }
            Glyph { text: "I"; font.italic: true; font.family: "Georgia"; active: parent.parent.active }
        }
        Tool {
            active: bar.helper.underline
            tip: qsTr("Underline") + " (⌘U)" + translationManager.emptyString
            onClicked: { bar.helper.setUnderline(!bar.helper.underline); bar.done(); }
            Glyph { text: "U"; font.underline: true; active: parent.parent.active }
        }
        Tool {
            active: bar.helper.strikeout
            tip: qsTr("Strikethrough") + translationManager.emptyString
            onClicked: { bar.helper.setStrikeout(!bar.helper.strikeout); bar.done(); }
            Glyph { text: "S"; font.strikeout: true; active: parent.parent.active }
        }
    }

    // Monero symbol from the XMR Sans font bundled with the app
    Group {
        Tool {
            tip: qsTr("Monero symbol") + " (ɱ)" + translationManager.emptyString
            onClicked: {
                var pos = bar.helper.insertText("\u0271", "XMR Sans");
                bar.done();
                bar.editor.cursorPosition = pos;
            }
            Glyph { text: "\u0271"; font.family: "XMR Sans"; font.pixelSize: 16 }
        }
    }

    ColorPick {
        current: bar.helper.textColor.valid ? bar.helper.textColor : bar.ink
        tip: qsTr("Text colour") + translationManager.emptyString
        noneLabel: qsTr("Automatic") + translationManager.emptyString
        onPicked: function(value) { bar.helper.setTextColor(value); }
        onCleared: bar.helper.setTextColor("")
    }

    ColorPick {
        marker: true
        none: !bar.helper.highlightColor.valid
        current: bar.helper.highlightColor.valid ? bar.helper.highlightColor : "transparent"
        tip: qsTr("Highlight") + translationManager.emptyString
        noneLabel: qsTr("No highlight") + translationManager.emptyString
        onPicked: function(value) { bar.helper.setHighlightColor(Qt.rgba(value.r, value.g, value.b, 0.45)); }
        onCleared: bar.helper.setHighlightColor("")
    }

    Drop {
        width: 140
        tip: qsTr("Font") + translationManager.emptyString
        model: bar.families
        current: bar.helper.fontFamily
        display: bar.helper.fontFamily !== "" ? bar.helper.fontFamily : bar.defaultFamily
        displayFamily: bar.helper.fontFamily
        onPicked: function(value) { bar.helper.setFontFamily(value); }
    }

    Drop {
        width: 130
        tip: qsTr("Paragraph style") + translationManager.emptyString
        model: [
            { value: "title", label: qsTr("Title") + translationManager.emptyString, size: 20, bold: true },
            { value: "heading", label: qsTr("Heading") + translationManager.emptyString, size: 17, bold: true },
            { value: "subheading", label: qsTr("Subheading") + translationManager.emptyString, size: 14, bold: true },
            { value: "body", label: qsTr("Normal") + translationManager.emptyString },
            { value: "mono", label: qsTr("Monospaced") + translationManager.emptyString, family: "Menlo" }
        ]
        current: bar.helper.paragraphStyle
        display: {
            for (var i = 0; i < model.length; i++)
                if (model[i].value === current)
                    return model[i].label;
            return "";
        }
        onPicked: function(value) { bar.helper.setParagraphStyle(value); }
    }

    // size: type a number or pick one
    Rectangle {
        width: 64
        height: 28
        radius: 7
        color: bar.groupColor
        TextInput {
            id: sizeInput
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.right: sizeDrop.left
            anchors.verticalCenter: parent.verticalCenter
            color: bar.ink
            font.pixelSize: 13
            selectByMouse: true
            validator: IntValidator { bottom: 6; top: 200 }
            text: activeFocus ? text : String(bar.helper.fontSize)
            onAccepted: { bar.helper.setFontSize(parseInt(text)); bar.done(); }
        }
        Drop {
            id: sizeDrop
            anchors.right: parent.right
            width: 26
            color: "transparent"
            tip: qsTr("Size") + translationManager.emptyString
            model: [9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 36, 48, 64, 72].map(function(v) { return { value: v, label: String(v) }; })
            current: bar.helper.fontSize
            onPicked: function(value) { bar.helper.setFontSize(value); }
        }
    }

    Group {
        Repeater {
            model: [
                { kind: "left", value: Qt.AlignLeft, tip: qsTr("Align left") },
                { kind: "center", value: Qt.AlignHCenter, tip: qsTr("Centre") },
                { kind: "right", value: Qt.AlignRight, tip: qsTr("Align right") },
                { kind: "justify", value: Qt.AlignJustify, tip: qsTr("Justify") }
            ]
            delegate: Tool {
                id: alignTool
                active: bar.helper.alignment === modelData.value
                tip: modelData.tip + translationManager.emptyString
                onClicked: { bar.helper.setAlignment(modelData.value); bar.done(); }
                Lines { kind: modelData.kind; ink: alignTool.active ? bar.activeInk : bar.ink }
            }
        }
    }

    Drop {
        width: 52
        tip: qsTr("Lists") + translationManager.emptyString
        face: Component { Lines { anchors.centerIn: undefined; kind: "list" } }
        model: [
            { value: "none", label: qsTr("None") + translationManager.emptyString },
            { value: "disc", label: "•  " + qsTr("Bullets") + translationManager.emptyString },
            { value: "circle", label: "◦  " + qsTr("Circles") + translationManager.emptyString },
            { value: "square", label: "▪  " + qsTr("Squares") + translationManager.emptyString },
            { value: "decimal", label: "1.  2.  3." },
            { value: "lower-alpha", label: "a.  b.  c." },
            { value: "upper-alpha", label: "A.  B.  C." },
            { value: "lower-roman", label: "i.  ii.  iii." },
            { value: "upper-roman", label: "I.  II.  III." },
            { value: "check", label: "☐  " + qsTr("Checklist") + translationManager.emptyString }
        ]
        current: bar.helper.listStyle
        onPicked: function(value) { bar.helper.setListStyle(value); }
    }

    Drop {
        width: 62
        tip: qsTr("Line spacing") + translationManager.emptyString
        model: [1.0, 1.15, 1.5, 2.0].map(function(v) { return { value: v, label: bar.spacingLabel(v) }; })
        current: Math.round(bar.helper.lineHeight * 100) / 100
        display: bar.spacingLabel(current)
        onPicked: function(value) { bar.helper.setLineHeight(value); }
    }
}
