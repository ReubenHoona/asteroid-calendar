// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The start (src/main.qml): QQuickView makes main.qml at 0 x 0 and gives it the window's size after
// it. The agenda is made once the app has its size, so it is laid out once, at the screen's; an open
// request read at start (tst_open) still finds it. The whole app on the doubles of mocks/.
import QtQuick
import QtTest
import Nemo.Configuration
import CalendarTest
import org.asteroid.controls

Item {
    id: root
    width: 384
    height: 384

    Rectangle { anchors.fill: parent; color: "black" }
    Item { id: host; anchors.fill: parent }

    TestCase {
        id: tc
        name: "CalendarStart"
        when: windowShown

        property var app: null

        function init() {
            ConfStore.reset()
            Bus.reset()
        }
        function cleanup() {
            if (app)
                app.destroy()
            app = null
            wait(20)
        }

        function test_agenda_made_at_the_apps_size() {
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            compare(c.status, Component.Ready, c.errorString())
            app = c.createObject(null)
            verify(app !== null)
            compare(app.width, 0)
            compare(app.stack.firstPageItem, undefined, "no agenda at 0 x 0")
            app.parent = host
            compare(app.width, 384)
            var page = app.stack.firstPageItem
            verify(page, "the agenda, made at the screen's size")
            compare(page.width, 384)
            compare(page.height, 384)
            compare(app.stack.layers.length, 0)
        }
    }
}
