// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// src/CalendarLogic.js, the app's rules without a QML scene: days and spans, the agenda list (day
// groups, all-day and multi-day events, the window, the empty states and the footer), the card and
// details texts, the phone's extras in the stored event, reminders, the open request of CR-36 and the
// phone's acts (FP-A2). Every check runs on fixed dates: "today" is Tuesday 10 November 2026 (stock's
// example header "Today Tue 10"), all dates are local, so the checks hold in any time zone (TZ= of the
// runner; a zone with a daylight saving change tests the day arithmetic over it). The words are test
// strings; the real ones come from CalendarText.qml (tst_screens, tst_app).
import QtQuick
import QtTest
import "../../src/CalendarLogic.js" as Logic

TestCase {
    id: tc
    name: "CalendarLogic"

    readonly property date today: new Date(2026, 10, 10)
    // 10 Nov 2026 14:35 local, the "now" of the request checks
    readonly property real now: new Date(2026, 10, 10, 14, 35).getTime()

    function pad(n) { return n < 10 ? "0" + n : "" + n }
    readonly property var f: ({
        allDay: "All day",
        until: "Until %1",
        noTitle: "(No title)",
        multiDay: "%1 (Day %2/%3)",
        today: "Today",
        tomorrow: "Tomorrow",
        time: function (d) { return d.getHours() + ":" + tc.pad(d.getMinutes()) },
        range: function (a, b) { return tc.f.time(a) + "-" + tc.f.time(b) },
        weekdayDate: function (w, n) { return w + " " + n },
        dayName: function (d) { return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()] },
        otherDay: function (d) { return tc.f.dayName(d) + ", " + d.getDate() },
        dateRange: function (a, b) { return tc.f.otherDay(a) + " - " + tc.f.otherDay(b) },
        weeks: function (n) { return n === 1 ? "1 week" : n + " weeks" },
        days: function (n) { return n === 1 ? "1 day" : n + " days" },
        hours: function (n) { return n === 1 ? "1 hour" : n + " hours" },
        minutes: function (n) { return n === 1 ? "1 minute" : n + " minutes" },
        before: "%1 before",
        after: "%1 after the start",
        atTime: "At time of event",
        onTheDay: "On the day at %1",
        dayBefore: "The day before at %1",
        daysBefore: "%1 before at %2"
    })

    function ev(title, allDay, id) {
        return { displayLabel: title, allDay: allDay === true, instanceId: id || title, location: "", description: "",
                 calendarUid: "test-notebook", readOnly: false }
    }
    // an occurrence on today + day at hh:mm, minutes long
    function occ(title, day, h, m, minutes, allDay, id) {
        var s = new Date(2026, 10, 10 + day, h, m)
        return { event: ev(title, allDay, id), startTime: s, endTime: new Date(s.getTime() + minutes * 60000) }
    }
    function build(rows, syncedUntil, phoneSynced) {
        return Logic.buildItems(rows, { today: tc.today, syncedUntil: syncedUntil || null,
                                        phoneSynced: phoneSynced === undefined ? true : phoneSynced })
    }
    function kinds(items) {
        return items.map(function (i) { return i.kind }).join(",")
    }
    function events(items) {
        return items.filter(function (i) { return i.kind === "event" })
    }
    function labels(items) {
        return events(items).map(function (i) { return i.event.displayLabel }).join(",")
    }

    // ---------------------------------------------------------------- days

    function test_days() {
        compare(Logic.startOfDay(new Date(2026, 10, 10, 15, 30)).getTime(), new Date(2026, 10, 10).getTime())
        compare(Logic.addDays(new Date(2026, 10, 30), 1).getTime(), new Date(2026, 11, 1).getTime(), "over a month end")
        compare(Logic.addDays(new Date(2026, 11, 31), 1).getTime(), new Date(2027, 0, 1).getTime(), "over a year end")
        compare(Logic.addDays(new Date(2026, 10, 10, 13, 0), -3).getTime(), new Date(2026, 10, 7).getTime(), "back, as a day")
        // whole calendar days, also over a daylight saving change (where the zone has one)
        compare(Logic.dayNumber(new Date(2027, 3, 4)) - Logic.dayNumber(new Date(2027, 3, 3)), 1)
        compare(Logic.dayNumber(new Date(2026, 8, 28)) - Logic.dayNumber(new Date(2026, 8, 27)), 1)
        compare(Logic.dayNumber(new Date(2026, 2, 30)) - Logic.dayNumber(new Date(2026, 2, 29)), 1)
        compare(Logic.dayNumber(new Date(2026, 2, 9)) - Logic.dayNumber(new Date(2026, 2, 8)), 1)
        compare(Logic.dayNumber(new Date(2026, 10, 2)) - Logic.dayNumber(new Date(2026, 10, 1)), 1)
        compare(Logic.addDays(new Date(2026, 2, 7, 12), 2).getTime(), new Date(2026, 2, 9).getTime(), "over a spring change")
        compare(Logic.addDays(new Date(2026, 9, 31), 2).getTime(), new Date(2026, 10, 2).getTime(), "over an autumn change")
        compare(Logic.span(false, new Date(2026, 10, 1, 0, 30), new Date(2026, 10, 1, 23, 30)).count, 1, "a 24 h day")
        compare(Logic.dayNumber(new Date(2027, 0, 1, 23, 59)) - Logic.dayNumber(new Date(2026, 0, 1, 0, 0)), 365)
        verify(Logic.isMidnight(new Date(2026, 10, 10)))
        verify(!Logic.isMidnight(new Date(2026, 10, 10, 0, 0, 1)))
        verify(!Logic.isMidnight(new Date(2026, 10, 10, 0, 0, 0, 1)))
    }

    function test_span() {
        // timed: the end is the first instant after the event, so an end at midnight stays on the day before
        compare(Logic.span(false, new Date(2026, 10, 10, 9), new Date(2026, 10, 10, 10)).count, 1)
        compare(Logic.span(false, new Date(2026, 10, 10, 22), new Date(2026, 10, 11, 0)).count, 1, "ends at midnight: one day")
        compare(Logic.span(false, new Date(2026, 10, 10, 22), new Date(2026, 10, 11, 0, 1)).count, 2)
        var s = Logic.span(false, new Date(2026, 10, 9, 22), new Date(2026, 10, 12, 11))
        compare(s.count, 4)
        compare(s.first.getTime(), new Date(2026, 10, 9).getTime())
        compare(s.last.getTime(), new Date(2026, 10, 12).getTime())
        // all-day: the plugin's end is the last day (inclusive)
        compare(Logic.span(true, new Date(2026, 10, 10), new Date(2026, 10, 10)).count, 1)
        compare(Logic.span(true, new Date(2026, 10, 10), new Date(2026, 10, 12)).count, 3)
        // no end, or an end before the start: one day
        compare(Logic.span(false, new Date(2026, 10, 10, 9), new Date(2026, 10, 10, 8)).count, 1)
        compare(Logic.span(false, new Date(2026, 10, 10, 9), null).count, 1)
        // 'All day' also for a timed event from midnight to midnight (lxt.java:330)
        verify(Logic.allDayLike(false, new Date(2026, 10, 10), new Date(2026, 10, 11)))
        verify(Logic.allDayLike(false, new Date(2026, 10, 10), new Date(2026, 10, 12)), "two whole days")
        verify(!Logic.allDayLike(false, new Date(2026, 10, 10, 0, 30), new Date(2026, 10, 11)))
        verify(!Logic.allDayLike(false, new Date(2026, 10, 10), null))
        verify(Logic.allDayLike(true, new Date(2026, 10, 10, 9), new Date(2026, 10, 10, 10)))
    }

    // ---------------------------------------------------------------- the window (CR-55's reader)

    function test_window() {
        compare(Logic.windowEnd(tc.today, null).getTime(), new Date(2026, 10, 17).getTime(), "not known: today + 7 days")
        compare(Logic.windowEnd(new Date(2026, 10, 10, 18, 5), null).getTime(), new Date(2026, 10, 17).getTime(), "from the day")
        compare(Logic.windowEnd(tc.today, new Date(2026, 10, 20, 13, 45)).getTime(), new Date(2026, 10, 20).getTime(),
                "the stored end, as a day")
        compare(Logic.windowEnd(tc.today, new Date(2026, 10, 3)).getTime(), tc.today.getTime(), "an end in the past: today")
        compare(Logic.windowEnd(tc.today, tc.today).getTime(), tc.today.getTime())
    }

    function test_syncedUntilValue() {
        // /org/asteroidos/calendar/synced-until: unix seconds, 0 = not known (CR-55)
        compare(Logic.syncedUntilDate(0), null)
        compare(Logic.syncedUntilDate(-5), null)
        compare(Logic.syncedUntilDate(undefined), null)
        compare(Logic.syncedUntilDate(null), null)
        compare(Logic.syncedUntilDate("x"), null)
        compare(Logic.syncedUntilDate(1795000000).getTime(), 1795000000000, "seconds, not ms")
        compare(Logic.syncedUntilDate("1795000000").getTime(), 1795000000000, "a number as text")
    }

    // ---------------------------------------------------------------- the list (weather-calendar-22 ... 30)

    function test_groupsAndOrder() {
        var rows = [
            occ("Test Event B", 0, 12, 30, 60),
            occ("Test All Day", 0, 0, 0, 0, true),
            occ("Test Event A", 0, 9, 0, 15),
            occ("Test Event C", 2, 15, 0, 45)
        ]
        var items = build(rows)
        compare(kinds(items), "header,event,event,event,spacer,header,event,spacer", "per day with events: header, events, spacer")
        compare(labels(items), "Test All Day,Test Event A,Test Event B,Test Event C", "all-day first, then by start")
        verify(items[1].allDay)
        compare(items[0].day.getTime(), tc.today.getTime())
        compare(items[5].day.getTime(), new Date(2026, 10, 12).getTime(), "the day without events has no header")
        compare(items[2].day.getTime(), tc.today.getTime(), "an event knows its row's day")
        verify(items.every(function (i) { return i.kind !== "footer" }), "no footer while the window end is unknown")
        // keys are unique (the list's delegates)
        var keys = items.map(function (i) { return i.key })
        compare(keys.filter(function (k, i) { return keys.indexOf(k) === i }).length, keys.length)
    }

    function test_sameStartOrder() {
        // same start: by title (case-insensitive), then by id
        var rows = [occ("b", 0, 9, 0, 30, false, "2"), occ("A", 0, 9, 0, 30, false, "9"), occ("a", 0, 9, 0, 30, false, "1")]
        compare(events(build(rows)).map(function (i) { return i.event.instanceId }).join(), "1,9,2")
        verify(Logic.compareItems({ allDay: true, start: new Date(2026, 10, 10, 23), event: ev("z") },
                                  { allDay: false, start: new Date(2026, 10, 10, 1), event: ev("a") }) < 0, "all-day first")
    }

    function test_windowClips() {
        var rows = [occ("Test Past", -2, 9, 0, 60), occ("Test Edge", 7, 9, 0, 60), occ("Test Beyond", 8, 9, 0, 60),
                    occ("Test Yesterday Night", -1, 22, 0, 180)]
        compare(labels(build(rows)), "Test Yesterday Night,Test Edge",
                "today to today + 7: a past event is gone, one that runs into today is in, the day after the window is not")
        // a stored window end moves the edge
        compare(labels(build(rows, new Date(2026, 10, 18, 6))), "Test Yesterday Night,Test Edge,Test Beyond")
        compare(labels(build(rows, new Date(2026, 10, 12))), "Test Yesterday Night")
        // an event that ended at today's midnight is not today's
        compare(labels(build([{ event: ev("Test Ended"), startTime: new Date(2026, 10, 9, 22), endTime: tc.today }])), "")
    }

    function test_multiDay() {
        // Mon 9 22:00 to Thu 12 11:00: today (Tue) is day 2 of 4, Monday is before the list
        var items = build([{ event: ev("Test Trip"), startTime: new Date(2026, 10, 9, 22), endTime: new Date(2026, 10, 12, 11) }])
        var evs = events(items)
        compare(evs.length, 3, "Tue, Wed, Thu")
        compare(kinds(items), "header,event,spacer,header,event,spacer,header,event,spacer", "one row under each day")
        compare(evs.map(function (i) { return i.dayIndex + "/" + i.dayCount }).join(), "2/4,3/4,4/4")
        compare(Logic.title(evs[0], f), "Test Trip (Day 2/4)")
        compare(Logic.timeLine(evs[0], f), "All day", "a middle day")
        compare(Logic.timeLine(evs[1], f), "All day", "a middle day")
        compare(Logic.timeLine(evs[2], f), "Until 11:00", "the last day")
        verify(evs.every(function (i) { return !i.allDay }), "still a timed event")
        // the first day shows the start time
        evs = events(build([{ event: ev("Test Trip"), startTime: new Date(2026, 10, 10, 22), endTime: new Date(2026, 10, 11, 11) }]))
        compare(Logic.timeLine(evs[0], f), "22:00")
        compare(Logic.title(evs[0], f), "Test Trip (Day 1/2)")
        compare(Logic.timeLine(evs[1], f), "Until 11:00")
        // starts at midnight on a later day: 'All day' on the first day
        evs = events(build([{ event: ev("Test Trip"), startTime: new Date(2026, 10, 11), endTime: new Date(2026, 10, 12, 10) }]))
        compare(Logic.timeLine(evs[0], f), "All day")
        // ends exactly at midnight on its last day: 'All day' there
        evs = events(build([{ event: ev("Test Camp"), startTime: new Date(2026, 10, 10, 14), endTime: new Date(2026, 10, 12, 0) }]))
        compare(evs.length, 2)
        compare(Logic.timeLine(evs[0], f), "14:00")
        compare(Logic.timeLine(evs[1], f), "All day", "the last day ends at its midnight")
        // an all-day event over 3 days
        evs = events(build([{ event: ev("Test Holiday", true), startTime: new Date(2026, 10, 10), endTime: new Date(2026, 10, 12) }]))
        compare(evs.length, 3)
        compare(Logic.title(evs[1], f), "Test Holiday (Day 2/3)")
        verify(evs.every(function (i) { return i.allDay && Logic.timeLine(i, f) === "All day" }))
        // a timed event over two whole days reads as all-day on both
        evs = events(build([{ event: ev("Test Two Days"), startTime: new Date(2026, 10, 10), endTime: new Date(2026, 10, 12) }]))
        compare(evs.length, 2)
        verify(evs.every(function (i) { return i.allDay }))
        compare(Logic.title(evs[1], f), "Test Two Days (Day 2/2)")
    }

    function test_timeLines() {
        var evs = events(build([occ("Test Meeting", 0, 9, 0, 60), occ("Test Day", 0, 0, 0, 0, true),
                                occ("Test Midnight", 1, 0, 0, 24 * 60), occ("Test Late", 1, 22, 0, 120)]))
        compare(Logic.timeLine(evs[1], f), "9:00-10:00", "one day: the range")
        compare(Logic.timeLine(evs[0], f), "All day", "all-day: no 00:00")
        compare(Logic.timeLine(evs[2], f), "All day", "midnight to midnight")
        compare(Logic.timeLine(evs[3], f), "22:00-0:00", "ends at the next midnight: still one day, the range")
        compare(Logic.title(evs[0], f), "Test Day")
    }

    function test_noTitle() {
        var evs = events(build([occ("", 0, 9, 0, 60), occ("   ", 0, 10, 0, 60)]))
        compare(Logic.title(evs[0], f), "(No title)")
        compare(Logic.title(evs[1], f), "(No title)")
        compare(Logic.title({ event: ev(" Test Event A "), dayCount: 1, dayIndex: 1 }, f), "Test Event A", "trimmed")
        compare(Logic.title({ event: ev(""), dayCount: 3, dayIndex: 2 }, f), "(No title) (Day 2/3)")
    }

    function test_emptyStates() {
        var items = build([])
        compare(kinds(items), "header,noEvents", "today's header and 'No events until <date>'")
        compare(items[0].day.getTime(), tc.today.getTime())
        compare(items[1].until.getTime(), new Date(2026, 10, 17).getTime(), "until today + 7")
        items = build([], new Date(2026, 10, 19, 8))
        compare(kinds(items), "header,noEvents", "no footer under the empty state")
        compare(items[1].until.getTime(), new Date(2026, 10, 19).getTime(), "the stored window end")
        compare(kinds(build([], null, false)), "header,hint", "the phone never synced: the hint")
        // only events outside the window: empty
        compare(kinds(build([occ("Test Past", -3, 9, 0, 60)])), "header,noEvents")
        // the watch's own events with no sync: the list, no hint
        compare(kinds(build([occ("Test Own", 0, 9, 0, 60)], null, false)), "header,event,spacer")
        // rows without an event or a start are skipped
        compare(kinds(build([{ event: null, startTime: new Date(2026, 10, 10, 9) }, { event: ev("x"), startTime: null }])),
                "header,noEvents")
    }

    function test_footer() {
        var items = build([occ("Test Event A", 0, 9, 0, 60)], new Date(2026, 10, 17, 9, 30))
        compare(kinds(items), "header,event,spacer,footer", "'Synced until' ends the list")
        compare(items[3].until.getTime(), new Date(2026, 10, 17).getTime(), "as a day")
    }

    // ---------------------------------------------------------------- headers (weather-calendar-23)

    function test_headers() {
        var h = Logic.dayHeader(new Date(2026, 10, 10), tc.today, f)
        compare(h.kind, "today"); compare(h.lead, "Today"); compare(h.date, "Tue 10", "Today Tue 10")
        h = Logic.dayHeader(new Date(2026, 10, 11), tc.today, f)
        compare(h.kind, "tomorrow"); compare(h.lead, "Tomorrow"); compare(h.date, "Wed 11")
        h = Logic.dayHeader(new Date(2026, 10, 12), tc.today, f)
        compare(h.kind, "other"); compare(h.lead, ""); compare(h.date, "Thu, 12")
        h = Logic.dayHeader(new Date(2026, 11, 1), new Date(2026, 10, 30), f)
        compare(h.kind, "tomorrow", "over a month end"); compare(h.date, "Tue 1")
        h = Logic.dayHeader(new Date(2026, 10, 10, 18), new Date(2026, 10, 10, 7), f)
        compare(h.kind, "today", "times do not matter")
    }

    // ---------------------------------------------------------------- the phone's extras (weather-calendar-24, -31)

    readonly property string ics: "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:x\r\nBEGIN:VEVENT\r\nUID:a-b\r\nSUMMARY:Test Event\r\n"
        + "DESCRIPTION:Line one\\nline two\\, with a comma\r\n"
        + "X-EOS-COLOR:ff3fa9f5\r\nX-EOS-RSVP:0\r\nX-EOS-ORGANIZER:Sample\\, Organizer\r\n"
        + "X-EOS-CALENDAR;X-PARAM=\"a:b\":Test\r\n Calendar\r\nX-EOS-EVENTID:123\r\n"
        + "BEGIN:VALARM\r\nTRIGGER:-PT10M\r\nACTION:DISPLAY\r\nEND:VALARM\r\n"
        + "BEGIN:VALARM\r\nTRIGGER;RELATED=START:-PT1H30M\r\nACTION:DISPLAY\r\nEND:VALARM\r\n"
        + "BEGIN:VALARM\r\nTRIGGER;RELATED=END:-PT5M\r\nACTION:DISPLAY\r\nEND:VALARM\r\n"
        + "BEGIN:VALARM\r\nTRIGGER;VALUE=DATE-TIME:20261110T080000Z\r\nACTION:DISPLAY\r\nEND:VALARM\r\n"
        + "BEGIN:VALARM\r\nTRIGGER:PT5M\r\nACTION:DISPLAY\r\nEND:VALARM\r\n"
        + "BEGIN:VALARM\r\nTRIGGER:-P1DT2H\r\nACTION:DISPLAY\r\nEND:VALARM\r\n"
        + "BEGIN:VALARM\r\nTRIGGER:-PT10M\r\nACTION:DISPLAY\r\nEND:VALARM\r\n"
        + "END:VEVENT\r\nEND:VCALENDAR\r\n"

    function test_parseExtras() {
        var x = Logic.parseExtras(ics)
        compare(x.color, "ff3fa9f5")
        compare(x.response, 0)
        compare(x.organizer, "Sample, Organizer", "text escapes")
        compare(x.calendar, "TestCalendar", "a folded line and a parameter holding a colon")
        compare(x.eventId, "123")
        compare(JSON.stringify(x.reminders), "[10,90,-5,1560]",
                "minutes before; END-related, absolute and repeated ones dropped; 5 after is -5; a day and 2 h is 1560")
        x = Logic.parseExtras("")
        compare(x.color, ""); compare(x.response, -1); compare(x.eventId, ""); compare(x.reminders.length, 0)
        x = Logic.parseExtras("BEGIN:VCALENDAR\nBEGIN:VEVENT\nX-EOS-COLOR:3fa9f5\nX-EOS-RSVP:9\nEND:VEVENT\nEND:VCALENDAR")
        compare(x.color, "ff3fa9f5", "a six digit colour is opaque")
        compare(x.response, -1, "out of range")
        compare(Logic.parseExtras("X-EOS-RSVP:2\nBEGIN:VEVENT\nEND:VEVENT").response, -1, "outside the VEVENT")
        compare(Logic.parseExtras("BEGIN:VEVENT\nX-EOS-RSVP:3\nEND:VEVENT").response, 3, "LF only")
        compare(Logic.parseExtras("BEGIN:VEVENT\nx-eos-rsvp:1\nEND:VEVENT").response, 1, "names are case-insensitive")
    }

    function test_triggers() {
        compare(Logic.triggerMinutes("-PT10M"), 10)
        compare(Logic.triggerMinutes("PT0S"), 0)
        compare(Logic.triggerMinutes("-P1W"), 10080)
        compare(Logic.triggerMinutes("+PT1H"), -60)
        compare(Logic.triggerMinutes("-PT90S"), 2, "seconds round")
        compare(Logic.triggerMinutes("soon"), null)
    }

    function test_color() {
        compare(Logic.eventColor({ color: "80112233" }, "#ff0000"), "#112233", "the event colour, its alpha ignored")
        compare(Logic.eventColor({ color: "" }, "#ff0000"), "#ff0000", "the notebook's")
        compare(Logic.eventColor({ color: "" }, ""), "#3fa9f5", "the Phone notebook's blue")
        compare(Logic.eventColor({ color: "" }, "nonsense"), "#3fa9f5")
        compare(Logic.eventColor(null, "#00ff00"), "#00ff00")
        compare(Logic.normalizeColor("#FF3FA9F5"), "ff3fa9f5")
        compare(Logic.normalizeColor("zz"), "")
    }

    // ---------------------------------------------------------------- reminders (weather-calendar-32)

    function test_reminders() {
        var d = new Date(2026, 10, 12, 9, 0)
        compare(Logic.reminderLabel(10, false, d, f), "10 minutes before")
        compare(Logic.reminderLabel(1, false, d, f), "1 minute before")
        compare(Logic.reminderLabel(60, false, d, f), "1 hour before")
        compare(Logic.reminderLabel(90, false, d, f), "1 hour 30 minutes before")
        compare(Logic.reminderLabel(1440, false, d, f), "1 day before")
        compare(Logic.reminderLabel(10080, false, d, f), "1 week before")
        compare(Logic.reminderLabel(10080 + 1440 + 120 + 5, false, d, f), "1 week 1 day 2 hours 5 minutes before")
        compare(Logic.reminderLabel(0, false, d, f), "At time of event")
        compare(Logic.reminderLabel(-5, false, d, f), "5 minutes after the start")
        // an all-day event: the time is the start of the day minus the offset (stock lsn.java:350-385)
        compare(Logic.reminderLabel(-540, true, d, f), "On the day at 9:00", "9 hours after midnight")
        compare(Logic.reminderLabel(0, true, d, f), "On the day at 0:00")
        compare(Logic.reminderLabel(900, true, d, f), "The day before at 9:00", "15 hours before midnight")
        compare(Logic.reminderLabel(1440, true, d, f), "The day before at 0:00")
        compare(Logic.reminderLabel(1500, true, d, f), "2 days before at 23:00", "25 hours before midnight")
        compare(Logic.reminderLabel(8640 + 540, true, d, f), "1 week before at 15:00", "a week and a bit")
        // stock's count is (minutes + 1440) / 1440, also on a whole number of days (as lsn.java:367)
        compare(Logic.reminderLabel(2880, true, d, f), "3 days before at 0:00")
    }

    // ---------------------------------------------------------------- details (weather-calendar-32, -33)

    function test_detailLines() {
        var it = { event: ev("Test Event A"), start: new Date(2026, 10, 10, 9), end: new Date(2026, 10, 10, 10) }
        compare(Logic.dateLine(it, tc.today, f), "Today")
        it.start = new Date(2026, 10, 11, 9); it.end = new Date(2026, 10, 11, 10)
        compare(Logic.dateLine(it, tc.today, f), "Tomorrow")
        it.start = new Date(2026, 10, 13, 9); it.end = new Date(2026, 10, 13, 10)
        compare(Logic.dateLine(it, tc.today, f), "Fri, 13")
        it.start = new Date(2026, 10, 9, 9); it.end = new Date(2026, 10, 9, 10)
        compare(Logic.dateLine(it, tc.today, f), "Mon, 9", "yesterday is a date")
        it.start = new Date(2026, 10, 13, 9); it.end = new Date(2026, 10, 15, 10)
        compare(Logic.dateLine(it, tc.today, f), "Fri, 13 - Sun, 15")
        compare(Logic.detailTime(it.event, it.start, it.end, f), "9:00 – 10:00", "a multi-day event: both times")
        compare(Logic.detailTime(ev("A"), new Date(2026, 10, 13, 9), new Date(2026, 10, 13, 10), f), "9:00-10:00")
        compare(Logic.detailTime(ev("A", true), new Date(2026, 10, 13), new Date(2026, 10, 13), f), "All day")
        compare(Logic.detailTime(ev("A"), new Date(2026, 10, 13), new Date(2026, 10, 14), f), "All day", "midnight to midnight")
        // all-day over 3 days: the range of dates
        var all = { event: ev("A", true), start: new Date(2026, 10, 13), end: new Date(2026, 10, 15) }
        compare(Logic.dateLine(all, tc.today, f), "Fri, 13 - Sun, 15")
    }

    function test_deleteRules() {
        var e = ev("A")
        verify(Logic.canDelete(e, false), "a watch-local event")
        e.calendarUid = Logic.phoneNotebookUid
        verify(!Logic.canDelete(e, false), "a phone event: not until Gadgetbridge can delete it there")
        verify(Logic.canDelete(e, true))
        e.readOnly = true
        verify(!Logic.canDelete(e, true), "read only")
    }

    function test_detailRows() {
        var e = ev("A")
        compare(Logic.detailRows(e, {}, [], false).join(), "title,when,calendar")
        e.location = "Test Room"; e.description = "Test notes"
        compare(Logic.detailRows(e, {}, ["10 minutes before"], true).join(),
                "title,when,location,description,reminders,calendar,delete", "stock order")
        e.location = "  "
        compare(Logic.detailRows(e, {}, [], false).join(), "title,when,description,calendar")
        // the phone's segments go between the calendar's name and 'Delete event'
        var p = { location: "", description: "" }
        compare(Logic.detailRows(p, {}, [], true, { rsvp: true, open: true }).join(), "title,when,calendar,rsvp,openPhone,delete")
        compare(Logic.detailRows(p, {}, [], false, { rsvp: false, open: true }).join(), "title,when,calendar,openPhone")
        compare(Logic.detailRows(p, {}, [], false, { rsvp: true, open: false }).join(), "title,when,calendar,rsvp")
    }

    function test_format() {
        compare(Logic.format("%1 (Day %2/%3)", ["x %2", 1, 3]), "x %2 (Day 1/3)", "one pass: an argument holding %2 stays")
        compare(Logic.format("%2 %1", ["a", "b"]), "b a")
        compare(Logic.format("%4", ["a"]), "%4")
    }

    // ---------------------------------------------------------------- the open request (CR-36, FP-A2)

    function test_requestEvent() {
        var start = new Date(2026, 10, 11, 9, 0).getTime()
        var r = Logic.parseOpenRequest("event:" + start + "@" + now, now)
        verify(r !== null)
        compare(r.route, "event")
        compare(r.start, start)
        compare(r.at, now)
        compare(Logic.parseOpenRequest(null, now), null)
    }

    function test_requestAge() {
        var s = "event:" + new Date(2026, 10, 11, 9, 0).getTime() + "@"
        verify(Logic.parseOpenRequest(s + now, now) !== null, "now")
        verify(Logic.parseOpenRequest(s + (now - 59999), now) !== null, "59.999 s old")
        verify(Logic.parseOpenRequest(s + (now - 60000), now) !== null, "60 s old: not older than 60 s")
        compare(Logic.parseOpenRequest(s + (now - 60001), now), null, "older than 60 s")
        compare(Logic.parseOpenRequest(s + (now - 3600000), now), null, "an hour old")
        verify(Logic.parseOpenRequest(s + (now + 5000), now) !== null, "5 s ahead (another clock)")
        compare(Logic.parseOpenRequest(s + (now + 5001), now), null, "more than 5 s in the future")
        compare(Logic.requestMaxAge, 60000)
        compare(Logic.requestMaxFuture, 5000)
    }

    function test_requestSplitsAtTheLastAt() {
        var start = new Date(2026, 10, 11, 9, 0).getTime()
        // the route is what is before the LAST "@": a route that holds an "@" is not "event:<startMs>"
        compare(Logic.parseOpenRequest("event:" + start + "@1@" + now, now), null, "route event:<ms>@1")
        compare(Logic.parseOpenRequest("event:" + start + "@" + now + "@" + now, now), null)
        // the stamp is the part after the last "@": here 1 ms after the epoch, far too old
        compare(Logic.parseOpenRequest("event:" + start + "@" + now + "@1", now), null)
    }

    function test_requestRejects() {
        compare(Logic.parseOpenRequest("", now), null)
        compare(Logic.parseOpenRequest(undefined, now), null)
        compare(Logic.parseOpenRequest("event:1793160000000", now), null, "no stamp")
        compare(Logic.parseOpenRequest("event:1793160000000@", now), null)
        compare(Logic.parseOpenRequest("event:1793160000000@soon", now), null)
        compare(Logic.parseOpenRequest("event:1793160000000@-5", now), null)
        compare(Logic.parseOpenRequest("event:@" + now, now), null, "no start")
        compare(Logic.parseOpenRequest("event:0@" + now, now), null)
        compare(Logic.parseOpenRequest("event:-5@" + now, now), null)
        compare(Logic.parseOpenRequest("event:12x@" + now, now), null)
        compare(Logic.parseOpenRequest("Event:12@" + now, now), null, "the route's case matters")
        compare(Logic.parseOpenRequest("alarm:3@" + now, now), null, "another app's route")
        compare(Logic.parseOpenRequest("1793160000000@" + now, now), null, "the route is event:<startMs>")
    }

    function row(day, hour, minute, title, id) {
        var s = new Date(2026, 10, 10 + day, hour, minute)
        return { event: ev(title, false, id), startTime: s, endTime: new Date(s.getTime() + 3600000) }
    }

    function test_findEventItem() {
        var rows = [row(0, 9, 0, "Test Event A"), row(1, 9, 0, "Test Event C"), row(1, 9, 0, "Test Event B")]
        var items = build(rows)
        compare(Logic.findEventItem(items, rows[0].startTime.getTime(), tc.today).event.displayLabel, "Test Event A")
        // two events start together: the first in the agenda's order (title)
        compare(Logic.findEventItem(items, rows[1].startTime.getTime(), tc.today).event.displayLabel, "Test Event B")
        compare(Logic.findEventItem(items, rows[0].startTime.getTime() + 1, tc.today), null, "to the millisecond")
        compare(Logic.findEventItem(items, 12345, tc.today), null, "no such event")
        compare(Logic.findEventItem([], 12345, tc.today), null)
        // only events: a header's day is no match
        compare(Logic.findEventItem(items, tc.today.getTime(), tc.today), null)
    }

    function test_findEventItemMultiDay() {
        var s = new Date(2026, 10, 9, 22, 0)
        var items = build([{ event: ev("Test Trip"), startTime: s, endTime: new Date(2026, 10, 12, 11, 0) }])
        compare(Logic.findEventItem(items, s.getTime(), tc.today).dayIndex, 2, "the row of today (Day 2/4)")
        compare(Logic.findEventItem(items, s.getTime(), new Date(2026, 10, 11)).dayIndex, 3)
        compare(Logic.findEventItem(items, s.getTime(), new Date(2026, 10, 20)).dayIndex, 2, "not one of its days: the first row")
    }

    // ---------------------------------------------------------------- the phone's acts (FP-A2: RSVP, Open on phone)

    readonly property string phoneUid: Logic.phoneNotebookUid
    function extras(rsvp, id) {
        var t = "BEGIN:VEVENT\r\n"
        if (rsvp !== null)
            t += "X-EOS-RSVP:" + rsvp + "\r\n"
        if (id !== null)
            t += "X-EOS-EVENTID:" + id + "\r\n"
        return Logic.parseExtras(t + "END:VEVENT\r\n")
    }

    function test_phoneEventId() {
        compare(Logic.phoneEventId({ eventId: "456" }), 456)
        compare(Logic.phoneEventId({ eventId: " 456 " }), 456)
        compare(Logic.phoneEventId({ eventId: "" }), 0)
        compare(Logic.phoneEventId({ eventId: "abc" }), 0)
        compare(Logic.phoneEventId({ eventId: "0" }), 0)
        compare(Logic.phoneEventId({ eventId: "-4" }), 0)
        compare(Logic.phoneEventId({ eventId: "4.5" }), 0)
        compare(Logic.phoneEventId({ eventId: "9007199254740991" }), 9007199254740991, "2^53 - 1")
        compare(Logic.phoneEventId({ eventId: "99999999999999999999" }), 0, "beyond 2^53")
        compare(Logic.phoneEventId(null), 0)
        compare(Logic.phoneEventId({}), 0)
    }

    function test_canRespondAndOpen() {
        var phone = { calendarUid: phoneUid }, own = { calendarUid: "test-notebook" }
        var x = extras(0, 456)
        verify(Logic.canRespond(phone, x))
        verify(Logic.canOpenOnPhone(phone, x))
        verify(!Logic.canRespond(own, x), "the watch's own events have no phone to answer to")
        verify(!Logic.canOpenOnPhone(own, x))
        for (var r = 1; r <= 3; r++)
            verify(Logic.canRespond(phone, extras(r, 456)), "answered " + r + ": can change it")
        verify(!Logic.canRespond(phone, extras(null, 456)), "no response sent: the user is no guest")
        verify(Logic.canOpenOnPhone(phone, extras(null, 456)))
        verify(!Logic.canRespond(phone, extras(1, null)), "no phone id")
        verify(!Logic.canOpenOnPhone(phone, extras(1, null)))
        verify(!Logic.canRespond(null, x))
        verify(!Logic.canOpenOnPhone(null, x))
    }

    function test_acts() {
        var x = extras(0, 456)
        // gb AsteroidOSPhoneData.rsvp: {"a":"rsvp","id":<phone event id>,"st":1|2|3}, 1 Yes, 2 Maybe, 3 No
        compare(JSON.stringify(Logic.rsvpAct(x, 1)), '{"a":"rsvp","id":456,"st":1}')
        compare(JSON.stringify(Logic.rsvpAct(x, 2)), '{"a":"rsvp","id":456,"st":2}')
        compare(JSON.stringify(Logic.rsvpAct(x, 3)), '{"a":"rsvp","id":456,"st":3}')
        compare(Logic.rsvpAnswers.join(), "1,2,3")
        // gb AsteroidOSPhoneData.openTarget: {"a":"open","w":"event","id":..,"b":<start in SECONDS>} (gb multiplies by 1000)
        var start = new Date(2026, 10, 10, 14, 30, 0, 500)
        compare(JSON.stringify(Logic.openEventAct(x, start)),
                '{"a":"open","w":"event","id":456,"b":' + Math.floor(start.getTime() / 1000) + '}')
        compare(JSON.stringify(Logic.openEventAct(x, null)), '{"a":"open","w":"event","id":456}', "no start: the phone looks it up")
        compare(JSON.stringify(Logic.openCalendarAct()), '{"a":"open","w":"calendar"}')
    }
}
