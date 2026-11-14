/*
 * Copyright (C) 2022 - Timo Könnecke <github.com/eLtMosen>
 *               2016 - Florent Revest <revestflo@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import org.nemomobile.calendar
import Nemo.Configuration
import org.asteroid.controls
import "CalendarLogic.js" as Logic

/*
 * The Calendar app (W2-app-calendar), as stock CP3A's Calendar:
 *  - a black scaffold with the time at the top (weather-calendar-14);
 *  - the agenda (AgendaPage): one list from today to the end of the window the
 *    phone synced, a header per day, a card per event (22 ... 30);
 *  - a tap opens the read-only details (EventDetails, 32) with 'Delete event'
 *    and its confirmation (33);
 *  - no event creation, no editing, no month or day picker (35, Q51).
 * It only reads: the phone's events come from asteroid-btsyncd into the
 * mkcal notebook "Phone" and the sync window end from dconf.
 */
Application {
    id: app

    // Wear OS apps are black with the time curved along the top
    showTime: true

    /*! Today at 00:00; it is taken again whenever the app comes back to the front (no timer). */
    property date today: Logic.startOfDay(new Date())
    /*! The AgendaModel rows as plain objects, for the logic. */
    property var occurrences: []

    // the end of the window the phone synced (Gadgetbridge look-ahead); unset: 0
    ConfigurationValue {
        id: syncedUntilSetting
        key: "/org/asteroidos/calendar/synced-until"
        defaultValue: 0
    }
    readonly property var syncedUntil: Logic.syncedUntilDate(syncedUntilSetting.value)
    readonly property date windowEnd: Logic.windowEnd(today, syncedUntil)

    // for the tests
    readonly property alias stack: layerStack
    readonly property alias model: agendaModel

    function refreshToday() {
        var t = Logic.startOfDay(new Date())
        if (t.getTime() !== today.getTime())
            today = t
    }

    function collect() {
        var l = []
        for (var i = 0; i < collector.count; i++) {
            var o = collector.objectAt(i)
            if (o && o.event)
                l.push({ event: o.event, startTime: o.startTime, endTime: o.endTime })
        }
        occurrences = l
    }
    function recollect() {
        Qt.callLater(collect)
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                app.refreshToday()
        }
    }

    AgendaModel {
        id: agendaModel
        startDate: app.today
        endDate: app.windowEnd
    }
    Instantiator {
        id: collector
        model: agendaModel
        delegate: QtObject {
            property QtObject event: model.event
            property date startTime: model.occurrence.startTime
            property date endTime: model.occurrence.endTime
        }
        onObjectAdded: app.recollect()
        onObjectRemoved: app.recollect()
    }

    // the Phone notebook exists once asteroid-btsyncd has synced at least once
    NotebookQuery {
        id: phoneNotebook
        targetUid: Logic.phoneNotebookUid
    }

    Component {
        id: detailsPage
        EventDetails {
            today: app.today
        }
    }
    Component {
        id: agendaPage
        AgendaPage {
            occurrences: app.occurrences
            today: app.today
            syncedUntil: app.syncedUntil
            phoneSynced: phoneNotebook.isValid
            onEventClicked: (item) => layerStack.push(detailsPage, { "item": item })
            onVisibleChanged: if (visible) app.refreshToday()
        }
    }

    LayerStack {
        id: layerStack
        firstPage: agendaPage
    }
}
