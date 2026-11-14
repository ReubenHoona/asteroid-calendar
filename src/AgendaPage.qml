/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import org.asteroid.controls
import "CalendarLogic.js" as Logic

/*
 * The agenda (weather-calendar-22 ... 30): stock's TimelineScreen
 * (lwz.java:105-144), one continuous list from today to the end of the
 * synced window. For each day with events: a header, the day's events (all
 * day first), a 12 dp spacer. With no events at all: today's header and
 * 'No events until <date>' (or a hint when the phone never synced). Else
 * the footer 'Synced until <date>' once the phone has told the window end.
 * It opens at the top (today). No month view, no day picker, no add button.
 */
Item {
    id: page

    /*! The AgendaModel rows: [{ event, startTime, endTime }]. */
    property var occurrences: []
    /*! Today, at the start of the day (the app refreshes it when it is shown again). */
    property date today: Logic.startOfDay(new Date())
    /*! The end of the window the phone synced, or null when it never said. */
    property var syncedUntil: null
    /*! The phone's notebook exists (a sync has run at least once). */
    property bool phoneSynced: true

    signal eventClicked(var item)

    readonly property var items: Logic.buildItems(occurrences, {
        today: today, syncedUntil: syncedUntil, phoneSynced: phoneSynced
    })
    /*! The end of the list: the synced window, else today + 7 days. */
    readonly property date windowEnd: Logic.windowEnd(today, syncedUntil)

    /*! The list rows: the items and, once the phone has synced, stock's 'View more on phone' button at the end. */
    readonly property var rows: phoneSynced ? items.concat([{ kind: "viewMore", key: "viewMore" }]) : items
    /*! The phone's relay (a test can replace it); nothing is asked before the button is pressed. */
    property var relay: _relay
    /*! "", "busy" or "failed" */
    property string viewMoreState: ""

    readonly property alias list: _list
    readonly property alias texts: _texts

    /*! Open the phone's calendar (relay act open, w calendar). */
    function viewMore() {
        if (viewMoreState === "busy")
            return
        viewMoreState = "busy"
        page.relay.act(Logic.openCalendarAct(), function (r) {
            viewMoreState = r && r.ok === true ? "" : "failed"
        })
    }

    CalendarText { id: _texts }
    PhoneRelay { id: _relay }

    ScalingList {
        id: _list
        anchors.fill: parent
        model: page.rows
        sideMargin: Theme.margin.side
        topMargin: Theme.margin.scaffoldVertical
        bottomMargin: Theme.margin.scaffoldVertical

        itemDelegate: Item {
            id: cell
            property int index
            property var modelData
            readonly property string kind: modelData ? modelData.kind : ""
            width: parent ? parent.width : 0
            height: loader.item ? loader.item.height : 0

            Loader {
                id: loader
                width: parent.width
                sourceComponent: cell.kind === "event" ? eventRow
                               : cell.kind === "header" ? headerRow
                               : cell.kind === "spacer" ? spacerRow
                               : cell.kind === "noEvents" || cell.kind === "hint" ? noEventsRow
                               : cell.kind === "footer" ? footerRow
                               : cell.kind === "viewMore" ? viewMoreRow : null
                onLoaded: {
                    if ("item" in item)
                        item.item = Qt.binding(function() { return cell.modelData })
                }
            }
        }
    }

    Component {
        id: eventRow
        EventCard {
            texts: _texts
            onClicked: (i) => page.eventClicked(i)
        }
    }
    Component {
        id: headerRow
        // titleSmall, centred, 8 dp below (lwl.java:115-330)
        Item {
            id: header
            property var item
            readonly property var parts: item ? Logic.dayHeader(item.day, page.today, _texts.headerFormat) : ({ kind: "other", lead: "", date: "" })
            readonly property alias label: _label
            function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
            height: _label.implicitHeight + Theme.dp(8)
            Label {
                id: _label
                width: parent.width
                role: "titleSmall"
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.StyledText
                color: Theme.color.onSurfaceVariant
                text: header.parts.kind === "other"
                      ? header.esc(header.parts.date)
                      : "<font color=\"" + Theme.color.onBackground + "\">" + header.esc(header.parts.lead) + "</font> <font color=\""
                        + Theme.color.primary + "\">" + header.esc(header.parts.date) + "</font>"
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
    }
    Component {
        id: spacerRow
        Item { height: Theme.dp(12) }
    }
    Component {
        id: noEventsRow
        // bodyMedium, onSurfaceVariant, centred, 16 dp above and 22 dp below (lwl.java:22-95)
        Item {
            id: none
            property var item
            readonly property alias label: _text
            height: _text.implicitHeight + Theme.dp(16) + Theme.dp(22)
            Label {
                id: _text
                y: Theme.dp(16)
                width: parent.width
                role: "bodyMedium"
                color: Theme.color.onSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: none.item && none.item.kind === "hint" ? _texts.neverSynced
                      : none.item ? Logic.format(_texts.noEventsUntil, [_texts.fullDate(none.item.until)]) : ""
            }
        }
    }
    Component {
        id: viewMoreRow
        // stock's last chip of the list (TimelineDecorations, view_more_on_phone_button): asks the phone to open its calendar
        Item {
            id: more
            property var item
            readonly property string kind: "viewMore"
            height: _moreColumn.height + Theme.dp(8)
            Column {
                id: _moreColumn
                width: parent.width
                spacing: Theme.dp(4)
                Button {
                    objectName: "viewMoreButton"
                    width: parent.width
                    variant: "tonal"
                    enabled: page.viewMoreState !== "busy"
                    iconName: "ios-phone-portrait"
                    text: _texts.viewMoreOnPhone
                    onClicked: page.viewMore()
                }
                Label {
                    objectName: "viewMoreError"
                    visible: page.viewMoreState === "failed"
                    width: parent.width
                    role: "bodyMedium"
                    color: Theme.color.error
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: _texts.openFailed
                }
            }
        }
    }
    Component {
        id: footerRow
        // titleSmall, onSurfaceVariant, centred, 8 dp below (lwl.java:420-470)
        Item {
            id: footer
            property var item
            readonly property alias label: _text
            height: _text.implicitHeight + Theme.dp(8)
            Label {
                id: _text
                width: parent.width
                role: "titleSmall"
                color: Theme.color.onSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: footer.item ? Logic.format(_texts.syncedUntil, [_texts.fullDate(footer.item.until)]) : ""
            }
        }
    }
}
