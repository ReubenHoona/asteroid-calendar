// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// FP-A2 (gaps 34, 38): the phone's side of the details and the agenda, over asteroid-btsyncd's assistant
// relay (src/PhoneRelay.qml). The Nemo.DBus double logs every call: the bus, service, object path,
// interface, method and the typed arguments are checked exactly against btsyncd (assistantservice.h:
// Actions() -> as, Act(u id, s json) -> b, signal ActResult(u id, s json); phonestatusservice.h:
// Connected() -> b), and the acts against Gadgetbridge (AsteroidOSPhoneData.rsvp and openTarget, the
// acts rsvp and open of AsteroidOSPhoneDataActions): {"a":"rsvp","id":<phone event id>,"st":1|2|3},
// {"a":"open","w":"event","id":<phone event id>,"b":<start in seconds>}, {"a":"open","w":"calendar"}.
// Then what the screen shows for an answer, a failure, no phone, an old Gadgetbridge and no answer at
// all. Nothing is asked before a tap.
import QtQuick
import QtTest
import Nemo.Configuration
import CalendarTest
import org.asteroid.controls
import "../../src" as App
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
    Component { id: relayC; App.PhoneRelay { } }
    Component { id: detailsC; App.EventDetails { width: 384; height: 384 } }
    Component { id: agendaC; App.AgendaPage { width: 384; height: 384 } }

    TestCase {
        id: tc
        name: "CalendarPhone"
        when: windowShown

        readonly property string svc: "org.asteroidos.btsyncd"
        readonly property string apath: "/org/asteroidos/btsyncd/assistant"
        readonly property string aiface: "org.asteroidos.btsyncd.Assistant"
        readonly property string ppath: "/org/asteroidos/btsyncd/phone"
        readonly property string piface: "org.asteroidos.btsyncd.Phone"
        readonly property date today: new Date(2026, 10, 10)
        // Tue 10 Nov 2026 14:30 local, the event's start
        readonly property date start: new Date(2026, 10, 10, 14, 30)

        function init() {
            ConfStore.reset()
            Bus.reset()
            ConfStore.set("/org/asteroidos/settings/use-12h-format", true)
            TimeFormat.locale = Qt.locale("en_US")
            Notebooks.map = ({})
        }
        property var pages: []
        // the pages go before the events they show (those are temporary objects, destroyed after cleanup)
        function cleanup() {
            for (var i = pages.length - 1; i >= 0; i--)
                pages[i].destroy()
            pages = []
            wait(20)
        }
        function ics(rsvp, id) {
            var l = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nX-EOS-COLOR:ff3fa9f5\r\nX-EOS-CALENDAR:Test Calendar\r\n"
            if (rsvp !== null)
                l += "X-EOS-RSVP:" + rsvp + "\r\n"
            if (id !== null)
                l += "X-EOS-EVENTID:" + id + "\r\n"
            return l + "END:VEVENT\r\nEND:VCALENDAR\r\n"
        }
        // the details of a phone event (X-EOS-RSVP rsvp, X-EOS-EVENTID id; null leaves it out)
        function details(rsvp, id, uid) {
            var ev = createTemporaryObject(eventC, tc, { displayLabel: "Test Event", instanceId: "t1",
                                                         calendarUid: uid === undefined ? Logic.phoneNotebookUid : uid,
                                                         ics: ics(rsvp, id) })
            var item = { event: ev, start: tc.start, end: new Date(tc.start.getTime() + 3600000), allDay: false,
                         dayIndex: 1, dayCount: 1, day: tc.today }
            var p = detailsC.createObject(host, { item: item, today: tc.today, pop: function () { } })
            verify(p !== null)
            pages = pages.concat([p])
            p.list.cacheBuffer = 20000
            wait(300)
            return p
        }
        function agenda(phoneSynced) {
            var p = createTemporaryObject(agendaC, host, { occurrences: [], today: tc.today,
                                                         phoneSynced: phoneSynced === undefined ? true : phoneSynced })
            verify(p !== null)
            p.list.cacheBuffer = 20000
            wait(300)
            return p
        }
        function findAll(item, name, out) {
            out = out || []
            if (!item)
                return out
            if (item.objectName === name)
                out.push(item)
            var kids = item.children || []
            for (var i = 0; i < kids.length; i++)
                findAll(kids[i], name, out)
            if (item.contentItem && kids.indexOf(item.contentItem) < 0)
                findAll(item.contentItem, name, out)
            return out
        }
        function one(p, name) {
            var l = findAll(p, name)
            compare(l.length, 1, "one " + name)
            return l[0]
        }
        // a finger on the control: the list scrolled to it first
        function press(p, name) {
            var b = one(p, name)
            verify(b.visible && b.enabled, name + " can be pressed")
            var y = b.mapToItem(p.list.contentItem, 0, 0).y
            p.list.contentY = y + b.height / 2 - p.list.height / 2
            wait(50)
            var pt = b.mapToItem(screen, b.width / 2, b.height / 2)
            verify(pt.y > 40 && pt.y < 344, name + " on the screen: " + pt.y)
            mouseClick(screen, pt.x, pt.y)
        }
        // the acts passed to the phone so far (Bus.acts is a new array after each)
        function actsAre(n) {
            tryVerify(function () { return Bus.acts.length === n }, 2000, n + " acts sent")
        }
        function acts() {
            return Bus.acts.map(function (a) { return a.json })
        }
        // the relay's interfaces as the double saw them
        function ifaces() {
            return Bus.objects.map(function (o) { return o.bus + " " + o.service + " " + o.path + " " + o.iface + " " + o.signalsEnabled })
        }

        // ------------------------------------------------------------------ the relay

        function test_relayInterfaces() {
            var r = createTemporaryObject(relayC, tc)
            verify(r !== null)
            compare(ifaces().sort().join(" | "),
                    "1 org.asteroidos.btsyncd /org/asteroidos/btsyncd/assistant org.asteroidos.btsyncd.Assistant true | "
                    + "1 org.asteroidos.btsyncd /org/asteroidos/btsyncd/phone org.asteroidos.btsyncd.Phone false",
                    "the session bus (DBus.SessionBus = 1); signals on the assistant interface only")
            var a = Bus.objects.filter(function (o) { return o.path === apath })[0]
            compare(typeof a.rcActResult, "function", "Nemo.DBus delivers ActResult to rc + the signal name")
            compare(a.actResult, undefined, "no other spelling")
            compare(Bus.calls.length, 0, "nothing asked until an act")
        }

        function test_actCallShapes() {
            var r = createTemporaryObject(relayC, tc)
            var got = []
            r.act({ a: "rsvp", id: 456, st: 1 }, function (res) { got.push(res) })
            actsAre(1)
            var c = Bus.calls
            compare(c.length, 2, "Actions, then Act")
            compare([c[0].service, c[0].path, c[0].iface, c[0].method, c[0].typed].join(),
                    [svc, apath, aiface, "Actions", true].join())
            compare(JSON.stringify(c[0].args), "[]", "Actions() takes nothing")
            compare([c[1].service, c[1].path, c[1].iface, c[1].method, c[1].typed].join(), [svc, apath, aiface, "Act", true].join())
            compare(c[1].args.length, 2)
            compare(c[1].args[0].type, "u", "the id is a D-Bus uint32")
            verify(Number.isInteger(c[1].args[0].value) && c[1].args[0].value > 0 && c[1].args[0].value < 0x40000000,
                   "below btsyncd's own ids (InternalIdBase): " + c[1].args[0].value)
            compare(c[1].args[1].type, "s")
            compare(c[1].args[1].value, '{"a":"rsvp","id":456,"st":1}', "the act as JSON text")
            compare(Bus.callsOf("Connected").length, 0, "the phone lists the act: no Connected()")
            compare(got.length, 0, "no result before the phone's")
            // the phone's answer (ActResult) reaches the caller once
            verify(Bus.answer({ ok: true, st: 1 }))
            compare(got.length, 1)
            compare(JSON.stringify(got[0]), '{"ok":true,"st":1}')
            Bus.answer({ ok: true, st: 1 })
            compare(got.length, 1, "once")
            // the next act has another id
            r.act({ a: "open", w: "calendar" }, function (res) { got.push(res) })
            actsAre(2)
            verify(Bus.acts[1].id !== Bus.acts[0].id)
        }

        function test_actNoPhone() {
            var r = createTemporaryObject(relayC, tc)
            var got = []
            // btsyncd not there: Actions() fails
            Bus.actions = null
            r.act({ a: "rsvp", id: 456, st: 1 }, function (res) { got.push(res) })
            tryCompare(got, "length", 1, 2000)
            compare(JSON.stringify(got[0]), '{"ok":false,"er":"no-phone"}')
            compare(Bus.callsOf("Act").length, 0, "nothing sent")
            // no phone connected: Actions() is empty, Connected() false
            Bus.actions = []
            Bus.connected = false
            r.act({ a: "rsvp", id: 456, st: 1 }, function (res) { got.push(res) })
            tryCompare(got, "length", 2, 2000)
            compare(got[1].er, "no-phone")
            var pc = Bus.callsOf("Connected")
            compare(pc.length, 1)
            compare([pc[0].service, pc[0].path, pc[0].iface, JSON.stringify(pc[0].args)].join(), [svc, ppath, piface, "[]"].join())
        }

        function test_actOldGadgetbridge() {
            var r = createTemporaryObject(relayC, tc)
            var got = []
            // connected, but its Gadgetbridge does not list the act
            Bus.actions = ["nav", "contacts", "sms"]
            r.act({ a: "open", w: "event", id: 456 }, function (res) { got.push(res) })
            tryCompare(got, "length", 1, 2000)
            compare(JSON.stringify(got[0]), '{"ok":false,"er":"old-app"}')
            compare(Bus.callsOf("Act").length, 0)
        }

        function test_actRefusedOrFailed() {
            var r = createTemporaryObject(relayC, tc)
            var got = []
            Bus.actReply = false
            r.act({ a: "open", w: "calendar" }, function (res) { got.push(res) })
            tryCompare(got, "length", 1, 2000)
            compare(got[0].er, "no-phone", "Act() false: the phone went away")
            Bus.actReply = "error"
            r.act({ a: "open", w: "calendar" }, function (res) { got.push(res) })
            tryCompare(got, "length", 2, 2000)
            compare(got[1].er, "no-phone", "Act() failed")
        }

        function test_actNoAnswer() {
            var r = createTemporaryObject(relayC, tc)
            var got = []
            r.timeoutMs = 150
            r.act({ a: "rsvp", id: 456, st: 2 }, function (res) { got.push(res) })
            actsAre(1)
            wait(50)
            compare(got.length, 0, "still waiting")
            tryCompare(got, "length", 1, 2000)
            compare(JSON.stringify(got[0]), '{"ok":false,"er":"timeout"}')
            // the phone's late answer changes nothing
            Bus.answer({ ok: true, st: 2 })
            wait(50)
            compare(got.length, 1)
            // Act() never answered at all: the same timeout
            Bus.actReply = "none"
            r.act({ a: "rsvp", id: 456, st: 2 }, function (res) { got.push(res) })
            tryCompare(got, "length", 2, 2000)
            compare(got[1].er, "timeout")
        }

        function test_actBadResults() {
            var r = createTemporaryObject(relayC, tc)
            var got = []
            var texts = ["not json", "5", "null", '"text"']
            for (var i = 0; i < texts.length; i++) {
                r.act({ a: "open", w: "calendar" }, function (res) { got.push(res) })
                actsAre(i + 1)
                Bus.answer(texts[i])
                compare(got.length, i + 1)
                compare(JSON.stringify(got[i]), '{"ok":false,"er":"failed"}', texts[i])
            }
        }

        function test_actOtherIds() {
            var r = createTemporaryObject(relayC, tc)
            var a = [], b = []
            r.act({ a: "rsvp", id: 456, st: 1 }, function (res) { a.push(res) })
            r.act({ a: "open", w: "calendar" }, function (res) { b.push(res) })
            actsAre(2)
            // a result for an id the relay did not send (another app's act) is not ours
            Bus.actResult(Bus.acts[0].id + Bus.acts[1].id + 7, { ok: true })
            compare(a.length + b.length, 0)
            // answers out of order reach their own caller
            Bus.actResult(Bus.acts[1].id, { ok: true, how: "started" })
            compare(b.length, 1)
            compare(a.length, 0)
            Bus.actResult(Bus.acts[0].id, { ok: false, er: "not-found" })
            compare(a.length, 1)
            compare(a[0].er, "not-found")
        }

        // ------------------------------------------------------------------ the details' rows

        function test_rowsOfAPhoneEvent() {
            var p = details(0, 456)
            compare(p.rows.join(), "title,when,calendar,rsvp,openPhone", "the phone's two segments after the calendar's name")
            compare(one(p, "calendarLabel").text, "Test Calendar")
            compare(Bus.calls.length, 0, "no D-Bus call while the page only shows")
        }
        function test_rowsWithoutResponse() {
            var p = details(null, 456)
            compare(p.rows.join(), "title,when,calendar,openPhone", "the user is no guest: no RSVP")
            compare(findAll(p, "rsvpSegment").length, 0)
            compare(findAll(p, "openOnPhoneButton").length, 1)
        }
        function test_rowsWithoutPhoneId() {
            compare(details(0, null).rows.join(), "title,when,calendar", "nothing to send back: no phone segments")
        }
        function test_rowsOfAWatchEvent() {
            var p = details(0, 456, "test-notebook")
            compare(p.rows.join(), "title,when,calendar,delete")
            compare(findAll(p, "openOnPhoneButton").length, 0)
            compare(findAll(p, "rsvpSegment").length, 0)
        }

        // ------------------------------------------------------------------ RSVP (weather-calendar-34)

        function test_rsvpChips() {
            var p = details(0, 456)
            compare(one(p, "rsvpLabel").text, "Going?")
            compare(one(p, "rsvpButton1").text, "Yes")
            compare(one(p, "rsvpButton2").text, "Maybe")
            compare(one(p, "rsvpButton3").text, "No")
            compare(one(p, "rsvpButton1").iconName, "ios-checkmark")
            compare(one(p, "changeRsvpButton").visible, false)
            compare(one(p, "rsvpError").visible, false)
            verify(one(p, "rsvpButton1").mapToItem(p, 0, 0).y < one(p, "openOnPhoneButton").mapToItem(p, 0, 0).y,
                   "RSVP above Open on phone")
        }

        function test_rsvpYes() {
            var p = details(0, 456)
            press(p, "rsvpButton1")
            compare(p.rsvpBusy, true)
            actsAre(1)
            compare(acts().join(), '{"a":"rsvp","id":456,"st":1}')
            compare(one(p, "rsvpButton2").enabled, false, "one answer at a time")
            compare(one(p, "rsvpButton1").enabled, false)
            p.respond(2)
            wait(50)
            compare(Bus.acts.length, 1, "no second act while one is on its way")
            Bus.answer({ ok: true, st: 1 })
            compare(p.rsvpBusy, false)
            compare(p.response, 1)
            wait(50)
            compare(one(p, "rsvpLabel").text, "Responded Yes")
            compare(one(p, "changeRsvpButton").visible, true)
            compare(one(p, "changeRsvpButton").text, "Change RSVP")
            compare(findAll(p, "rsvpButton1").length, 0, "the chips are gone")
            compare(one(p, "rsvpError").visible, false)
        }

        function test_rsvpChange() {
            var p = details(1, 456)
            compare(one(p, "rsvpLabel").text, "Responded Yes", "the phone's own answer")
            press(p, "changeRsvpButton")
            wait(50)
            compare(one(p, "rsvpLabel").text, "Going?")
            press(p, "rsvpButton3")
            actsAre(1)
            compare(acts().join(), '{"a":"rsvp","id":456,"st":3}')
            Bus.answer({ ok: true, st: 3 })
            wait(50)
            compare(one(p, "rsvpLabel").text, "Responded No")
            compare(p.changing, false)
        }

        function test_rsvpMaybeFromThePhone() {
            var p = details(2, 456)
            compare(one(p, "rsvpLabel").text, "Responded Maybe")
            compare(findAll(p, "rsvpButton2").length, 0)
        }

        function test_rsvpFails() {
            var p = details(0, 456)
            press(p, "rsvpButton1")
            actsAre(1)
            // Gadgetbridge without WRITE_CALENDAR
            Bus.answer({ ok: false, er: "no-permission", perm: "calendar" })
            wait(50)
            compare(p.response, 0, "still needs action")
            compare(one(p, "rsvpError").visible, true)
            compare(one(p, "rsvpError").text, "Response could not be updated.")
            compare(one(p, "rsvpError").color.toString(), Theme.color.error.toString())
            compare(one(p, "rsvpLabel").text, "Going?")
            // tried again: the message goes with the new try
            press(p, "rsvpButton1")
            compare(one(p, "rsvpError").visible, false)
            actsAre(2)
            Bus.answer({ ok: true, st: 1 })
            wait(50)
            compare(one(p, "rsvpLabel").text, "Responded Yes")
        }

        function test_rsvpNoPhone() {
            var p = details(0, 456)
            Bus.actions = null
            press(p, "rsvpButton1")
            tryCompare(p, "rsvpFailed", true, 2000)
            compare(Bus.callsOf("Act").length, 0, "nothing sent")
            compare(p.rsvpBusy, false)
            compare(one(p, "rsvpError").visible, true)
        }

        function test_rsvpOldGadgetbridge() {
            var p = details(0, 456)
            Bus.actions = ["nav", "contacts"]
            press(p, "rsvpButton2")
            tryCompare(p, "rsvpFailed", true, 2000)
            compare(Bus.callsOf("Act").length, 0, "the phone does not list rsvp")
            compare(Bus.callsOf("Connected").length, 1)
        }

        function test_rsvpNoAnswer() {
            var p = details(0, 456)
            p.relay.timeoutMs = 150
            press(p, "rsvpButton1")
            compare(p.rsvpBusy, true)
            tryCompare(p, "rsvpFailed", true, 2000)
            compare(p.rsvpBusy, false)
            compare(one(p, "rsvpError").visible, true)
            // a late answer changes nothing
            Bus.answer({ ok: true, st: 1 })
            wait(50)
            compare(p.response, 0)
            compare(one(p, "rsvpLabel").text, "Going?")
        }

        // ------------------------------------------------------------------ Open on phone (weather-calendar-38)

        function test_openOnPhone() {
            var p = details(0, 456)
            var b = one(p, "openOnPhoneButton")
            compare(b.text, "Open on phone")
            compare(b.iconName, "ios-phone-portrait")
            compare(one(p, "openStatus").visible, false)
            press(p, "openOnPhoneButton")
            compare(p.openState, "busy")
            compare(one(p, "openOnPhoneButton").enabled, false, "one at a time")
            actsAre(1)
            var a = Bus.acts[0].act
            compare(Object.keys(a).sort().join(), "a,b,id,w")
            compare(a.a, "open")
            compare(a.w, "event")
            compare(a.id, 456)
            compare(a.b, Math.floor(tc.start.getTime() / 1000), "the occurrence's start in seconds (gb multiplies by 1000)")
            compare(Bus.acts[0].json, '{"a":"open","w":"event","id":456,"b":' + Math.floor(tc.start.getTime() / 1000) + '}')
            Bus.answer({ ok: true, how: "notification" })
            wait(50)
            compare(p.openState, "ok")
            compare(one(p, "openStatus").visible, true)
            compare(one(p, "openStatus").text, "Opened on your phone")
            compare(one(p, "openStatus").color.toString(), Theme.color.onSurfaceVariant.toString())
            compare(one(p, "openOnPhoneButton").enabled, true, "can be pressed again")
        }

        function test_openOnPhoneFails() {
            var p = details(null, 456)
            press(p, "openOnPhoneButton")
            actsAre(1)
            Bus.answer({ ok: false, er: "no-app" })
            wait(50)
            compare(p.openState, "failed")
            compare(one(p, "openStatus").visible, true)
            compare(one(p, "openStatus").text, "Could not open on your phone")
            compare(one(p, "openStatus").color.toString(), Theme.color.error.toString())
        }

        function test_openOnPhoneNoPhoneOrNoAnswer() {
            var p = details(null, 456)
            Bus.actions = null
            press(p, "openOnPhoneButton")
            tryCompare(p, "openState", "failed", 2000)
            compare(Bus.callsOf("Act").length, 0)
            // no answer from the phone
            Bus.actions = Bus.fullActions.slice()
            p.relay.timeoutMs = 150
            press(p, "openOnPhoneButton")
            compare(p.openState, "busy")
            actsAre(1)
            tryCompare(p, "openState", "failed", 2000)
            compare(one(p, "openStatus").text, "Could not open on your phone")
        }

        // ------------------------------------------------------------------ View more on phone (the agenda's last row)

        function test_viewMoreOnPhone() {
            var p = agenda()
            var b = one(p, "viewMoreButton")
            compare(b.text, "View more on phone")
            compare(one(p, "viewMoreError").visible, false)
            compare(Bus.calls.length, 0, "nothing asked before the tap")
            press(p, "viewMoreButton")
            compare(p.viewMoreState, "busy")
            actsAre(1)
            compare(acts().join(), '{"a":"open","w":"calendar"}')
            Bus.answer({ ok: true, how: "started" })
            compare(p.viewMoreState, "", "the phone shows its calendar; the watch says nothing")
            compare(one(p, "viewMoreError").visible, false)
            // a failure says so
            press(p, "viewMoreButton")
            actsAre(2)
            Bus.answer({ ok: false, er: "no-app" })
            wait(50)
            compare(p.viewMoreState, "failed")
            compare(one(p, "viewMoreError").visible, true)
            compare(one(p, "viewMoreError").text, "Could not open on your phone")
        }

        function test_noViewMoreBeforeTheFirstSync() {
            var p = agenda(false)
            compare(findAll(p, "viewMoreButton").length, 0, "no phone yet: the hint only")
            compare(Bus.calls.length, 0)
        }
    }
}
