// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double of the nemo calendar plugin's NotebookQuery over CalendarTest's Notebooks.
import QtQuick
import CalendarTest

QtObject {
    property string targetUid
    readonly property var entry: Notebooks.map[targetUid]
    readonly property bool isValid: entry !== undefined
    readonly property string name: entry ? entry.name : ""
    readonly property string color: entry ? entry.color : ""
}
