/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import org.nemomobile.calendar
import org.asteroid.controls
import "CalendarLogic.js" as Logic

/*
 * The event details (weather-calendar-32, -33): stock's DetailsScreen
 * (lmg.java:118-248), a read-only list of segments in stock order:
 *   the title with the calendar colour square, the date and the time range
 *   (labelSmall 13 sp, onSurfaceVariant), the location, the description, the
 *   reminders ('10 minutes before'), the calendar's name, then 'Delete event'
 *   and its confirmation 'Delete this event?'.
 * There is no editing. Guests, the response and 'Open on phone' are not
 * here (the phone side is not finished, see NOTES).
 */
Item {
    id: page

    /*! The agenda item that was tapped (CalendarLogic.buildItems()). */
    property var item
    /*! Today, at the start of the day. */
    property date today: Logic.startOfDay(new Date())
    /*! Gadgetbridge can delete the phone's events (the del-req request exists). */
    property bool phoneCanDelete: false
    // LayerStack's push sets these
    property var pop
    property int depth: 0

    readonly property var event: item ? item.event : null
    readonly property var extras: {
        if (!event)
            return Logic.parseExtras("")
        event.displayLabel
        return Logic.parseExtras(event.iCalendar ? event.iCalendar("") : "")
    }
    readonly property color eventColor: Logic.eventColor(extras, event ? event.color : "")
    readonly property var reminderTexts: {
        var out = []
        if (!event || !item)
            return out
        for (var i = 0; i < extras.reminders.length; i++)
            out.push(Logic.reminderLabel(extras.reminders[i], event.allDay, item.start, _texts.detailFormat))
        return out
    }
    readonly property string calendarName: extras.calendar !== "" ? extras.calendar : _notebook.name
    readonly property bool deletable: event ? Logic.canDelete(event, phoneCanDelete) : false
    readonly property var rows: event ? Logic.detailRows(event, extras, reminderTexts, deletable) : []
    readonly property string titleText: item ? Logic.title({ event: event, dayCount: 1, dayIndex: 1 }, _texts.lineFormat) : ""
    readonly property string dateText: item ? Logic.dateLine(item, today, _texts.detailFormat) : ""
    readonly property string timeText: item ? Logic.detailTime(event, item.start, item.end, _texts.detailFormat) : ""

    readonly property alias list: _list
    readonly property alias deleteDialog: _confirm
    readonly property alias texts: _texts

    /*! Delete the event and leave the details. */
    function deleteEvent() {
        if (event && deletable)
            event.deleteEvent()
        if (pop)
            pop()
    }

    CalendarText { id: _texts }
    NotebookQuery {
        id: _notebook
        targetUid: page.event ? page.event.calendarUid : ""
    }

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
            width: parent ? parent.width : 0
            height: loader.item ? loader.item.height : 0
            Loader {
                id: loader
                width: parent.width
                sourceComponent: {
                    switch (cell.modelData) {
                    case "title": return titleRow
                    case "when": return whenRow
                    case "location": return locationRow
                    case "description": return descriptionRow
                    case "reminders": return remindersRow
                    case "calendar": return calendarRow
                    case "delete": return deleteRow
                    }
                    return null
                }
            }
        }
    }

    // 12 dp above, the colour square, the title at most 3 lines (lse.java:30-66)
    Component {
        id: titleRow
        DetailRow {
            objectName: "titleRow"
            topPadding: Theme.dp(12)
            hasSquare: true
            squareColor: page.eventColor
            Label {
                objectName: "titleLabel"
                width: parent.width
                role: "titleMedium"
                color: Theme.color.onBackground
                text: page.titleText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
    // the date and the time range, labelSmall 13 sp onSurfaceVariant (lpm.java:19)
    Component {
        id: whenRow
        DetailRow {
            objectName: "whenRow"
            Label {
                objectName: "dateLabel"
                width: parent.width
                role: "labelSmall"
                color: Theme.color.onSurfaceVariant
                text: page.dateText
                horizontalAlignment: Text.AlignLeft
            }
            Label {
                objectName: "timeLabel"
                width: parent.width
                role: "labelSmall"
                color: Theme.color.onSurfaceVariant
                text: page.timeText
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
    // the place, as text: a map app that can search is not on the watch
    Component {
        id: locationRow
        DetailRow {
            objectName: "locationRow"
            iconName: "ios-pin-outline"
            Accessible.name: _texts.locationLabel
            Label {
                objectName: "locationLabel"
                width: parent.width
                role: "bodyMedium"
                color: Theme.color.onSurface
                text: page.event ? String(page.event.location).trim() : ""
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
    Component {
        id: descriptionRow
        DetailRow {
            objectName: "descriptionRow"
            iconName: "ios-text"
            Accessible.name: _texts.descriptionLabel
            Label {
                objectName: "descriptionLabel"
                width: parent.width
                role: "bodyMedium"
                color: Theme.color.onSurface
                text: page.event ? String(page.event.description).trim() : ""
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
    // one line per reminder, '10 minutes before'
    Component {
        id: remindersRow
        DetailRow {
            objectName: "remindersRow"
            iconName: "ios-notifications-outline"
            Accessible.name: _texts.remindersLabel
            Repeater {
                model: page.reminderTexts
                delegate: Label {
                    required property string modelData
                    objectName: "reminderLabel"
                    width: parent.width
                    role: "bodyMedium"
                    color: Theme.color.onSurface
                    text: modelData
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }
    Component {
        id: calendarRow
        DetailRow {
            objectName: "calendarRow"
            iconName: "ios-calendar-outline"
            Accessible.name: _texts.calendarLabel
            Label {
                objectName: "calendarLabel"
                width: parent.width
                role: "bodyMedium"
                color: Theme.color.onSurface
                text: page.calendarName
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
    // 'Delete event' at the end of the list; it asks first (loe.java, DeletionConfirmationDialog)
    Component {
        id: deleteRow
        Item {
            height: _delete.height + Theme.dp(4)
            Button {
                id: _delete
                objectName: "deleteButton"
                y: Theme.dp(4)
                width: parent.width
                variant: "tonal"
                iconName: "ios-trash-outline"
                text: _texts.deleteEvent
                onClicked: _confirm.open()
            }
        }
    }

    AlertDialog {
        id: _confirm
        objectName: "deleteDialog"
        behind: _list
        title: _texts.deleteQuestion
        buttons: "confirmDismiss"
        onConfirmed: page.deleteEvent()
    }
}
