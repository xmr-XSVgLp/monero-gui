import QtQuick
import QtQuick.Layouts

import "../../components" as MoneroComponents

// Security > Extreme privacy: one switch that turns off prices, external services and update checks, and only
// lets traffic out through an approved route (NymVPN or the SOCKS5 proxy). Without a route nothing syncs.
ColumnLayout {
    id: tab
    spacing: 16

    readonly property bool on: persistentSettings.extremePrivacy
    readonly property string routeAddress: appWindow.approvedRoute()
    readonly property bool hasRoute: routeAddress !== ""

    MoneroComponents.TextPlain {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: qsTr("A profile for when privacy matters more than convenience. Nothing leaves the app except through an approved route, and the wallet does not sync until that route is up.") + translationManager.emptyString
    }

    MoneroComponents.SettingsCard {
        padding: 22
        spacing: 16
        selected: tab.on

        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Rectangle {
                width: 14; height: 14; radius: 7
                color: tab.on ? (tab.hasRoute ? securityPage.goodColor : securityPage.badColor) : securityPage.offColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                MoneroComponents.TextPlain {
                    text: (tab.on ? qsTr("Extreme privacy is ON") : qsTr("Extreme privacy is off")) + translationManager.emptyString
                    font.pixelSize: 20
                    font.bold: true
                    color: MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                    themeTransition: false
                    color: !tab.on ? MoneroComponents.Style.dimmedFontColor : tab.hasRoute ? securityPage.goodColor : securityPage.badColor
                    text: !tab.on ? qsTr("The app works as usual.") + translationManager.emptyString
                          : tab.hasRoute ? qsTr("Approved route: %1").arg(securityPage.route.text) + translationManager.emptyString
                          : qsTr("SYNC BLOCKED: there is no approved route. Connect NymVPN or turn on the SOCKS5 proxy.") + translationManager.emptyString
                }
            }
            MoneroComponents.StandardButton {
                text: (tab.on ? qsTr("Turn off") : qsTr("Turn on")) + translationManager.emptyString
                primary: !tab.on
                onClicked: appWindow.setExtremePrivacy(!tab.on)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: tab.on && !tab.hasRoute
            spacing: 10
            MoneroComponents.StandardButton {
                small: true
                text: qsTr("Connect NymVPN") + translationManager.emptyString
                onClicked: securityPage.openSettings("Node")
            }
            Item { Layout.fillWidth: true }
        }
    }

    MoneroComponents.SectionTitle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("What it does") + translationManager.emptyString
    }

    MoneroComponents.SettingsCard {
        padding: 18
        spacing: 14

        SecRow {
            dot: tab.on ? securityPage.goodColor : securityPage.offColor
            tag: (persistentSettings.fiatPriceEnabled ? qsTr("on") : qsTr("off")) + translationManager.emptyString
            title: qsTr("Price queries off") + translationManager.emptyString
            detail: qsTr("Kraken, CoinPaprika, Frankfurter, CoinGecko and the swap rates stop. Markets and Swaps hide from the menu.") + translationManager.emptyString
        }
        SecRow {
            dot: tab.on ? securityPage.goodColor : securityPage.offColor
            tag: (persistentSettings.checkForUpdates ? qsTr("on") : qsTr("off")) + translationManager.emptyString
            title: qsTr("Update checks off") + translationManager.emptyString
            detail: qsTr("The update lookup uses DNS outside the proxy, so it is turned off. Check for new versions by hand on GitHub.") + translationManager.emptyString
        }
        SecRow {
            dot: tab.on ? securityPage.goodColor : securityPage.offColor
            title: qsTr("No direct connections") + translationManager.emptyString
            detail: qsTr("The remote node, the connection check and the node manager only go out through the approved route. Without a route the app blocks them instead of falling back to your real IP.") + translationManager.emptyString
        }
        SecRow {
            dot: tab.on ? securityPage.goodColor : securityPage.offColor
            title: qsTr("Local node behind the route") + translationManager.emptyString
            detail: qsTr("monerod is started with --proxy pointing to the route, without UPnP (--no-igd), without announcing its port (--hide-my-port) and without a bootstrap node. Without a route it does not start.") + translationManager.emptyString
        }
        SecRow {
            dot: tab.on ? securityPage.goodColor : securityPage.offColor
            title: qsTr("No accidental telemetry") + translationManager.emptyString
            detail: qsTr("This wallet has no analytics. With these switches off, the only traffic left is the Monero network itself, through the route.") + translationManager.emptyString
        }
        SecRow {
            dot: securityPage.warnColor
            title: qsTr("Restart the local node") + translationManager.emptyString
            visible: !persistentSettings.useRemoteNode && appWindow.daemonRunning
            detail: qsTr("monerod is already running with the flags it had when it started. Stop it and start it again (Settings > Node) so it uses the route.") + translationManager.emptyString
        }
        SecRow {
            dot: securityPage.warnColor
            title: qsTr("Links open outside") + translationManager.emptyString
            detail: qsTr("Links in Wallet+ open in your browser, which does not go through Nym or the app's proxy.") + translationManager.emptyString
        }
        SecRow {
            dot: securityPage.offColor
            title: qsTr("When you turn it off") + translationManager.emptyString
            detail: qsTr("Price conversion and update checks go back to how they were before.") + translationManager.emptyString
        }
    }
}
