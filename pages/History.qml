// Copyright (c) 2014-2024, The Monero Project
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import FontAwesome

import moneroComponents.Wallet 1.0
import moneroComponents.WalletManager 1.0
import moneroComponents.TransactionHistory 1.0
import moneroComponents.TransactionInfo 1.0
import moneroComponents.TransactionHistoryModel 1.0
import moneroComponents.Clipboard 1.0

import "../components/effects/" as MoneroEffects
import "../components" as MoneroComponents
import "../js/Utils.js" as Utils
import "../js/TxUtils.js" as TxUtils


Rectangle {
    id: root
    property var model
    property int sideMargin: 20
    readonly property color accentColor: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
    readonly property color borderColor: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
    property var initialized: false
    property int txMax: Math.max(5, ((appWindow.height - 250) / 60))
    property int txOffset: 0
    property int txPage: (txOffset / txMax) + 1
    property int txCount: 0
    property var sortSearchString: null
    property bool sortDirection: true  // true = desc, false = asc
    property string sortBy: "blockheight"
    property var txModelData: []  // representation of transaction data (appWindow.currentWallet.historyModel)
    property var txData: []  // representation of FILTERED transation data
    property var txDataCollapsed: []  // keep track of which txs are collapsed
    property string historyStatusMessage: ""
    property alias contentHeight: pageRoot.height

    Clipboard { id: clipboard }
    ListModel { id: txListViewModel }

    color: "transparent"

    onTxMaxChanged: root.updateDisplay(root.txOffset, root.txMax);

    ColumnLayout {
        id: pageRoot
        anchors.topMargin: 40

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 0

        // header: title + "Sort & filter" toggle
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: sideMargin
            Layout.rightMargin: sideMargin
            spacing: 12

            MoneroComponents.LabelSubheader {
                Layout.fillWidth: true
                fontSize: 24
                textFormat: Text.RichText
                text: qsTr("Transactions") + translationManager.emptyString
            }

            Item {
                id: sortAndFilter
                visible: root.txCount > 0
                property bool collapsed: false   // true = filter card open
                readonly property bool hovered: sortAndFilterMouse.containsMouse
                Layout.preferredWidth: sortAndFilterRow.implicitWidth + 28
                Layout.preferredHeight: 32

                MoneroComponents.CardPanel {
                    anchors.fill: parent
                    cut: 7
                    hovered: sortAndFilter.hovered
                    selected: sortAndFilter.collapsed
                }

                RowLayout {
                    id: sortAndFilterRow
                    anchors.centerIn: parent
                    spacing: 10

                    MoneroComponents.TextPlain {
                        text: (qsTr("Sort & filter") + translationManager.emptyString).toUpperCase()
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 12
                        font.letterSpacing: 1.5
                        color: sortAndFilter.collapsed || sortAndFilter.hovered
                               ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }

                    Canvas {
                        id: sortCollapsedIcon
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        rotation: sortAndFilter.collapsed ? 270 : 90
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        property color c: root.accentColor
                        onCChanged: requestPaint()
                        onPaint: root.paintChevron(getContext("2d"), c)
                    }
                }

                MouseArea {
                    id: sortAndFilterMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        sortAndFilter.collapsed = !sortAndFilter.collapsed
                    }
                }
            }
        }

        // filter card: search, date range, sort
        Item {
            visible: sortAndFilter.collapsed
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.leftMargin: sideMargin
            Layout.rightMargin: sideMargin
            implicitHeight: filterColumn.implicitHeight + 32

            MoneroComponents.CardPanel {
                anchors.fill: parent
                cut: 12
            }

            ColumnLayout {
                id: filterColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 14

                MoneroComponents.LineEdit {
                    id: searchInput
                    Layout.fillWidth: true
                    input.topPadding: 6
                    input.bottomPadding: 6
                    fontSize: 15
                    labelFontSize: 14
                    placeholderText: qsTr("Search by Transaction ID, Address, Description, Amount or Blockheight") + translationManager.emptyString
                    placeholderFontSize: 15
                    inputHeight: 34
                    onTextUpdated: {
                        if (!sortAndFilter.collapsed) {
                            sortAndFilter.collapsed = true;
                        }
                        if(searchInput.text != null && searchInput.text.length >= 3){
                            root.sortSearchString = searchInput.text;
                            root.reset();
                            root.updateFilter();
                        } else {
                            root.sortSearchString = null;
                            root.reset();
                            root.updateFilter();
                        }
                    }

                    Rectangle {
                        color: "transparent"
                        height: cleanButton.height
                        width: cleanButton.width
                        Layout.rightMargin: -8
                        Layout.leftMargin: -2

                        MoneroComponents.InlineButton {
                            id: cleanButton
                            buttonColor: "transparent"
                            fontFamily: FontAwesome.fontFamilySolid
                            fontStyleName: "Solid"
                            fontPixelSize: 18
                            text: FontAwesome.times
                            tooltip: qsTr("Clean") + translationManager.emptyString
                            tooltipLeft: true
                            visible: searchInput.text != ""
                            onClicked: searchInput.text = ""
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 20

                    MoneroComponents.DatePicker {
                        id: fromDatePicker
                        Layout.fillWidth: true
                        width: 100
                        inputLabel.text: qsTr("Date from") + translationManager.emptyString
                        inputLabel.font.pixelSize: 14
                        onCurrentDateChanged: {
                            if(root.initialized){
                                root.reset();
                                root.updateFilter();
                            }
                        }
                    }

                    MoneroComponents.DatePicker {
                        id: toDatePicker
                        Layout.fillWidth: true
                        width: 100
                        inputLabel.text: qsTr("Date to") + translationManager.emptyString
                        inputLabel.font.pixelSize: 14

                        onCurrentDateChanged: {
                            if(root.initialized){
                                root.reset();
                                root.updateFilter();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.accentColor
                    opacity: 0.3
                }

                // sort chips
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MoneroComponents.TextPlain {
                        Layout.rightMargin: 6
                        font.family: MoneroComponents.Style.fontRegular.name
                        font.pixelSize: 14
                        text: qsTr("Sort by") + ":" + translationManager.emptyString
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }

                    Repeater {
                        model: [
                            { key: "blockheight", label: QT_TR_NOOP("Blockheight") },
                            { key: "timestamp", label: QT_TR_NOOP("Date") },
                            { key: "amount", label: QT_TR_NOOP("Amount") }
                        ]

                        delegate: Item {
                            id: sortChip
                            readonly property bool active: root.sortBy === modelData.key
                            readonly property bool hovered: sortChipMouse.containsMouse
                            Layout.preferredWidth: sortChipRow.implicitWidth + 24
                            Layout.preferredHeight: 30

                            MoneroComponents.NeonFrame {
                                anchors.fill: parent
                                cut: 6
                                accent: sortChip.active ? root.accentColor : root.borderColor
                                lineOpacity: sortChip.active ? 0.9 : (sortChip.hovered ? 0.6 : 0.25)
                                fillColor: root.accentColor
                                fillOpacity: sortChip.active ? 0.16 : (sortChip.hovered ? 0.06 : 0.0)
                                ticks: false
                                Behavior on lineOpacity { NumberAnimation { duration: 120 } }
                            }

                            RowLayout {
                                id: sortChipRow
                                anchors.centerIn: parent
                                spacing: 6

                                MoneroComponents.TextPlain {
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.pixelSize: 14
                                    text: qsTr(modelData.label) + translationManager.emptyString
                                    color: sortChip.active || sortChip.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }

                                Canvas {
                                    visible: sortChip.active
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    // desc: pointing down, asc: pointing up
                                    rotation: root.sortDirection ? 90 : 270
                                    property color c: MoneroComponents.Style.defaultFontColor
                                    onCChanged: requestPaint()
                                    onPaint: root.paintChevron(getContext("2d"), c, 10)
                                }
                            }

                            MouseArea {
                                id: sortChipMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    if(root.sortBy !== modelData.key) {
                                        root.sortDirection = true;
                                    } else {
                                        root.sortDirection = !root.sortDirection
                                    }

                                    root.sortBy = modelData.key;
                                    root.updateSort();
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // status message + pagination
        RowLayout {
            Layout.topMargin: 16
            Layout.bottomMargin: 10
            Layout.fillWidth: true
            Layout.leftMargin: sideMargin
            Layout.rightMargin: sideMargin
            spacing: 8

            MoneroComponents.TextPlain {
                // status message
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 14
                text: root.historyStatusMessage
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            RowLayout {
                id: pagination
                visible: root.txCount > 0
                spacing: 6
                Layout.alignment: Qt.AlignRight

                MoneroComponents.TextPlain {
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 14
                    text: qsTr("Page") + ":" + translationManager.emptyString
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    id: paginationText
                    Layout.rightMargin: 4
                    text: root.txPage + "/" + Math.ceil(root.txCount / root.txMax)
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.underline: paginationMouse.containsMouse
                    color: MoneroComponents.Style.defaultFontColor
                    themeTransition: false

                    MouseArea {
                        id: paginationMouse
                        // jump to page functionality
                        property int pages: Math.ceil(root.txCount / root.txMax)
                        anchors.fill: parent
                        hoverEnabled: pages > 1
                        cursorShape: hoverEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if(pages === 1)
                                return;

                            inputDialog.labelText = qsTr("Jump to page (1-%1)").arg(pages) + translationManager.emptyString;
                            inputDialog.kind = "info";
                            inputDialog.onAcceptedCallback = function() {
                                var pageNumber = parseInt(inputDialog.inputText);
                                if (!isNaN(pageNumber) && pageNumber >= 1 && pageNumber <= pages) {
                                    root.paginationJump(parseInt(pageNumber));
                                    return;
                                }

                                appWindow.showStatusMessage(qsTr("Invalid page. Must be a number within the specified range."), 4);
                            }
                            inputDialog.onRejectedCallback = null;
                            inputDialog.open()
                        }
                    }
                }

                MoneroComponents.BookIconButton {
                    id: paginationPrev
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    enabled: false
                    icon: "‹"
                    iconFamily: MoneroComponents.Style.fontMonoMedium.name
                    iconSize: 17
                    onClicked: {
                        root.paginationPrevClicked();
                    }
                }

                MoneroComponents.BookIconButton {
                    id: paginationNext
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    enabled: false
                    icon: "›"
                    iconFamily: MoneroComponents.Style.fontMonoMedium.name
                    iconSize: 17
                    onClicked: {
                        root.paginationNextClicked();
                    }
                }
            }
        }

        ListView {
            visible: true
            id: txListview
            Layout.fillWidth: true
            Layout.leftMargin: sideMargin
            Layout.rightMargin: sideMargin
            Layout.preferredHeight: contentHeight;
            model: txListViewModel
            interactive: false
            spacing: 6

            delegate: Item {
                id: delegate
                property bool collapsed: root.txDataCollapsed.indexOf(hash) >= 0 ? true : false
                readonly property bool hovered: rowHover.hovered
                readonly property bool confirmed: confirmations < confirmationsRequired ? false : true
                readonly property real detailColumnWidth: Math.floor((width - 32 - 40) / 3)
                width: txListview.width
                height: collapsed ? 52 + detailsColumn.implicitHeight : 52

                HoverHandler { id: rowHover }

                MoneroComponents.CardPanel {
                    anchors.fill: parent
                    cut: 9
                    hovered: delegate.hovered
                    selected: delegate.collapsed
                }

                // summary line: direction, amount, counterpart, status, date, chevron
                RowLayout {
                    id: summaryRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    height: 52
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 26

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 5
                            accent: root.borderColor
                            lineOpacity: delegate.hovered || delegate.collapsed ? 0.6 : 0.3
                            fillColor: root.borderColor
                            fillOpacity: 0.03
                            ticks: false
                        }

                        MoneroComponents.TxArrow {
                            visible: !isFailed && !isPending
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            out: isout
                        }

                        MoneroComponents.TextPlain {
                            visible: isFailed || isPending
                            anchors.centerIn: parent
                            font.family: FontAwesome.fontFamilySolid
                            font.styleName: isFailed ? "Solid" : ""
                            font.pixelSize: 13
                            text: isFailed ? FontAwesome.times : FontAwesome.clockO
                            color: isFailed ? (MoneroComponents.Style.blackTheme ? "#FF4D5E" : "#C62828") : MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                    }

                    // amount: sign + value (the value alone is what gets copied)
                    RowLayout {
                        Layout.fillWidth: false
                        Layout.minimumWidth: 150
                        Layout.preferredWidth: 170
                        Layout.maximumWidth: 170
                        spacing: 0

                        MoneroComponents.TextPlain {
                            visible: amount != 0
                            text: isout ? "−" : "+"
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 15
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }

                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: amount == 0 ? MoneroComponents.Style.fontRegular.name : MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 15
                            text: (amount == 0 ? qsTr("Unknown amount") : displayAmount) + translationManager.emptyString
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false

                            MouseArea {
                                state: "copyable"
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.font.underline = true
                                onExited: parent.font.underline = false
                            }
                        }
                    }

                    // direction + counterpart
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 80
                        spacing: 1

                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: MoneroComponents.Style.fontRegular.name
                            font.pixelSize: 11
                            text: (isout ? qsTr("Sent") : qsTr("Received")).toUpperCase() + translationManager.emptyString
                            font.letterSpacing: 1
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18

                            MoneroComponents.TextPlain {
                                id: addressField
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 13
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                tooltip: recipientTooltip
                                text: {
                                    if (isout) {
                                        if (address) {
                                            return recipientText;
                                        }
                                        if (amount != 0) {
                                            return qsTr("Unknown recipient") + translationManager.emptyString;
                                        } else {
                                            return qsTr("My wallet") + translationManager.emptyString;
                                        }
                                    } else {
                                        if (receivingAddress) {
                                            if (subaddrIndex == 0) {
                                                return qsTr("Address") + " #0" + " (" + qsTr("Primary address") + ")" + translationManager.emptyString;
                                            } else {
                                                if (receivingAddressLabel) {
                                                    return qsTr("Address") + " #" + subaddrIndex + " (" + receivingAddressLabel + ")" + translationManager.emptyString;
                                                } else {
                                                    return qsTr("Address") + " #" + subaddrIndex + " (" + TxUtils.addressTruncate(receivingAddress, 4) + ")" + translationManager.emptyString;
                                                }
                                            }
                                        } else {
                                            return qsTr("Unknown address") + translationManager.emptyString;
                                        }
                                    }
                                }

                                color: delegate.hovered || delegate.collapsed ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
                                themeTransition: false

                                MouseArea {
                                    state: isout ? "copyable_address" : "copyable_receiving_address"
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: Math.min(parent.width, parent.paintedWidth)
                                    height: parent.height
                                    hoverEnabled: true
                                    onEntered: {
                                        parent.font.underline = true;
                                        if (recipientTooltip) {
                                            parent.tooltipPopup.x = 0;
                                            parent.tooltipPopup.open();
                                        }
                                    }
                                    onExited: {
                                        parent.font.underline = false;
                                        parent.tooltipPopup.close();
                                    }
                                }
                            }
                        }
                    }

                    // status chip: failed / pending / unconfirmed (x/y)
                    Item {
                        id: statusChip
                        readonly property string label: isFailed ? qsTr("Failed") + translationManager.emptyString
                                                      : isPending ? qsTr("Pending") + translationManager.emptyString
                                                      : !delegate.confirmed ? confirmations + "/" + confirmationsRequired : ""
                        visible: label !== ""
                        Layout.preferredWidth: statusChipText.implicitWidth + 18
                        Layout.preferredHeight: 22

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 4
                            accent: isFailed ? (MoneroComponents.Style.blackTheme ? "#FF4D5E" : "#C62828") : root.accentColor
                            lineOpacity: 0.75
                            fillColor: accent
                            fillOpacity: 0.12
                            ticks: false
                        }

                        MoneroComponents.TextPlain {
                            id: statusChipText
                            anchors.centerIn: parent
                            text: statusChip.label
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 11
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                    }

                    MoneroComponents.TextPlain {
                        Layout.minimumWidth: persistentSettings.historyHumanDates ? 90 : 128
                        horizontalAlignment: Text.AlignRight
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 12
                        text: persistentSettings.historyHumanDates ? dateHuman : dateTime.substring(0, 16)
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }

                    Canvas {
                        id: collapsedIcon
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        rotation: delegate.collapsed ? 270 : 90
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        property color c: root.accentColor
                        onCChanged: requestPaint()
                        onPaint: root.paintChevron(getContext("2d"), c)
                    }
                }

                // details, shown when the row is open
                ColumnLayout {
                    id: detailsColumn
                    visible: delegate.collapsed
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: summaryRow.bottom
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.accentColor
                        opacity: 0.3
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        columns: 3
                        columnSpacing: 20
                        rowSpacing: 14

                        // fee / mined
                        ColumnLayout {
                            Layout.preferredWidth: delegate.detailColumnWidth
                            spacing: 3

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 12
                                text: isout ? qsTr("Fee") : confirmationsRequired === 60 ? qsTr("Mined") : qsTr("Fee") + translationManager.emptyString
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 13
                                text: {
                                    if(!isout && confirmationsRequired === 60) return qsTr("Yes") + translationManager.emptyString;
                                    if(fee !== "") return Utils.removeTrailingZeros(fee) + " XMR";
                                    return "-";
                                }
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false

                                MouseArea {
                                    state: "copyable"
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.font.underline = true
                                    onExited: parent.font.underline = false
                                }
                            }
                        }

                        // confirmations
                        ColumnLayout {
                            Layout.preferredWidth: delegate.detailColumnWidth
                            spacing: 3

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 12
                                text: qsTr("Confirmations") + translationManager.emptyString
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 13
                                text: delegate.confirmed ? confirmations : confirmations + "/" + confirmationsRequired
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false

                                MouseArea {
                                    state: "copyable"
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.font.underline = true
                                    onExited: parent.font.underline = false
                                }
                            }
                        }

                        // blockheight
                        ColumnLayout {
                            Layout.preferredWidth: delegate.detailColumnWidth
                            spacing: 3

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 12
                                text: qsTr("Blockheight") + translationManager.emptyString
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 13
                                text: (blockheight > 0 ? blockheight : qsTr('Pending')) + translationManager.emptyString;
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false

                                MouseArea {
                                    state: "copyable"
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.font.underline = true
                                    onExited: parent.font.underline = false
                                }
                            }
                        }

                        // date (full)
                        ColumnLayout {
                            Layout.preferredWidth: delegate.detailColumnWidth
                            spacing: 3

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 12
                                text: qsTr("Date") + translationManager.emptyString
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 13
                                text: persistentSettings.historyHumanDates ? dateHuman : dateTime
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false

                                MouseArea {
                                    state: "copyable"
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        parent.font.underline = true
                                        if (persistentSettings.historyHumanDates) {
                                            parent.text = dateTime;
                                        }
                                    }
                                    onExited: {
                                        parent.font.underline = false
                                        if (persistentSettings.historyHumanDates) {
                                            parent.text = dateHuman
                                        }
                                    }
                                }
                            }
                        }

                        // description + edit
                        ColumnLayout {
                            Layout.preferredWidth: 2 * delegate.detailColumnWidth + 20
                            Layout.columnSpan: 2
                            spacing: 3

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 12
                                text: qsTr("Description") + translationManager.emptyString
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                MoneroComponents.TextPlain {
                                    id: txNoteText
                                    Layout.maximumWidth: detailsColumn.width * 0.55
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.pixelSize: 14
                                    text: tx_note !== "" ? tx_note : "-"
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false

                                    MouseArea {
                                        state: "copyable"
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.font.underline = true
                                        onExited: parent.font.underline = false
                                    }
                                }

                                MoneroComponents.BookIconButton {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    interactive: false
                                    hovered: txNoteArea.containsMouse
                                    image: "qrc:///images/icons/edit-neon.png"

                                    MouseArea {
                                        id: txNoteArea
                                        state: "set_tx_note"
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }

                    // transaction ID
                    MoneroComponents.TextPlain {
                        Layout.topMargin: 14
                        font.family: MoneroComponents.Style.fontRegular.name
                        font.pixelSize: 12
                        text: qsTr("Transaction ID") + translationManager.emptyString
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }

                    MoneroComponents.TextPlain {
                        Layout.topMargin: 3
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 12
                        text: hash
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false

                        MouseArea {
                            state: "copyable"
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width: Math.min(parent.width, parent.paintedWidth)
                            height: parent.height
                            hoverEnabled: true
                            onEntered: parent.font.underline = true
                            onExited: parent.font.underline = false
                        }
                    }

                    // transaction key + actions
                    RowLayout {
                        Layout.topMargin: 14
                        Layout.bottomMargin: 14
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 12
                                text: qsTr("Transaction key") + translationManager.emptyString
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                font.family: state === "ready" ? MoneroComponents.Style.fontMonoRegular.name : MoneroComponents.Style.fontRegular.name
                                font.pixelSize: state === "ready" ? 12 : 14
                                text: qsTr("Click to reveal")
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                                state: "txkey_hidden"

                                MouseArea {
                                    state: "copyable_txkey"
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: Math.min(parent.width, parent.paintedWidth)
                                    height: parent.height
                                    hoverEnabled: true
                                    onEntered: parent.font.underline = true
                                    onExited: parent.font.underline = false
                                }
                            }
                        }

                        Image {
                            visible: !isout && confirmationsRequired === 60
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            source: "qrc:///images/icons/miningxmr.png"
                        }

                        MoneroComponents.BookIconButton {
                            id: btnDetails
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            interactive: false
                            hovered: detailsMouse.containsMouse
                            icon: FontAwesome.info
                            iconFamily: FontAwesome.fontFamilySolid
                            iconStyle: "Solid"
                            iconSize: 14
                            tooltip: qsTr("Transaction details") + translationManager.emptyString

                            MouseArea {
                                id: detailsMouse
                                state: "details"
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.tooltipPopup.open()
                                onExited: parent.tooltipPopup.close()
                            }
                        }

                        MoneroComponents.BookIconButton {
                            visible: isout
                            enabled: currentWallet ? !currentWallet.isHwBacked() : false
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            interactive: false
                            hovered: proofMouse.containsMouse
                            icon: FontAwesome.productHunt
                            iconFamily: FontAwesome.fontFamilyBrands
                            iconSize: 15
                            tooltip: qsTr("Generate payment proof") + translationManager.emptyString

                            MouseArea {
                                id: proofMouse
                                state: "proof"
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.tooltipPopup.open()
                                onExited: parent.tooltipPopup.close()
                            }
                        }
                    }
                }

                MouseArea {
                    id: collapseArea
                    objectName: "collapseArea"
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: {
                        // detect clicks on text (for copying), otherwise toggle collapse
                        var doCollapse = true;
                        var res = Utils.qmlEach(delegate, ['containsMouse', 'preventStealing', 'scrollGestureEnabled'], ['collapseArea'], []);
                        for(var i = 0; i < res.length; i+=1){
                            if(res[i].containsMouse === true){
                                if(res[i].state === 'copyable' && res[i].parent.hasOwnProperty('text')) toClipboard(res[i].parent.text);
                                if(res[i].state === 'copyable_address') (recipientAddresses ? root.toClipboard(recipientAddresses) : root.toClipboard(addressField.text));
                                if(res[i].state === 'copyable_receiving_address') root.toClipboard(currentWallet.address(subaddrAccount, subaddrIndex));
                                if(res[i].state === 'copyable_txkey') root.getTxKey(hash, res[i]);
                                if(res[i].state === 'set_tx_note') root.editDescription(hash, tx_note, root.txPage);
                                if(res[i].state === 'details') root.showTxDetails(hash, paymentId, destinations, subaddrAccount, subaddrIndex, dateTime, displayAmount, isout);
                                if(res[i].state === 'proof') root.showTxProof(hash, paymentId, address);
                                doCollapse = false;
                                break;
                            }
                        }

                        if(doCollapse){
                            collapsed = !collapsed;

                            // remember collapsed state
                            if(collapsed){
                                root.txDataCollapsed.push(hash);
                            } else {
                                root.removeFromCollapsedList(hash);
                            }
                        }
                    }
                }
            }
        }

        // advanced options: collapsible card
        Item {
            id: showAdvancedCheckbox
            readonly property bool checked: persistentSettings.historyShowAdvanced
            readonly property bool hovered: advHeaderMouse.containsMouse
            Layout.topMargin: 24
            Layout.bottomMargin: 20
            Layout.leftMargin: sideMargin
            Layout.rightMargin: sideMargin
            Layout.fillWidth: true
            implicitHeight: advColumn.implicitHeight

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 10
                accent: root.borderColor
                lineOpacity: showAdvancedCheckbox.checked || showAdvancedCheckbox.hovered ? 0.6 : 0.25
                fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#DADFDB"
                fillOpacity: MoneroComponents.Style.blackTheme ? 0.92 : 0.9
                ticks: false
                Behavior on lineOpacity { NumberAnimation { duration: 150 } }
            }

            ColumnLayout {
                id: advColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Canvas {
                            Layout.preferredWidth: 12
                            Layout.preferredHeight: 12
                            rotation: showAdvancedCheckbox.checked ? 90 : 0
                            Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            property color c: root.accentColor
                            onCChanged: requestPaint()
                            onPaint: root.paintChevron(getContext("2d"), c)
                        }

                        MoneroComponents.TextPlain {
                            text: qsTr("Advanced options").toUpperCase() + translationManager.emptyString
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 13
                            font.letterSpacing: 2
                            color: showAdvancedCheckbox.checked || showAdvancedCheckbox.hovered
                                   ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }

                        Item { Layout.fillWidth: true }
                    }

                    MouseArea {
                        id: advHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: persistentSettings.historyShowAdvanced = !persistentSettings.historyShowAdvanced
                    }
                }

                Rectangle {
                    visible: showAdvancedCheckbox.checked
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.preferredHeight: 1
                    color: root.accentColor
                    opacity: 0.3
                }

                RowLayout {
                    visible: showAdvancedCheckbox.checked
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Layout.topMargin: 14
                    spacing: 24

                    MoneroComponents.CheckBox {
                        id: humanDatesCheckBox
                        checked: persistentSettings.historyHumanDates
                        onClicked: {
                            persistentSettings.historyHumanDates = !persistentSettings.historyHumanDates
                            root.updateDisplay(root.txOffset, root.txMax);
                        }
                        text: qsTr("Human readable date format") + translationManager.emptyString
                    }

                    Item { Layout.fillWidth: true }

                    MoneroComponents.StandardButton {
                        visible: !isIOS
                        small: true
                        text: qsTr("Export all history") + translationManager.emptyString
                        onClicked: {
                            writeCSVFileDialog.open();
                        }
                    }
                }
            }
        }
    }

    // chevron pointing right, drawn in a size x size box; rotate the Canvas to point elsewhere
    function paintChevron(ctx, c, size) {
        var s = (size || 12) / 12;
        ctx.reset();
        ctx.strokeStyle = c;
        ctx.lineWidth = 1.8;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        ctx.moveTo(3.5 * s, 1.5 * s); ctx.lineTo(8.5 * s, 6 * s); ctx.lineTo(3.5 * s, 10.5 * s);
        ctx.stroke();
    }

    function refresh(){
        if(appWindow.currentWallet != null && typeof appWindow.currentWallet.history !== "undefined" ) {
            currentWallet.history.refresh(currentWallet.currentSubaddressAccount);
        }

        if (typeof root.model !== 'undefined' && root.model != null) {
            toDatePicker.currentDate = root.model.transactionHistory.lastDateTime
        }

        // extract from model, create JS array of txs
        root.updateTransactionsFromModel();

        // fill listview, update UI
        root.updateDisplay(root.txOffset, root.txMax);
    }

    function reset(keepDate) {
        root.txOffset = 0;

        if (typeof root.model !== 'undefined' && root.model != null) {
            if (!keepDate) {
                root.model.dateFromFilter = "2014-04-18" // genesis block
                root.model.dateToFilter = "9999-09-09" // fix before september 9999
            }
            // negative values disable filters here;
            root.model.amountFromFilter = -1;
            root.model.amountToFilter = -1;
            root.model.directionFilter = TransactionInfo.Direction_Both;
        }
    }

    function updateFilter(currentPage){
        // applying filters
        root.txData = JSON.parse(JSON.stringify(root.txModelData)); // deepcopy

        const timezoneOffset = new Date().getTimezoneOffset() * 60;
        var fromDate = Math.floor(fromDatePicker.currentDate.getTime() / 86400000) * 86400 + timezoneOffset;
        var toDate = (Math.floor(toDatePicker.currentDate.getTime() / 86400000) + 1) * 86400 + timezoneOffset;
        var recipientQuery = (root.sortSearchString || "").toLowerCase();

        var txs = [];
        for (var i = 0; i < root.txData.length; i++){
            var item = root.txData[i];

            // daterange filtering
            if(item.timestamp < fromDate || item.timestamp > toDate){
                continue;
            }

            // search string filtering
            if(root.sortSearchString == null || root.sortSearchString === ""){
                txs.push(root.txData[i]);
                continue;
            }

            if(root.sortSearchString.length >= 1){
                if(item.amount && item.amount.toString().startsWith(root.sortSearchString)){
                    txs.push(item);
                } else if(item.recipientAddresses.split("\n").some(function(address) {
                    return address.toLowerCase().startsWith(recipientQuery);
                })){
                    txs.push(item);
                } else if(item.recipientSearchNames.toLowerCase().indexOf(recipientQuery) !== -1){
                    txs.push(item);
                } else if(item.receivingAddress !== "" && item.receivingAddress.toLowerCase().startsWith(root.sortSearchString.toLowerCase())){
                    txs.push(item);
                } else if(item.receivingAddressLabel !== "" && item.receivingAddressLabel.toLowerCase().startsWith(root.sortSearchString.toLowerCase())){
                    txs.push(item);
                } else if(typeof item.blockheight !== "undefined" && item.blockheight.toString().startsWith(root.sortSearchString)) {
                    txs.push(item);
                } else if(item.tx_note.toLowerCase().indexOf(root.sortSearchString.toLowerCase()) !== -1) {
                    txs.push(item);
                } else if (item.hash.startsWith(root.sortSearchString)){
                    txs.push(item);
                }
            }
        }

        root.txData = txs;
        root.txCount = root.txData.length;

        root.updateSort();
        root.updateDisplay(root.txOffset, root.txMax);
        if (currentPage) {
            root.paginationJump(parseInt(currentPage));
        }
    }

    function updateSort(){
        // applying sorts
        root.txOffset = 0;
        root.txData.sort(function(a, b) {
            if (root.sortBy === "blockheight") {
                var aPending = a.blockheight === "";
                var bPending = b.blockheight === "";
                if (aPending !== bPending)
                    return aPending ? 1 : -1;
                if (aPending)
                    return a.timestamp - b.timestamp;
            }
            return a[root.sortBy] - b[root.sortBy];
        });

        if(root.sortDirection)
            root.txData.reverse();

        root.updateDisplay(root.txOffset, root.txMax);
    }

    function updateDisplay(tx_offset, tx_max) {
        txListViewModel.clear();

        // limit results as per tx_max (root.txMax)
        var txs = root.txData.slice(tx_offset, tx_offset + tx_max);

        // collapse tx if there is a single result
        if(root.txPage === 1 && txs.length === 1)
            root.txDataCollapsed.push(txs[0]['hash']);

        // populate listview
        for (var i = 0; i < txs.length; i++){
            txListViewModel.append(txs[i]);
        }

        root.updateHistoryStatusMessage();

        // determine pagination button states
        var count = txData.length;
        if(count <= root.txMax) {
            paginationPrev.enabled = false;
            paginationNext.enabled = false;
            return;
        }

        if(root.txOffset < root.txMax)
            paginationPrev.enabled = false;
        else
            paginationPrev.enabled = true;

        if((root.txOffset + root.txMax) >= count)
            paginationNext.enabled = false;
        else
            paginationNext.enabled = true;
    }

    function updateTransactionsFromModel() {
        // This function copies the items of `appWindow.currentWallet.historyModel` to `root.txModelData`, as a list of javascript objects
        if(currentWallet == null || typeof currentWallet.history === "undefined" ) return;
        if(currentWallet.isBackgroundSyncing()) return;

        var _model = root.model;
        var total = 0
        var count = _model.rowCount()
        root.txModelData = [];

        for (var i = 0; i < count; ++i) {
            var idx = _model.index(i, 0);
            var isPending = model.data(idx, TransactionHistoryModel.TransactionPendingRole);
            var isFailed = model.data(idx, TransactionHistoryModel.TransactionFailedRole);
            var isout = _model.data(idx, TransactionHistoryModel.TransactionIsOutRole);
            var amount = _model.data(idx, TransactionHistoryModel.TransactionAmountRole);
            var hash = _model.data(idx, TransactionHistoryModel.TransactionHashRole);
            var paymentId = _model.data(idx, TransactionHistoryModel.TransactionPaymentIdRole);
            var destinations = _model.data(idx, TransactionHistoryModel.TransactionDestinationsRole);
            var destinationAddresses = _model.data(idx, TransactionHistoryModel.TransactionDestinationAddressesRole);
            var time = _model.data(idx, TransactionHistoryModel.TransactionTimeRole);
            var date = _model.data(idx, TransactionHistoryModel.TransactionDateRole);
            var blockheightValue = _model.data(idx, TransactionHistoryModel.TransactionBlockHeightRole);
            var blockheight = blockheightValue == null ? "" : blockheightValue.toString();
            var confirmations = _model.data(idx, TransactionHistoryModel.TransactionConfirmationsRole);
            var confirmationsRequired = _model.data(idx, TransactionHistoryModel.TransactionConfirmationsRequiredRole);
            var fee = _model.data(idx, TransactionHistoryModel.TransactionFeeRole);
            var subaddrAccount = model.data(idx, TransactionHistoryModel.TransactionSubaddrAccountRole);
            var subaddrIndex = model.data(idx, TransactionHistoryModel.TransactionSubaddrIndexRole);
            var timestamp = new Date(date + " " + time).getTime() / 1000;
            var dateHuman = Utils.ago(timestamp);

            if (amount === 0) {
                // transactions to the same account have amount === 0, while the 'destinations string'
                // has the correct amount, so we try to fetch it from that instead.
                amount = Number(TxUtils.destinationsToAmount(destinations));
            }
            var displayAmount = Utils.removeTrailingZeros(amount.toFixed(12)) + " XMR";

            var tx_note = currentWallet.getUserNote(hash);
            var address = "";
            var recipientAddresses = "";
            var recipientSearchNames = "";
            var recipientText = "";
            var recipientTooltip = "";
            var receivingAddress = "";
            var receivingAddressLabel = "";

            if (isout) {
                var uniqueAddresses = [];
                var recipientNames = [];
                var recipientTooltipEntries = [];

                for (var destinationIndex = 0; destinationIndex < destinationAddresses.length; ++destinationIndex) {
                    var destinationAddress = destinationAddresses[destinationIndex];
                    if (uniqueAddresses.indexOf(destinationAddress) !== -1)
                        continue;

                    uniqueAddresses.push(destinationAddress);
                    var destinationName = currentWallet ? currentWallet.addressBook.getDescription(destinationAddress) : "";
                    destinationName = destinationName || "";
                    recipientNames.push(destinationName);
                    var shortDestinationAddress = TxUtils.addressTruncate(destinationAddress, 8);
                    recipientTooltipEntries.push(destinationName ? Utils.htmlEscape(destinationName) + " — " + shortDestinationAddress : shortDestinationAddress);
                }

                address = uniqueAddresses.length > 0 ? uniqueAddresses[0] : "";
                recipientAddresses = uniqueAddresses.join("\n");
                recipientSearchNames = recipientNames.join("\n");
                recipientTooltip = uniqueAddresses.length > 1 ? recipientTooltipEntries.join("<br>") : "";
                if (uniqueAddresses.length === 1) {
                    recipientText = recipientNames[0] ? FontAwesome.addressBook + " " + recipientNames[0] : TxUtils.addressTruncate(address, 8);
                } else if (uniqueAddresses.length > 1) {
                    recipientText = qsTr("%1 recipients").arg(uniqueAddresses.length) + translationManager.emptyString;
                }
            } else {
                receivingAddress = currentWallet ? currentWallet.address(subaddrAccount, subaddrIndex) : null;
                receivingAddressLabel = currentWallet ? appWindow.currentWallet.getSubaddressLabel(subaddrAccount, subaddrIndex) : null;
            }

            if (isout)
                total = walletManager.subi(total, amount)
            else
                total = walletManager.addi(total, amount)

            root.txModelData.push({
                "i": i,
                "isPending": isPending,
                "isFailed": isFailed,
                "isout": isout,
                "amount": amount,
                "displayAmount": displayAmount,
                "hash": hash,
                "paymentId": paymentId,
                "address": address,
                "recipientAddresses": recipientAddresses,
                "recipientSearchNames": recipientSearchNames,
                "recipientText": recipientText,
                "recipientTooltip": recipientTooltip,
                "destinations": destinations,
                "tx_note": tx_note,
                "dateHuman": dateHuman,
                "dateTime": date + " " + time,
                "blockheight": blockheight,
                "timestamp": timestamp,
                "fee": fee,
                "confirmations": confirmations,
                "confirmationsRequired": confirmationsRequired,
                "receivingAddress": receivingAddress,
                "receivingAddressLabel": receivingAddressLabel,
                "subaddrAccount": subaddrAccount,
                "subaddrIndex": subaddrIndex
            });
        }

        root.txData = JSON.parse(JSON.stringify(root.txModelData)); // deepcopy
        root.txCount = root.txData.length;
    }

    function update(currentPage) {
        // handle outside mutation of tx model; incoming/outgoing funds or new blocks. Update table.
        currentWallet.history.refresh(currentWallet.currentSubaddressAccount);

        root.updateTransactionsFromModel();
        root.updateFilter(currentPage);
    }

    function editDescription(_hash, _tx_note, currentPage){
        inputDialog.labelText = qsTr("Set description:") + translationManager.emptyString;
        inputDialog.onAcceptedCallback = function() {
            appWindow.currentWallet.setUserNote(_hash, inputDialog.inputText);
            appWindow.showStatusMessage(qsTr("Updated description."),3);
            root.update(currentPage);
        }
        inputDialog.onRejectedCallback = null;
        inputDialog.open(_tx_note);
    }

    function paginationPrevClicked(){
        root.txOffset -= root.txMax;
        updateDisplay(root.txOffset, root.txMax);
    }

    function paginationNextClicked(){
        root.txOffset += root.txMax;
        updateDisplay(root.txOffset, root.txMax);
    }

    function paginationJump(pageNumber){
        root.txOffset = root.txMax * Math.ceil(pageNumber - 1 || 0);
        updateDisplay(root.txOffset, root.txMax);
    }

    function removeFromCollapsedList(hash){
        root.txDataCollapsed = root.txDataCollapsed.filter(function(item) {
            return item !== hash
        });
    }

    function updateHistoryStatusMessage(){
        if(root.txModelData.length <= 0){
            root.historyStatusMessage = qsTr("No transaction history yet.") + translationManager.emptyString;
        } else if (root.txData.length <= 0){
            root.historyStatusMessage = qsTr("No results.") + translationManager.emptyString;
        } else {
            root.historyStatusMessage = qsTr("%1 transactions total, showing %2.").arg(root.txData.length).arg(txListViewModel.count) + translationManager.emptyString;
        }
    }

    function getTxKey(hash, elem){
        if (elem.parent.state != 'ready'){
            currentWallet.getTxKeyAsync(hash, function(hash, txKey) {
                elem.parent.text = txKey ? txKey : '-';
                elem.parent.state = 'ready';
            });
        } else {
            toClipboard(elem.parent.text);
        }
    }

    function showTxDetails(hash, paymentId, destinations, subaddrAccount, subaddrIndex, dateTime, amount, isout) {
        var tx_note = currentWallet.getUserNote(hash)
        var rings = currentWallet.getRings(hash)
        var address_label = subaddrIndex == 0 ? (qsTr("Primary address") + translationManager.emptyString) : currentWallet.getSubaddressLabel(subaddrAccount, subaddrIndex)
        var address = currentWallet.address(subaddrAccount, subaddrIndex)
        const hasPaymentId = parseInt(paymentId, 16);
        const integratedAddress = !isout && hasPaymentId ? currentWallet.integratedAddress(paymentId) : null;

        if (rings)
            rings = rings.replace(/\|/g, '\n')

        currentWallet.getTxKeyAsync(hash, function(hash, tx_key) {
            informationPopup.title = qsTr("Transaction details") + translationManager.emptyString;
            informationPopup.kind = "tx";
            informationPopup.content = buildTxDetailsString(hash, hasPaymentId ? paymentId : null, tx_key, tx_note, destinations, rings, address, address_label, integratedAddress, dateTime, amount);
            informationPopup.onCloseCallback = null
            informationPopup.open();
        });
    }

    function showTxProof(hash, paymentId, address){
        if(!address){
            console.log('getProof: Error fetching address')
            return;
        }

        var checked = (TxUtils.checkTxID(hash) && TxUtils.checkAddress(address, appWindow.persistentSettings.nettype));
        if(!checked){
            console.log('getProof: Error checking TxId and/or address');
        }

        console.log("getProof: Generate clicked: txid " + hash + ", address " + address);
        middlePanel.getProofClicked(hash, address, '', null);
        informationPopup.title  = qsTr("Payment proof") + translationManager.emptyString;
        informationPopup.kind = "tx";
        informationPopup.text = qsTr("Generating payment proof") + "..." + translationManager.emptyString;
        informationPopup.onCloseCallback = null
        informationPopup.open()
    }

    function toClipboard(text){
        console.log("Copied to clipboard");
        clipboard.setText(text);
        appWindow.showStatusMessage(qsTr("Copied to clipboard"),3);
    }

    function buildTxDetailsString(tx_id, paymentId, tx_key,tx_note, destinations, rings, address, address_label, integratedAddress, dateTime, amount) {
        var trStart = '<tr><td style="white-space: nowrap; padding-top:5px"><b>',
            trMiddle = '</b></td><td style="padding-left:10px;padding-top:5px;">',
            trEnd = "</td></tr>";

        return '<table border="0">'
            + (tx_id ? trStart + qsTr("Tx ID:") + trMiddle + tx_id + trEnd : "")
            + (dateTime ? trStart + qsTr("Date") + ":" + trMiddle + dateTime + trEnd : "")
            + (amount ? trStart + qsTr("Amount") + ":" + trMiddle + amount + trEnd : "")
            + (address ? trStart + qsTr("Address:") + trMiddle + address + trEnd : "")
            + (paymentId ? trStart + qsTr("Payment ID:") + trMiddle + paymentId + trEnd : "")
            + (integratedAddress ? trStart + qsTr("Integrated address") + ":" + trMiddle + integratedAddress + trEnd : "")
            + (tx_key ? trStart + qsTr("Tx key:") + trMiddle + tx_key + trEnd : "")
            + (tx_note ? trStart + qsTr("Tx note:") + trMiddle + Utils.htmlEscape(tx_note) + trEnd : "")
            + (destinations ? trStart + qsTr("Destinations:") + trMiddle + destinations + trEnd : "")
            + (rings ? trStart + qsTr("Rings:") + trMiddle + rings + trEnd : "")
            + "</table>"
            + translationManager.emptyString;
    }

    FolderDialog {
        id: writeCSVFileDialog
        title: qsTr("Please choose a folder") + translationManager.emptyString
        onRejected: {
            console.log("csv write canceled")
        }
        onAccepted: {
            var dataDir = walletManager.urlToLocalPath(writeCSVFileDialog.selectedFolder);
            var written = currentWallet.history.writeCSV(currentWallet.currentSubaddressAccount, dataDir);

            if(written !== ""){
                confirmationDialog.title = qsTr("Success") + translationManager.emptyString;
                var text = qsTr("CSV file written to: %1").arg(written) + "\n\n"
                text += qsTr("Tip: Use your favorite spreadsheet software to sort on blockheight.") + "\n\n" + translationManager.emptyString;
                confirmationDialog.text = text;
                confirmationDialog.cancelText = qsTr("Open folder") + translationManager.emptyString;
                confirmationDialog.onAcceptedCallback = null;
                confirmationDialog.onRejectedCallback = function() {
                    oshelper.openContainingFolder(written);
                }
                confirmationDialog.open();
            } else {
                informationPopup.title = qsTr("Error") + translationManager.emptyString;
                informationPopup.text = qsTr("Error exporting transaction data.") + "\n\n" + translationManager.emptyString;
                informationPopup.onCloseCallback = null;
                informationPopup.open();

            }
        }
        Component.onCompleted: {
            var _folder = 'file://' + appWindow.accountsDir;
            try {
                _folder = 'file://' + desktopFolder;
            }
            catch(err) {}
            finally {
                writeCSVFileDialog.currentFolder = _folder;
            }
        }
    }

    function onPageCompleted() {
        if(appWindow.currentWallet != null){
            root.model = appWindow.currentWallet.historyModel;
            root.model.sortRole = TransactionHistoryModel.TransactionBlockHeightRole
            root.model.sort(0, Qt.DescendingOrder);
        }

        root.reset();
        root.refresh();

        // Block height order does not imply date order, especially for failed transactions.
        if(appWindow.currentWallet != null){
            var count = root.model.rowCount()
            if (count > 0) {
                var firstDate = root.model.data(root.model.index(0, 0), TransactionHistoryModel.TransactionDateRole);
                for (var i = 1; i < count; ++i) {
                    var date = root.model.data(root.model.index(i, 0), TransactionHistoryModel.TransactionDateRole);
                    if (date < firstDate)
                        firstDate = date;
                }
                fromDatePicker.currentDate = firstDate;
            } else {
                //date of monero birth (2014-04-18)
                fromDatePicker.currentDate = model.transactionHistory.firstDateTime
            }
        }

        root.initialized = true;
        root.updateFilter();
    }

    function onPageClosed(){
        root.initialized = false;
        root.reset(true);
        root.clearFields();
    }

    function searchInHistory(searchTerm){
        searchInput.text = searchTerm;
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
        sortAndFilter.collapsed = true;
    }

    function clearFields() {
        sortAndFilter.collapsed = false;
        searchInput.text = "";
        root.txDataCollapsed = [];
    }
}
