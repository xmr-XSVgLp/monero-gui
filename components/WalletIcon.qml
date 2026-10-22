import QtQuick

import "." as MoneroComponents

// Icon of a wallet tile on the open-wallet page. kind: safe | trezor | viewonly | ledger | usb | testnet | stagenet
// | custom/<name> (images/wallet-icons/custom_icons/<name>.png)
Item {
    id: root
    property string kind: "safe"

    readonly property var images: ({
        safe: "qrc:///images/wallet-icons/open-wallet-safe.png",
        trezor: "qrc:///images/wallet-icons/open-wallet-from-file-trezor.png",
        viewonly: "qrc:///images/wallet-icons/open-wallet-from-file-view-only.png",
        ledger: "qrc:///images/wallet-icons/restore-wallet-from-hardware.png",
        testnet: "qrc:///images/wallet-icons/open-wallet-from-file-testnet.png",
        stagenet: "qrc:///images/wallet-icons/open-wallet-from-file-stagenet.png"
    })

    MoneroComponents.UsbIcon {
        visible: root.kind === "usb"
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.81)
        height: width
    }

    Image {
        visible: root.kind !== "usb"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        source: root.kind.indexOf("custom/") === 0 ? "qrc:///images/wallet-icons/custom_icons/" + root.kind.substring(7) + ".png"
                                                   : (root.images[root.kind] || root.images.safe)
    }
}
