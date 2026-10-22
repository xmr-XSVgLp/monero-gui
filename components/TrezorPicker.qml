import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as MoneroComponents

// Explicit device choice, including Bluetooth discovery while a USB Trezor is connected
// (like Cake Wallet). open(devices, preselectPath, onChosen, onCancelled)
Item {
    id: root
    visible: false
    property var devices: []
    property string selectedPath: ""
    property bool searching: false
    property int searchGeneration: 0
    property var chosenCallback: null
    property var cancelledCallback: null
    readonly property bool dark: MoneroComponents.Style.blackTheme

    function modelName(code) {
        switch (code) {
        case "1": return "Trezor Model One";
        case "T": return "Trezor Model T";
        case "Safe 3": case "T2B1": case "T3B1": return "Trezor Safe 3";
        case "Safe 5": case "T3T1": return "Trezor Safe 5";
        case "Safe 7": case "T3W1": return "Trezor Safe 7";
        default: return code ? "Trezor " + code : "Trezor";
        }
    }
    function connectionName(path) {
        if (path.indexOf("webusb:") === 0) return qsTr("USB · puerto %1").arg(path.substring(7).replace(/:/g, "-"));
        if (path.indexOf("ble:") === 0) return qsTr("Bluetooth");
        if (path.indexOf("udp:") === 0) return qsTr("Emulador · %1").arg(path.substring(4));
        if (path.indexOf("bridge:") === 0) return qsTr("Trezor Bridge");
        return path;
    }
    function title(d) {
        if (d.label) return d.label;
        if (d.name) return d.name;
        return qsTr("Trezor sin identificar");
    }

    function open(list, preselectPath, onChosen, onCancelled) {
        ++searchGeneration;
        searching = false;
        devices = list;
        chosenCallback = onChosen;
        cancelledCallback = onCancelled;
        selectedPath = "";
        for (var i = 0; i < list.length; ++i)
            if (list[i].path === preselectPath) selectedPath = preselectPath;
        if (selectedPath === "")
            for (var j = 0; j < list.length; ++j)
                if (list[j].lastUsed) selectedPath = list[j].path;
        if (selectedPath === "" && list.length > 0) selectedPath = list[0].path;
        if (!visible) appWindow.modalDialogs++;
        visible = true;
        forceActiveFocus();
    }
    function finish(chosen) {
        if (!visible || (chosen && (searching || !devices.some(function(d) { return d.path === selectedPath; })))) return;
        ++searchGeneration;
        searching = false;
        if (visible) appWindow.modalDialogs = Math.max(0, appWindow.modalDialogs - 1);
        visible = false;
        var cb = chosen ? chosenCallback : cancelledCallback;
        chosenCallback = null;
        cancelledCallback = null;
        if (cb) cb(selectedPath);
    }
    function searchBluetooth() {
        if (searching || !visible) return;
        searching = true;
        var generation = ++searchGeneration;
        walletManager.trezorDevicesAsync(true, function(json) {
            if (!visible || generation !== searchGeneration) return;
            searching = false;
            var list = [];
            try { list = JSON.parse(json); } catch (e) {}
            appWindow.rememberTrezorDevices(list);
            devices = appWindow.withKnownTrezorNames(list);
            if (!devices.some(function(d) { return d.path === root.selectedPath; }))
                selectedPath = devices.length > 0 ? devices[0].path : "";
        });
    }

    Keys.onEscapePressed: finish(false)
    Keys.onReturnPressed: if (selectedPath !== "") finish(true)
    Keys.onEnterPressed: if (selectedPath !== "") finish(true)
    Keys.onUpPressed: move(-1)
    Keys.onDownPressed: move(1)
    function move(step) {
        for (var i = 0; i < devices.length; ++i)
            if (devices[i].path === selectedPath) {
                selectedPath = devices[Math.max(0, Math.min(devices.length - 1, i + step))].path;
                return;
            }
    }

    MoneroComponents.ModalTint { }
    MoneroComponents.ModalCard {
        title: qsTr("Elige tu Trezor")
        kind: ""
        maxWidth: 560

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Elige el Trezor para esta cartera. Si usas un Safe 7 inalámbrico, pulsa Buscar por Bluetooth aunque haya otro Trezor conectado por USB.")
            font.pixelSize: 14
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(rows.implicitHeight, root.height * 0.5)
            contentWidth: width
            contentHeight: rows.implicitHeight
            clip: true
            ScrollBar.vertical: MoneroComponents.NeonScrollBar { }
            ColumnLayout {
                id: rows
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.devices
                    delegate: Item {
                        id: row
                        readonly property bool selected: modelData.path === root.selectedPath
                        Layout.fillWidth: true
                        Layout.preferredHeight: 62
                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 8
                            ticks: false
                            accent: row.selected ? MoneroComponents.Style.orange : (root.dark ? "#E8ECE9" : "#2B3A30")
                            lineOpacity: row.selected ? 0.9 : (rowArea.containsMouse ? 0.5 : 0.25)
                            glow: row.selected ? 0.5 : 0
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 14
                            MoneroComponents.TrezorIcon {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                accent: row.selected ? MoneroComponents.Style.orange : MoneroComponents.Style.dimmedFontColor
                                glow: row.selected
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: root.title(modelData)
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: root.modelName(modelData.model) + "  ·  " + root.connectionName(modelData.path)
                                    font.pixelSize: 12
                                    color: MoneroComponents.Style.dimmedFontColor
                                }
                            }
                            MoneroComponents.TextPlain {
                                visible: !!modelData.lastUsed
                                text: qsTr("último usado")
                                font.pixelSize: 11
                                color: MoneroComponents.Style.dimmedFontColor
                            }
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedPath = modelData.path
                            onDoubleClicked: { root.selectedPath = modelData.path; root.finish(true); }
                        }
                    }
                }
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: root.devices.some(function(d) { return !d.label; })
            text: qsTr("El nombre de un Trezor aparece después de conectarlo una vez.")
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            MoneroComponents.StandardButton {
                small: true
                primary: false
                enabled: !root.searching
                text: root.searching ? qsTr("Buscando...") : qsTr("Buscar por Bluetooth")
                onClicked: root.searchBluetooth()
            }
            Item { Layout.fillWidth: true }
            MoneroComponents.StandardButton { small: true; primary: false; text: qsTr("Cancelar"); onClicked: root.finish(false) }
            MoneroComponents.StandardButton {
                small: true
                enabled: root.selectedPath !== "" && !root.searching
                text: qsTr("Conectar")
                onClicked: root.finish(true)
            }
        }
    }
}
