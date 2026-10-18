import QtQuick
import QtTest
import "../../components" as UI
Item {
    id: appWindow
    width: 900; height: 650
    property bool transitioning: false
    property int modalDialogs: 0
    property string nymVpnState: "connected"
    property bool nymClientAvailable: true
    property string nymVpnMessage: ""
    property bool nymVpnInfoLoading: false
    property string nymVpnEntryId: "entry"
    property string nymVpnExitId: "exit"
    property string nymVpnIp: "IP"
    property string nymVpnIpPlace: ""
    property string nymVpnRouteNote: ""
    property bool opened: false
    function nymVpnOpenAccount() { opened = true; }
    function nymVpnCheckInstall() {}
    function nymVpnLoadDirectory() {}
    function nymVpnDescribeGateway(id) { return id; }
    property QtObject translationManager: QtObject { property string emptyString: "" }
    property QtObject persistentSettings: QtObject {
        property bool nymVpnRequired: true
        property bool nymVpnEnabled: true
    }
    property QtObject oshelper: QtObject {
        property QtObject nymClient: QtObject {
            property bool accountAvailable: false
            property string message: ""
            property string device: "12345678901234567890123456789012345678901234"
            function accountSettings() { return {mnemonic: "saved test phrase"}; }
        }
    }
    UI.NymVpnPanel { id: panel; width: parent.width; checked: true }
    TestCase {
        name: "NymPanel"
        when: windowShown
        function test_header_link_opens_account_without_collapsing() {
            appWindow.nymVpnState = "connected";
            wait(50);
            var link = findChild(panel, "nymDeviceLink");
            verify(link !== null);
            verify(link.width > 20);
            mouseClick(link, link.width / 2, link.height / 2);
            compare(appWindow.opened, true);
            compare(panel.checked, true);
        }
        function test_seed_input_has_two_lines() {
            appWindow.nymVpnState = "off";
            wait(50);
            var input = findChild(panel, "nymSeedInput");
            verify(input.visible);
            verify(input.height >= input.font.pixelSize * 2 + input.topPadding + input.bottomPadding);
            compare(input.wrapMode, TextEdit.Wrap);
            compare(input.text, "saved test phrase");
            verify(input.height < input.font.pixelSize * 3 + input.topPadding + input.bottomPadding);
        }
    }
}
