import QtQuick
import QtTest
import "../../components" as UI
Item {
    id: appWindow
    width: 900; height: 650
    function releaseFocus() {}
    property int modalDialogs: 0
    property bool transitioning: false
    property QtObject translationManager: QtObject { property string emptyString: "" }
    UI.ScheduledPaymentDialog { id: dialog; anchors.fill: parent }
    TestCase {
        name: "ScheduledPaymentDialog"
        when: windowShown
        function test_exit_requires_explicit_consent() {
            var closed = false;
            dialog.open("Pending", "Schedules will be retained", "Keep open", "Close anyway", function() { closed = true; });
            compare(appWindow.modalDialogs, 1);
            wait(30);
            mouseClick(findChild(dialog, "keepOpen"));
            compare(closed, false);
            compare(dialog.visible, false);
            compare(appWindow.modalDialogs, 0);
            dialog.open("Pending", "Schedules will be retained", "Keep open", "Close anyway", function() { closed = true; });
            wait(30);
            mouseClick(findChild(dialog, "closeAnyway"));
            compare(closed, true);
            compare(appWindow.modalDialogs, 0);
        }
    }
}
