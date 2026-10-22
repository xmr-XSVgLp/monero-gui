import QtQuick
import QtQuick.Layouts
import "." as MoneroComponents

Item {
    id: root
    visible: false
    property string heading: ""
    property string message: ""
    property string cancelLabel: ""
    property string acceptLabel: ""
    property var accepted: null
    function open(title, text, cancel, accept, callback) {
        if (visible) return;
        heading = title; message = text; cancelLabel = cancel; acceptLabel = accept; accepted = callback;
        appWindow.modalDialogs++;
        visible = true;
        forceActiveFocus();
    }
    function finish(confirm) {
        var callback = accepted;
        accepted = null;
        if (visible) appWindow.modalDialogs = Math.max(0, appWindow.modalDialogs - 1);
        visible = false;
        if (confirm && callback) callback();
    }
    Keys.onEscapePressed: finish(false)
    MoneroComponents.ModalTint { }
    MoneroComponents.ModalCard {
        title: root.heading
        kind: ""
        maxWidth: 620
        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.message
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            MoneroComponents.StandardButton { objectName: "keepOpen"; small: true; text: root.cancelLabel; onClicked: root.finish(false) }
            MoneroComponents.StandardButton { objectName: "closeAnyway"; small: true; text: root.acceptLabel; onClicked: root.finish(true) }
        }
    }
}
