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
import QtQuick.Layouts

import FontAwesome

import "." as MoneroComponents
import "effects/" as MoneroEffects

Item {
    id: checkBox
    property alias text: label.text
    property string checkedIcon: "qrc:///images/check-white.svg"
    property string uncheckedIcon
    property bool fontAwesomeIcons: false
    property int imgWidth: 13
    property int imgHeight: 13
    property bool toggleOnClick: true
    property bool checked: false
    property alias background: backgroundRect.color
    property bool border: true
    property int fontSize: 14
    property alias fontColor: label.color
    property bool iconOnTheLeft: true
    property alias tooltipIconVisible: label.tooltipIconVisible
    property alias tooltip: label.tooltip
    signal clicked()

    height: 25
    width: checkBoxLayout.width
    opacity: enabled ? 1 : 0.7

    Keys.onEnterPressed: toggle()
    Keys.onReturnPressed: toggle()
    Keys.onSpacePressed: toggle()

    function toggle(){
        if (checkBox.toggleOnClick) {
            checkBox.checked = !checkBox.checked
        }
        checkBox.clicked()
    }

    RowLayout {
        id: checkBoxLayout
        layoutDirection: iconOnTheLeft ? Qt.LeftToRight : Qt.RightToLeft
        spacing: 10

        Item {
            id: checkMark
            height: checkBox.height
            width: checkBox.height

            Rectangle {
                id: backgroundRect
                visible: checkBox.border && !checkBox.enabled
                anchors.fill: parent
                color: checkBox.enabled ? "transparent" : MoneroComponents.Style.inputBoxBackgroundDisabled
            }

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                visible: checkBox.border
                cut: 6
                ticks: false
                fillOpacity: checkBox.checked ? 0.16 : 0.03
                lineOpacity: checkBox.checked || checkBox.activeFocus || checkArea.containsMouse ? 1.0 : 0.5
                glow: checkBox.checked ? 0.7 : (checkArea.containsMouse ? 0.35 : 0)
                Behavior on fillOpacity { NumberAnimation { duration: 140 } }
            }

            // neon tick for the default check icon
            Canvas {
                id: neonTick
                readonly property bool active: !checkBox.fontAwesomeIcons && checkBox.uncheckedIcon == ""
                    && checkBox.checkedIcon == "qrc:///images/check-white.svg"
                property real progress: checkBox.checked ? 1 : 0
                Behavior on progress { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                visible: active && progress > 0
                anchors.fill: parent
                anchors.margins: 5
                onProgressChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"), w = width, h = height;
                    ctx.reset();
                    var p = [[0.05, 0.55], [0.38, 0.88], [0.95, 0.12]];
                    var l1 = Math.hypot((p[1][0]-p[0][0])*w, (p[1][1]-p[0][1])*h);
                    var l2 = Math.hypot((p[2][0]-p[1][0])*w, (p[2][1]-p[1][1])*h);
                    var len = (l1 + l2) * progress;
                    ctx.lineWidth = 2.4;
                    ctx.lineCap = "square";
                    ctx.strokeStyle = MoneroComponents.Style.orange;
                    ctx.beginPath();
                    ctx.moveTo(p[0][0]*w, p[0][1]*h);
                    if (len <= l1) {
                        var t = len / l1;
                        ctx.lineTo((p[0][0] + (p[1][0]-p[0][0])*t)*w, (p[0][1] + (p[1][1]-p[0][1])*t)*h);
                    } else {
                        var t2 = (len - l1) / l2;
                        ctx.lineTo(p[1][0]*w, p[1][1]*h);
                        ctx.lineTo((p[1][0] + (p[2][0]-p[1][0])*t2)*w, (p[1][1] + (p[2][1]-p[1][1])*t2)*h);
                    }
                    ctx.stroke();
                }
            }

            MoneroEffects.ImageMask {
                id: img
                visible: !neonTick.active && (checkBox.checked || checkBox.uncheckedIcon != "")
                anchors.centerIn: parent
                width: checkBox.imgWidth
                height: checkBox.imgHeight
                color: MoneroComponents.Style.orange
                fontAwesomeFallbackIcon: checkBox.fontAwesomeIcons ? getIcon() : FontAwesome.plus
                fontAwesomeFallbackSize: 14
                image: checkBox.fontAwesomeIcons ? "" : getIcon()

                function getIcon() {
                    if (checkBox.checked || checkBox.uncheckedIcon == "")
                        return checkBox.checkedIcon;
                    return checkBox.uncheckedIcon;
                }
            }
        }

        MoneroComponents.TextPlain {
            id: label
            font.family: MoneroComponents.Style.fontRegular.name
            font.pixelSize: checkBox.fontSize
            color: MoneroComponents.Style.defaultFontColor
            textFormat: Text.RichText
            wrapMode: Text.NoWrap
            visible: text != ""
        }
    }

    MouseArea {
        id: checkArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: !label.tooltipIconVisible && label.tooltip ? label.tooltipPopup.open() : ""
        onExited:  !label.tooltipIconVisible && label.tooltip ? label.tooltipPopup.close() : ""
        onClicked: {
            toggle()
        }
    }
}
