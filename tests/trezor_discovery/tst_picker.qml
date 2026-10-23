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
 property int modalDialogs: 0
 function rememberTrezorDevices(list) {}
 function withKnownTrezorNames(list) { return list; }
 QtObject {
  id: walletManager
  property int calls: 0
  property var reply
  function trezorDevicesAsync(bluetooth, callback) { calls++; reply=callback; }
 }
 UI.TrezorPicker { id: picker; anchors.fill: parent }
 TestCase {
  name: "AutomaticTrezorDiscovery"
  when: windowShown
  function test_searchLifecycle() {
   var usb={path:"webusb:1",label:"Safe 3"};
   picker.open([usb],"webusb:1",null,null);
   tryCompare(walletManager,"calls",1);
   verify(picker.searching);
   picker.searchBluetooth();
   compare(walletManager.calls,1);
   walletManager.reply(JSON.stringify([usb,{path:"ble:7",label:"Safe 7"}]));
   compare(picker.devices.length,2);
   compare(picker.selectedPath,"webusb:1");
   tryCompare(walletManager,"calls",2,6500);
   picker.finish(false);
   walletManager.reply('[{"path":"ble:other"}]');
   compare(picker.devices.length,2);
   wait(5200);
   compare(walletManager.calls,2);
   compare(appWindow.modalDialogs,0);
  }
 }
}
