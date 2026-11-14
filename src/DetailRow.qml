/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import org.asteroid.controls

/*
 * A segment of the event details (stock's icon-and-text row, lrx.java:67-640):
 * 6 dp at each side, a 26 dp slot for a 20 dp icon (or the calendar colour
 * square of the title), 12 dp, then the text, 8 dp below. The slot stays
 * empty on a row without an icon so the texts line up (the date and time
 * lines).
 */
Item {
    id: row

    /*! An icon name for the slot (empty: the slot stays empty). */
    property string iconName: ""
    /*! A colour: the slot shows the title's square in it instead of an icon. */
    property color squareColor: "transparent"
    property bool hasSquare: false
    /*! The texts, in a column. */
    default property alias content: _column.data
    readonly property alias column: _column
    readonly property alias icon: _icon
    readonly property alias square: _square

    /*! 6 dp sides, 26 dp slot, 12 dp gap, 8 dp below. */
    readonly property real sidePadding: Theme.dp(6)
    readonly property real slotWidth: Theme.dp(26)
    readonly property real gap: Theme.dp(12)
    readonly property real iconSize: Theme.dp(20)
    property real bottomPadding: Theme.dp(8)
    property real topPadding: 0

    width: parent ? parent.width : Theme.dp(192)
    height: Math.max(_column.implicitHeight, slotWidth) + topPadding + bottomPadding

    Icon {
        id: _icon
        visible: row.iconName !== ""
        x: row.sidePadding + (row.slotWidth - row.iconSize) / 2
        y: row.topPadding + Theme.dp(2)
        width: row.iconSize
        height: row.iconSize
        name: row.iconName
        color: Theme.color.onSurfaceVariant
    }
    Rectangle {
        id: _square
        visible: row.hasSquare
        // the calendar colour, 12 dp, centred in the slot on the first line
        width: Theme.dp(12)
        height: width
        x: row.sidePadding + (row.slotWidth - width) / 2
        y: row.topPadding + Theme.dp(4)
        color: row.squareColor
    }
    Column {
        id: _column
        x: row.sidePadding + row.slotWidth + row.gap
        y: row.topPadding
        width: row.width - x - row.sidePadding
    }
}
