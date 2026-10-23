import QtQuick
import QtTest
import "../../components" as UI
Item {
 id: appWindow
 width: 900; height: 700
 property bool active: false
 property bool hideBalanceForced: false
 property bool themeTransition: false
 property bool transitioning: false
 function updateBalance() {}
 QtObject { id: oshelper; function isCapsLock() { return false; } }
 QtObject { id: translationManager; property string emptyString: "" }
 Item { id: leftPanel }
 Item { id: middlePanel }
 Item { id: wizard; property bool deviceWalletCreationInProgress: false }
 Item { id: titleBar }
 Item { id: rootItem; state: "wizard" }
 TextInput { id: other; focus: true }
 UI.PasswordDialog { id: dialog; anchors.fill: parent }
 UI.BootScreen {
  id: boot
  anchors.fill: parent
  onFinished: { if (dialog.visible) Qt.callLater(dialog.focusPassword); }
 }
 SignalSpy { id: accepted; target: dialog; signalName: "accepted" }
 TestCase {
  name: "PasswordFocus"
  when: windowShown
  function test_introFinishesWithoutClick() {
   appWindow.active=true;
   dialog.open("Test wallet");
   wait(1);
   boot.start();
   verify(boot.activeFocus);
   verify(!dialog.activeFocus);
   // Wait for the real intro and fade-out, without keyboard or mouse input.
   tryCompare(boot,"visible",false,10000);
   tryCompare(dialog,"activeFocus",true);
   keyClick(Qt.Key_A);keyClick(Qt.Key_B);keyClick(Qt.Key_C);
   compare(dialog.password,"abc");
   keyClick(Qt.Key_Return);
   compare(accepted.count,1);
   compare(dialog.visible,false);
  }
 }
}
