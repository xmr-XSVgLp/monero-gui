import QtQuick
import QtTest
import "../../pages" as Pages
Item {
    id: appWindow
    width: 1100; height: 900
    property var currentWallet: null
    property string walletDeviceLabel: ""
    property bool themeTransition: false
    property bool transitioning: false
    property QtObject translationManager: QtObject { property string emptyString: "" }
    property QtObject oshelper: QtObject { function resourceImages(folder) { return []; } }
    function releaseFocus() {}
    QtObject { id: middlePanel; property var currentView: page }
    component TestWallet: QtObject {
        property int reads: 0
        property int applies: 0
        function isTrezor() { return true; }
        function deviceFeaturesAsync() { reads++; }
        function deviceApplySettingsAsync(settings) { applies++; }
        signal deviceFeaturesReceived(string json, string error)
        signal deviceSettingsApplied(bool ok, string error)
        signal deviceBrightnessDone(bool ok, string error)
    }
    TestWallet { id: safe3 }
    TestWallet { id: safe7 }
    Pages.TrezorDevice { id: page; width: parent.width; height: parent.height }
    TestCase {
        name: "MultiWalletTrezor"
        when: windowShown
        function test_switchAndLateResponse() {
            appWindow.currentWallet = safe3;
            tryCompare(safe3, "reads", 1);
            safe3.deviceFeaturesReceived(JSON.stringify({label:"Safe 3", model:"Safe 3", homescreenWidth:128, homescreenHeight:64, homescreenFormat:3}), "");
            compare(page.features.label, "Safe 3");
            verify(page.monoScreen);
            page.pendingWallpaper = "old-model.png";
            page.pendingName = "Old image";
            page.message = "Old result";
            appWindow.currentWallet = null;
            compare(page.features, null);
            appWindow.currentWallet = safe7;
            tryCompare(safe7, "reads", 1);
            compare(page.pendingWallpaper, "");
            compare(page.pendingName, "");
            compare(page.message, "");
            safe3.deviceFeaturesReceived(JSON.stringify({label:"Stale Safe 3"}), "");
            compare(page.features, null);
            safe7.deviceFeaturesReceived(JSON.stringify({label:"Safe 7", internalModel:"T3W1", homescreenWidth:380, homescreenHeight:520}), "");
            compare(page.features.label, "Safe 7");
            compare(appWindow.walletDeviceLabel, "Safe 7");
            verify(!page.monoScreen);
            page.apply("label", {label:"Renamed"});
            compare(safe7.applies, 1);
            compare(safe3.applies, 0);
            safe7.deviceSettingsApplied(true, "");
            compare(safe7.reads, 2);
            safe7.deviceFeaturesReceived("", "disconnected");
            compare(page.features, null);
            compare(page.busy, "");
            verify(page.readError !== "");
            appWindow.currentWallet = null;
            compare(page.features, null);
            compare(page.readError, "");
        }
    }
}
