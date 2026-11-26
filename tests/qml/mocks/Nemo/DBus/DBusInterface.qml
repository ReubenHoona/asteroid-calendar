// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: Nemo.DBus' DBusInterface. Every call goes to CalendarTest's Bus (the session bus with
// asteroid-btsyncd and the phone behind it), which logs it with its typed arguments as given and
// answers a moment later; a signal reaches the object's "rc" + signal name function while
// signalsEnabled is on, as the real plugin does.
import QtQuick
import CalendarTest

QtObject {
    id: obj
    property int bus: 1
    property string service
    property string path
    property string iface
    property bool signalsEnabled: false

    function typedCall(method, args, callback, errorCallback) {
        return Bus.call(obj, method, args, callback, errorCallback, true)
    }
    function call(method, args, callback, errorCallback) {
        return Bus.call(obj, method, args, callback, errorCallback, false)
    }
    Component.onCompleted: Bus.register(obj)
    Component.onDestruction: Bus.unregister(obj)
}
