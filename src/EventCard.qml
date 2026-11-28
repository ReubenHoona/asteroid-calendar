/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import org.asteroid.controls
import "CalendarLogic.js" as Logic

/*
 * One event in the agenda (weather-calendar-24): stock's EventChip, a Wear
 * M3 Card inset 4 dp on each side (lxv.java:60-330, lxt.java:100-414):
 *  - at least 64 dp tall, corners 26 dp, 12 dp padding (the shared Card);
 *  - the container is black with the calendar colour at 20 % over it
 *    (lxv.java:222-243), outlined 1 dp in the colour while the user has not
 *    answered (X-EOS-RSVP 0) or when every other guest declined (lxv.java:
 *    198-205, R5 D-16), then with the 16 dp error icon "Everyone else
 *    declined" in the event colour before the time and 4 dp after it
 *    (lxt.java:262-312);
 *  - the time line (titleSmall 14 sp, white), the title (titleMedium 16 sp,
 *    onSurface, two lines at most), the location (bodyLarge 16 sp,
 *    onSurfaceVariant, one line; nothing when there is none).
 * The details open on a tap.
 */
Item {
    id: row

    /*! An item of CalendarLogic.buildItems(): { event, start, end, allDay, dayIndex, dayCount }. */
    property var item
    /*! The CalendarText of the page. */
    property var texts

    signal clicked(var item)

    readonly property var event: item ? item.event : null
    // what the phone sent along (colour, response), read from the stored event
    readonly property var extras: {
        if (!event)
            return Logic.parseExtras("")
        event.displayLabel     // the event object's own change signals re-read it
        event.location
        return Logic.parseExtras(event.iCalendar ? event.iCalendar("") : "")
    }
    readonly property color eventColor: Logic.eventColor(extras, event ? event.color : "")
    /*! The container: black with the event colour at 20 %. */
    readonly property color cardColor: Qt.tint("#000000", Qt.rgba(eventColor.r, eventColor.g, eventColor.b, 0.2))
    /*! Not answered yet, or everyone else declined: outlined in the event colour. */
    readonly property bool outlined: Logic.outlined(extras)
    /*! Every other guest declined (the icon) */
    readonly property bool everyoneDeclined: extras.guests !== null && extras.guests.everyoneElseDeclined === true
    readonly property string timeText: item && texts ? Logic.timeLine(item, texts.lineFormat) : ""
    readonly property string titleText: item && texts ? Logic.title(item, texts.lineFormat) : ""
    readonly property string locationText: event && event.location ? String(event.location).trim() : ""

    readonly property alias card: _card
    readonly property alias timeLabel: _time
    readonly property alias declinedIcon: _declined
    readonly property alias titleLabel: _title
    readonly property alias locationLabel: _location

    /*! 4 dp each side of the card (E55). */
    readonly property real inset: Theme.dp(4)

    width: parent ? parent.width : Theme.dp(192)
    height: _card.height

    Card {
        id: _card
        x: row.inset
        width: row.width - 2 * row.inset
        containerColor: row.cardColor
        // stock's Card: padding 12 dp, spacing none
        padding: Theme.space.l
        container.border.width: row.outlined ? Theme.dp(1) : 0
        container.border.color: row.eventColor
        onClicked: row.clicked(row.item)

        Accessible.name: row.titleText + ", " + row.timeText + (row.everyoneDeclined ? ", " + row.texts.everyoneDeclined : "")

        Row {
            width: parent.width
            spacing: Theme.dp(4)
            Icon {
                id: _declined
                objectName: "declinedIcon"
                visible: row.everyoneDeclined
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(16)
                height: width
                name: "ios-alert"
                color: row.eventColor
                Accessible.name: row.texts ? row.texts.everyoneDeclined : ""
            }
            Label {
                id: _time
                width: parent.width - (_declined.visible ? _declined.width + parent.spacing : 0)
                role: "titleSmall"
                color: Theme.color.onBackground
                text: row.timeText
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
        Label {
            id: _title
            width: parent.width
            role: "titleMedium"
            color: Theme.color.onSurface
            text: row.titleText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
        }
        Label {
            id: _location
            width: parent.width
            visible: row.locationText !== ""
            role: "bodyLarge"
            color: Theme.color.onSurfaceVariant
            text: row.locationText
            maximumLineCount: 1
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
        }
    }
}
