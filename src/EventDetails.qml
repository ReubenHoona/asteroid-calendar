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
 * rsvp and open).
 * R5 (AUDIT-72):
 *  - D-08 the guests segment after the location (GuestsSegment, lqe/lqf,
 *    lqg.java:77-545, lsn.java:430-495): a people icon, "N guests" and under
 *    it "N yes, N no" or "N awaiting"; the note "Guests hidden by the
 *    organizer" / "Too many guests to show"; a row per guest the phone sent:
 *    a 25 dp slot with an 18 dp letter disc and the 14 dp response badge
 *    (guests_segment_yes/maybe/no_icon: #ceead6 / #e8eaed / #fad2cf with a
 *    black ring), the name, "Organizer" under the organizer's.
 *  - D-14 'Delete event' for the phone's events (with a phone id): after the
 *    question the phone deletes it (act evdel; one occurrence of a repeating
 *    event), then the watch's copy goes and the page closes; a failure says
 *    "Event could not be deleted." (lnj.java:280-287).
 *  - D-15 a tap on the location shows the place in the phone's maps (act
 *    open w=map; stock opens Maps with geo:0,0?q=, mar.java:47-70; the
 *    watch's Maps has no place search), "Opened on your phone" after it.
 */
Item {
    id: page

    /*! The agenda item that was tapped (CalendarLogic.buildItems()). */
    property var item
    /*! Today, at the start of the day. */
    property date today: Logic.startOfDay(new Date())
    /*! A phone event can be deleted on the phone (Gadgetbridge's evdel, D-14): it has the phone's id. Nothing
     *  is asked before Delete is pressed: a phone app without the act answers "Event could not be deleted." */
    property bool phoneCanDelete: canOpenOnPhone
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
    /*! the location's tap (D-15): "", "busy", "ok" or "failed" */
    property string mapState: ""
    /*! Delete (D-14): "", "busy" or "failed" */
    property string deleteState: ""
    // false once the page has gone: a late answer is dropped
    property var _life: ({ open: true })
    Component.onDestruction: _life.open = false
    readonly property var guests: extras.guests
    readonly property var guestsSummary: guests ? Logic.guestsSummary(guests, _texts.guestsFormat) : null
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

    /*! Delete the event and leave the details; a phone event is deleted on the phone first (D-14). */
    function deleteEvent() {
        if (!event || !deletable || deleteState === "busy")
            return
        if (event.calendarUid !== Logic.phoneNotebookUid) {
            event.deleteEvent()
            if (pop)
                pop()
            return
        }
        deleteState = "busy"
        var life = _life
        page.relay.act(Logic.deleteAct(extras, item ? item.start : null), function (r) {
            if (!life.open)
                return
            if (r && r.ok === true) {
                deleteState = ""
                // the watch's copy goes at once; the phone's next sync agrees
                if (page.event)
                    page.event.deleteEvent()
                if (pop)
                    pop()
            } else {
                deleteState = "failed"
            }
        })
    }

    /*! The location's tap: the place in the phone's maps (D-15). */
    function openMap() {
        if (mapState === "busy" || !event || String(event.location || "").trim() === "")
            return
        mapState = "busy"
        var life = _life
        page.relay.act(Logic.mapAct(event.location), function (r) {
            if (life.open)
                mapState = r && r.ok === true ? "ok" : "failed"
        })
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
                    case "guests": return guestsRow
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
    // the place; a tap shows it in the phone's maps (D-15: stock's LocationSegment opens Maps)
    Component {
        id: locationRow
        DetailRow {
            id: _locationRow
            objectName: "locationRow"
            iconName: "ios-pin-outline"
            Accessible.name: _texts.locationLabel
            Accessible.role: Accessible.Button
            Label {
                objectName: "locationLabel"
                width: parent.width
                role: "bodyMedium"
                color: Theme.color.onSurface
                text: page.event ? String(page.event.location).trim() : ""
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }
            Label {
                objectName: "mapStatus"
                visible: page.mapState === "ok" || page.mapState === "failed"
                width: parent.width
                role: "labelSmall"
                color: page.mapState === "failed" ? Theme.color.error : Theme.color.onSurfaceVariant
                text: page.mapState === "failed" ? _texts.openFailed : _texts.openedOnPhone
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }
            MouseArea {
                objectName: "locationButton"
                parent: _locationRow
                anchors.fill: parent
                enabled: page.mapState !== "busy"
                onClicked: page.openMap()
            }
        }
    }
    // the guests (D-08): the summary, the note, a row per guest
    Component {
        id: guestsRow
        Column {
            objectName: "guestsSegment"
            width: parent ? parent.width : 0
            DetailRow {
                objectName: "guestsSummary"
                iconName: "ios-people-outline"
                Accessible.name: page.guestsSummary ? page.guestsSummary.title + ", " + page.guestsSummary.detail : ""
                Label {
                    objectName: "guestsTitle"
                    width: parent.width
                    role: "bodyMedium"
                    color: Theme.color.onSurface
                    text: page.guestsSummary ? page.guestsSummary.title : ""
                    horizontalAlignment: Text.AlignLeft
                }
                Label {
                    objectName: "guestsDetail"
                    width: parent.width
                    role: "labelSmall"
                    color: Theme.color.onSurfaceVariant
                    text: page.guestsSummary ? page.guestsSummary.detail : ""
                    horizontalAlignment: Text.AlignLeft
                }
                Label {
                    objectName: "guestsNote"
                    visible: text !== ""
                    width: parent.width
                    role: "labelSmall"
                    color: Theme.color.onSurfaceVariant
                    wrapMode: Text.Wrap
                    text: !page.guests ? "" : page.guests.note === "hidden" ? _texts.guestsHidden
                                                : page.guests.note === "tooMany" ? _texts.guestsTooMany : ""
                    horizontalAlignment: Text.AlignLeft
                }
            }
            Repeater {
                model: page.guests ? page.guests.list : []
                delegate: Item {
                    id: guestRow
                    required property var modelData
                    objectName: "guestRow"
                    width: parent ? parent.width : 0
                    height: Math.max(_slot.height, _names.implicitHeight) + Theme.dp(8)
                    Accessible.role: Accessible.StaticText
                    Accessible.name: _texts.guestDescription(modelData.name, modelData.response)
                    // the 25 dp slot under the summary's icon: the letter disc and the response badge
                    Item {
                        id: _slot
                        x: Theme.dp(6) + (Theme.dp(26) - width) / 2
                        width: Theme.dp(25)
                        height: width
                        Rectangle {
                            width: Theme.dp(18)
                            height: width
                            radius: width / 2
                            color: Theme.color.surfaceContainerHigh
                            Label {
                                anchors.centerIn: parent
                                role: "labelSmall"
                                color: Theme.color.onSurface
                                text: guestRow.modelData.name.charAt(0).toUpperCase()
                            }
                        }
                        Rectangle {
                            objectName: "guestBadge"
                            visible: guestRow.modelData.response > 0
                            readonly property int response: guestRow.modelData.response
                            x: parent.width - width
                            y: parent.height - height
                            width: Theme.dp(14)
                            height: width
                            radius: width / 2
                            border.width: Theme.dp(1.4)
                            border.color: "#000000"
                            color: response === 1 ? "#ceead6" : response === 2 ? "#e8eaed" : "#fad2cf"
                            Icon {
                                anchors.centerIn: parent
                                width: Theme.dp(10)
                                height: width
                                name: parent.response === 1 ? "ios-checkmark" : parent.response === 2 ? "ios-help" : "ios-close"
                                color: parent.response === 1 ? "#0d652d" : parent.response === 2 ? "#3c4043" : "#b31412"
                            }
                        }
                    }
                    Column {
                        id: _names
                        x: Theme.dp(6) + Theme.dp(26) + Theme.dp(12)
                        width: parent.width - x - Theme.dp(6)
                        Label {
                            objectName: "guestName"
                            width: parent.width
                            role: "bodyMedium"
                            color: Theme.color.onSurface
                            text: guestRow.modelData.name
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignLeft
                        }
                        Label {
                            objectName: "guestOrganizer"
                            visible: guestRow.modelData.organizer
                            width: parent.width
                            role: "labelSmall"
                            color: Theme.color.onSurfaceVariant
                            text: _texts.organizer
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }
            }
            Item { width: 1; height: Theme.dp(8) }
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
            height: _deleteColumn.height + Theme.dp(4)
            Column {
                id: _deleteColumn
                y: Theme.dp(4)
                width: parent.width
                spacing: Theme.dp(4)
                Button {
                    id: _delete
                    objectName: "deleteButton"
                    width: parent.width
                    variant: "tonal"
                    enabled: page.deleteState !== "busy"
                    iconName: "ios-trash-outline"
                    text: _texts.deleteEvent
                    onClicked: _confirm.open()
                }
                Label {
                    objectName: "deleteError"
                    visible: page.deleteState === "failed"
                    width: parent.width
                    role: "bodyMedium"
                    color: Theme.color.error
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: _texts.deleteFailed
                }
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
