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


// Trezor page (Wallet+ > Trezor): the device customization Trezor Suite offers (name, homescreen, brightness,
// haptic feedback, auto-lock), plus a gallery of homescreens made for XMR Wallet+. Every change is confirmed
// on the device itself.

import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

import "../components" as MoneroComponents

Rectangle {
    id: pageTrezor
    color: "transparent"

    property alias trezorHeight: mainLayout.height
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color blue: dark ? "#6CB8FF" : "#1565C0"
    readonly property color good: dark ? "#3DDC84" : "#1E7D45"
    readonly property color bad: dark ? "#FF6B6B" : "#C62828"
    readonly property bool isTrezor: currentWallet ? currentWallet.isTrezor() : false

    // what the device reported (GetFeatures), null until read
    property var features: null
    property string readError: ""
    // "", "read", "label", "wallpaper", "brightness", "haptic", "lock"
    property string busy: ""
    property string message: ""
    property bool messageOk: true

    // the homescreen picked in the gallery or from a file, waiting to be sent
    property string pendingWallpaper: ""
    property string pendingName: ""

    // names of the wallpapers made for the app; any other image dropped in the folder is listed by its file name
    readonly property var builtInNames: ({
        fuego: qsTr("Fire") + translationManager.emptyString,
        matrix: "Matrix",
        morado: qsTr("Purple glitch") + translationManager.emptyString,
        cypher: "Cypherpunk",
        circuito: qsTr("Circuit") + translationManager.emptyString,
        minimal: qsTr("Minimal") + translationManager.emptyString,
        azul: qsTr("Blue") + translationManager.emptyString,
        espacio: qsTr("Space") + translationManager.emptyString
    })
    readonly property var builtInOrder: ["fuego", "matrix", "morado", "cypher", "circuito", "minimal", "azul", "espacio"]

    // every image in images/trezor-wallpapers (Safe 7) or its safe5 subfolder (Safe 5), built into the app:
    // the app's own wallpapers first, then the rest by name
    readonly property var gallery: {
        var urls = oshelper.resourceImages(squareScreen ? "images/trezor-wallpapers/safe5" : "images/trezor-wallpapers");
        var list = urls.map(function(url) {
            var file = url.substring(url.lastIndexOf("/") + 1);
            var base = file.replace(/\.[^.]+$/, "");
            var order = builtInOrder.indexOf(base);
            return {
                url: url,
                name: order >= 0 ? builtInNames[base] : base.replace(/[_-]+/g, " "),
                order: order >= 0 ? order : builtInOrder.length
            };
        });
        list.sort(function(a, b) { return a.order - b.order || a.name.localeCompare(b.name); });
        return list;
    }

    // minutes offered for the auto-lock, like Trezor Suite
    readonly property var lockMinutes: [1, 2, 5, 10, 15, 30, 60]

    readonly property int screenWidth: features && features.homescreenWidth ? features.homescreenWidth : 380
    readonly property int screenHeight: features && features.homescreenHeight ? features.homescreenHeight : 520
    // square screen (Safe 5, 240×240): its own gallery and a 16 KB limit instead of 64 KB
    readonly property bool squareScreen: screenWidth === screenHeight
    readonly property int maxBytes: squareScreen ? 16384 : 65536
    // preview size on this page: the device screen at half size, 240 px wide for the square one
    readonly property int previewWidth: squareScreen ? 240 : 190
    readonly property int previewHeight: squareScreen ? 240 : 260
    readonly property int thumbWidth: squareScreen ? 112 : 96
    readonly property int thumbHeight: squareScreen ? 112 : 131

    function modelName(f) {
        if (f.internalModel === "T3W1")
            return "Trezor Safe 7";
        if (f.internalModel === "T3T1")
            return "Trezor Safe 5";
        return f.model ? "Trezor " + f.model : "Trezor";
    }

    function onPageCompleted() {
        if (isTrezor && busy === "")
            readFeatures();
    }

    function readFeatures() {
        if (!currentWallet || !isTrezor)
            return;
        busy = "read";
        readError = "";
        currentWallet.deviceFeaturesAsync();
    }

    function errorText(error) {
        var e = (error || "").toLowerCase();
        if (e.indexOf("cancel") >= 0)
            return qsTr("Cancelled on the Trezor. Nothing was changed.") + translationManager.emptyString;
        if (e.indexOf("image") === 0)
            return qsTr("The image could not be prepared for the Trezor (%1).").arg(error.substring(7)) + translationManager.emptyString;
        if (e.indexOf("format") >= 0)
            return qsTr("The Trezor rejected the image format.") + translationManager.emptyString;
        if (e.indexOf("not a trezor") >= 0)
            return qsTr("This wallet does not use a Trezor.") + translationManager.emptyString;
        if (e.indexOf("unexpected") >= 0 || e.indexOf("unknown message") >= 0)
            return qsTr("The Trezor firmware does not support this option. Update it with Trezor Suite.") + translationManager.emptyString;
        return qsTr("The Trezor did not accept the change. Check that it is connected and unlocked.") + translationManager.emptyString
               + (error ? " (" + error + ")" : "");
    }

    function apply(kind, settings) {
        if (!currentWallet || busy !== "")
            return;
        busy = kind;
        message = "";
        currentWallet.deviceApplySettingsAsync(settings);
    }

    function sendWallpaper() {
        if (pendingWallpaper === "")
            return;
        apply("wallpaper", { wallpaper: pendingWallpaper, width: screenWidth, height: screenHeight, maxBytes: maxBytes });
    }

    function lockIndex(ms) {
        var best = 0;
        for (var i = 0; i < lockMinutes.length; ++i)
            if (Math.abs(lockMinutes[i] * 60000 - ms) < Math.abs(lockMinutes[best] * 60000 - ms))
                best = i;
        return best;
    }

    Connections {
        target: currentWallet
        ignoreUnknownSignals: true

        function onDeviceFeaturesReceived(json, error) {
            if (pageTrezor.busy === "read")
                pageTrezor.busy = "";
            if (error !== "") {
                pageTrezor.readError = pageTrezor.errorText(error);
                return;
            }
            try {
                pageTrezor.features = JSON.parse(json);
            } catch (e) {
                pageTrezor.readError = "JSON";
                return;
            }
            labelInput.text = pageTrezor.features.label || "";
            // keep the name in the title bar in step with the device
            appWindow.walletDeviceLabel = pageTrezor.features.label || pageTrezor.modelName(pageTrezor.features);
            // a picked gallery image from the other model's gallery no longer fits
            var pending = pageTrezor.pendingWallpaper;
            if (pending.indexOf("qrc:") === 0 && (pending.indexOf("/safe5/") >= 0) !== pageTrezor.squareScreen) {
                pageTrezor.pendingWallpaper = "";
                pageTrezor.pendingName = "";
            }
            lockDropdown.currentIndex = pageTrezor.lockIndex(pageTrezor.features.autoLockMs || 600000);
        }

        function onDeviceSettingsApplied(ok, error) {
            var kind = pageTrezor.busy;
            pageTrezor.busy = "";
            pageTrezor.messageOk = ok;
            if (!ok) {
                pageTrezor.message = pageTrezor.errorText(error);
            } else if (kind === "label") {
                pageTrezor.message = qsTr("Name saved on the Trezor.") + translationManager.emptyString;
            } else if (kind === "wallpaper") {
                pageTrezor.message = qsTr("Homescreen sent to the Trezor.") + translationManager.emptyString;
                pageTrezor.pendingWallpaper = "";
                pageTrezor.pendingName = "";
            } else if (kind === "haptic") {
                pageTrezor.message = qsTr("Haptic feedback changed.") + translationManager.emptyString;
            } else if (kind === "lock") {
                pageTrezor.message = qsTr("Auto-lock changed.") + translationManager.emptyString;
            } else {
                pageTrezor.message = qsTr("Saved on the Trezor.") + translationManager.emptyString;
            }
            pageTrezor.readFeatures();
        }

        function onDeviceBrightnessDone(ok, error) {
            pageTrezor.busy = "";
            pageTrezor.messageOk = ok;
            pageTrezor.message = ok ? qsTr("Brightness set on the Trezor.") + translationManager.emptyString
                                    : pageTrezor.errorText(error);
        }
    }

    FileDialog {
        id: wallpaperDialog
        title: qsTr("Choose an image for the Trezor") + translationManager.emptyString
        nameFilters: [ qsTr("Images") + " (*.jpg *.jpeg *.png *.bmp *.gif *.webp)" ]
        onAccepted: {
            pageTrezor.pendingWallpaper = wallpaperDialog.selectedFile.toString();
            var path = decodeURIComponent(pageTrezor.pendingWallpaper);
            pageTrezor.pendingName = path.substring(path.lastIndexOf("/") + 1);
        }
    }

    // one setting: title and explanation on the left, its control on the right (like Trezor Suite)
    component SettingRow: RowLayout {
        id: row
        default property alias control: controls.data
        property string title: ""
        property string body: ""
        Layout.fillWidth: true
        spacing: 24

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                text: row.title
                font.pixelSize: 16
                font.bold: true
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                visible: row.body !== ""
                text: row.body
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
        }
        RowLayout {
            id: controls
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 10
        }
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: MoneroComponents.Style.dividerColor
        opacity: MoneroComponents.Style.dividerOpacity
    }

    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 20

        // ---- header: device and what it reported ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            MoneroComponents.TrezorIcon {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 58
                accent: pageTrezor.blue
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                MoneroComponents.LabelSubheader {
                    Layout.fillWidth: true
                    fontSize: 24
                    text: pageTrezor.features && pageTrezor.features.label ? pageTrezor.features.label : "Trezor"
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    text: {
                        if (!pageTrezor.isTrezor)
                            return qsTr("Open a wallet that uses a Trezor to customize the device.") + translationManager.emptyString;
                        if (pageTrezor.busy === "read")
                            return qsTr("Reading the device…") + translationManager.emptyString;
                        if (pageTrezor.readError !== "")
                            return pageTrezor.readError;
                        if (!pageTrezor.features)
                            return "";
                        var f = pageTrezor.features;
                        return pageTrezor.modelName(f) + "  ·  firmware " + f.version
                               + "  ·  " + qsTr("screen %1×%2").arg(pageTrezor.screenWidth).arg(pageTrezor.screenHeight) + translationManager.emptyString;
                    }
                }
            }

            MoneroComponents.StandardButton {
                small: true
                primary: false
                visible: pageTrezor.isTrezor
                enabled: pageTrezor.busy === ""
                text: qsTr("Read again") + translationManager.emptyString
                onClicked: pageTrezor.readFeatures()
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 14
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
            text: qsTr("Personalize your Trezor as in Trezor Suite. Each change has to be confirmed on the device. Close Trezor Suite while you use this page.") + translationManager.emptyString
        }

        // result of the last change
        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            visible: pageTrezor.message !== "" || pageTrezor.busy !== "" && pageTrezor.busy !== "read"
            wrapMode: Text.WordWrap
            font.pixelSize: 14
            font.bold: true
            themeTransition: false
            color: pageTrezor.busy !== "" ? pageTrezor.blue : pageTrezor.messageOk ? pageTrezor.good : pageTrezor.bad
            text: pageTrezor.busy !== "" && pageTrezor.busy !== "read"
                  ? (pageTrezor.busy === "wallpaper" ? qsTr("Sending the image… confirm it on the Trezor.") : qsTr("Confirm the change on the Trezor.")) + translationManager.emptyString
                  : pageTrezor.message
        }

        MoneroComponents.SettingsCard {
            padding: 24
            spacing: 22
            enabled: pageTrezor.isTrezor && pageTrezor.features !== null && pageTrezor.busy === ""
            opacity: enabled || pageTrezor.busy !== "" ? 1 : 0.55

            // ---- name ----
            SettingRow {
                title: qsTr("Device name") + translationManager.emptyString
                body: qsTr("Shown on the Trezor screen and in the title bar. Up to 16 characters.") + translationManager.emptyString

                MoneroComponents.LineEdit {
                    id: labelInput
                    Layout.preferredWidth: 220
                    fontSize: 15
                    input.maximumLength: 16
                    placeholderText: "My Trezor"
                }
                MoneroComponents.StandardButton {
                    small: true
                    enabled: labelInput.text.trim() !== "" && pageTrezor.features && labelInput.text.trim() !== pageTrezor.features.label
                    text: qsTr("Save name") + translationManager.emptyString
                    onClicked: pageTrezor.apply("label", { label: labelInput.text.trim() })
                }
            }

            Divider {}

            // ---- homescreen ----
            SettingRow {
                title: qsTr("Homescreen") + translationManager.emptyString
                body: qsTr("Upload your own image or pick one from the XMR Wallet+ gallery. It is cropped to %1×%2 pixels and sent as a JPEG of %3 KB at most.").arg(pageTrezor.screenWidth).arg(pageTrezor.screenHeight).arg(pageTrezor.maxBytes / 1024) + translationManager.emptyString

                MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    text: qsTr("Upload") + translationManager.emptyString
                    onClicked: wallpaperDialog.open()
                }
                MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    text: qsTr("Original") + translationManager.emptyString
                    tooltip: qsTr("Restore the Trezor's own homescreen") + translationManager.emptyString
                    onClicked: pageTrezor.apply("wallpaper", { wallpaperReset: true })
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 24

                // gallery
                Flow {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    Repeater {
                        model: pageTrezor.gallery
                        delegate: Item {
                            id: thumb
                            readonly property string url: modelData.url
                            readonly property bool selected: pageTrezor.pendingWallpaper === url
                            width: pageTrezor.thumbWidth
                            height: pageTrezor.thumbHeight + 22

                            Rectangle {
                                id: frame
                                width: pageTrezor.thumbWidth
                                height: pageTrezor.thumbHeight
                                radius: 8
                                color: "#000000"
                                border.width: thumb.selected ? 2 : 1
                                border.color: thumb.selected ? pageTrezor.blue
                                              : thumbArea.containsMouse ? Qt.rgba(pageTrezor.blue.r, pageTrezor.blue.g, pageTrezor.blue.b, 0.6)
                                              : MoneroComponents.Style.inputBorderColorInActive
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: thumb.url
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 190
                                    smooth: true
                                    asynchronous: true
                                }
                            }
                            MoneroComponents.TextPlain {
                                anchors.top: frame.bottom
                                anchors.topMargin: 4
                                width: frame.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: modelData.name
                                font.pixelSize: 11
                                color: thumb.selected ? pageTrezor.blue : MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                            MouseArea {
                                id: thumbArea
                                anchors.fill: frame
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pageTrezor.pendingWallpaper = thumb.url;
                                    pageTrezor.pendingName = modelData.name;
                                }
                            }
                        }
                    }
                }

                // preview of the chosen image as it will look on the device
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: pageTrezor.previewWidth + 16
                        Layout.preferredHeight: pageTrezor.previewHeight + 16
                        radius: 22
                        color: "#0A0A0A"
                        border.width: 1
                        border.color: pageTrezor.pendingWallpaper !== "" ? pageTrezor.blue : MoneroComponents.Style.inputBorderColorInActive

                        Rectangle {
                            id: previewScreen
                            anchors.centerIn: parent
                            width: pageTrezor.previewWidth
                            height: pageTrezor.previewHeight
                            radius: 14
                            color: "#000000"
                            clip: true
                            Image {
                                anchors.fill: parent
                                visible: pageTrezor.pendingWallpaper !== ""
                                source: pageTrezor.pendingWallpaper
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: pageTrezor.previewWidth * 2
                                smooth: true
                                asynchronous: true
                            }
                            MoneroComponents.TextPlain {
                                anchors.centerIn: parent
                                width: parent.width - 30
                                visible: pageTrezor.pendingWallpaper === ""
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: qsTr("Pick an image") + translationManager.emptyString
                                font.pixelSize: 13
                                color: "#8A8A8A"
                                themeTransition: false
                            }
                        }
                    }

                    MoneroComponents.TextPlain {
                        Layout.preferredWidth: pageTrezor.previewWidth + 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        visible: pageTrezor.pendingName !== ""
                        text: pageTrezor.pendingName
                        font.pixelSize: 12
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }

                    MoneroComponents.StandardButton {
                        Layout.alignment: Qt.AlignHCenter
                        small: true
                        enabled: pageTrezor.pendingWallpaper !== ""
                        text: qsTr("Send to Trezor") + translationManager.emptyString
                        onClicked: pageTrezor.sendWallpaper()
                    }
                }
            }

            Divider {}

            // ---- brightness ----
            SettingRow {
                title: qsTr("Brightness") + translationManager.emptyString
                body: qsTr("The Trezor shows a brightness control on its screen; adjust it there and confirm.") + translationManager.emptyString

                MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    text: qsTr("Change") + translationManager.emptyString
                    onClicked: {
                        pageTrezor.busy = "brightness";
                        pageTrezor.message = "";
                        currentWallet.deviceSetBrightnessAsync();
                    }
                }
            }

            Divider { visible: hapticRow.visible }

            // ---- haptic feedback (Safe 7) ----
            SettingRow {
                id: hapticRow
                visible: pageTrezor.features !== null && pageTrezor.features.hasHaptic === true
                title: qsTr("Haptic feedback") + translationManager.emptyString
                body: qsTr("The Trezor vibrates slightly when you touch its screen.") + translationManager.emptyString

                MoneroComponents.TextPlain {
                    text: (hapticSwitch.on ? qsTr("On") : qsTr("Off")) + translationManager.emptyString
                    font.pixelSize: 14
                    color: hapticSwitch.on ? pageTrezor.blue : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                Rectangle {
                    id: hapticSwitch
                    readonly property bool on: pageTrezor.features !== null && pageTrezor.features.haptic === true
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 24
                    radius: 12
                    color: on ? Qt.rgba(pageTrezor.blue.r, pageTrezor.blue.g, pageTrezor.blue.b, 0.35) : "transparent"
                    border.width: 1
                    border.color: on || switchArea.containsMouse ? pageTrezor.blue : MoneroComponents.Style.inputBorderColorInActive
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: hapticSwitch.on ? parent.width - width - 3 : 3
                        color: hapticSwitch.on ? pageTrezor.blue : MoneroComponents.Style.dimmedFontColor
                        Behavior on x { NumberAnimation { duration: 140 } }
                    }
                    MouseArea {
                        id: switchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pageTrezor.apply("haptic", { haptic: !hapticSwitch.on })
                    }
                }
            }

            Divider {}

            // ---- auto-lock ----
            SettingRow {
                title: qsTr("Auto-lock") + translationManager.emptyString
                body: qsTr("The Trezor locks itself after this time without use and asks for the PIN again.") + translationManager.emptyString

                MoneroComponents.StandardDropdown {
                    id: lockDropdown
                    Layout.preferredWidth: 180
                    dataModel: ListModel {
                        id: lockModel
                        Component.onCompleted: {
                            for (var i = 0; i < pageTrezor.lockMinutes.length; ++i) {
                                var m = pageTrezor.lockMinutes[i];
                                append({ column1: m === 60 ? qsTr("1 hour") + translationManager.emptyString
                                                           : qsTr("%1 min").arg(m) + translationManager.emptyString });
                            }
                        }
                    }
                    onChanged: {
                        if (!pageTrezor.features)
                            return;
                        var ms = pageTrezor.lockMinutes[lockDropdown.currentIndex] * 60000;
                        if (ms !== pageTrezor.features.autoLockMs)
                            pageTrezor.apply("lock", { autoLockMs: ms });
                    }
                }
            }
        }
    }
}
