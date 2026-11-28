// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The pages with the real controls (the qv-r2 checkout of the runner): the agenda (AgendaPage), its
// cards (EventCard) and the read-only details (EventDetails, DetailRow). Sizes are px on the 384 px
// round screen (1 dp = 2 px), from stock CP3A Calendar as the sources name it: the card (inset 4 dp,
// at least 64 dp, corners 26 dp, 12 dp padding, the colour at 20 % over black, an outline while the user
// has not answered), the day headers, the empty states, the footer, the details rows in stock order,
// 12 and 24 hour times, all-day without 00:00, multi-day days, the delete confirmation and no editing.
// The texts are the English catalog built from this checkout. Fixed dates: today is Tue 10 Nov 2026.
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
    Component { id: agendaC; App.AgendaPage { width: 384; height: 384 } }
    Component { id: detailsC; App.EventDetails { width: 384; height: 384 } }
    Component { id: spyC; SignalSpy { } }

    TestCase {
        id: tc
        name: "CalendarScreens"
        when: windowShown

        readonly property date today: new Date(2026, 10, 10)
        property var pages: []
        property int popped: 0

        function use12h(on, loc) {
            ConfStore.set("/org/asteroidos/settings/use-12h-format", on)
            TimeFormat.locale = Qt.locale(loc || "en_US")
        }
        function init() {
            ConfStore.reset()
            Bus.reset()
            use12h(true)
            Notebooks.map = ({})
            popped = 0
        }
        // the pages go before the events they show (temporary objects, destroyed after cleanup)
        function cleanup() {
            for (var i = pages.length - 1; i >= 0; i--)
                pages[i].destroy()
            pages = []
            wait(20)
        }
        function event(props) {
            return createTemporaryObject(eventC, tc, props)
        }
        function occ(title, day, h, m, minutes, extra) {
            var s = new Date(2026, 10, 10 + day, h, m)
            var props = { displayLabel: title, instanceId: title + day + h + m, calendarUid: "test-notebook" }
            for (var k in (extra || {}))
                props[k] = extra[k]
            return { event: event(props), startTime: s, endTime: new Date(s.getTime() + minutes * 60000) }
        }
        function page(comp, props) {
            var p = comp.createObject(host, props)
            verify(p !== null)
            pages = pages.concat([p])
            p.list.cacheBuffer = 20000
            wait(300)
            return p
        }
        function agenda(rows, extra) {
            var props = { occurrences: rows, today: tc.today }
            for (var k in (extra || {}))
                props[k] = extra[k]
            return page(agendaC, props)
        }
        function walk(it, pred, out) {
            out = out || []
            if (!it)
                return out
            if (pred(it))
                out.push(it)
            var kids = it.children || []
            for (var i = 0; i < kids.length; i++)
                walk(kids[i], pred, out)
            if (it.contentItem && kids.indexOf(it.contentItem) < 0)
                walk(it.contentItem, pred, out)
            return out
        }
        function named(p, name) {
            return walk(p, function (it) { return it.objectName === name })
        }
        // the cards in list order: the day, then the agenda's order inside the day
        function cards(p) {
            var out = walk(p.list.contentItem, function (it) { return it.timeLabel && it.titleLabel && it.locationLabel && it.card })
            out.sort(function (a, b) {
                var d = a.item.day.getTime() - b.item.day.getTime()
                return d !== 0 ? d : Logic.compareItems(a.item, b.item)
            })
            return out
        }
        // the day headers, top to bottom
        function headers(p) {
            var out = walk(p.list.contentItem, function (it) { return it.parts !== undefined && it.label && it.label.role === "titleSmall" })
            out.sort(function (a, b) { return a.mapToItem(p, 0, 0).y - b.mapToItem(p, 0, 0).y })
            return out
        }
        function rowWithLabel(p, role, part) {
            var l = walk(p.list.contentItem, function (it) {
                return it.label && it.label.text !== undefined && it.label.role === role && String(it.label.text).indexOf(part) >= 0
            })
            return l.length > 0 ? l[0] : null
        }
        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        // the time texts use narrow and thin spaces; compare them as plain spaces
        function plain(s) {
            return String(s).replace(/[    ]/g, " ")
        }

        function test_00_density() {
            compare(Theme.dp(1), 2, "the numbers below are px at 2 px per dp")
        }

        // ------------------------------------------------------------------ the card (weather-calendar-24)

        function test_cardGeometryAndColour() {
            var p = agenda([occ("Test Event A", 0, 9, 0, 30, { location: "Test Room" })])
            var c = cards(p)
            compare(c.length, 1)
            var card = c[0]
            compare(card.card.x, 8, "4 dp inset")
            compare(card.card.width, card.width - 16)
            verify(card.card.height >= 128, "at least 64 dp: " + card.card.height)
            compare(card.card.container.radius, 52, "corners 26 dp")
            compare(card.card.padding, 24, "12 dp padding")
            compare(card.timeLabel.mapToItem(card.card, 0, 0).x, 24)
            // the Phone notebook's blue at 20 % over black, opaque
            var col = card.card.containerColor
            near(col.r, 0x3f / 255 * 0.2, 0.004, "r"); near(col.g, 0xa9 / 255 * 0.2, 0.004, "g"); near(col.b, 0xf5 / 255 * 0.2, 0.004, "b")
            compare(Math.round(col.a * 100), 100)
            // time 14 sp white, title 16 sp onSurface, location 16 sp onSurfaceVariant
            compare(card.timeLabel.font.pixelSize, 28)
            compare(card.timeLabel.color.toString(), Theme.color.onBackground.toString())
            compare(card.titleLabel.font.pixelSize, 32)
            compare(card.titleLabel.color.toString(), Theme.color.onSurface.toString())
            compare(card.locationLabel.font.pixelSize, 32)
            compare(card.locationLabel.color.toString(), Theme.color.onSurfaceVariant.toString())
            compare(card.locationLabel.text, "Test Room")
            verify(card.locationLabel.visible)
            verify(card.timeLabel.y < card.titleLabel.y && card.titleLabel.y < card.locationLabel.y, "time, title, location")
        }

        function test_cardWithoutLocation() {
            var card = cards(agenda([occ("Test Event A", 0, 9, 0, 30)]))[0]
            verify(!card.locationLabel.visible, "no location line")
            verify(card.card.height >= 128)
        }

        function test_cardEventColourAndOutline() {
            var ics = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nX-EOS-COLOR:ffd93025\r\nX-EOS-RSVP:0\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
            var a = occ("Test Needs Answer", 0, 9, 0, 30, { ics: ics, color: "#00ff00" })
            var b = occ("Test Accepted", 0, 10, 0, 30, { ics: ics.replace("RSVP:0", "RSVP:1") })
            var c = cards(agenda([a, b]))
            compare(c.length, 2)
            compare(c[0].eventColor.toString(), "#d93025", "the phone's event colour, not the notebook's")
            near(c[0].card.containerColor.r, 0xd9 / 255 * 0.2, 0.004, "20 % of the event colour")
            compare(c[0].card.container.border.width, 2, "not answered: 1 dp outline")
            compare(c[0].card.container.border.color.toString(), "#d93025")
            compare(c[1].card.container.border.width, 0, "answered: no outline")
            verify(a.event.stats.n >= 1, "the extras come from the stored event")
        }

        // R5 D-16: every other guest declined: the outline and the 16 dp error icon in the event colour before the time
        function test_cardEveryoneElseDeclined() {
            var guests = function (x) {
                var d = { n: 3, c: [1, 0, 2, 0], g: [["Me Example", 1, 3], ["Bo Sample", 3, 0], ["Cy Test", 3, 0]] }
                if (x)
                    d.x = 1
                return "X-EOS-GUESTS:" + encodeURIComponent(JSON.stringify(d)) + "\r\n"
            }
            var ics = function (x) {
                return "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nX-EOS-COLOR:ffd93025\r\nX-EOS-RSVP:1\r\n" + guests(x)
                       + "END:VEVENT\r\nEND:VCALENDAR\r\n"
            }
            var p = agenda([occ("Test Declined By All", 0, 9, 0, 30, { ics: ics(true), location: "Test Room" }),
                            occ("Test Going", 0, 10, 0, 30, { ics: ics(false) })])
            var c = cards(p)
            compare(c.length, 2)
            compare(c[0].card.container.border.width, 2, "outlined though the user answered")
            compare(c[0].card.container.border.color.toString(), "#d93025")
            verify(c[0].declinedIcon.visible)
            compare(c[0].declinedIcon.width, 32, "16 dp")
            compare(c[0].declinedIcon.color.toString(), "#d93025", "the event colour")
            compare(c[0].timeLabel.mapToItem(c[0].card, 0, 0).x, 24 + 32 + 8, "the time 4 dp after the icon")
            verify(c[0].card.Accessible.name.indexOf("Everyone else declined") > 0)
            compare(c[1].card.container.border.width, 0)
            verify(!c[1].declinedIcon.visible)
            compare(c[1].timeLabel.mapToItem(c[1].card, 0, 0).x, 24)
            grabImage(p).save("shots/d16-declined.png")
        }

        function test_cardNotebookColour() {
            var card = cards(agenda([occ("Test Own", 0, 9, 0, 30, { color: "#ff9800" })]))[0]
            compare(card.eventColor.toString(), "#ff9800", "no colour from the phone: the notebook's")
            compare(card.card.container.border.width, 0)
        }

        function test_cardLongTexts() {
            var p = agenda([occ("Test Event with a very long title that needs more than two lines on this small round screen", 0, 9, 0, 30,
                                { location: "Test location text that is far too long to fit on one line of the card" })])
            var card = cards(p)[0]
            compare(card.titleLabel.lineCount, 2, "two lines at most")
            verify(card.titleLabel.truncated, "with an ellipsis")
            compare(card.locationLabel.lineCount, 1, "one line")
            verify(card.locationLabel.truncated)
        }

        function test_cardNoTitle() {
            compare(cards(agenda([occ("", 0, 9, 0, 30)]))[0].titleLabel.text, "(No title)")
        }

        function test_cardTap() {
            var p = agenda([occ("Test Event A", 0, 9, 0, 30)])
            var spy = createTemporaryObject(spyC, tc, { target: p, signalName: "eventClicked" })
            var card = cards(p)[0]
            var pt = card.card.mapToItem(screen, card.card.width / 2, card.card.height / 2)
            mouseClick(screen, pt.x, pt.y)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0].event.displayLabel, "Test Event A")
        }

        // ------------------------------------------------------------------ times (weather-calendar-25 ... 28)

        function test_times12h() {
            use12h(true, "en_US")
            var c = cards(agenda([occ("Test Morning", 0, 9, 0, 60), occ("Test Afternoon", 0, 14, 30, 60), occ("Test Noon", 0, 11, 0, 120)]))
            compare(plain(c[0].timeLabel.text), "9:00 – 10:00 AM", "12 h, the marker once")
            compare(plain(c[1].timeLabel.text), "11:00 AM – 1:00 PM", "markers on both ends")
            compare(plain(c[2].timeLabel.text), "2:30 – 3:30 PM")
            verify(c[2].timeLabel.text.indexOf("14") < 0, "no 14:30 in 12 hour mode")
        }

        function test_times24h() {
            use12h(false, "en_GB")
            var t = plain(cards(agenda([occ("Test Afternoon", 0, 14, 30, 60)]))[0].timeLabel.text)
            compare(t.replace(/\s/g, ""), "14:30–15:30", "24 h: " + t)
            verify(t.indexOf("PM") < 0 && t.indexOf("pm") < 0)
        }

        function test_allDay() {
            var c = cards(agenda([occ("Test All Day", 0, 0, 0, 0, { allDay: true }), occ("Test Event A", 0, 9, 0, 60)]))
            compare(c[0].timeLabel.text, "All day")
            compare(c[0].titleLabel.text, "Test All Day", "all-day first")
            compare(c[1].titleLabel.text, "Test Event A")
        }

        function test_multiDayCards() {
            use12h(true, "en_US")
            var rows = [{ event: event({ displayLabel: "Test Trip", instanceId: "trip", calendarUid: "test-notebook" }),
                          startTime: new Date(2026, 10, 9, 22, 0), endTime: new Date(2026, 10, 12, 11, 0) }]
            var c = cards(agenda(rows))
            compare(c.length, 3)
            compare(c[0].titleLabel.text, "Test Trip (Day 2/4)")
            compare(c[0].timeLabel.text, "All day")
            compare(c[1].titleLabel.text, "Test Trip (Day 3/4)")
            compare(c[2].titleLabel.text, "Test Trip (Day 4/4)")
            compare(plain(c[2].timeLabel.text), "Until 11:00 AM")
        }

        // ------------------------------------------------------------------ headers (weather-calendar-23)

        function test_headers() {
            var h = headers(agenda([occ("A", 0, 9, 0, 30), occ("B", 1, 9, 0, 30), occ("C", 2, 9, 0, 30)]))
            compare(h.length, 3)
            compare(h[0].parts.lead, "Today"); compare(h[0].parts.date, "Tue 10", "Today Tue 10")
            compare(h[1].parts.lead, "Tomorrow"); compare(h[1].parts.date, "Wed 11")
            compare(h[2].parts.lead, ""); compare(h[2].parts.date, "Thu, November 12", "weekday, month in full, no year (en_US)")
            verify(h[0].label.text.indexOf(Theme.color.onBackground.toString()) >= 0, "'Today' in white")
            verify(h[0].label.text.indexOf(Theme.color.primary.toString()) >= 0, "the date in primary")
            compare(h[2].label.color.toString(), Theme.color.onSurfaceVariant.toString())
            compare(h[0].label.font.pixelSize, 28, "titleSmall 14 sp")
            compare(h[0].label.horizontalAlignment, Text.AlignHCenter)
            near(h[0].height - h[0].label.implicitHeight, 16, 0.5, "8 dp below")
        }

        function test_headerDayFirstLocale() {
            use12h(false, "en_GB")
            var d = headers(agenda([occ("C", 2, 9, 0, 30)]))[0].parts.date
            verify(/Thu/.test(d) && /November/.test(d) && !/2026/.test(d), "abbreviated weekday, full month, no year: " + d)
            verify(d.indexOf("12") < d.indexOf("November"), "the day before the month: " + d)
        }

        // ------------------------------------------------------------------ the list (weather-calendar-22)

        function test_structure() {
            var p = agenda([occ("A", 0, 9, 0, 30), occ("B", 0, 10, 0, 30), occ("C", 3, 9, 0, 30)])
            compare(p.items.map(function (i) { return i.kind }).join(), "header,event,event,spacer,header,event,spacer")
            compare(p.rows.length, 8, "the items and 'View more on phone'")
            compare(p.list.contentY, -p.list.topMargin, "opens at the top (today)")
            compare(p.windowEnd.getTime(), new Date(2026, 10, 17).getTime())
            var sp = walk(p.list.contentItem, function (it) { return it.height === 24 && it.children.length === 0 && it.parent
                                                                       && it.parent.parent && it.parent.parent.kind === "spacer" })
            verify(sp.length >= 1, "12 dp spacers after a day")
        }

        // ------------------------------------------------------------------ empty states and footer (weather-calendar-29, -30)

        function test_noEvents() {
            use12h(true, "en_US")
            var p = agenda([])
            compare(p.items.map(function (i) { return i.kind }).join(), "header,noEvents")
            var n = rowWithLabel(p, "bodyMedium", "No events until")
            verify(n !== null)
            compare(n.label.text, "No events until Nov 17, 2026")
            compare(n.label.font.pixelSize, 28, "bodyMedium 14 sp")
            compare(n.label.color.toString(), Theme.color.onSurfaceVariant.toString())
            compare(n.label.horizontalAlignment, Text.AlignHCenter)
            compare(n.label.y, 32, "16 dp above")
            near(n.height - n.label.y - n.label.implicitHeight, 44, 0.5, "22 dp below")
            var h = headers(p)
            compare(h.length, 1)
            compare(h[0].parts.date, "Tue 10", "today's header above it")
        }

        function test_noEventsWindowFromSync() {
            verify(rowWithLabel(agenda([], { syncedUntil: new Date(2026, 10, 24, 6, 0) }), "bodyMedium", "Nov 24, 2026") !== null)
        }

        function test_neverSynced() {
            var p = agenda([], { phoneSynced: false })
            verify(rowWithLabel(p, "bodyMedium", "Turn on calendar sync on your phone") !== null)
            verify(rowWithLabel(p, "bodyMedium", "No events until") === null)
        }

        function test_footer() {
            var p = agenda([occ("A", 0, 9, 0, 30)], { syncedUntil: new Date(2026, 10, 17, 9, 0) })
            var f = rowWithLabel(p, "titleSmall", "Synced until")
            verify(f !== null)
            compare(f.label.text, "Synced until Nov 17, 2026")
            compare(f.label.font.pixelSize, 28)
            compare(f.label.color.toString(), Theme.color.onSurfaceVariant.toString())
            near(f.height - f.label.implicitHeight, 16, 0.5, "8 dp below")
            verify(rowWithLabel(agenda([occ("A", 0, 9, 0, 30)]), "titleSmall", "Synced until") === null, "unknown: no footer")
        }

        // ------------------------------------------------------------------ the details (weather-calendar-32, -33)

        readonly property string detailIcs: "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nX-EOS-COLOR:ff3fa9f5\r\nX-EOS-CALENDAR:Test Calendar\r\n"
            + "BEGIN:VALARM\r\nTRIGGER:-PT10M\r\nEND:VALARM\r\nBEGIN:VALARM\r\nTRIGGER:-PT1H\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        function details(extraEvent, start, end, extra) {
            var o = occ("Test Event", 0, 14, 30, 60, extraEvent)
            var item = { event: o.event, start: start || o.startTime, end: end || o.endTime, allDay: false, dayIndex: 1, dayCount: 1 }
            var props = { item: item, today: tc.today, pop: function () { tc.popped++ } }
            for (var k in (extra || {}))
                props[k] = extra[k]
            return page(detailsC, props)
        }

        function test_detailsRows() {
            use12h(true, "en_US")
            var p = details({ location: "Test Room", description: "Test notes", ics: detailIcs })
            compare(p.rows.join(), "title,when,location,description,reminders,calendar,delete", "stock order")
            var title = named(p, "titleLabel")[0]
            compare(title.text, "Test Event")
            compare(title.font.pixelSize, 32, "titleMedium")
            compare(title.color.toString(), Theme.color.onBackground.toString())
            compare(title.maximumLineCount, 3)
            var row = named(p, "titleRow")[0]
            compare(row.hasSquare, true)
            compare(row.square.color.toString(), "#3fa9f5", "the colour square")
            compare(row.square.width, 24, "12 dp")
            compare(row.topPadding, 24, "12 dp above")
            var d = named(p, "dateLabel")[0], t = named(p, "timeLabel")[0]
            compare(d.text, "Today")
            compare(plain(t.text), "2:30 – 3:30 PM")
            compare(d.font.pixelSize, 26, "labelSmall 13 sp")
            compare(t.font.pixelSize, 26)
            compare(d.color.toString(), Theme.color.onSurfaceVariant.toString())
            compare(named(p, "locationLabel")[0].text, "Test Room")
            compare(named(p, "descriptionLabel")[0].text, "Test notes")
            compare(named(p, "reminderLabel").map(function (l) { return l.text }).join(" | "), "10 minutes before | 1 hour before")
            compare(named(p, "calendarLabel")[0].text, "Test Calendar", "the phone's calendar name")
            compare(named(p, "deleteButton").length, 1)
            compare(row.column.x, 12 + 52 + 24, "6 dp, the 26 dp slot, 12 dp, then the texts")
            compare(named(p, "locationRow")[0].iconName, "ios-pin-outline")
            compare(named(p, "remindersRow")[0].iconName, "ios-notifications-outline")
            compare(named(p, "calendarRow")[0].iconName, "ios-calendar-outline")
        }

        function test_detailsMinimal() {
            compare(details({}).rows.join(), "title,when,calendar,delete")
            Notebooks.map = ({ "test-notebook": { name: "Sample Notebook", color: "#123456" } })
            // the plugin's event colour is its notebook's
            var p = details({ color: "#123456" })
            compare(named(p, "calendarLabel")[0].text, "Sample Notebook", "the notebook's name when the phone sent none")
            compare(named(p, "titleRow")[0].square.color.toString(), "#123456", "and its colour")
            compare(named(p, "locationRow").length, 0)
            compare(named(p, "descriptionRow").length, 0)
            compare(named(p, "remindersRow").length, 0)
        }

        function test_detailsAllDay() {
            var o = occ("Test All Day", 0, 0, 0, 0, { allDay: true })
            var item = { event: o.event, start: o.startTime, end: o.endTime, allDay: true, dayIndex: 1, dayCount: 1 }
            var p = page(detailsC, { item: item, today: tc.today })
            compare(named(p, "timeLabel")[0].text, "All day")
            compare(named(p, "dateLabel")[0].text, "Today")
        }

        function test_detailsMultiDay() {
            use12h(true, "en_US")
            var p = details({}, new Date(2026, 10, 13, 9, 0), new Date(2026, 10, 15, 17, 0))
            var d = named(p, "dateLabel")[0].text
            verify(d.indexOf("Fri") >= 0 && d.indexOf("Sun") >= 0, "both dates: " + d)
            compare(plain(named(p, "timeLabel")[0].text), "9:00 AM – 5:00 PM")
            compare(named(p, "titleLabel")[0].text, "Test Event", "no '(Day n/m)' in the details")
        }

        function test_deletePhoneEventHidden() {
            var p = details({ calendarUid: Logic.phoneNotebookUid })
            compare(p.rows.indexOf("delete"), -1, "a phone event cannot be deleted from the watch")
            compare(named(p, "deleteButton").length, 0)
            verify(details({ calendarUid: Logic.phoneNotebookUid }, undefined, undefined, { phoneCanDelete: true }).rows.indexOf("delete") >= 0,
                   "once Gadgetbridge can delete it on the phone")
        }

        function test_deleteConfirm() {
            var p = details({})
            var b = named(p, "deleteButton")[0]
            compare(b.text, "Delete event")
            verify(!p.deleteDialog.shown)
            p.list.positionViewAtEnd()
            wait(100)
            var pt = b.mapToItem(screen, b.width / 2, b.height / 2)
            mouseClick(screen, pt.x, pt.y)
            tryVerify(function () { return p.deleteDialog.shown }, 2000)
            compare(p.deleteDialog.title, "Delete this event?")
            compare(p.deleteDialog.buttons, "confirmDismiss")
            compare(p.item.event.deleted, 0, "nothing deleted before the confirmation")
            p.deleteDialog.dismissed()
            p.deleteDialog.close()
            compare(p.item.event.deleted, 0, "dismissed: nothing")
            compare(tc.popped, 0)
            p.deleteDialog.open()
            p.deleteDialog.confirmed()
            compare(p.item.event.deleted, 1, "confirmed: deleted once")
            compare(tc.popped, 1, "and back to the list")
        }

        function test_noEditing() {
            var p = details({ location: "x", description: "y" })
            compare(walk(p.list.contentItem, function (it) { return it.cursorPosition !== undefined && it.readOnly !== undefined }).length, 0,
                    "no text input")
        }
    }
}
