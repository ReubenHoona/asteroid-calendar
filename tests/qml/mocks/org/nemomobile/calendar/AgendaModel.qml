// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double of the nemo calendar plugin's AgendaModel: the roles "event" (a CalendarTest TestEvent)
// and "occurrence" ({ startTime, endTime }); startDate and endDate only record what the app asks for.
// The test fills it with setRows() as the plugin does a moment after the app starts.
import QtQuick

ListModel {
    id: model
    dynamicRoles: true
    property date startDate
    property date endDate
    property int refreshes: 0
    signal updated()
    onStartDateChanged: refreshes++
    onEndDateChanged: refreshes++

    // rows: [{ event, startTime, endTime }]
    function setRows(rows) {
        clear()
        for (var i = 0; i < rows.length; i++)
            append({ "event": rows[i].event, "occurrence": { "startTime": rows[i].startTime, "endTime": rows[i].endTime } })
        updated()
    }
}
