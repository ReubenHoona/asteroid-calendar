// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The open request of contract row CR-36 (FP-A2, weather-calendar-37) in src/main.qml: the launcher's
// Agenda tile and the next event complication write dconf /org/asteroidos/calendar/ui/open =
// "event:<startMs>@<nowMs>" before they start or raise the app. The part before the LAST "@" is the
// route; the app reads the key at start and on every change, ignores a request older than 60 s or more
// than 5 s in the future, ignores a repeat of the request it handled last, clears the key ("") once it
// has read it, and opens the details of the agenda row whose occurrence starts at <startMs>. The model
// fills a moment after the app starts, so a request waits for its row (for 60 s from its stamp at
// most). The stamps are taken from the clock (the app compares them with Date.now()).
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
        name: "CalendarOpenRequest"
        when: windowShown

        readonly property string key: "/org/asteroidos/calendar/ui/open"
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
        function start() {
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            compare(c.status, Component.Ready, c.errorString())
            app = c.createObject(host, { width: 384, height: 384 })
            verify(app !== null)
            wait(50)
            return app
        }
        function day(n, h, m) {
            var t = Logic.startOfDay(new Date())
            return new Date(t.getFullYear(), t.getMonth(), t.getDate() + n, h || 0, m || 0)
        }
        function occ(title, n, h, m, minutes) {
            var s = day(n, h, m)
            var e = createTemporaryObject(eventC, tc, { displayLabel: title, instanceId: title + n, calendarUid: "test-notebook" })
            return { event: e, startTime: s, endTime: new Date(s.getTime() + minutes * 60000) }
        }
        // what the launcher writes: "event:<startMs>@<nowMs>", the stamp offsetMs from now
        function request(o, offsetMs) {
            return "event:" + o.startTime.getTime() + "@" + (Date.now() + (offsetMs || 0))
        }
        function load(rows) {
            app.model.setRows(rows)
            tryVerify(function () { return app.occurrences.length === rows.length }, 2000)
        }
        function shown() {
            return app.stack.layers.length === 1 ? app.stack.currentLayer : null
        }
        function titleShown() {
            var d = shown()
            return d ? d.item.event.displayLabel : ""
        }
        // the app read the request: the key is "" again, written by the app
        function cleared(n) {
            tryVerify(function () { return ConfStore.get(key) === "" }, 2000, "the key is cleared")
            compare(ConfStore.writesOf(key).length, n === undefined ? 1 : n, "the app wrote the key")
            compare(ConfStore.writesOf(key).every(function (v) { return v === "" }), true, "only \"\"")
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

        function test_atStart() {
            // the tile wrote the request, then started the app; the model fills a moment later
            var rows = [occ("Test Event A", 0, 9, 0, 30), occ("Test Event B", 2, 15, 0, 45)]
            ConfStore.set(key, request(rows[1]))
            start()
            cleared()
            compare(app.stack.layers.length, 0, "the agenda until the model has the row")
            compare(app.pendingStart, rows[1].startTime.getTime(), "waiting for its row")
            load(rows)
            tryCompare(app.stack.layers, "length", 1, 2000)
            compare(titleShown(), "Test Event B", "that event's details")
            var d = shown()
            verify(d.rows !== undefined && d.rows[0] === "title", "the details page")
            compare(d.item.start.getTime(), rows[1].startTime.getTime())
            compare(d.titleText, "Test Event B")
            compare(app.pendingStart, -1, "done")
            // back: the agenda under it
            d.pop()
            tryCompare(app.stack.layers, "length", 0, 3000)
            compare(app.stack.firstPageItem.items[1].event.displayLabel, "Test Event A")
        }

        function test_whileOpen() {
            var rows = [occ("Test Event A", 0, 9, 0, 30), occ("Test Event B", 2, 15, 0, 45)]
            start()
            load(rows)
            compare(app.stack.layers.length, 0)
            ConfStore.set(key, request(rows[0]))
            tryCompare(app.stack.layers, "length", 1, 2000)
            compare(titleShown(), "Test Event A")
            cleared()
            // another request while a details page is open: that page goes, the new one is the only one
            ConfStore.set(key, request(rows[1]))
            tryVerify(function () { return titleShown() === "Test Event B" }, 2000)
            compare(app.stack.layers.length, 1, "one details page, over the agenda")
            cleared(2)
        }

        function test_ageLimits() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            ConfStore.set(key, request(rows[0], -61000))
            cleared(1)
            wait(50)
            compare(app.stack.layers.length, 0, "older than 60 s: ignored")
            compare(app.pendingStart, -1)
            ConfStore.set(key, request(rows[0], 6000))
            cleared(2)
            wait(50)
            compare(app.stack.layers.length, 0, "more than 5 s in the future: ignored")
            ConfStore.set(key, request(rows[0], -58000))
            tryCompare(app.stack.layers, "length", 1, 2000)
            cleared(3)
            app.stack.pop(app.stack.currentLayer)
            ConfStore.set(key, request(rows[0], 4000))
            tryCompare(app.stack.layers, "length", 1, 2000, "4 s ahead (another clock): read")
            cleared(4)
        }

        function test_oldAtStart() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            ConfStore.set(key, request(rows[0], -120000))
            start()
            cleared()
            load(rows)
            wait(100)
            compare(app.stack.layers.length, 0, "a request from two minutes ago does not open anything")
        }

        function test_repeatIgnored() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            var r = request(rows[0])
            ConfStore.set(key, r)
            tryCompare(app.stack.layers, "length", 1, 2000)
            cleared(1)
            // the user goes back to the agenda; the same request comes again (the same value written once more)
            app.stack.pop(app.stack.currentLayer)
            compare(app.stack.layers.length, 0)
            ConfStore.set(key, r)
            cleared(2)
            wait(100)
            compare(app.stack.layers.length, 0, "a repeat of the request handled last is ignored")
            compare(app.pendingStart, -1)
            // a new request for the same event (a new stamp) is read
            ConfStore.set(key, "event:" + rows[0].startTime.getTime() + "@" + (Date.now() + 1))
            tryCompare(app.stack.layers, "length", 1, 2000)
            cleared(3)
        }

        function test_routeHoldsAnAt() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            var s = rows[0].startTime.getTime()
            // the route is what is before the LAST "@": "event:<ms>@1" is no route of this app
            ConfStore.set(key, "event:" + s + "@1@" + Date.now())
            cleared(1)
            wait(50)
            compare(app.stack.layers.length, 0, "route event:<ms>@1: ignored")
            // the stamp is the part after the last "@" (here 1 ms after the epoch)
            ConfStore.set(key, "event:" + s + "@" + Date.now() + "@1")
            cleared(2)
            wait(50)
            compare(app.stack.layers.length, 0, "stamp 1: too old")
        }

        function test_unknownRouteAndValues() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            ConfStore.set(key, "alarm:3@" + Date.now())
            cleared(1)
            ConfStore.set(key, "event:" + rows[0].startTime.getTime())
            cleared(2)
            ConfStore.set(key, 12345)
            cleared(3)
            wait(50)
            compare(app.stack.layers.length, 0, "another app's route, no stamp, a number: nothing opens")
            // "" itself is not written back
            ConfStore.set(key, "")
            wait(50)
            compare(ConfStore.writesOf(key).length, 3)
        }

        function test_noMatchingEvent() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            // no row starts then: the agenda stays, the request waits
            var late = occ("Test Late", 1, 10, 0, 30)
            ConfStore.set(key, request(late))
            cleared()
            wait(100)
            compare(app.stack.layers.length, 0, "no such event: the agenda")
            compare(app.pendingStart, late.startTime.getTime())
            // the row arrives within the minute (the phone's sync was on its way): it opens
            load([rows[0], late])
            tryCompare(app.stack.layers, "length", 1, 2000)
            compare(titleShown(), "Test Late")
        }

        function test_noMatchExpires() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            var late = occ("Test Late", 1, 10, 0, 30)
            // stamped 59 s ago: read now, but past 60 s by the time its row comes
            ConfStore.set(key, request(late, -59000))
            cleared()
            compare(app.pendingStart, late.startTime.getTime())
            wait(1500)
            load([rows[0], late])
            wait(100)
            compare(app.stack.layers.length, 0, "a row that comes after the minute does not open")
            compare(app.pendingStart, -1, "the request is dropped")
        }

        function test_tapDropsPending() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            var late = occ("Test Late", 1, 10, 0, 30)
            ConfStore.set(key, request(late))
            cleared()
            compare(app.pendingStart, late.startTime.getTime(), "waiting for the row")
            // the user taps the event that is there: the request is dropped, the late row does not take over
            var page = app.stack.firstPageItem
            page.list.cacheBuffer = 20000
            wait(100)
            var cards = find(page, function (it) { return it.timeLabel !== undefined && it.card !== undefined && it.item !== undefined })
            compare(cards.length, 1)
            var pt = cards[0].card.mapToItem(screen, cards[0].card.width / 2, cards[0].card.height / 2)
            mouseClick(screen, pt.x, pt.y)
            tryCompare(app.stack.layers, "length", 1, 2000)
            compare(app.pendingStart, -1)
            load([rows[0], late])
            wait(100)
            compare(app.stack.layers.length, 1)
            compare(titleShown(), "Test Event A")
        }

        function test_multiDayOpensTodaysRow() {
            var s = day(-1, 22, 0)
            var e = createTemporaryObject(eventC, tc, { displayLabel: "Test Trip", instanceId: "trip", calendarUid: "test-notebook" })
            start()
            load([{ event: e, startTime: s, endTime: day(2, 11, 0) }])
            ConfStore.set(key, "event:" + s.getTime() + "@" + Date.now())
            tryCompare(app.stack.layers, "length", 1, 2000)
            compare(shown().item.dayIndex, 2, "today is the second day of the trip")
            compare(shown().dateText.indexOf("Today"), -1, "the details give the trip's dates")
        }

        function test_requestTakesToday() {
            var rows = [occ("Test Event A", 0, 9, 0, 30)]
            start()
            load(rows)
            // the app was left open over midnight: the request takes the day again before it looks
            app.today = day(-1)
            ConfStore.set(key, request(rows[0]))
            tryCompare(app.stack.layers, "length", 1, 2000)
            compare(Logic.dayNumber(app.today), Logic.dayNumber(new Date()))
            compare(shown().dateText, "Today")
        }
    }
}
