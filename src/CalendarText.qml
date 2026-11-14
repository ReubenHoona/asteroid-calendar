/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import org.asteroid.controls
import org.asteroid.utils
import "CalendarLogic.js" as Logic

/*
 * The words and the date and time formats of the Calendar app, from stock
 * CP3A's strings (STRINGS.tsv com.google.android.calendar) and the shared
 * TimeFormat (the system 12/24 hour flag and the locale's am/pm). The
 * pages hand these objects to CalendarLogic.js, which stays free of QML.
 */
QtObject {
    id: text

    readonly property var locale: TimeFormat.locale
    readonly property string _loc: locale ? locale.name : ""

    //% "All day"
    readonly property string allDay: qsTrId("id-tile-all-day")
    //% "Today"
    readonly property string today: qsTrId("id-today")
    //% "Tomorrow"
    readonly property string tomorrow: qsTrId("id-tomorrow")
    //% "Until %1"
    readonly property string until: qsTrId("id-until-time")
    //% "(No title)"
    readonly property string noTitle: qsTrId("id-no-title")
    //% "%1 (Day %2/%3)"
    readonly property string multiDay: qsTrId("id-multi-day-count")
    //% "%1 %2"
    readonly property string weekdayDateOrder: qsTrId("id-weekday-date-order")
    //% "No events until %1"
    readonly property string noEventsUntil: qsTrId("id-no-events-until")
    //% "Synced until %1"
    readonly property string syncedUntil: qsTrId("id-synced-until")
    //% "Turn on calendar sync on your phone"
    readonly property string neverSynced: qsTrId("id-calendar-never-synced")
    //% "Delete event"
    readonly property string deleteEvent: qsTrId("id-delete-event")
    //% "Delete this event?"
    readonly property string deleteQuestion: qsTrId("id-delete-event-question")
    //% "Location"
    readonly property string locationLabel: qsTrId("id-event-location")
    //% "Description"
    readonly property string descriptionLabel: qsTrId("id-event-description")
    //% "Notifications"
    readonly property string remindersLabel: qsTrId("id-event-notifications")
    //% "Calendar"
    readonly property string calendarLabel: qsTrId("id-event-calendar")
    //% "Going?"
    readonly property string rsvpGoing: qsTrId("id-rsvp-going")
    //% "Yes"
    readonly property string rsvpYes: qsTrId("id-rsvp-yes")
    //% "Maybe"
    readonly property string rsvpMaybe: qsTrId("id-rsvp-maybe")
    //% "No"
    readonly property string rsvpNo: qsTrId("id-rsvp-no")
    //% "Responded %1"
    readonly property string rsvpResponded: qsTrId("id-rsvp-responded")
    //% "Change RSVP"
    readonly property string changeRsvp: qsTrId("id-rsvp-change")
    //% "Response could not be updated."
    readonly property string rsvpFailed: qsTrId("id-rsvp-failed")
    //% "Open on phone"
    readonly property string openOnPhone: qsTrId("id-open-on-phone")
    //% "Opened on your phone"
    readonly property string openedOnPhone: qsTrId("id-opened-on-phone")
    //% "Could not open on your phone"
    readonly property string openFailed: qsTrId("id-open-on-phone-failed")
    //% "View more on phone"
    readonly property string viewMoreOnPhone: qsTrId("id-view-more-on-phone")

    // the chip text of an answer (1 Yes, 2 Maybe, 3 No)
    function rsvpOption(st) {
        return st === 1 ? rsvpYes : st === 2 ? rsvpMaybe : rsvpNo
    }

    // 'Tue' + 10 -> 'Tue 10' (weekday_date_order)
    function weekdayDate(weekday, day) {
        return Logic.format(weekdayDateOrder, [weekday, day])
    }
    function dayName(d) {
        return locale.dayName(d.getDay(), Locale.ShortFormat)
    }
    // Day header of other days, 'Thu, 12 November' (en_NZ), 'Thu, November 12' (en_US): the weekday
    // abbreviated, the month in full, no year. Stock lwl.java:227 passes 32794 = ABBREV_WEEKDAY
    // 0x8000 + SHOW_DATE 0x10 + NO_YEAR 0x8 + SHOW_WEEKDAY 0x2; ABBREV_MONTH (0x10000) is not set.
    function otherDay(d) {
        return TimeFormat.date(d, "EEEMMMMd")
    }
    // Details date of a single day, 'Thu, 12 Nov': the details formatter (mqy.b) adds ABBREV_MONTH
    // (65536, mno.java:27 'i | 16'), so the month is abbreviated here.
    function detailDay(d) {
        return TimeFormat.date(d, "EEEMMMd")
    }
    // 'Thu, 12 - Sat, 14 Nov'
    function dateRange(a, b) {
        return DateFormat.formatRange(a, b, "EEEMMMd", _loc)
    }
    // '12 Nov 2026': abbreviated month, date and year (flags 65556)
    function fullDate(d) {
        return TimeFormat.date(d, "yMMMd")
    }

    // the unit words of a reminder (plurals.xml Nweeks, Ndays, Nhours, Nminutes)
    function weeks(n) {
        //% "1 week"
        if (n === 1) return qsTrId("id-week-one")
        //% "%1 weeks"
        return Logic.format(qsTrId("id-weeks-other"), [n])
    }
    function days(n) {
        //% "1 day"
        if (n === 1) return qsTrId("id-day-one")
        //% "%1 days"
        return Logic.format(qsTrId("id-days-other"), [n])
    }
    function hours(n) {
        //% "1 hour"
        if (n === 1) return qsTrId("id-hour-one")
        //% "%1 hours"
        return Logic.format(qsTrId("id-hours-other"), [n])
    }
    function minutes(n) {
        //% "1 minute"
        if (n === 1) return qsTrId("id-minute-one")
        //% "%1 minutes"
        return Logic.format(qsTrId("id-minutes-other"), [n])
    }

    // what CalendarLogic.timeLine() and title() take
    readonly property var lineFormat: ({
        allDay: allDay,
        until: until,
        noTitle: noTitle,
        multiDay: multiDay,
        time: function(d) { return TimeFormat.time(d) },
        range: function(a, b) { return TimeFormat.range(a, b) }
    })

    // what CalendarLogic.dayHeader() takes
    readonly property var headerFormat: ({
        today: today,
        tomorrow: tomorrow,
        weekdayDate: weekdayDate,
        dayName: dayName,
        otherDay: otherDay
    })

    // what the details take (dateLine, detailTime, reminderLabel)
    readonly property var detailFormat: ({
        allDay: allDay,
        today: today,
        tomorrow: tomorrow,
        otherDay: detailDay,
        dateRange: dateRange,
        time: function(d) { return TimeFormat.time(d) },
        range: function(a, b) { return TimeFormat.range(a, b) },
        weeks: weeks,
        days: days,
        hours: hours,
        minutes: minutes,
        //% "%1 before"
        before: qsTrId("id-reminder-before"),
        //% "%1 after the start"
        after: qsTrId("id-reminder-after"),
        //% "At time of event"
        atTime: qsTrId("id-reminder-at-time"),
        //% "On the day at %1"
        onTheDay: qsTrId("id-reminder-on-the-day"),
        //% "The day before at %1"
        dayBefore: qsTrId("id-reminder-day-before"),
        //% "%1 before at %2"
        daysBefore: qsTrId("id-reminder-days-before")
    })
}
