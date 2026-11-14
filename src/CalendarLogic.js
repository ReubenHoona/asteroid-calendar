/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

.pragma library

/*
 * The agenda's rules (W2-app-calendar), as stock CP3A Calendar (TimelineScreen
 * lwz.java:105-144, EventChip lxt.java:100-414, day headers lwl.java:115-330,
 * ReminderUtils lsn.java:358-413 / mna.java). Pure functions over plain
 * values so the tests can run them with no QML engine around: dates are JS
 * Dates, strings come in through the `f` object the caller fills from
 * qsTrId() and TimeFormat.
 */

// The mkcal notebook asteroid-btsyncd keeps the phone's events in
// (calendarservice.cpp NotebookUid)
var phoneNotebookUid = "8f1c2e4a-5b7d-4e6f-9a0b-a57e401d05ca"
// The Phone notebook's colour until the phone sends one (calendarservice.cpp)
var defaultColor = "#3fa9f5"
// What Gadgetbridge looks ahead when the stored window end is not known yet
var defaultWindowDays = 7

/* "%1 (Day %2/%3)" with the arguments in one pass (an argument may hold "%2") */
function format(text, args) {
    return String(text).replace(/%(\d)/g, function(m, d) {
        var i = parseInt(d, 10) - 1
        return i >= 0 && i < args.length ? String(args[i]) : m
    })
}

function startOfDay(d) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}

function addDays(d, n) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n)
}

/* Whole days since the epoch of the calendar date (DST safe) */
function dayNumber(d) {
    return Math.round(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000)
}

function isMidnight(d) {
    return d.getHours() === 0 && d.getMinutes() === 0 && d.getSeconds() === 0 && d.getMilliseconds() === 0
}

/*
 * The first and last calendar day of an occurrence. On an all-day event
 * the end is the last day (nemo-qml-plugin-calendar dailyEventOccurrences:
 * "on all day events the end time is inclusive"), otherwise it is the first
 * instant after the event, so one second less (a timed event that ends at
 * midnight does not run into the next day).
 */
function span(allDay, start, end) {
    var first = startOfDay(start)
    var last = first
    if (end && end.getTime() > start.getTime()) {
        last = allDay ? startOfDay(end) : startOfDay(new Date(end.getTime() - 1000))
    }
    if (last.getTime() < first.getTime())
        last = first
    return { first: first, last: last, count: dayNumber(last) - dayNumber(first) + 1 }
}

/*
 * 'All day' also for a timed event from midnight to midnight (lxt.java:330-340:
 * start and end both on a day start).
 */
function allDayLike(allDay, start, end) {
    return allDay || (isMidnight(start) && end && isMidnight(end))
}

/* The end of the list: the stored sync window, else today + 7 days */
function windowEnd(today, syncedUntil) {
    var t = startOfDay(today)
    var end = syncedUntil ? startOfDay(syncedUntil) : addDays(t, defaultWindowDays)
    return end.getTime() < t.getTime() ? t : end
}

/*
 * "Synced until" seconds from dconf: a Date, or null when nothing has
 * written one (the value 0 or less).
 */
function syncedUntilDate(seconds) {
    var s = Number(seconds)
    return s > 0 ? new Date(s * 1000) : null
}

/* Order inside a day: all-day first, then the start, then the title, then the id */
function compareItems(a, b) {
    if (a.allDay !== b.allDay)
        return a.allDay ? -1 : 1
    var d = a.start.getTime() - b.start.getTime()
    if (d !== 0)
        return d
    var ta = String(a.event.displayLabel || "").toLowerCase()
    var tb = String(b.event.displayLabel || "").toLowerCase()
    if (ta !== tb)
        return ta < tb ? -1 : 1
    var ia = String(a.event.instanceId || ""), ib = String(b.event.instanceId || "")
    return ia < ib ? -1 : ia > ib ? 1 : 0
}

/*
 * The agenda list (lwz.java:105-144):
 *   for each day with events: a header, its events, a 12 dp spacer;
 *   no events at all: today's header then 'No events until <window end>'
 *   (or the sync hint when the phone never synced);
 *   otherwise, the footer 'Synced until <date>' when that is known.
 * occurrences: [{ event, startTime, endTime }] (the AgendaModel rows).
 * o: { today, syncedUntil (Date or null), phoneSynced (bool) }
 */
function buildItems(occurrences, o) {
    var first = startOfDay(o.today)
    var end = windowEnd(first, o.syncedUntil)
    var nDays = dayNumber(end) - dayNumber(first) + 1
    var days = []
    for (var i = 0; i < nDays; i++)
        days.push([])
    var firstNumber = dayNumber(first)
    for (var k = 0; k < occurrences.length; k++) {
        var occ = occurrences[k]
        var ev = occ.event
        if (!ev || !occ.startTime)
            continue
        var s = span(ev.allDay, occ.startTime, occ.endTime)
        var like = allDayLike(ev.allDay, occ.startTime, occ.endTime)
        var from = Math.max(dayNumber(s.first), firstNumber)
        var to = Math.min(dayNumber(s.last), dayNumber(end))
        for (var n = from; n <= to; n++) {
            days[n - firstNumber].push({
                kind: "event",
                key: "e" + n + ":" + (ev.instanceId || k) + ":" + occ.startTime.getTime(),
                day: addDays(first, n - firstNumber),
                event: ev,
                occurrence: occ,
                start: occ.startTime,
                end: occ.endTime,
                allDay: like,
                dayIndex: n - dayNumber(s.first) + 1,
                dayCount: s.count
            })
        }
    }
    var items = []
    var any = false
    for (var d = 0; d < nDays; d++) {
        if (days[d].length === 0)
            continue
        any = true
        days[d].sort(compareItems)
        var day = addDays(first, d)
        items.push({ kind: "header", key: "h" + d, day: day })
        for (var e = 0; e < days[d].length; e++)
            items.push(days[d][e])
        items.push({ kind: "spacer", key: "s" + d })
    }
    if (!any) {
        items.push({ kind: "header", key: "h0", day: first })
        if (o.phoneSynced === false)
            items.push({ kind: "hint", key: "hint" })
        else
            items.push({ kind: "noEvents", key: "none", until: end })
    } else if (o.syncedUntil) {
        items.push({ kind: "footer", key: "footer", until: startOfDay(o.syncedUntil) })
    }
    return items
}

/*
 * The day header (lwl.java:115-330): today and tomorrow are 'Today' (white)
 * then the weekday and the day number in the primary colour ('Today Tue 10');
 * other days are the locale's weekday and date without the year, in
 * onSurfaceVariant. f: { today, tomorrow, weekdayDate(weekday, day),
 * dayName(date), otherDay(date) }.
 */
function dayHeader(day, today, f) {
    var delta = dayNumber(day) - dayNumber(today)
    if (delta === 0 || delta === 1) {
        return {
            kind: delta === 0 ? "today" : "tomorrow",
            lead: delta === 0 ? f.today : f.tomorrow,
            date: f.weekdayDate(f.dayName(day), day.getDate())
        }
    }
    return { kind: "other", lead: "", date: f.otherDay(day) }
}

/*
 * The time line of a card (lxt.java:320-414). f: { allDay, until (with %1),
 * time(date), range(start, end) }.
 */
function timeLine(item, f) {
    if (item.allDay)
        return f.allDay
    var start = item.start, end = item.end
    if (item.dayCount === 1)
        return f.range(start, end)
    if (item.dayIndex === 1)
        return isMidnight(start) ? f.allDay : f.time(start)
    if (item.dayIndex !== item.dayCount)
        return f.allDay
    if (end && isMidnight(end))
        return f.allDay
    return format(f.until, [f.time(end)])
}

/* The title of a card: '(No title)' when empty, '(Day 2/3)' on a multi-day event */
function title(item, f) {
    var label = String(item.event.displayLabel || "").trim()
    if (label === "")
        label = f.noTitle
    if (item.dayCount > 1)
        return format(f.multiDay, [label, item.dayIndex, item.dayCount])
    return label
}

/* ---- the phone's extras (X-EOS-* properties and reminders) from the event's iCalendar ---- */

function unfold(text) {
    return String(text || "").replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
}

function unescapeText(s) {
    return s.replace(/\\([nN,;\\])/g, function(m, c) { return c === "n" || c === "N" ? "\n" : c })
}

// 'X-EOS-COLOR;X-PARAM="a:b":ff3fa9f5' -> { name: 'X-EOS-COLOR', params: ..., value: 'ff3fa9f5' }
function splitLine(line) {
    var quoted = false, nameEnd = -1, colon = -1
    for (var i = 0; i < line.length; i++) {
        var c = line[i]
        if (c === '"')
            quoted = !quoted
        else if (!quoted && c === ";" && nameEnd < 0)
            nameEnd = i
        else if (!quoted && c === ":") {
            colon = i
            break
        }
    }
    if (colon < 0)
        return null
    var name = line.substring(0, nameEnd >= 0 ? nameEnd : colon).toUpperCase()
    var params = nameEnd >= 0 ? line.substring(nameEnd + 1, colon).toUpperCase() : ""
    return { name: name, params: params, value: line.substring(colon + 1) }
}

// "aarrggbb" ("rrggbb" is opaque); "" when it is no colour
function normalizeColor(text) {
    var t = String(text || "").trim().replace(/^#/, "").toLowerCase()
    if (/^[0-9a-f]{6}$/.test(t))
        return "ff" + t
    return /^[0-9a-f]{8}$/.test(t) ? t : ""
}

// "-PT10M" -> minutes before the start (10); "PT5M" -> -5; null for anything else
function triggerMinutes(value) {
    var m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(String(value).trim())
    if (!m)
        return null
    var secs = (parseInt(m[2] || 0, 10) * 7 + parseInt(m[3] || 0, 10)) * 86400
             + parseInt(m[4] || 0, 10) * 3600 + parseInt(m[5] || 0, 10) * 60 + parseInt(m[6] || 0, 10)
    var minutes = Math.round(secs / 60)
    return m[1] === "-" ? minutes : -minutes
}

/*
 * What asteroid-btsyncd stored on the event (calendarservice.h): the event
 * colour X-EOS-COLOR, the user's response X-EOS-RSVP (0 needs action, 1
 * accepted, 2 tentative, 3 declined, -1 unknown), X-EOS-ORGANIZER,
 * X-EOS-CALENDAR (the phone's calendar name), X-EOS-EVENTID, and the
 * reminders (display alarms with a start offset).
 */
function parseExtras(ics) {
    var out = { color: "", response: -1, organizer: "", calendar: "", eventId: "", reminders: [] }
    var inEvent = false, inAlarm = false, alarmMinutes = null, alarmEnd = false
    var lines = unfold(ics)
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        var p = splitLine(line)
        if (!p)
            continue
        if (p.name === "BEGIN") {
            var kind = p.value.toUpperCase()
            if (kind === "VEVENT") inEvent = true
            if (kind === "VALARM" && inEvent) { inAlarm = true; alarmMinutes = null; alarmEnd = false }
            continue
        }
        if (p.name === "END") {
            var k = p.value.toUpperCase()
            if (k === "VALARM" && inAlarm) {
                inAlarm = false
                if (alarmMinutes !== null && !alarmEnd && out.reminders.indexOf(alarmMinutes) < 0)
                    out.reminders.push(alarmMinutes)
            } else if (k === "VEVENT") {
                inEvent = false
            }
            continue
        }
        if (!inEvent)
            continue
        if (inAlarm) {
            if (p.name === "TRIGGER" && p.params.indexOf("VALUE=DATE-TIME") < 0) {
                alarmMinutes = triggerMinutes(p.value)
                alarmEnd = p.params.indexOf("RELATED=END") >= 0
            }
            continue
        }
        switch (p.name) {
        case "X-EOS-COLOR": out.color = normalizeColor(p.value); break
        case "X-EOS-RSVP":
            var r = parseInt(p.value, 10)
            out.response = r >= 0 && r <= 3 ? r : -1
            break
        case "X-EOS-ORGANIZER": out.organizer = unescapeText(p.value); break
        case "X-EOS-CALENDAR": out.calendar = unescapeText(p.value); break
        case "X-EOS-EVENTID": out.eventId = unescapeText(p.value); break
        }
    }
    return out
}

/* The card colour (lxv.java:222-243): the event colour (its alpha ignored),
   else the notebook's, else the Phone notebook's blue; "#rrggbb" */
function eventColor(extras, notebookColor) {
    var c = extras && extras.color ? extras.color : ""
    if (c !== "")
        return "#" + c.substring(2)
    var n = normalizeColor(notebookColor)
    return n !== "" ? "#" + n.substring(2) : defaultColor
}

/* ---- reminders (lsn.java:358-413, mna.java) ---- */

/* 90 -> '1 hour 30 minutes': weeks, days, hours, minutes, each only when present */
function durationText(minutes, f) {
    var parts = []
    var units = [[10080, f.weeks], [1440, f.days], [60, f.hours], [1, f.minutes]]
    var left = minutes
    for (var i = 0; i < units.length; i++) {
        if (left >= units[i][0]) {
            var n = Math.floor(left / units[i][0])
            parts.push(units[i][1](n))
            left -= n * units[i][0]
        }
    }
    return parts.join(" ")
}

/*
 * One reminder line. A timed event: '10 minutes before', 'At time of
 * event', '5 minutes after the start'. An all-day event: 'On the day at
 * 9:00 AM', 'The day before at 5:00 PM', '2 days before at 9:00 AM' (the
 * time is the start of the day minus the offset).
 * f: { weeks(n), days(n), hours(n), minutes(n), before (%1), after (%1),
 * atTime, onTheDay (%1), dayBefore (%1), daysBefore (%1 %2), time(date) }.
 */
function reminderLabel(minutes, allDay, startDay, f) {
    if (!allDay) {
        if (minutes === 0)
            return f.atTime
        if (minutes < 0)
            return format(f.after, [durationText(-minutes, f)])
        return format(f.before, [durationText(minutes, f)])
    }
    var midnight = startOfDay(startDay)
    var at = f.time(new Date(midnight.getTime() - minutes * 60000))
    if (minutes <= 0)
        return format(f.onTheDay, [at])
    if (minutes <= 1440)
        return format(f.dayBefore, [at])
    var shifted = minutes + 1440
    var amount, unit
    if (shifted <= 10080 || shifted % 10080 >= 1440) {
        amount = Math.floor(shifted / 1440)
        unit = f.days(amount)
    } else {
        amount = Math.floor(shifted / 10080)
        unit = f.weeks(amount)
    }
    return format(f.daysBefore, [unit, at])
}

/* ---- the details screen ---- */

/* A single day: 'Today', 'Tomorrow' or the date; several: the first - the last date */
function dateLine(item, today, f) {
    var s = span(item.event.allDay, item.start, item.end)
    if (s.count > 1)
        return f.dateRange(s.first, s.last)
    var delta = dayNumber(s.first) - dayNumber(today)
    if (delta === 0)
        return f.today
    if (delta === 1)
        return f.tomorrow
    return f.otherDay(s.first)
}

/* The time line of the details: 'All day', the range, or both ends of a multi-day event */
function detailTime(event, start, end, f) {
    var s = span(event.allDay, start, end)
    if (allDayLike(event.allDay, start, end))
        return f.allDay
    if (s.count === 1)
        return f.range(start, end)
    return f.time(start) + " – " + f.time(end)
}

/* Watch-local events can be deleted; the phone's only when Gadgetbridge can do it there too */
function canDelete(event, phoneCanDelete) {
    if (event.readOnly)
        return false
    return event.calendarUid !== phoneNotebookUid || phoneCanDelete === true
}

/* The rows of the details screen in stock order (lmg.java:118-248).
   phone: { rsvp, open } (booleans) adds the phone's two segments between the calendar name and 'Delete event' */
function detailRows(event, extras, reminders, deletable, phone) {
    var rows = ["title", "when"]
    if (String(event.location || "").trim() !== "")
        rows.push("location")
    if (String(event.description || "").trim() !== "")
        rows.push("description")
    if (reminders.length > 0)
        rows.push("reminders")
    rows.push("calendar")
    if (phone && phone.rsvp)
        rows.push("rsvp")
    if (phone && phone.open)
        rows.push("openPhone")
    if (deletable)
        rows.push("delete")
    return rows
}

/* ---- another app's request (CR-36): dconf /org/asteroidos/calendar/ui/open ---- */

/* How old a request may be, and how far in the future (clock differences), in ms */
var requestMaxAge = 60000
var requestMaxFuture = 5000

/*
 * "event:<startMs>@<nowMs>" -> { route: "event", start: <startMs>, at: <nowMs> }, the part before the LAST "@" being the route.
 * null for an empty value, a request older than 60 s or more than 5 s in the future, and a route this app does
 * not know. now: Date.now().
 */
function parseOpenRequest(value, now) {
    var text = String(value === undefined || value === null ? "" : value)
    var at = text.lastIndexOf("@")
    if (at < 0)
        return null
    var stamp = text.substring(at + 1)
    if (!/^\d+$/.test(stamp))
        return null
    var age = now - Number(stamp)
    if (!(age >= -requestMaxFuture && age <= requestMaxAge))
        return null
    var m = /^event:(\d+)$/.exec(text.substring(0, at))
    if (!m)
        return null
    var start = Number(m[1])
    return start > 0 && isFinite(start) ? { route: "event", start: start, at: Number(stamp) } : null
}

/*
 * The agenda item for an event that starts at startMs (the launcher's tile writes the occurrence's start). Several
 * rows can match (a multi-day event has one per day, several events can start together): the row of today first,
 * else the first in list order. items: buildItems(); null when none.
 */
function findEventItem(items, startMs, today) {
    var first = null
    var day = dayNumber(today)
    for (var i = 0; i < items.length; i++) {
        var it = items[i]
        if (it.kind !== "event" || !it.start || it.start.getTime() !== startMs)
            continue
        if (dayNumber(it.day) === day)
            return it
        if (first === null)
            first = it
    }
    return first
}

/* ---- the phone's side: RSVP and 'Open on phone' (relay acts rsvp and open) ---- */

/* The phone's own id of the event (X-EOS-EVENTID, what the watch sends back in rsvp and open); 0 when none */
function phoneEventId(extras) {
    var t = String(extras && extras.eventId !== undefined ? extras.eventId : "").trim()
    if (!/^\d+$/.test(t))
        return 0
    var n = Number(t)
    return n > 0 && n <= 9007199254740991 ? n : 0
}

/* RSVP is offered for the phone's events the phone said a response for (X-EOS-RSVP 0..3) */
function canRespond(event, extras) {
    return !!event && event.calendarUid === phoneNotebookUid && phoneEventId(extras) > 0
        && extras.response >= 0 && extras.response <= 3
}

/* 'Open on phone' is offered for the phone's events */
function canOpenOnPhone(event, extras) {
    return !!event && event.calendarUid === phoneNotebookUid && phoneEventId(extras) > 0
}

/* The answers: Yes 1, Maybe 2, No 3 (gb AsteroidOSPhoneData.rsvp) */
var rsvpAnswers = [1, 2, 3]

/* The relay act of an answer: {"a":"rsvp","id":<phone event id>,"st":1|2|3} */
function rsvpAct(extras, st) {
    return { a: "rsvp", id: phoneEventId(extras), st: st }
}

/* The relay act that opens the event on the phone: b is the start in SECONDS (gb multiplies it by 1000) */
function openEventAct(extras, start) {
    var act = { a: "open", w: "event", id: phoneEventId(extras) }
    var ms = start ? start.getTime() : 0
    if (ms > 0)
        act.b = Math.floor(ms / 1000)
    return act
}

/* The relay act of 'View more on phone': the phone's calendar (gb: {"a":"open","w":"calendar"}) */
function openCalendarAct() {
    return { a: "open", w: "calendar" }
}
