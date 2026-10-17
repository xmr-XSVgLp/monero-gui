// Notes page: private notes encrypted with AES-256-GCM in <wallet>_notes, next to the wallet.
// The key comes from the wallet keys (and a confirmation on the Trezor for hardware wallets),
// so the wallet password is asked every time the notes are opened.
// Notes are kept as JSON { version, notes: [{ title, text, updated }] } inside the encrypted file.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

Rectangle {
    id: pageNotes
    color: "transparent"

    property alias notesHeight: mainLayout.height
    readonly property color neutral: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: "#FF6600"
    readonly property bool device: currentWallet ? currentWallet.isHwBacked() : false

    property bool unlocked: false
    property bool busy: false
    property string error: ""
    property var notes: []
    property int current: -1
    property bool dirty: false
    property bool saving: false
    property string savedAt: ""
    property bool loadingEditor: false
    property int fileTick: 0

    function errorText(code) {
        if (code === "password")
            return qsTr("Wrong wallet password.") + translationManager.emptyString;
        if (code === "decrypt")
            return qsTr("The notes could not be decrypted. The file belongs to another wallet, Trezor or passphrase.") + translationManager.emptyString;
        if (code === "corrupt")
            return qsTr("The notes file is damaged.") + translationManager.emptyString;
        if (code === "io")
            return qsTr("The notes file could not be read or written.") + translationManager.emptyString;
        if (code === "keys")
            return qsTr("This wallet has no keys to encrypt notes with.") + translationManager.emptyString;
        if (code === "busy")
            return qsTr("The wallet is busy, try again.") + translationManager.emptyString;
        if (code === "locked")
            return qsTr("The notes are locked.") + translationManager.emptyString;
        if (code.indexOf("device") === 0)
            return qsTr("The Trezor did not confirm. Check that it is connected and unlocked.") + translationManager.emptyString
                   + (code.length > 8 ? " (" + code.substring(8) + ")" : "");
        return code;
    }

    function unlock() {
        if (!currentWallet || busy)
            return;
        busy = true;
        error = "";
        var pass = passwordInput.text;
        currentWallet.notesUnlockAsync(pass, function(ok, text, err) {
            busy = false;
            passwordInput.text = "";
            if (!ok) {
                error = errorText(err);
                return;
            }
            var list = [];
            if (text !== "") {
                try {
                    var data = JSON.parse(text);
                    list = data.notes || [];
                } catch (e) {
                    // plain text from an older or hand made file: keep it as one note
                    list = [{ title: qsTr("Notes") + translationManager.emptyString, text: text, updated: Date.now() }];
                }
            }
            notes = list;
            unlocked = true;
            dirty = false;
            savedAt = "";
            select(list.length > 0 ? 0 : -1);
        });
    }

    function lockNotes() {
        saveTimer.stop();
        if (dirty && unlocked && currentWallet) {
            save(function() { finishLock(); });
            return;
        }
        finishLock();
    }

    function finishLock() {
        if (currentWallet)
            currentWallet.notesLock();
        unlocked = false;
        notes = [];
        current = -1;
        dirty = false;
        loadingEditor = true;
        titleInput.text = "";
        bodyInput.text = "";
        loadingEditor = false;
        fileTick++;
    }

    function select(index) {
        loadingEditor = true;
        current = index;
        titleInput.text = index >= 0 ? notes[index].title : "";
        bodyInput.text = index >= 0 ? notes[index].text : "";
        loadingEditor = false;
    }

    function edited() {
        if (loadingEditor || current < 0)
            return;
        var list = notes.slice();
        list[current] = { title: titleInput.text, text: bodyInput.text, updated: Date.now() };
        notes = list;
        dirty = true;
        saveTimer.restart();
    }

    function addNote() {
        var list = notes.slice();
        list.unshift({ title: qsTr("New note") + translationManager.emptyString, text: "", updated: Date.now() });
        notes = list;
        dirty = true;
        select(0);
        saveTimer.restart();
        bodyInput.forceActiveFocus();
    }

    function deleteNote() {
        if (current < 0)
            return;
        var list = notes.slice();
        list.splice(current, 1);
        notes = list;
        dirty = true;
        select(Math.min(current, list.length - 1));
        saveTimer.restart();
    }

    function save(done) {
        if (!currentWallet || !unlocked)
            return;
        saving = true;
        dirty = false;
        var payload = JSON.stringify({ version: 1, notes: notes });
        currentWallet.notesSaveAsync(payload, function(ok, err) {
            saving = false;
            if (ok) {
                savedAt = new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss");
                error = "";
            } else {
                dirty = true;
                error = errorText(err);
            }
            if (done)
                done();
        });
    }

    function noteDate(ms) {
        return ms ? new Date(ms).toLocaleString(Qt.locale(), "dd/MM/yy HH:mm") : "";
    }

    function onPageCompleted() {
        error = "";
        fileTick++;
        if (!unlocked)
            passwordInput.forceActiveFocus();
    }

    function onPageClosed() {
        lockNotes();
    }

    Connections {
        target: appWindow
        function onCurrentWalletChanged() {
            pageNotes.unlocked = false;
            pageNotes.notes = [];
            pageNotes.current = -1;
            pageNotes.dirty = false;
        }
    }

    Timer {
        id: saveTimer
        interval: 1500
        onTriggered: if (pageNotes.dirty && !pageNotes.saving) pageNotes.save()
    }

    component Frame: MoneroComponents.NeonFrame {
        cut: 12
        accent: pageNotes.neutral
        lineOpacity: 0.35
        fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#EEF4EF"
        fillOpacity: 0.92
        glow: 0.0
    }

    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MoneroComponents.LabelSubheader {
                Layout.fillWidth: true
                fontSize: 24
                text: qsTr("Notes") + translationManager.emptyString
            }

            MoneroComponents.TextPlain {
                visible: pageNotes.unlocked
                text: pageNotes.saving ? (qsTr("Saving…") + translationManager.emptyString)
                      : pageNotes.dirty ? (qsTr("Unsaved changes") + translationManager.emptyString)
                      : pageNotes.savedAt !== "" ? (qsTr("Saved %1").arg(pageNotes.savedAt) + translationManager.emptyString)
                      : (qsTr("Encrypted") + translationManager.emptyString)
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.StandardButton {
                small: true
                visible: pageNotes.unlocked
                text: qsTr("Lock") + translationManager.emptyString
                onClicked: pageNotes.lockNotes()
            }
        }

        // ---------- locked ----------
        Item {
            Layout.fillWidth: true
            visible: !pageNotes.unlocked
            implicitHeight: lockedBody.implicitHeight + 40

            Frame { anchors.fill: parent }

            ColumnLayout {
                id: lockedBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 14

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    color: MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                    text: (pageNotes.device
                           ? qsTr("The notes are encrypted with the wallet keys and your Trezor. Enter the wallet password and then confirm on the Trezor.")
                           : qsTr("The notes are encrypted with the wallet keys. Enter the wallet password to open them."))
                          + translationManager.emptyString
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: 12
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    text: currentWallet && pageNotes.fileTick >= 0 ? ((currentWallet.notesFileExists() ? "" : qsTr("New file: ") + translationManager.emptyString)
                                           + currentWallet.notesFilePath()) : ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 300
                        Layout.maximumWidth: 300
                        implicitHeight: 38
                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 6
                            accent: pageNotes.neutral
                            lineOpacity: passwordInput.activeFocus ? 0.9 : 0.4
                            fillColor: pageNotes.neutral
                            fillOpacity: 0.04
                            ticks: false
                        }
                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: MoneroComponents.Style.defaultFontColor
                            selectionColor: Qt.rgba(0.5, 0.5, 0.5, 0.4)
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 14
                            clip: true
                            enabled: !pageNotes.busy
                            onAccepted: pageNotes.unlock()
                        }
                        MoneroComponents.TextPlain {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: passwordInput.text === "" && !passwordInput.activeFocus
                            text: qsTr("Wallet password") + translationManager.emptyString
                            font.pixelSize: 14
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                    }

                    MoneroComponents.StandardButton {
                        enabled: !pageNotes.busy
                        text: (pageNotes.busy ? (pageNotes.device ? qsTr("Confirm on the Trezor…") : qsTr("Opening…"))
                                              : qsTr("Open notes")) + translationManager.emptyString
                        onClicked: pageNotes.unlock()
                    }

                    Item { Layout.fillWidth: true }
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    visible: pageNotes.error !== ""
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                    color: "#FF5A5A"
                    themeTransition: false
                    text: pageNotes.error
                }
            }
        }

        // ---------- unlocked ----------
        Item {
            Layout.fillWidth: true
            visible: pageNotes.unlocked
            implicitHeight: 520

            Frame { anchors.fill: parent }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // note list
                ColumnLayout {
                    Layout.preferredWidth: 220
                    Layout.maximumWidth: 220
                    Layout.fillHeight: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MoneroComponents.StandardButton {
                            small: true
                            text: qsTr("New note") + translationManager.emptyString
                            onClicked: pageNotes.addNote()
                        }
                        MoneroComponents.StandardButton {
                            small: true
                            primary: false
                            enabled: pageNotes.current >= 0
                            text: qsTr("Delete") + translationManager.emptyString
                            onClicked: pageNotes.deleteNote()
                        }
                    }

                    ListView {
                        id: noteList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: pageNotes.notes
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            width: noteList.width
                            height: 46
                            radius: 2
                            color: index === pageNotes.current ? Qt.rgba(1, 0.4, 0, 0.14)
                                   : rowArea.containsMouse ? Qt.rgba(0.5, 0.5, 0.5, 0.10) : "transparent"
                            border.width: index === pageNotes.current ? 1 : 0
                            border.color: Qt.rgba(1, 0.4, 0, 0.6)
                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 2
                                MoneroComponents.TextPlain {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: modelData.title !== "" ? modelData.title : (qsTr("Untitled") + translationManager.emptyString)
                                    font.pixelSize: 14
                                    font.bold: index === pageNotes.current
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }
                                MoneroComponents.TextPlain {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: pageNotes.noteDate(modelData.updated)
                                    font.pixelSize: 11
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                            }
                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pageNotes.select(index)
                            }
                        }
                    }

                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        visible: pageNotes.notes.length === 0
                        wrapMode: Text.WordWrap
                        text: qsTr("No notes yet.") + translationManager.emptyString
                        font.pixelSize: 13
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    width: 1
                    color: pageNotes.neutral
                    opacity: 0.2
                }

                // editor
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    enabled: pageNotes.current >= 0
                    opacity: enabled ? 1 : 0.4

                    TextInput {
                        id: titleInput
                        Layout.fillWidth: true
                        color: MoneroComponents.Style.defaultFontColor
                        selectionColor: Qt.rgba(0.5, 0.5, 0.5, 0.4)
                        font.pixelSize: 20
                        font.bold: true
                        selectByMouse: true
                        clip: true
                        maximumLength: 120
                        onTextEdited: pageNotes.edited()
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: pageNotes.accent
                        opacity: 0.5
                    }

                    Flickable {
                        id: bodyFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: bodyInput.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        function ensureVisible(r) {
                            if (contentY >= r.y)
                                contentY = r.y;
                            else if (contentY + height <= r.y + r.height)
                                contentY = r.y + r.height - height;
                        }

                        TextEdit {
                            id: bodyInput
                            width: bodyFlick.width
                            height: Math.max(implicitHeight, bodyFlick.height)
                            wrapMode: TextEdit.Wrap
                            color: MoneroComponents.Style.defaultFontColor
                            selectionColor: Qt.rgba(0.5, 0.5, 0.5, 0.4)
                            font.family: MoneroComponents.Style.fontRegular.name
                            font.pixelSize: 15
                            selectByMouse: true
                            textFormat: TextEdit.PlainText
                            onTextChanged: pageNotes.edited()
                            onCursorRectangleChanged: bodyFlick.ensureVisible(cursorRectangle)

                            MoneroComponents.TextPlain {
                                visible: bodyInput.text === "" && pageNotes.current >= 0
                                text: qsTr("Write here. Everything is saved encrypted.") + translationManager.emptyString
                                font.pixelSize: 15
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                        }
                    }
                }
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            visible: pageNotes.unlocked && pageNotes.error !== ""
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            color: "#FF5A5A"
            themeTransition: false
            text: pageNotes.error
        }
    }
}
