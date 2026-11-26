Copyright (C) 2026 eos-mainline contributors
SPDX-License-Identifier: GPL-3.0-or-later

# asteroid-calendar tests

QML tests of the Calendar app (the agenda, the event details, the launcher's open request and the
phone's RSVP and Open on phone), run without a watch: the app's own QML from `src/` on an aarch64
`qmltestrunner` under qemu user mode, against a copy of an AsteroidOS image rootfs, with test doubles
for dconf, the session bus and the nemo calendar plugin. Nothing is scheduled, nothing rings, nothing
reaches a phone.

## The files

### tst_logic.qml

`src/CalendarLogic.js` without a scene, on fixed dates (today is Tue 10 Nov 2026, all dates local, so
the checks hold in any time zone): day arithmetic (also over a daylight saving change), spans of
timed, all-day and multi-day events, the agenda list (a header, the events and a spacer per day with
events; all-day first, then start, title, id), the window (today to the synced end, else today + 7),
the empty states ("No events until", the never-synced hint) and the "Synced until" footer, card time
lines and titles ("All day", "Until 11:00", "(Day 2/4)", "(No title)"), day headers, the phone's
X-EOS-* extras and reminders in the stored event's iCalendar text, colours, reminder labels, the
details' date and time lines, delete rules and row order, the open request parser of CR-36 (age
limits, the split at the last "@", rejects), `findEventItem`, and the phone's acts (`rsvp`, `open`).

### tst_app.qml

`src/main.qml` on the doubles: the black frame with the time, the AgendaModel asked for today to the
window end, the CR-55 reader of `/org/asteroidos/calendar/synced-until` (unix seconds, 0 = unknown;
at start, on change, 0, negative, text, removed, in the past; the app never writes it), the model's
rows in the agenda, empty and never-synced states, a tap to the details and back, delete with its
confirmation, today taken again, no editing, month view or day picker.

### tst_open.qml

The open request of CR-36 (FP-A2): `/org/asteroidos/calendar/ui/open` = `event:<startMs>@<nowMs>`,
read at start and on change, the key cleared ("" written by the app) after each read; requests older
than 60 s or more than 5 s ahead ignored; a repeat of the request handled last ignored; a route that
holds an "@" (the route is what is before the last "@"); other routes and values; the details of the
event that starts at `<startMs>` (an open details page replaced); no matching event yet (the request
waits for its row, for 60 s from its stamp at most); a tap dropping a waiting request; the row of
today for a multi-day event; the day taken again before the lookup.

### tst_phone.qml

FP-A2's RSVP, Open on phone and View more on phone through `src/PhoneRelay.qml`. Every D-Bus call is
checked exactly: the session bus, service `org.asteroidos.btsyncd`, path
`/org/asteroidos/btsyncd/assistant`, interface `org.asteroidos.btsyncd.Assistant`, `Actions()` with no
arguments, `Act(u id, s json)` with the act as JSON text, the `ActResult` signal through the Nemo.DBus
handler name `rcActResult`, and `Connected()` on `/org/asteroidos/btsyncd/phone`
(`org.asteroidos.btsyncd.Phone`). The acts as Gadgetbridge reads them:
`{"a":"rsvp","id":<phone event id>,"st":1|2|3}`, `{"a":"open","w":"event","id":<phone event id>,"b":<start in seconds>}`,
`{"a":"open","w":"calendar"}`. Results: success, the phone's error, no phone, an old Gadgetbridge, Act
refused or failed, no answer (the relay's timeout, then a late answer ignored), bad JSON, results for
other ids; and what the details and the agenda show for each ("Responded Yes", "Change RSVP",
"Response could not be updated.", "Opened on your phone", "Could not open on your phone"). Nothing is
asked of the bus before a tap.

### tst_screens.qml

The pages with the real controls: card geometry and colours in px (1 dp = 2 px), outline while
unanswered, long texts, 12 and 24 hour times, all-day, multi-day cards, day headers in two locales,
the list structure, empty states, footer, the details rows in stock order with their sizes, colours
and icons, the notebook's name and colour, the delete button and its confirmation, no text input.

### tst_render.qml

Pictures for a look against the stock frame (`calendar-agenda`, `calendar-agenda-end`,
`calendar-details`, `calendar-details-rsvp`, `calendar-details-open` in the SHOTS folder): the whole
app on its agenda and a phone event's details, invented events only.

## Running

    cd <this checkout>
    R=<rootfs copy> QEMU=<qemu-aarch64> XSYSROOT=<aarch64 sysroot> CONTROLS=<qml-asteroid checkout> XB=<plugin dir> \
        SYSROOTS=<OE sysroots-components> SHOTS=<picture folder> tests/run-qemu.sh [tst_x ...]

With no names every `tests/qml/tst_*.qml` runs. The environment of `tests/run-qemu.sh`:

- `R` (required): a copy of an image rootfs, used as qemu's `-L` and for the QML imports.
- `QEMU` (required): the qemu-aarch64 user mode binary.
- `QMLTESTRUNNER` or `XSYSROOT`: an aarch64 qmltestrunner of the image's Qt (default
  `$XSYSROOT/usr/bin/qmltestrunner`).
- `CONTROLS`, `XB`: a qml-asteroid checkout whose controls replace the rootfs's, and the directory
  with its plugin built for aarch64 (without `XB` the checkout's `tests/qemu/xbuild.sh` builds it,
  which needs `XSYSROOT` and `SYSROOTS`).
- `SYSROOTS`: the OE build's `tmp/sysroots-components`, for lupdate and lrelease (the English catalog
  is made from this checkout); or `QM`: a catalog to use instead.
- `BUILD`: build and log folder (default `build/qemu-tests`, ignored by git).
- `SHOTS`: where the pictures go (default: the run folder, removed at the end).
- `TMO`: seconds per file (default 600). `KEEP=1`: keep the run folder. `FAILS`: failure lines shown
  per file (default 12).
- `TZ`: the time zone of the run (default UTC). The tests hold in any zone the rootfs's zoneinfo and
  ICU both know: `TZ=EST5EDT` runs the day arithmetic over daylight saving changes, `TZ=Etc/GMT-13`
  puts the local day far from the UTC one. A POSIX rule string (`XXX-13YYY,M9.5.0,...`) is not one:
  ICU, which formats the times, does not read it and shows UTC times while the dates are local.

The output is one line per file and a total, for example:

    tst_app.qml: 13 passed, 0 failed, 0 skipped, loops 0
    ...
    Total: 129 passed, 0 failed, 0 skipped, 0 binding-loop warnings in 6 files (logs: .../build/qemu-tests/logs)

The counts include each file's initTestCase and cleanupTestCase. The runner exits 1 on a failure, a
file without totals or a binding-loop warning; each file's full log is in the logs folder.

## The doubles (tests/qml/mocks)

The mocks folder is first on the import path, so these modules stand in for the real ones:

- `Nemo.Configuration`: `ConfigurationValue` on the `ConfStore` singleton (dconf): `set()` is a write
  from outside the app (btsyncd, the launcher), the app's own writes are logged (`writesOf(key)`).
- `Nemo.DBus`: `DBusInterface` (and the `DBus` bus enum) passing every call to `CalendarTest.Bus`.
- `CalendarTest.Bus`: the session bus with asteroid-btsyncd's assistant relay and phone status and the
  phone behind them (`actions`, `connected`, `actReply`); it logs each call with its typed arguments,
  answers a moment later as the real bus does, and sends `ActResult` only when the test answers.
- `org.nemomobile.calendar`: `AgendaModel` (a ListModel the test fills with `setRows()`, the roles
  `event` and `occurrence`) and `NotebookQuery` over `CalendarTest.Notebooks` (the mkcal notebooks;
  the Phone notebook exists once btsyncd has synced).
- `CalendarTest.TestEvent`: a stored event (title, all-day, location, description, notebook, colour,
  `iCalendar()` with the phone's X-EOS-* extras and reminders, `deleteEvent()`).

`org.asteroid.controls` (the CONTROLS checkout) and `org.asteroid.utils` (the rootfs's) are the real
modules.

## What the tests cannot see (needs the watch)

- The real nemo calendar plugin and mkcal: which occurrences AgendaModel gives for the window (its
  dates are QDate), the inclusive end of all-day events, event objects that go away after a sync.
- asteroid-btsyncd and Gadgetbridge: the calendar sync that fills the Phone notebook and writes
  `synced-until`, the relay acts reaching the phone, the phone's calendar opening or its RSVP written.
- The launcher writing `calendar/ui/open` from the Agenda tile and the next event complication and
  starting or raising the app; real dconf change delivery between processes.
- The compositor, touch and crown on the round screen, the time text, the push and back transitions
  (drawn with a shader the software renderer here does not draw while they run), fonts and icons as
  the watch renders them, and battery cost.
- The app takes today from the clock: tst_app, tst_open and tst_render place their events relative to
  the day of the run (a run across midnight can fail once).
