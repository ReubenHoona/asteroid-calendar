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
 * There is no editing. For the phone's events, between the calendar's name and
 * 'Delete event', stock's two phone segments (lqx, lpj, lqq): the RSVP segment
 * ('Going?' with Yes / Maybe / No, then 'Responded Yes' with 'Change RSVP') and
 * the 'Open on phone' chip. Both go through Gadgetbridge (PhoneRelay: the acts
 * rsvp and open); the guest list is not shown (the phone does not send it).
 */
Item {
    id: page

    /*! The agenda item that was tapped (CalendarLogic.buildItems()). */
    property var item
    /*! Today, at the start of the day. */
    property date today: Logic.startOfDay(new Date())
    /*! Gadgetbridge can delete the phone's events (the del-req request exists). */
    property bool phoneCanDelete: false
    /*! The phone's relay (a test can replace it); nothing is asked before a button is pressed. */
    property var relay: _relay
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
    // the phone's segments (weather-calendar-34, -38)
    readonly property bool canRespond: event ? Logic.canRespond(event, extras) : false
    readonly property bool canOpenOnPhone: event ? Logic.canOpenOnPhone(event, extras) : false
    /*! The answer just sent (1 Yes, 2 Maybe, 3 No), -1 while the phone's own is shown */
    property int answered: -1
    /*! The user's response: the answer sent, else the phone's (0 needs action) */
    readonly property int response: answered >= 0 ? answered : extras.response
    /*! 'Change RSVP' was pressed: the three chips again */
    property bool changing: false
    property bool rsvpBusy: false
    property bool rsvpFailed: false
    /*! "", "busy", "ok" or "failed" */
    property string openState: ""
    readonly property var rows: event ? Logic.detailRows(event, extras, reminderTexts, deletable,
                                                         { rsvp: canRespond, open: canOpenOnPhone }) : []
    readonly property string titleText: item ? Logic.title({ event: event, dayCount: 1, dayIndex: 1 }, _texts.lineFormat) : ""
    readonly property string dateText: item ? Logic.dateLine(item, today, _texts.detailFormat) : ""
    readonly property string timeText: item ? Logic.detailTime(event, item.start, item.end, _texts.detailFormat) : ""

    readonly property alias list: _list
    readonly property alias deleteDialog: _confirm
    readonly property alias texts: _texts

    /*! Answer the invitation: st 1 Yes, 2 Maybe, 3 No (relay act rsvp). */
    function respond(st) {
        if (rsvpBusy || !canRespond)
            return
        rsvpBusy = true
        rsvpFailed = false
        page.relay.act(Logic.rsvpAct(extras, st), function (r) {
            rsvpBusy = false
            if (r && r.ok === true) {
                answered = st
                changing = false
            } else {
                rsvpFailed = true
            }
        })
    }

    /*! Open the event on the phone (relay act open). */
    function openOnPhone() {
        if (openState === "busy" || !canOpenOnPhone)
            return
        openState = "busy"
        page.relay.act(Logic.openEventAct(extras, item ? item.start : null), function (r) {
            openState = r && r.ok === true ? "ok" : "failed"
        })
    }

    /*! Delete the event and leave the details. */
    function deleteEvent() {
        if (event && deletable)
            event.deleteEvent()
        if (pop)
            pop()
    }

    CalendarText { id: _texts }
    PhoneRelay { id: _relay }
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
                    case "rsvp": return rsvpRow
                    case "openPhone": return openPhoneRow
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
    // the RSVP segment (lqx, lpj, lrq): 'Going?' and three chips while the response needs action (or after
    // 'Change RSVP'), else 'Responded Yes' with 'Change RSVP'; a failed answer says why (rsvp_failed_error_message)
    Component {
        id: rsvpRow
        Item {
            id: rsvp
            readonly property bool answeredNow: page.response >= 1 && page.response <= 3 && !page.changing
            height: _rsvpColumn.height + Theme.dp(4)
            Column {
                id: _rsvpColumn
                objectName: "rsvpSegment"
                y: Theme.dp(4)
                width: parent.width
                spacing: Theme.dp(4)
                Label {
                    objectName: "rsvpLabel"
                    width: parent.width
                    topPadding: Theme.dp(6)
                    bottomPadding: Theme.dp(6)
                    role: "bodyMedium"
                    color: Theme.color.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: rsvp.answeredNow ? Logic.format(_texts.rsvpResponded, [_texts.rsvpOption(page.response)])
                                           : _texts.rsvpGoing
                }
                Button {
                    objectName: "changeRsvpButton"
                    visible: rsvp.answeredNow
                    width: parent.width
                    variant: "tonal"
                    enabled: !page.rsvpBusy
                    text: _texts.changeRsvp
                    onClicked: page.changing = true
                }
                Repeater {
                    model: rsvp.answeredNow ? [] : Logic.rsvpAnswers
                    delegate: Button {
                        required property int modelData
                        objectName: "rsvpButton" + modelData
                        width: _rsvpColumn.width
                        variant: "tonal"
                        enabled: !page.rsvpBusy
                        iconName: modelData === 1 ? "ios-checkmark" : modelData === 2 ? "ios-help" : "ios-close"
                        text: _texts.rsvpOption(modelData)
                        onClicked: page.respond(modelData)
                    }
                }
                Label {
                    objectName: "rsvpError"
                    visible: page.rsvpFailed
                    width: parent.width
                    role: "bodyMedium"
                    color: Theme.color.error
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: _texts.rsvpFailed
                }
            }
        }
    }
    // 'Open on phone' (lqq, OpenOnPhoneSegment): asks Gadgetbridge to show the event; 'Opened on your phone' when it did
    Component {
        id: openPhoneRow
        Item {
            height: _openColumn.height + Theme.dp(4)
            Column {
                id: _openColumn
                y: Theme.dp(4)
                width: parent.width
                spacing: Theme.dp(4)
                Button {
                    objectName: "openOnPhoneButton"
                    width: parent.width
                    variant: "tonal"
                    enabled: page.openState !== "busy"
                    iconName: "ios-phone-portrait"
                    text: _texts.openOnPhone
                    onClicked: page.openOnPhone()
                }
                Label {
                    objectName: "openStatus"
                    visible: page.openState === "ok" || page.openState === "failed"
                    width: parent.width
                    role: "bodyMedium"
                    color: page.openState === "failed" ? Theme.color.error : Theme.color.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: page.openState === "failed" ? _texts.openFailed : _texts.openedOnPhone
                }
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
