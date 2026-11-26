// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Pictures of the app for a look against the stock frame (shots/calendar-*.png, the runner's SHOTS
// folder): the whole app (main.qml, the time at the top) on its agenda, the end of the agenda (the
// footer and 'View more on phone'), and a phone event's details from the top and at its phone segments
// (RSVP, 'Open on phone'). Invented events only; the rows are placed relative to the day of the run.
// The checks only make sure something was drawn where the pictures need it.
import QtQuick
import QtTest
import Nemo.Configuration
import CalendarTest
import org.asteroid.controls
import "../../src/CalendarLogic.js" as Logic

Item {
    id: root
    width: 384
    height: 384

    Rectangle { anchors.fill: parent; color: "black" }

    Item {
        id: screen
        width: 384
        height: 384
        clip: true
        Item { id: host; anchors.fill: parent }
        Canvas {
            anchors.fill: parent
            z: 100
            onPaint: {
                var ctx = getContext("2d")
                ctx.fillStyle = "#000000"
                ctx.beginPath()
                ctx.rect(0, 0, width, height)
                ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI, true)
                ctx.fill()
            }
        }
    }

    Component { id: eventC; TestEvent { } }

    TestCase {
        id: tc
        name: "CalendarRender"
        when: windowShown

        property var app: null

        function init() {
            ConfStore.reset()
            Bus.reset()
            ConfStore.set("/org/asteroidos/settings/use-12h-format", true)
            TimeFormat.locale = Qt.locale("en_US")
            var m = {}
            m[Logic.phoneNotebookUid] = { name: "Phone", color: "#3fa9f5" }
            Notebooks.map = m
        }
        function cleanup() {
            if (app)
                app.destroy()
            app = null
            wait(20)
        }
        function day(n, h, m) {
            var t = Logic.startOfDay(new Date())
            return new Date(t.getFullYear(), t.getMonth(), t.getDate() + n, h || 0, m || 0)
        }
        function phoneIcs(rsvp, id, color) {
            return "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nX-EOS-COLOR:" + color + "\r\nX-EOS-CALENDAR:Test Calendar\r\n"
                 + (rsvp !== null ? "X-EOS-RSVP:" + rsvp + "\r\n" : "") + "X-EOS-EVENTID:" + id + "\r\n"
                 + "BEGIN:VALARM\r\nTRIGGER:-PT10M\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
        }
        function row(props, s, e) {
            return { event: createTemporaryObject(eventC, tc, props), startTime: s, endTime: e }
        }
        function start(until) {
            ConfStore.set("/org/asteroidos/calendar/synced-until", Math.floor(until.getTime() / 1000))
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            compare(c.status, Component.Ready, c.errorString())
            app = c.createObject(host, { width: 384, height: 384 })
            verify(app !== null)
            var rows = [
                row({ displayLabel: "Test Planning", instanceId: "r1", calendarUid: Logic.phoneNotebookUid, location: "Test Room",
                      description: "Test notes for the meeting", ics: phoneIcs(0, 456, "ff3fa9f5") }, day(0, 14, 30), day(0, 15, 30)),
                row({ displayLabel: "Test All Day", instanceId: "r2", calendarUid: Logic.phoneNotebookUid, allDay: true,
                      ics: phoneIcs(null, 457, "ff33b679") }, day(0), day(0)),
                row({ displayLabel: "Sample Review", instanceId: "r3", calendarUid: Logic.phoneNotebookUid,
                      ics: phoneIcs(1, 458, "ffe67c73") }, day(1, 9, 0), day(1, 10, 0)),
                row({ displayLabel: "Test Trip", instanceId: "r4", calendarUid: Logic.phoneNotebookUid,
                      ics: phoneIcs(null, 459, "fff6bf26") }, day(1, 18, 0), day(3, 11, 0))
            ]
            app.model.setRows(rows)
            tryVerify(function () { return app.occurrences.length === rows.length }, 2000)
            app.stack.firstPageItem.list.cacheBuffer = 20000
            wait(400)
            return rows
        }
        // a grab of the round screen, saved; true when it has light pixels in the band [y0, y1)
        function shot(name, y0, y1) {
            var img = grabImage(screen)
            img.save("shots/calendar-" + name + ".png")
            var lit = 0
            for (var y = y0; y < y1; y += 4)
                for (var x = 60; x < 324; x += 4) {
                    var c = Qt.color(img.pixel(x, y))
                    if (c.r + c.g + c.b > 1.2)
                        lit++
                }
            return lit
        }

        function test_agenda() {
            start(day(7, 12))
            verify(shot("agenda", 60, 330) > 20, "the agenda drew text")
            var list = app.stack.firstPageItem.list
            list.positionViewAtEnd()
            wait(400)
            verify(shot("agenda-end", 60, 330) > 20, "the end of the agenda drew text")
        }

        function test_details() {
            var rows = start(day(7, 12))
            ConfStore.set("/org/asteroidos/calendar/ui/open", "event:" + rows[0].startTime.getTime() + "@" + Date.now())
            tryCompare(app.stack.layers, "length", 1, 2000)
            var d = app.stack.currentLayer
            d.list.cacheBuffer = 20000
            // the push transition draws through a shader mask while it runs: the picture waits for its end
            tryVerify(function () { return !app.stack.pushing }, 10000, "the push is over")
            wait(300)
            verify(shot("details", 60, 330) > 20, "the details drew text")
            // the phone's segments: 'Going?' with Yes / Maybe / No, then 'Open on phone'
            var y = d.rows.indexOf("rsvp")
            verify(y > 0)
            d.list.positionViewAtIndex(y, ListView.Beginning)
            wait(400)
            verify(shot("details-rsvp", 60, 330) > 20)
            d.list.positionViewAtIndex(d.rows.indexOf("openPhone"), ListView.Center)
            wait(400)
            verify(shot("details-open", 60, 330) > 20)
        }
    }
}
