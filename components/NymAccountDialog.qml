import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as MoneroComponents

Item {
    id: root
    visible: false
    property string errorText: ""
    property string filePath: ""
    property string savedPhrase: ""
    property string deviceId: ""
    property bool loadFailed: false
    readonly property bool busy: oshelper.nymClient.state === "connected" || oshelper.nymClient.state === "working"

    function loadAccount() {
        var values = oshelper.nymClient.accountSettings();
        errorText = values.error || "";
        loadFailed = errorText !== "";
        savedPhrase = values.mnemonic || "";
        deviceId = values.device_id || "";
        filePath = values.path || "";
        reveal.checked = false;
    }
    function open() {
        loadAccount();
        if (!visible) appWindow.modalDialogs++;
        visible = true;
        forceActiveFocus();
    }
    function close() {
        if (visible) appWindow.modalDialogs = Math.max(0, appWindow.modalDialogs - 1);
        visible = false;
        savedPhrase = "";
        reveal.checked = false;
    }
    Keys.onEscapePressed: close()
    MoneroComponents.ModalTint { }
    MoneroComponents.ModalCard {
        title: qsTr("Cuenta NymVPN")
        kind: ""
        maxWidth: 640
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contents.implicitHeight, root.height * 0.65)
            contentWidth: width
            contentHeight: contents.implicitHeight
            clip: true
            ScrollBar.vertical: MoneroComponents.NeonScrollBar { }
            ColumnLayout {
                id: contents
                width: parent.width
                spacing: 12
                MoneroComponents.Label { text: qsTr("Frase de la cuenta NymVPN (24 palabras)"); fontSize: 13 }
                TextArea {
                    id: phrase
                    objectName: "nymAccountSeedInput"
                    FontMetrics { id: phraseMetrics; font: phrase.font }
                    Layout.preferredHeight: 2 * phraseMetrics.height + topPadding + bottomPadding
                    clip: true
                    wrapMode: TextEdit.Wrap
                    selectByMouse: reveal.checked
                    color: MoneroComponents.Style.defaultFontColor
                    text: reveal.checked ? root.savedPhrase : root.savedPhrase.replace(/[^\s]/g, "•")
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    padding: 10
                    readOnly: true
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    background: MoneroComponents.NeonFrame { cut: 6; ticks: false; lineOpacity: 0.4 }
                }
                MoneroComponents.CheckBox { id: reveal; text: qsTr("Mostrar frase") }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    text: qsTr("ID del dispositivo: ") + (root.deviceId || qsTr("Disponible después de conectar"))
                    font.pixelSize: 12
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    text: root.filePath
                    font.pixelSize: 12
                }
                MoneroComponents.Label {
                    text: qsTr("Archivo JSON local")
                    fontSize: 12
                    tooltipIconVisible: true
                    tooltip: qsTr("La frase se guarda sin cifrar en nym.conf, con permisos de lectura y escritura solo para tu usuario. La cuenta se recuerda automáticamente. Cerrar sesión desconecta Nym y conserva la frase y el ID del dispositivo. Conectar con otra frase crea una identidad nueva.")
                }
                MoneroComponents.StandardButton {
                    visible: oshelper.nymClient.legacyAccountSaved
                    enabled: !root.busy
                    small: true
                    text: qsTr("Trasladar cuenta del llavero a nym.conf")
                    onClicked: {
                        var error = oshelper.nymClient.migrateLegacyAccount();
                        if (error !== "") root.errorText = error;
                        else root.loadAccount();
                    }
                }
                MoneroComponents.TextPlain {
                    visible: root.errorText !== ""
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: root.errorText
                    color: "#E08A8A"
                    themeTransition: false
                    font.pixelSize: 12
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Item { Layout.fillWidth: true }
            MoneroComponents.StandardButton {
                small: true
                accent: "#C62828"
                text: qsTr("Cerrar sesión Nym")
                onClicked: {
                    appWindow.nymVpnDisconnect();
                    root.close();
                }
            }
            MoneroComponents.StandardButton { small: true; text: qsTr("Cerrar"); onClicked: root.close() }
        }
    }
}
