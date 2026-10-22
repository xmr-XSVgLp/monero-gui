import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

import "../../components" as MoneroComponents
import "../../js/Utils.js" as Utils

// Security > Security center: file permissions, password strength, backups, node connection and privacy
// settings. It only looks at metadata: the keys and the seed are never read or shown here.
ColumnLayout {
    id: tab
    spacing: 16
    property alias backupsHeading: backupsHeading

    property int refreshTick: 0
    property var nodeInfo: null
    property string nodeError: ""
    property string backupMessage: ""
    property var volumes: []     // removable drives (USB, SD), refreshed while this tab is shown

    // the drive the open wallet lives on, or null if it is on this computer
    readonly property var walletVolume: {
        for (var i = 0; i < volumes.length; ++i)
            if (walletPath.indexOf(volumes[i].root + "/") === 0)
                return volumes[i];
        return null;
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: tab.visible
        onTriggered: {
            var v = oshelper.removableVolumes();
            if (JSON.stringify(v) !== JSON.stringify(tab.volumes))
                tab.volumes = v;
        }
    }

    function saveToUsb(volume) {
        var r = oshelper.backupWallet(tab.walletPath, volume.root + "/XMR");
        if (r.ok) {
            tab.setBackup("usb", Date.now());
            tab.backupMessage = qsTr("Saved on %1 in %2. Open it from \"USB / SD wallets\" when opening a wallet, and unplug the drive after closing the wallet.").arg(volume.name).arg(r.dir) + translationManager.emptyString;
        } else if (r.error === "same") {
            tab.backupMessage = qsTr("This wallet is already open from that folder.") + translationManager.emptyString;
        } else {
            tab.backupMessage = qsTr("The copy could not be written on %1.").arg(volume.name) + translationManager.emptyString;
        }
    }

    readonly property string walletPath: currentWallet ? currentWallet.path : ""
    readonly property bool hardware: currentWallet ? currentWallet.isHwBacked() : false
    readonly property string walletFolder: walletPath.substring(0, Math.max(walletPath.lastIndexOf("/"), 0))

    // [{label, path, info}] for the wallet's files and its folder
    readonly property var files: {
        refreshTick;
        if (walletPath === "")
            return [];
        var list = [
            { label: qsTr("Keys file (.keys)") + translationManager.emptyString, path: walletPath + ".keys" },
            { label: qsTr("Wallet cache") + translationManager.emptyString, path: walletPath },
            { label: qsTr("Encrypted notes") + translationManager.emptyString, path: walletPath + "_notes" },
            { label: qsTr("Wallet folder") + translationManager.emptyString, path: walletFolder }
        ];
        for (var i = 0; i < list.length; ++i)
            list[i].info = oshelper.filePermissions(list[i].path);
        return list.filter(function(f) { return f.info.exists; });
    }
    readonly property bool permissionsOk: {
        for (var i = 0; i < files.length; ++i)
            if (files[i].info.groupOrOthers) return false;
        return files.length > 0;
    }

    // rough strength from length and character classes; the password itself is never shown or stored
    readonly property var password: {
        var p = appWindow.walletPassword || "";
        var classes = (/[a-z]/.test(p) ? 1 : 0) + (/[A-Z]/.test(p) ? 1 : 0) + (/[0-9]/.test(p) ? 1 : 0) + (/[^A-Za-z0-9]/.test(p) ? 1 : 0);
        var pool = (/[a-z]/.test(p) ? 26 : 0) + (/[A-Z]/.test(p) ? 26 : 0) + (/[0-9]/.test(p) ? 10 : 0) + (/[^A-Za-z0-9]/.test(p) ? 33 : 0);
        var bits = p.length * (pool > 0 ? Math.log(pool) / Math.LN2 : 0);
        if (/^(.)\1+$/.test(p) || /^(1234+5?6?7?8?9?0?|password|contraseña|monero|qwerty|wallet)[\d!.]*$/i.test(p))
            bits = Math.min(bits, 20);
        var level = p.length === 0 ? 0 : bits < 40 ? 1 : bits < 60 ? 2 : bits < 80 ? 3 : 4;
        return { empty: p.length === 0, level: level, long: p.length >= 12, classes: classes, bits: Math.round(bits) };
    }

    readonly property var backups: {
        refreshTick;
        try { return (JSON.parse(persistentSettings.securityBackups) || {})[walletPath] || {}; } catch (e) { return {}; }
    }
    function setBackup(key, value) {
        var all = {};
        try { all = JSON.parse(persistentSettings.securityBackups) || {}; } catch (e) {}
        var b = all[walletPath] || {};
        b[key] = value;
        all[walletPath] = b;
        persistentSettings.securityBackups = JSON.stringify(all);
        refreshTick++;
    }
    function ago(t) {
        if (!t) return "";
        var d = Math.floor((Date.now() - t) / 86400000);
        return d === 0 ? qsTr("today") + translationManager.emptyString : qsTr("%1 days ago").arg(d) + translationManager.emptyString;
    }
    readonly property bool backupOk: hardware || (!!backups.seed && (backups.keys ? (Date.now() - backups.keys) < 90 * 86400000 : true))

    readonly property string remoteAddress: remoteNodesModel.currentRemoteNode().address || ""
    readonly property bool remoteTls: /^https:\/\//i.test(remoteAddress) || /:443$/.test(remoteAddress)
    readonly property bool remoteLocal: /^(https?:\/\/)?(127\.0\.0\.1|localhost|\[::1\]):/i.test(remoteAddress)
    readonly property bool nodeOk: persistentSettings.useRemoteNode
                                   ? securityPage.route.kind !== "direct" || remoteLocal
                                   : appWindow.daemonRunning && nodeInfo !== null && (nodeInfo.outgoing_connections_count || 0) > 0
    readonly property bool privacyOk: true   // Network configuration: always Tor or Nym, never direct
    readonly property bool sessionOk: persistentSettings.lockOnUserInActivity && persistentSettings.askPasswordBeforeSending

    readonly property int passed: (permissionsOk ? 1 : 0) + (password.level >= 3 || hardware ? 1 : 0) + (backupOk ? 1 : 0)
                                  + (nodeOk ? 1 : 0) + (privacyOk ? 1 : 0) + (sessionOk ? 1 : 0)

    function loadNode() {
        nodeError = "";
        if (persistentSettings.useRemoteNode || !appWindow.daemonRunning) {
            nodeInfo = null;
            return;
        }
        oshelper.nodeRpc(appWindow.localDaemonAddress, "", "/get_info", "", 8000, function(ok, ms, body, error) {
            if (!ok) { nodeInfo = null; nodeError = error; return; }
            try { nodeInfo = JSON.parse(body); } catch (e) { nodeInfo = null; nodeError = "JSON"; }
        });
    }

    function onPageCompleted() {
        refreshTick++;
        loadNode();
    }

    FolderDialog {
        id: backupFolderDialog
        title: qsTr("Choose where to save the wallet backup") + translationManager.emptyString
        onAccepted: {
            var folder = walletManager.urlToLocalPath(backupFolderDialog.selectedFolder);
            var r = oshelper.backupWallet(tab.walletPath, folder);
            if (r.ok) {
                tab.setBackup("keys", Date.now());
                tab.backupMessage = qsTr("Saved in %1: %2 (permissions 600). Keep it on a drive other than this computer.").arg(r.dir).arg(r.files.join(", ")) + translationManager.emptyString;
            } else if (r.error === "same") {
                tab.backupMessage = qsTr("This wallet is already open from that folder.") + translationManager.emptyString;
            } else {
                tab.backupMessage = qsTr("The copy could not be written in that folder.") + translationManager.emptyString;
            }
        }
    }

    // ---- summary ----
    MoneroComponents.SettingsCard {
        padding: 22
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            MoneroComponents.TextPlain {
                text: tab.passed + "/6"
                font.pixelSize: 34
                font.bold: true
                font.family: MoneroComponents.Style.fontMonoRegular.name
                color: tab.passed === 6 ? securityPage.goodColor : tab.passed >= 4 ? securityPage.warnColor : securityPage.badColor
                themeTransition: false
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                MoneroComponents.TextPlain {
                    text: (tab.passed === 6 ? qsTr("Everything in order") : qsTr("%1 checks need attention").arg(6 - tab.passed)) + translationManager.emptyString
                    font.pixelSize: 18
                    font.bold: true
                    color: MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    text: qsTr("These checks only look at file permissions, dates and settings. Your private keys and seed are never read or shown here.") + translationManager.emptyString
                }
            }
            MoneroComponents.StandardButton {
                small: true
                primary: false
                text: qsTr("Check again") + translationManager.emptyString
                onClicked: tab.onPageCompleted()
            }
        }
    }

    // ---- 1. files ----
    MoneroComponents.SectionTitle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("File permissions") + translationManager.emptyString
    }
    MoneroComponents.SettingsCard {
        padding: 18
        spacing: 12
        MoneroComponents.TextPlain {
            visible: tab.files.length === 0
            text: qsTr("Open a wallet to check its files.") + translationManager.emptyString
            font.pixelSize: 13
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }
        Repeater {
            model: tab.files
            delegate: SecRow {
                dot: modelData.info.groupOrOthers ? (modelData.info.isDir ? securityPage.warnColor : securityPage.badColor) : securityPage.goodColor
                title: modelData.label
                tag: modelData.info.mode
                detail: "<font face=\"" + MoneroComponents.Style.fontMonoRegular.name + "\">" + Utils.htmlEscape(modelData.path) + "</font><br>"
                        + (modelData.info.groupOrOthers ? qsTr("Other users of this Mac can read it.") : qsTr("Only your user can read it.")) + translationManager.emptyString
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: tab.files.length > 0 && !tab.permissionsOk
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
                text: qsTr("Sets 600 on the files and 700 on the folder: only your user can open them.") + translationManager.emptyString
            }
            MoneroComponents.StandardButton {
                small: true
                text: qsTr("Fix permissions") + translationManager.emptyString
                onClicked: {
                    for (var i = 0; i < tab.files.length; ++i)
                        oshelper.restrictPermissions(tab.files[i].path);
                    tab.refreshTick++;
                }
            }
        }
    }

    // ---- 2. password ----
    MoneroComponents.SectionTitle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("Wallet password") + translationManager.emptyString
    }
    MoneroComponents.SettingsCard {
        padding: 18
        spacing: 12
        SecRow {
            readonly property var names: [qsTr("No password"), qsTr("Weak"), qsTr("Fair"), qsTr("Strong"), qsTr("Very strong")]
            dot: [securityPage.badColor, securityPage.badColor, securityPage.warnColor, securityPage.goodColor, securityPage.goodColor][tab.password.level]
            title: names[tab.password.level] + translationManager.emptyString
            tag: tab.password.empty ? "" : qsTr("~%1 bits").arg(tab.password.bits) + translationManager.emptyString
            detail: (tab.password.empty ? qsTr("Anyone with access to this Mac can open the wallet file.")
                     : [tab.password.long ? qsTr("12 characters or more") : qsTr("shorter than 12 characters"),
                        qsTr("%1 of 4 character types").arg(tab.password.classes)].join(" · "))
                    + (tab.hardware ? "<br>" + qsTr("The spend key lives in the Trezor; this password protects the view key and the history.") : "")
                    + translationManager.emptyString
            MoneroComponents.StandardButton {
                small: true
                primary: tab.password.level < 3
                text: qsTr("Change password") + translationManager.emptyString
                onClicked: securityPage.openSettings("Wallet")
            }
        }
        Row {
            spacing: 4
            Repeater {
                model: 4
                Rectangle {
                    width: 46; height: 5; radius: 2
                    color: index < tab.password.level
                           ? (tab.password.level >= 3 ? securityPage.goodColor : tab.password.level === 2 ? securityPage.warnColor : securityPage.badColor)
                           : MoneroComponents.Style.inputBorderColorInActive
                }
            }
        }
    }

    // ---- 3. backups ----
    MoneroComponents.SectionTitle {
        id: backupsHeading
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("Backups") + translationManager.emptyString
    }
    MoneroComponents.SettingsCard {
        padding: 18
        spacing: 14
        SecRow {
            visible: tab.hardware
            dot: securityPage.goodColor
            title: qsTr("Hardware wallet") + translationManager.emptyString
            detail: qsTr("Your funds are backed by the Trezor's own recovery words (the wallet backup you wrote down when setting it up). If the Trezor is lost, those words restore everything.") + translationManager.emptyString
        }
        SecRow {
            visible: !tab.hardware
            dot: tab.backups.seed ? securityPage.goodColor : securityPage.badColor
            title: qsTr("Seed written down") + translationManager.emptyString
            tag: tab.backups.seed ? tab.ago(tab.backups.seed) : ""
            detail: (tab.backups.seed ? qsTr("You confirmed you keep the 25 words offline.")
                                      : qsTr("Not confirmed yet. The 25 words are the only backup that restores the wallet anywhere.")) + translationManager.emptyString
            MoneroComponents.StandardButton {
                small: true
                primary: false
                text: qsTr("Show seed") + translationManager.emptyString
                tooltip: qsTr("Asks for the password and opens Seed & keys") + translationManager.emptyString
                onClicked: Utils.showSeedPage()
            }
            MoneroComponents.StandardButton {
                small: true
                visible: !tab.backups.seed
                text: qsTr("I have it on paper") + translationManager.emptyString
                onClicked: tab.setBackup("seed", Date.now())
            }
        }
        SecRow {
            dot: tab.backups.keys ? ((Date.now() - tab.backups.keys) < 90 * 86400000 ? securityPage.goodColor : securityPage.warnColor) : securityPage.offColor
            title: qsTr("Wallet backup") + translationManager.emptyString
            tag: tab.backups.keys ? tab.ago(tab.backups.keys) : ""
            detail: (tab.backups.keys ? qsTr("Saved from here. Save again if you changed the password, labels or notes.")
                                      : qsTr("Saves the wallet files (keys, cache with labels and history, encrypted notes) in a folder %1 on a USB drive or another disk. They need your password to open.").arg("xmr_" + tab.walletPath.split("/").pop())) + translationManager.emptyString
            MoneroComponents.StandardButton {
                small: true
                primary: false
                enabled: tab.walletPath !== ""
                text: qsTr("Save…") + translationManager.emptyString
                onClicked: backupFolderDialog.open()
            }
        }
        SecRow {
            dot: tab.walletVolume ? securityPage.goodColor : tab.backups.usb ? securityPage.goodColor : securityPage.offColor
            title: qsTr("Wallet on a USB / SD drive") + translationManager.emptyString
            tag: tab.walletVolume ? qsTr("open from %1").arg(tab.walletVolume.name) + translationManager.emptyString
                 : tab.backups.usb ? tab.ago(tab.backups.usb) : ""
            detail: (tab.walletVolume
                     ? qsTr("This wallet is running from the drive. Close it before unplugging, so the cache is saved.")
                     : qsTr("Saves the wallet in XMR/%1 on a USB drive or SD card. Plug it in, open it from \"USB / SD wallets\" and unplug it when you close the wallet: while it is unplugged the wallet is not on any computer. Once it opens from the drive, you can delete the copy on this computer yourself.").arg("xmr_" + tab.walletPath.split("/").pop())
                       + (tab.volumes.length === 0 ? "<br>" + qsTr("Connect a USB drive or SD card to save it.") : ""))
                    + translationManager.emptyString
            Repeater {
                model: tab.walletVolume ? [] : tab.volumes
                delegate: MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    enabled: tab.walletPath !== ""
                    text: qsTr("Save to %1").arg(modelData.name) + translationManager.emptyString
                    onClicked: tab.saveToUsb(modelData)
                }
            }
        }
        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            visible: tab.backupMessage !== ""
            wrapMode: Text.WordWrap
            text: tab.backupMessage
            font.pixelSize: 12
            color: securityPage.blue
            themeTransition: false
        }
    }

    // ---- 4. node and privacy ----
    MoneroComponents.SectionTitle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("Node and network") + translationManager.emptyString
    }
    MoneroComponents.SettingsCard {
        padding: 18
        spacing: 14
        SecRow {
            visible: !persistentSettings.useRemoteNode
            dot: tab.nodeOk ? securityPage.goodColor : appWindow.daemonRunning ? securityPage.warnColor : securityPage.badColor
            title: qsTr("Local node") + translationManager.emptyString
            tag: appWindow.daemonRunning ? (tab.nodeInfo ? "v" + (tab.nodeInfo.version || "?") : "") : qsTr("stopped") + translationManager.emptyString
            detail: !appWindow.daemonRunning ? qsTr("monerod is not running: the wallet cannot sync.") + translationManager.emptyString
                    : tab.nodeInfo === null ? (tab.nodeError !== "" ? qsTr("It does not answer (%1).").arg(tab.nodeError) : qsTr("Asking the node…")) + translationManager.emptyString
                    : qsTr("%1 outgoing and %2 incoming peers · %3").arg(tab.nodeInfo.outgoing_connections_count || 0).arg(tab.nodeInfo.incoming_connections_count || 0)
                         .arg(tab.nodeInfo.synchronized ? qsTr("synchronized") : qsTr("syncing %1 / %2").arg(tab.nodeInfo.height || 0).arg(tab.nodeInfo.target_height || 0))
                      + translationManager.emptyString
        }
        SecRow {
            visible: persistentSettings.useRemoteNode
            dot: tab.nodeOk ? (tab.remoteTls || tab.remoteLocal ? securityPage.goodColor : securityPage.warnColor) : securityPage.badColor
            title: qsTr("Remote node") + translationManager.emptyString
            tag: tab.remoteAddress
            detail: [tab.remoteLocal ? qsTr("on this computer") : tab.remoteTls ? qsTr("encrypted (TLS)") : qsTr("unencrypted HTTP"),
                     qsTr("route: %1").arg(securityPage.route.text),
                     remoteNodesModel.currentRemoteNode().trusted ? qsTr("marked as trusted (it can see more: use it only if it is yours)") : qsTr("not trusted")
                    ].join(" · ") + translationManager.emptyString
            MoneroComponents.StandardButton {
                small: true
                primary: false
                text: qsTr("Nodes") + translationManager.emptyString
                onClicked: securityPage.tab = "Nodes"
            }
        }
        SecRow {
            dot: tab.privacyOk ? securityPage.goodColor : securityPage.warnColor
            title: qsTr("Network privacy") + translationManager.emptyString
            tag: persistentSettings.extremePrivacy ? qsTr("extreme") : (persistentSettings.netWallet === "nym" ? "Nym" : "Tor")
            detail: (persistentSettings.extremePrivacy ? qsTr("Extreme privacy on. Requests leave through: %1").arg(securityPage.route.text)
                     : qsTr("The app's requests leave through: %1").arg(securityPage.route.text)) + translationManager.emptyString
            MoneroComponents.StandardButton {
                small: true
                primary: false
                visible: !persistentSettings.extremePrivacy
                text: qsTr("Extreme privacy") + translationManager.emptyString
                onClicked: securityPage.tab = "Privacy"
            }
        }
        SecRow {
            dot: tab.sessionOk ? securityPage.goodColor : securityPage.warnColor
            title: qsTr("Session protection") + translationManager.emptyString
            detail: [persistentSettings.lockOnUserInActivity ? qsTr("locks after %1 min of inactivity").arg(persistentSettings.lockOnUserInActivityInterval) : qsTr("does not lock when idle"),
                     persistentSettings.askPasswordBeforeSending ? qsTr("asks the password before sending") : qsTr("sends without asking the password")
                    ].join(" · ") + translationManager.emptyString
            MoneroComponents.StandardButton {
                small: true
                primary: false
                visible: !tab.sessionOk
                text: qsTr("Settings") + translationManager.emptyString
                onClicked: securityPage.openSettings("UI")
            }
        }
    }
}
