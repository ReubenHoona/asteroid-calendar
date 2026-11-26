// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double of the nemo calendar plugin's CalendarStoredEvent (the AgendaModel role "event"): the
// properties the app reads, iCalendar() (the stored event's text, where the phone's X-EOS-* extras
// and the reminders are) and deleteEvent().
import QtQuick

QtObject {
    property string displayLabel: ""
    property bool allDay: false
    property string location: ""
    property string description: ""
    property string calendarUid: ""
    property string instanceId: ""
    property bool readOnly: false
    // the notebook's colour (the plugin's CalendarEvent::color() is its notebook's)
    property string color: ""
    // what iCalendar() returns
    property string ics: ""
    // calls counted in an object, so that a binding that calls iCalendar() does not depend on the count
    property var stats: ({ n: 0 })
    property int deleted: 0

    function iCalendar(prodId) {
        stats.n++
        return ics
    }
    function deleteEvent() {
        deleted++
    }
}
