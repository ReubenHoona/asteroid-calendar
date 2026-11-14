/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import Nemo.DBus

/*
 * The calendar's one link to the phone: asteroid-btsyncd's assistant relay
 * (org.asteroidos.btsyncd.Assistant on the session bus: Actions, Act and the
 * ActResult signal), the way the launcher's AssistantActions and the Messages
 * app do it. It is used for the two acts Gadgetbridge answers for events:
 *
 *   { a: "rsvp", id: <phone event id>, st: 1 | 2 | 3 }              -> { ok, st } | { ok: false, er }
 *   { a: "open", w: "event", id: <phone event id>, b: <start, s> }  -> { ok, how } | { ok: false, er }
 *   { a: "open", w: "calendar" }                                    -> the same
 *
 * Nothing is asked until act() is called (a tap), nothing is polled, and the
 * only timer is one single shot for the answer that is being waited for (M1).
 * The result's `er` is the phone's code, or "no-phone" (no phone connected),
 * "old-app" (the phone's Gadgetbridge does not list the act), "timeout" or "failed".
 */
QtObject {
    id: relay

    /*! The time an answer may take at most, ms (a little above btsyncd's own limit for the act) */
    property int timeoutMs: 25000

    property int _seq: 5000 + Math.floor(Math.random() * 1000000)
    property var _waits: ({})

    /*! Ask the phone for \a json.a; \a cb(result) is called once. */
    function act(json, cb) {
        relayIface.typedCall("Actions", [], function (list) {
            if (list && list.indexOf(json.a) >= 0) {
                relay._send(json, cb)
                return
            }
            // connected but without the act: Gadgetbridge is too old
            phoneIface.typedCall("Connected", [], function (c) {
                cb({ ok: false, er: c === true ? "old-app" : "no-phone" })
            }, function () { cb({ ok: false, er: "no-phone" }) })
        }, function () { cb({ ok: false, er: "no-phone" }) })
    }

    function _send(json, cb) {
        var id = ++relay._seq
        var waits = relay._waits
        waits[id] = { cb: cb, expires: Date.now() + relay.timeoutMs }
        relay._waits = waits
        relay._arm()
        relayIface.typedCall("Act", [{ "type": "u", "value": id }, { "type": "s", "value": JSON.stringify(json) }],
            function (ok) { if (ok !== true) relay._answer(id, { ok: false, er: "no-phone" }) },
            function () { relay._answer(id, { ok: false, er: "no-phone" }) })
    }

    function _answer(id, r) {
        var w = _waits[id]
        if (!w)
            return
        var waits = _waits
        delete waits[id]
        _waits = waits
        _arm()
        w.cb(r)
    }

    function _result(id, json) {
        var r
        try { r = JSON.parse(json) } catch (e) { r = { ok: false, er: "failed" } }
        if (r === null || typeof r !== "object")
            r = { ok: false, er: "failed" }
        _answer(id, r)
    }

    function _arm() {
        var next = -1
        for (var id in _waits) {
            if (next < 0 || _waits[id].expires < next)
                next = _waits[id].expires
        }
        if (next < 0) {
            expiry.stop()
            return
        }
        expiry.interval = Math.max(1, next - Date.now())
        expiry.restart()
    }

    property Timer _expiry: Timer {
        id: expiry
        repeat: false
        onTriggered: {
            var now = Date.now()
            var due = []
            for (var id in relay._waits)
                if (relay._waits[id].expires <= now)
                    due.push(id)
            for (var i = 0; i < due.length; i++)
                relay._answer(due[i], { ok: false, er: "timeout" })
            relay._arm()
        }
    }

    // Nemo.DBus: the handler of a signal is named "rc" + the signal
    property DBusInterface _iface: DBusInterface {
        id: relayIface
        bus: DBus.SessionBus
        service: "org.asteroidos.btsyncd"
        path: "/org/asteroidos/btsyncd/assistant"
        iface: "org.asteroidos.btsyncd.Assistant"
        signalsEnabled: true
        function rcActResult(id: int, json: string) { relay._result(id, json) }
    }
    property DBusInterface _phone: DBusInterface {
        id: phoneIface
        bus: DBus.SessionBus
        service: "org.asteroidos.btsyncd"
        path: "/org/asteroidos/btsyncd/phone"
        iface: "org.asteroidos.btsyncd.Phone"
    }
}
