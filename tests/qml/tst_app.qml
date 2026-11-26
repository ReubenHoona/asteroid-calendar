// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// src/main.qml, the Calendar app, on the doubles of tests/qml/mocks: the frame (black, the time at the
// top), the AgendaModel asked for today to the end of the synced window, the window end read from dconf
// /org/asteroidos/calendar/synced-until (CR-55: unix seconds, 0 = not known) at start and on change,
// the model's rows in the agenda, the empty and never-synced states, a tap to the read-only details,
// back, delete, today taken again, and no editing, month view or day picker. The app takes today from
// the clock, so the rows here are placed relative to the day the test runs.
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
        // the round edge of the watch
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
        name: "CalendarApp"
        when: windowShown

        readonly property string untilKey: "/org/asteroidos/calendar/synced-until"
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
        // the app goes before the events it shows (they are temporary objects, destroyed after cleanup)
        function cleanup() {
            if (app)
                app.destroy()
            app = null
            wait(20)
        }
        // the app, with dconf values that are there before it starts
        function start(conf) {
            for (var k in (conf || {}))
                ConfStore.set(k, conf[k])
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            compare(c.status, Component.Ready, c.errorString())
            app = c.createObject(host, { width: 384, height: 384 })
            verify(app !== null)
            wait(50)
            return app
        }
        function today() {
            return Logic.startOfDay(new Date())
        }
        function day(n, h, m) {
            var t = today()
            return new Date(t.getFullYear(), t.getMonth(), t.getDate() + n, h || 0, m || 0)
        }
        function seconds(d) {
            return Math.floor(d.getTime() / 1000)
        }
        function sameDay(a, b) {
            return Logic.dayNumber(a) === Logic.dayNumber(b)
        }
        function occ(title, n, h, m, minutes, extra) {
            var s = day(n, h, m)
            var props = { displayLabel: title, instanceId: title + n, calendarUid: "test-notebook" }
            for (var k in (extra || {}))
                props[k] = extra[k]
            var e = createTemporaryObject(eventC, tc, props)
            return { event: e, startTime: s, endTime: new Date(s.getTime() + minutes * 60000) }
        }
        function load(rows) {
            app.model.setRows(rows)
            tryVerify(function () { return app.occurrences.length === rows.length }, 2000)
        }
        function agenda() {
            var p = app.stack.firstPageItem
            verify(p && p.items !== undefined, "the agenda page")
            p.list.cacheBuffer = 20000
            return p
        }
        function kinds(page) {
            return page.items.map(function (i) { return i.kind }).join(",")
        }
        function find(item, pred, out) {
            out = out || []
            if (!item)
                return out
            if (pred(item))
                out.push(item)
            var kids = item.children || []
            for (var i = 0; i < kids.length; i++)
                find(kids[i], pred, out)
            if (item.contentItem && kids.indexOf(item.contentItem) < 0)
                find(item.contentItem, pred, out)
            return out
        }
        function cards(page) {
            return find(page, function (it) { return it.timeLabel !== undefined && it.card !== undefined && it.item !== undefined })
        }
        function labelWith(page, part) {
            var l = find(page, function (it) { return it.text !== undefined && it.font !== undefined && it.visible
                                                     && String(it.text).indexOf(part) >= 0 })
            return l.length > 0 ? l[0] : null
        }
        function tap(item) {
            var p = item.mapToItem(screen, item.width / 2, item.height / 2)
            mouseClick(screen, p.x, p.y)
        }
        function fullDate(d) {
            return TimeFormat.date(d, "yMMMd")
        }

        // ------------------------------------------------------------------ the frame

        function test_frame() {
            start()
            // weather-calendar-14: black, the time at the top, no mesh
            compare(app.showTime, true)
            compare(app.backgroundColor.toString(), Theme.color.background.toString())
            compare(app.meshBackground, false)
            compare(app.stack.layers.length, 0, "the agenda only")
            verify(app.stack.firstPageItem !== null)
            verify(sameDay(app.today, new Date()), "today")
            compare(app.today.getHours(), 0)
            compare(app.pendingStart, -1, "no request")
            compare(Bus.calls.length, 0, "nothing asked of the bus at start")
        }

        // ------------------------------------------------------------------ the window (CR-55)

        function test_modelRangeWithoutSync() {
            start()
            verify(sameDay(app.model.startDate, today()), "from today")
            verify(sameDay(app.model.endDate, day(7)), "to today + 7 days while the phone has not said")
            compare(app.syncedUntil, null)
            var p = agenda()
            compare(kinds(p), "header,noEvents")
            verify(labelWith(p, "No events until " + fullDate(day(7))) !== null)
            verify(labelWith(p, "Synced until") === null, "no footer")
        }

        function test_syncedUntilAtStart() {
            var until = day(12, 8, 30)
            start({ "/org/asteroidos/calendar/synced-until": seconds(until) })
            compare(app.syncedUntil.getTime(), seconds(until) * 1000, "unix seconds")
            verify(sameDay(app.model.endDate, until), "the model goes to the stored day")
            verify(sameDay(app.windowEnd, until))
            var p = agenda()
            verify(labelWith(p, "No events until " + fullDate(until)) !== null, "the empty state says the stored end")
            load([occ("Test Event A", 0, 9, 0, 30), occ("Test Event B", 11, 9, 0, 30), occ("Test Event C", 13, 9, 0, 30)])
            wait(50)
            compare(kinds(p), "header,event,spacer,header,event,spacer,footer", "day 13 is after the window; the footer")
            verify(labelWith(p, "Synced until " + fullDate(until)) !== null)
        }

        function test_syncedUntilChanges() {
            start()
            load([occ("Test Event A", 0, 9, 0, 30), occ("Test Event B", 9, 9, 0, 30)])
            var p = agenda()
            compare(kinds(p), "header,event,spacer", "day 9 is after today + 7")
            // btsyncd writes the key at the end of a full sync: the list follows at once
            var until = day(10, 6)
            ConfStore.set(untilKey, seconds(until))
            verify(sameDay(app.model.endDate, until))
            wait(50)
            compare(kinds(p), "header,event,spacer,header,event,spacer,footer")
            // 0 = not known again
            ConfStore.set(untilKey, 0)
            compare(app.syncedUntil, null)
            verify(sameDay(app.model.endDate, day(7)))
            wait(50)
            compare(kinds(p), "header,event,spacer")
            // a negative value is no date
            ConfStore.set(untilKey, -100)
            compare(app.syncedUntil, null)
            // a value as text (a hand-made dconf write)
            ConfStore.set(untilKey, String(seconds(day(3))))
            verify(sameDay(app.model.endDate, day(3)))
            // the key removed: the default 0
            ConfStore.unset(untilKey)
            compare(app.syncedUntil, null)
            verify(sameDay(app.model.endDate, day(7)))
            compare(ConfStore.writesOf(untilKey).length, 0, "the app only reads the key")
        }

        function test_syncedUntilInThePast() {
            var until = day(-3, 12)
            start({ "/org/asteroidos/calendar/synced-until": seconds(until) })
            verify(sameDay(app.model.endDate, today()), "an end in the past: today only")
            load([occ("Test Event A", 0, 9, 0, 30), occ("Test Event B", 1, 9, 0, 30)])
            var p = agenda()
            wait(50)
            compare(kinds(p), "header,event,spacer,footer", "tomorrow is beyond the window; the footer says the stored day")
            verify(labelWith(p, "Synced until " + fullDate(until)) !== null)
        }

        // ------------------------------------------------------------------ the list

        function test_rowsReachTheList() {
            start()
            load([occ("Test Event A", 0, 9, 0, 30), occ("Test Event B", 2, 15, 0, 45)])
            var p = agenda()
            wait(50)
            compare(kinds(p), "header,event,spacer,header,event,spacer")
            compare(p.items[1].event.displayLabel, "Test Event A")
            compare(p.rows[p.rows.length - 1].kind, "viewMore", "the phone has synced: 'View more on phone' last")
            compare(cards(p).length, 2)
            // a row removed by the model
            load([occ("Test Event A", 0, 9, 0, 30)])
            wait(50)
            compare(kinds(p), "header,event,spacer")
            compare(cards(p).length, 1)
        }

        function test_emptyAndNeverSynced() {
            start()
            compare(kinds(agenda()), "header,noEvents", "the Phone notebook exists: no events")
            Notebooks.map = ({})
            wait(50)
            var p = agenda()
            compare(kinds(p), "header,hint", "no Phone notebook: never synced")
            verify(labelWith(p, "Turn on calendar sync on your phone") !== null)
            compare(find(p, function (it) { return it.objectName === "viewMoreButton" }).length, 0, "no 'View more' before a sync")
        }

        function test_tapOpensDetails() {
            start()
            load([occ("Test Event A", 0, 9, 0, 30, { location: "Test Room", description: "Test notes" })])
            var p = agenda()
            wait(100)
            var c = cards(p)
            compare(c.length, 1)
            tap(c[0].card)
            tryCompare(app.stack.layers, "length", 1, 2000)
            var d = app.stack.currentLayer
            verify(d.rows !== undefined, "the details")
            compare(d.item.event.displayLabel, "Test Event A")
            compare(d.rows.join(), "title,when,location,description,calendar,delete")
            compare(d.titleText, "Test Event A")
            compare(d.dateText, "Today")
            verify(sameDay(d.today, today()), "the app's today")
            // back to the agenda (the page's pop is the stack's animated pop)
            d.pop()
            tryCompare(app.stack.layers, "length", 0, 3000)
            compare(app.stack.firstPageItem, p, "the same agenda")
        }

        function test_deleteFromDetails() {
            start()
            var o = occ("Test Event A", 0, 9, 0, 30)
            load([o])
            var items = agenda().items
            app.stack.push(Qt.createComponent(Qt.resolvedUrl("../../src/EventDetails.qml")), { "item": items[1] })
            tryCompare(app.stack.layers, "length", 1, 2000)
            var d = app.stack.currentLayer
            verify(d.deletable)
            d.deleteDialog.open()
            d.deleteDialog.confirmed()
            compare(o.event.deleted, 1, "deleted once")
            tryCompare(app.stack.layers, "length", 0, 3000)
        }

        function test_refreshToday() {
            start()
            var yesterday = day(-1)
            app.today = yesterday
            verify(sameDay(app.model.startDate, yesterday))
            app.refreshToday()
            verify(sameDay(app.today, new Date()), "taken again")
            verify(sameDay(app.model.startDate, today()))
            // the same day: nothing changes (no new query)
            var before = app.model.refreshes
            app.refreshToday()
            compare(app.model.refreshes, before)
            // the agenda shown again takes it too
            app.today = yesterday
            var p = agenda()
            p.visible = false
            p.visible = true
            verify(sameDay(app.today, new Date()))
        }

        function test_noEditingNoPicker() {
            start()
            load([occ("Test Event A", 0, 9, 0, 30)])
            wait(50)
            // weather-calendar-35, Q51: no add button, no month header, no day carousel, no text field
            compare(find(app, function (it) { return it.iconName === "ios-add" }).length, 0)
            compare(find(app, function (it) { return it.orientation === ListView.Horizontal && it.currentIndex !== undefined }).length, 0)
            compare(find(app, function (it) { return it.cursorPosition !== undefined }).length, 0)
        }
    }
}
