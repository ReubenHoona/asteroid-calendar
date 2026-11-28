// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double of the session bus behind the Nemo.DBus double: asteroid-btsyncd's assistant relay
// (org.asteroidos.btsyncd.Assistant on /org/asteroidos/btsyncd/assistant: Actions() -> as,
// Act(u id, s json) -> b and the signal ActResult(u id, s json)) and its phone status
// (org.asteroidos.btsyncd.Phone on /org/asteroidos/btsyncd/phone: Connected() -> b), as
// assistantservice.h and phonestatusservice.h declare them. Any other service, path, interface or
// method is an error, as on the bus. Every call is logged as it was made; the replies come a moment
// later (the real calls are asynchronous). An accepted act gets no ActResult until the test sends
// one (answer(), actResult()): a test that never answers is the phone that never does.
pragma Singleton
import QtQuick

QtObject {
    id: bus

    readonly property string service: "org.asteroidos.btsyncd"
    readonly property string assistantPath: "/org/asteroidos/btsyncd/assistant"
    readonly property string assistantIface: "org.asteroidos.btsyncd.Assistant"
    readonly property string phonePath: "/org/asteroidos/btsyncd/phone"
    readonly property string phoneIface: "org.asteroidos.btsyncd.Phone"
    // what a connected Gadgetbridge with the phone data actions lists (gb AsteroidOSPhoneData.ACTIONS and the base acts)
    readonly property var fullActions: ["nav", "contacts", "sms", "call", "convs", "msgs", "msend", "mread", "rsvp", "open",
                                        "wifipw", "cam", "evdel"]

    // Actions()' reply; null: the call fails (btsyncd is not running)
    property var actions: []
    // Connected()'s reply
    property bool connected: true
    // Act()'s reply: true (passed to the phone), false (refused: the phone is away), "error" (the call fails),
    // "none" (no reply at all)
    property var actReply: true
    // the calls in order: { bus, service, path, iface, method, typed, args (as given), values (plain) }
    property var calls: []
    // the acts that were passed to the phone: { id, json, act (parsed) }
    property var acts: []
    property var objects: []
    property var queue: []

    function reset() {
        actions = fullActions.slice()
        connected = true
        actReply = true
        calls = []
        acts = []
        queue = []
    }

    function register(o) {
        objects = objects.concat([o])
    }
    function unregister(o) {
        objects = objects.filter(function (x) { return x !== o })
    }

    function call(o, method, args, callback, errorCallback, typed) {
        var list = args === undefined || args === null ? [] : (Array.isArray(args) ? args : [args])
        var given = JSON.parse(JSON.stringify(list))
        var values = given.map(function (a) { return a !== null && typeof a === "object" && "value" in a ? a.value : a })
        calls = calls.concat([{ bus: o.bus, service: o.service, path: o.path, iface: o.iface, method: method, typed: typed,
                                args: given, values: values }])
        var r = reply(o, method, values)
        if (r !== null) {
            queue.push({ obj: o, r: r, callback: callback, errorCallback: errorCallback })
            deliver.restart()
        }
        return true
    }

    // { value } or { error }; null: no reply
    function reply(o, method, values) {
        if (o.service !== service)
            return { error: "org.freedesktop.DBus.Error.ServiceUnknown" }
        if (o.path === assistantPath && o.iface === assistantIface) {
            if (method === "Actions")
                return actions === null ? { error: "org.freedesktop.DBus.Error.ServiceUnknown" } : { value: actions.slice() }
            if (method === "Act") {
                if (actReply === "none")
                    return null
                if (actReply === "error")
                    return { error: "org.freedesktop.DBus.Error.NoReply" }
                if (actReply === true) {
                    var act = null
                    try { act = JSON.parse(values[1]) } catch (e) { }
                    acts = acts.concat([{ id: values[0], json: values[1], act: act }])
                }
                return { value: actReply }
            }
        }
        if (o.path === phonePath && o.iface === phoneIface && method === "Connected")
            return { value: connected }
        return { error: "org.freedesktop.DBus.Error.UnknownMethod" }
    }

    property Timer _deliver: Timer {
        id: deliver
        interval: 0
        onTriggered: {
            var list = bus.queue
            bus.queue = []
            for (var i = 0; i < list.length; i++) {
                var q = list[i]
                // a destroyed interface gets no reply (the plugin's watcher goes with it)
                if (bus.objects.indexOf(q.obj) < 0)
                    continue
                if (q.r.error !== undefined) {
                    if (q.errorCallback)
                        q.errorCallback(q.r.error, "test double")
                } else if (q.callback) {
                    q.callback(q.r.value)
                }
            }
        }
    }

    // the signal ActResult(id, json) of the relay: every live assistant interface with signals on gets it
    function actResult(id, result) {
        var json = typeof result === "string" ? result : JSON.stringify(result)
        var list = objects.slice()
        for (var i = 0; i < list.length; i++) {
            var o = list[i]
            if (o.signalsEnabled && o.service === service && o.path === assistantPath && o.iface === assistantIface
                    && typeof o.rcActResult === "function")
                o.rcActResult(id, json)
        }
    }
    // the phone's answer to the last act it was given
    function answer(result) {
        if (acts.length === 0)
            return false
        actResult(acts[acts.length - 1].id, result)
        return true
    }
    function callsOf(method) {
        return calls.filter(function (c) { return c.method === method })
    }

    Component.onCompleted: reset()
}
