# AGENTS.md — working on fractonica-ios

The guide for a coding agent (or engineer) picking this repository up. It tells
you where everything is and what you must not break. Read it before the code.

- **What this is:** the native iPhone + Mac app for the Fractonica clock (an
  eclipse-anchored harmonic clock): one multiplatform SwiftUI target, iOS 17+
  and macOS 14+, no third-party dependencies.
- **Where the truth lives, in order:** `../SPEC.md` (the clock) →
  `../core/include/fractonica.h` (the C API, every function documented) →
  `../design/README.md` and `../design/astrolabe/DESIGN.md` (the look, binding)
  → this repository. `../core/AGENTS.md` has an "I need X → call Y" table for
  the core.
- **Status:** version 0.1.0 of the app (built against core 0.2.0), all six stages are done: `FractonicaKit`
  (the Swift face of the core); the app shell: tokens, model, drawing
  primitives, the instrument, the limb, navigation, accessibility, snapshot
  mode; all four screens, NOW, LADDER, LENS and WAVE (the timeline, with
  time travel), in both layouts and both modes; the integration pass (UI
  tests, the icon, the launch screen, the pictures in `docs/`); and the
  review pass (stage 6: every improvised piece of notation moved into the
  shim, Earth seconds scheduled, small phones, narrow windows and iPads,
  Mac trackpad input; see §8). Since then (stage 7) the core gained the
  functions this app asked for: they are wrapped in the kit, the shim
  pieces they replace are deleted, and the mode toggle's ring takes taps.
  Stage 8 adopted core 0.2.0: `frc_span_next_change_since` (elapsed and
  past-zero signed spans are scheduled), U+2212 before a negative civil
  year, an offset text of a day or more refused, the stricter civil parser,
  and a level's kind said only in the core's words (`major` `unit`
  `between` `sub-Blink`).
  `App/Screens/ScreenKit.swift` is the contract of a screen; the four are
  worked examples of it.
- **In a hurry:** section 6 is the map of the app ("I need X → it is in Y"),
  section 4 the commands, section 8 what has and has not been verified.

## 1. Hard rules

1. **No Fractonica arithmetic in Swift.** Every number, name, symbol, phase,
   boundary, span, date, glyph state and formatted quantity comes from the C
   core through `FractonicaKit`. Arc geometry comes from `Arc.child` /
   `Arc.point` / `Arc.waveRoot`, glyph outlines from `Glyph.path`. If the core
   lacks something, do not improvise it: ask for a core function (exact C
   signature and reason) and, only if you cannot proceed, isolate a clearly
   marked temporary shim in ONE file named `Shim*.swift`.
2. **Never edit** anything under `../core`, `../design`, `../reference`,
   `../web`, `../esp32` or `../SPEC.md`. Work only inside `ios/`.
3. **Pure mode shows only Fractonica:** no Gregorian date, weekday, month,
   year, hour / minute / second, time zone, Hz, metre, SI prefix or per cent
   anywhere, including accessibility labels and values, tooltips, window
   titles and menus. Earth mode adds the translations exactly where
   DESIGN.md §9 says, led by the Earth sign. No percentages in either mode.
   Nothing blinks or pulses. Words: screens NOW, LADDER, LENS, WAVE; toggle
   PURE / EARTH.
4. **Time is `Instant`:** Unix **microseconds**. Redraw when something visible
   changes, scheduled from the instants the kit returns (`Odometer.nextChange`,
   `Threshold.instant`, `Sync.next.instant`; `nil` = nothing later). Never
   poll. Continuous arc fill may animate at a modest frame rate (DESIGN.md §10).
5. **Outside the catalogue** every reading throws `FractonicaError.outOfRange`.
   Follow design/README.md ruling 7: the instrument stays engraved, the
   reading is replaced by `OUT OF CATALOGUE · α#1 – α#18`, time travel clamps
   (`Catalogue.clamped`).
6. **Earth-mode zone** is the device's `TimeZone`; the offset is taken per
   instant from Foundation and the civil fields and text from the core:
   `CivilTime(instant, timeZone: .current)`.
7. No git command that changes anything is run by an agent unless the owner
   asks. No warnings in our own Swift code (`Tools/build.sh` fails on one).
8. **One token table.** No colour and no font outside `App/Design/Theme*.swift`
   (`Color(token:)`, `Typeface`). Views and renderers ask the theme:
   `ink.palette.lumen`, `theme.engraved(7.5, palette.ash)`.
9. **The one shim** is `App/Model/ShimCoreGaps.swift`: everything the core
   cannot provide yet and the app composes itself. What is left in it:
   whether a sub-Blink period is legible (`spanIsLegible`), a rung's place
   in its band (`placeInBand`), the device wordings (`timerTicks`,
   `oscillatorStep`), the Sun's drift in seconds (`seconds`), and the
   calendar walks (`civilHours`, `step(_:field:by:zone:)`). Its header lists
   which are pure-safe and the core function that should replace each.
   **Add nothing of this kind anywhere else** (no `split` of a core text, no
   `local + 1`, no hand-made `"\(n) in \(x)"`): put it in the shim and ask for
   the core function. When the core gains one, delete the shim's. The core
   now writes the Earth texts (`App/Model/EarthText.swift` only chooses the
   form and appends the zone's abbreviation), and the wave's track is the
   core's index and phase (`App/Model/WaveTrack.swift`, through
   `frc_time_at_phase`): neither file is a shim.
10. **Time travel never leaves the catalogue** and is global: every way of
    moving the cursor ends in `AppModel.scrub(to:)`, which clamps
    (`Model/AppModel+TimeTravel.swift`), and every screen reads
    `model.instant`.

## 2. Layout

```
ios/
  AGENTS.md  README.md (the GitHub front page)  LICENSE  .gitignore
  project.yml                 XcodeGen: the source of truth. Fractonica.xcodeproj is generated, git-ignored
  FractonicaKit/              Swift package: the thin Swift face of ../core            (section 3)
    Package.swift             depends on .package(path: "../../core"), product CFractonica
    Sources/FractonicaKit/
    Tests/FractonicaKitTests/ (section 5)
  App/                        the app target's sources                                 (section 6)
    FractonicaApp.swift       entry point, the scene, the menu
    Model/  Design/  Drawing/  Instrument/  Screens/  Snapshot/  Resources/
  AppTests/                   the app's unit tests (hosted by the Mac app)             (section 5)
  AppUITests/                 UI tests: the running app driven through its accessibility elements
  Tools/                      build.sh  test-kit.sh  test-app.sh  test-ui.sh  snapshot.sh
                              simulator-shots.sh  icon.sh  simulator-id.sh
  docs/                       GUIDE.md (the long README) and its pictures: hero.jpg (README), overview.png, icon.png, screens/ (curated snapshots)
  build/                      git-ignored: DerivedData, snapshots, screenshots, build logs
```

## 3. FractonicaKit: what is where

The kit contains **no arithmetic of its own**. A file wraps one corner of
`fractonica.h`; its doc comments name the C function behind every member.

| File (`Sources/FractonicaKit/…`) | Holds | Core functions |
|---|---|---|
| `Support/FractonicaError.swift` | `FractonicaError` (mirrors `frc_status_t`), `check(_:)` | — |
| `Support/CoreText.swift` | THE text helper: buffer, UTF-8, negative-status convention; `arrayOfTuple` | every `frc_format_*` goes through it |
| `Support/Fractonica.swift` | `Fractonica.coreVersion`, `.specVersion`, `.ordinal(_:)`, `.ascii(_:)` | `frc_format_ordinal`, `frc_to_ascii` |
| `Time/Instant.swift` | `Instant` (Int64 µs), `Date` conversions | `frc_time_from_ms/_s`, `frc_time_is_none` |
| `Time/Fraction.swift` | `Fraction` (0.32 fixed point: phases) | `frc_frac_to_double` |
| `Time/Catalogue.swift` | `Catalogue` (`.saros141`, custom series), domain, `clamped`, the `read(into:)` helper | `frc_catalogue_*` |
| `Time/Position.swift` | `Position`, `Catalogue.position(at:)` | `frc_position_at`, `frc_time_at_position` |
| `Hierarchy/Level.swift` | `Level` 0…62, `LevelKind` (`.text`: `major` `unit` `between` `sub-Blink`) | `frc_factor`, `frc_siblings`, `frc_prefix`, `frc_format_level_name/_word`, `frc_level_kind`, `frc_format_level_kind` |
| `Hierarchy/Unit.swift` | `Unit` (the nine units) | `frc_unit_*`, `frc_format_unit_*` |
| `Hierarchy/Quarter.swift` | `Quarter` (Peak Node Valley End) | `frc_format_quarter` |
| `Clock/Cycle.swift` | `Cycle`, `CyclePoints`, `Threshold`; cycles at / by index, next threshold, parent / children, names; `cycle.placeText` (`8 of 9`); `clock.instant(_:index:atPhase:)` | `frc_cycle_*`, `frc_next_threshold`, `frc_format_cycle_name`, `frc_format_cycle_place`, `frc_time_at_phase` |
| `Clock/Glyph.swift` | `Glyph` (a state of a phase glyph); `Glyph(at: quarter)` (the state at a threshold) | `frc_glyph_*`, `frc_glyph_at_quarter` |
| `Clock/Odometer.swift` | `Odometer` (digits + `nextChange`) | `frc_odometer_at`, `frc_odometer_of_phase` |
| `Clock/Sync.swift` | `Sync` (`.helion`: the running Helion's place 0…18), `Catalogue.syncOdometer`, `clock.instant(sync:atPhase:)` | `frc_sync_*`, `frc_time_at_sync_phase` |
| `Clock/Pentad.swift` | `Pentad` (`.first`: its first Helion's place 0 5 10 15; `.numeral` `II`), `PentadForm` (`.numeral`) | `frc_pentad_*`, `frc_format_pentad` (`FRC_PENTAD_NUMERAL`) |
| `Notation/FractonicaDate.swift` | `FractonicaDate`, `DateForm`, parse, date ↔ instant; `date.term(_:)`, `date.terms` (`ε#5`, `34η`) | `frc_date_at`, `frc_date_to_time`, `frc_format_date`, `frc_format_date_term`, `frc_parse_date` |
| `Notation/DateStepping.swift` | `Catalogue.instant(byStepping:by:from:)` (the stamp's tumblers) | a composition of the above |
| `Notation/Span.swift` | `Span` (`.text()`, `.signedText()` `+6ι 43λ`, `.text(in: unit)` `−6 235λ`), `SpanPart`, `Catalogue.span(from:to:)`, `Catalogue.spanNextChange(from:to:)` (a span that shrinks), `Catalogue.spanNextChange(since:at:)` (a span that grows), `Level.span` | `frc_span_*`, `frc_format_span`, `frc_format_span_signed`, `frc_format_span_in_unit`, `frc_span_next_change`, `frc_span_next_change_since` |
| `Notation/Rate.swift` | `TimeLapseRate` (presets), `BlinkRate` (pB), `Level.cyclesPerBlink()` | `frc_rate_preset`, `frc_format_rate`, `frc_level_per_blink`, `frc_format_per_blink` |
| `Notation/PureWording.swift` | pure-mode texts: `Fractonica.count`, `.count(signed:)`, `.lightWord`; `Level.countText(in:)`, `.childrenText` (`9 θ`), `.inParentText` (`11 in ζ`), `.prefixFactorsText`, `.rateText`, `.lightSpanText`; `Unit.inParentText` (`77 in ε`) | `frc_format_count`, `frc_format_count_signed`, `frc_format_light_word`, `frc_format_level_in_unit`, `frc_format_level_children`, `frc_format_level_in_parent`, `frc_format_unit_in_parent`, `frc_format_prefix_factors`, `frc_format_level_rate`, `frc_format_light_span` |
| `Ladder/SarosInterval.swift` | `SarosInterval` (`.reference`, mean, at an instant) | `frc_interval_*` |
| `Ladder/Quantity.swift` | `Quantity` (17 digits; `init?(digits:exponent:)` for a caller's own value), `QuantityKind` | `frc_format_quantity`, `frc_sci_to_double` |
| `Ladder/Medium.swift` | `Medium`, `Speed` | `frc_medium_speed`, `frc_format_medium_*` |
| `Ladder/Band.swift` | `Band` (`.name`, `no band` included; `.edges` in hertz, Earth only) | `frc_format_band`, `frc_band_edges` |
| `Ladder/Level+Ladder.swift` | period / frequency / length (exact, text, Double), band, device ticks / step | `frc_period`, `frc_frequency`, `frc_length`, `frc_format_period` …, `frc_band`, `frc_device_*` |
| `Geometry/GlyphPath.swift` | `Glyph.path` (`GlyphPathElement`), `.segments`, `.bounds` | `frc_glyph_path`, `frc_glyph_segments`, `frc_glyph_bounds` |
| `Geometry/GlyphPath+CoreGraphics.swift` | `Glyph.outline(unit:origin:)` → `GlyphOutline` (CGPaths) | — (same coordinates, in points) |
| `Geometry/Arc.swift` | `Arc`: `child(m:local:odd:)`, `point(at:)`, `waveRoot(half:)`, `fullCircle` | `frc_arc_child`, `frc_arc_point`, `frc_arc_wave_root` |
| `Geometry/Arc+CoreGraphics.swift` | `Arc.cgPath(from:to:)`, `addPath(to:from:to:)` | `frc_arc_point` for the end points |
| `Civil/CivilTime.swift` | `CivilTime` (Earth mode only); `instant(in: TimeZone)` for wall-clock fields; `.isValid`; `CivilTime.parse(_:)` (a typed date, with or without a zone) | `frc_civil_from_time`, `frc_time_from_civil`, `frc_format_civil`, `frc_civil_validate`, `frc_parse_civil` |
| `Civil/CivilText.swift` | `CivilForm` (14 forms), `civil.text(_:)` (`THU 8 OCT 2026 · 12:00:00`, `9 OCT 01:34`; a year before 1 `−0044`, but `.isoDate` `-0044-03-15`), `CivilTime.offsetText(seconds:)` (`nil` for a day or more), `Fractonica.duration(microseconds:maxParts:)` (`23 min 53 s`) | `frc_format_civil_text`, `frc_format_duration` |

### I need X → use Y

| I need | Use |
|---|---|
| the clock | `let clock = Catalogue.saros141` |
| now | `Instant.now`; a `Date`: `Instant(date)` |
| is the clock defined there | `clock.contains(instant)`; clamp: `clock.clamped(instant)` |
| the reading `ε#5 34η 29ι 21λ 3ν` | `try clock.date(at:)` then `.text(.shortLetters, finest: .blink)` and friends; the stamp: `.stamp` |
| `DELTA TRIFRACTON · END` | `clock.cycle(.delta, at:)` → `.name` and `.quarter.name` (uppercase in the view) |
| the two centre glyphs | `try clock.odometer(focus, at:)` → `.glyphs`, redraw at `.nextChange` |
| draw a glyph | `glyph.outline(unit: u, origin: stemTop)` → stroke `.strokes` (round caps / joins, `.lineWidth`), fill `.dots` |
| a level's phase for lighting an arc | `clock.cycle(level, at:).phase.value` (0..<1) |
| which half-cycle arc of the ring is lit, and how far | the CHILD level's running cycle: `.localHalfIndex`, `.halfProgress.value` |
| the same one nesting level deeper (an arc that is HALF a parent cycle) | the grandchild's running cycle: `.halfIndexInParentHalf`, `.halfProgress.value` |
| sibling counter / beads | `cycle.local` of `cycle.siblings` |
| lit bezel graduations | `grandchild.index − focus.firstDescendantIndex(at: grandchildLevel)` |
| next threshold and its countdown | `clock.nextThreshold(level, after:)`, `clock.span(from: now, to: threshold.instant!).text()` |
| all four thresholds of a cycle | `clock.points(of: cycle)` |
| parent / children of a cycle | `clock.parent(of:)`, `clock.children(of:)` |
| the Sun | `clock.sync(at:)`, `clock.syncOdometer(at:)`, `clock.pentad(at:)`; the sync number: `Fractonica.count(signed: Int64(n))`; the drift: `clock.span(from: sync.nominal, to: sync.start).text(in: .flavon)` |
| the Sun's ring / lane | `clock.sync(number:)`, `clock.pentad(sync:index:)` for index 0…3; the running Helion's slot `sync.helion`, a Pentad's first slot `pentad.first`; `pentad.isHypopentad` → square, its numeral `pentad.numeral` |
| a span as text | `span.text()` (two parts), `span.text(maxParts: 1)`, `span.parts()`; signed `span.signedText()`; in one unit `span.text(in: .flavon)` |
| when a countdown's text changes | `clock.spanNextChange(from: now, to: boundary)` |
| when an elapsed time's text changes, or a signed span's past its zero | `clock.spanNextChange(since: origin, at: now)` (a signed span: `spanNextChange(from:to:)` before the boundary, `since:` from it on) |
| a term of the stamp | `date.term(.helion)`, all nine `date.terms` |
| a rung's period in pure mode | `level.span.text()` down to the Blink; `level.countText(in: unit)`; finer: `level.rateText(digits:)` |
| what a rung is made of / is part of | `level.childrenText` (`9 θ`), `level.inParentText` (`11 in ζ`), `unit.inParentText` (`77 in ε`), `cycle.placeText` (`8 of 9`), `level.prefixFactorsText` |
| a length in pure mode | `level.lightSpanText(medium)`; the word alone `Fractonica.lightWord` |
| period / frequency / length in Earth mode | `level.periodText()`, `.frequencyText()`, `.lengthText(speed:)`; numbers for a log rule: `.periodSeconds()` … |
| a rung's band | `level.band()`, `band.name` (`no band` for `.noBand`); its edges (Earth) `band.edges` |
| the glyph at a threshold | `Glyph(at: .node)` |
| an instant at a phase (a scrub) | `clock.instant(level, index:, atPhase:)`; on the Sun's ring `clock.instant(sync:atPhase:)` |
| step one term of the stamp | `clock.instant(byStepping: .helion, by: +1, from: cursor)` |
| read a stamp back | `try FractonicaDate(parsing: text)`, `clock.instant(of: date)` |
| the hero ring's arcs | `Arc.fullCircle(center:radius:)`, `.child(m: 2 * focus.factor, local: j, odd: j % 2 == 1)`, recurse with `m = childLevel.factor`, `odd = (j * m + k) % 2 == 1` |
| the wave | `Arc.waveRoot(half:)`, scaled in the view |
| stroke part of an arc | `arc.cgPath(from: 0, to: p)` / `arc.addPath(to: path, from:to:)` |
| the point of now | `arc.cgPoint(at: progress)` |
| Earth date and time | `CivilTime(instant, timeZone: .current)` (fields, `.isoText`, `.text(.dateTime)` …) |
| an Earth duration | `Fractonica.duration(microseconds:)` |
| the instant of a typed Earth date | `CivilTime.parse(text)`, then `.time.instant` (zone named) or `.time.instant(in: zone)` |

### Conventions

- **Everything read at an instant is a method of `Catalogue`**, declared in an
  extension next to the type it returns. Static facts hang on `Level`, `Unit`,
  `Quarter`, `Medium`, `Band`.
- **Levels are zero-based** (`Level.helion.index == 6`); the user-facing number
  is `level.depth`. Only `Level.isClockLevel` levels (0…21) have readings.
- **Errors:** a `frc_status_t` function `throws` a `FractonicaError`. A text
  function whose arguments the Swift types already make valid returns a plain
  `String`; one that can be asked something undefined returns `String?`.
- **"No such instant"** (`FRC_TIME_NONE`) is `nil`, never a sentinel.
- **Value types only**, all `Sendable`; no unsafe pointer in the public API.
  The package is built in Swift 6 language mode.
- **Adding a wrapper:** find the owning file in the table above (or add a
  small one), convert Swift values to C ones at the call, go through
  `CoreText` for text and `check` / `Catalogue.read(into:)` for a status, name
  the C function in the doc comment, add a row here and a test.
- A C enum stored in a `uint8_t` struct field needs a cast
  (`frc_unit_t(UInt32(part.unit))`); function-like macros and `FRC_TIME_NONE`
  are not imported (see `../core/docs/GUIDE.md`, "Apple platforms").
- `Arc.pi` is the core's `FRC_PI`. Swift's `Float.pi` is one float lower, and a
  carrier built from it does not divide the way the core expects: build
  carriers with `Arc.fullCircle`.

## 4. Build, run, test, snapshot

```
Tools/build.sh                 # xcodegen + build for the iPhone simulator and for the Mac
Tools/build.sh ios | mac       # one of them
Tools/snapshot.sh [dir]        # build the Mac app, render every screen to PNG (default build/snapshots)
Tools/test-kit.sh              # swift test for FractonicaKit (92 tests)
Tools/test-app.sh              # the app's unit tests on the Mac (58 tests; a window opens briefly)
Tools/test-ui.sh [simulator]   # the UI tests on a simulator (3 tests; the third runs on an iPad only)
Tools/simulator-shots.sh [simulator] [args]   # every screen x mode on a simulator -> build/screenshots/<name>/
Tools/icon.sh [args]           # redraw App/Resources/Assets.xcassets/AppIcon.appiconset from the instrument
```

- **The whole check, from nothing:** `rm -rf build Fractonica.xcodeproj
  FractonicaKit/.build && Tools/build.sh && Tools/test-kit.sh &&
  Tools/test-app.sh && Tools/test-ui.sh && Tools/snapshot.sh`. Every script
  exits with xcodebuild's own status (a failing test stops the chain); the
  full logs are `build/build-<ios|mac>.log`, `build/test-app.log`,
  `build/test-ui.log`.
- **zsh does not split words:** `set -- $spec` or `Tools/snapshot.sh dir $args`
  with several arguments in one variable passes ONE argument. Write the
  arguments out, or loop in a `bash` script.

- `Tools/build.sh` prints `BUILD SUCCEEDED, no warnings in our code` or the
  errors / our warnings, and keeps the full log in `build/build-<ios|mac>.log`.
  The simulator build is unsigned (`CODE_SIGNING_ALLOWED=NO`), the Mac build
  signed ad hoc. Products: `build/DerivedData/Build/Products/Debug/Fractonica.app`
  and `…/Debug-iphonesimulator/Fractonica.app`.
- The simulator is "iPhone 16 Pro" (`FRACTONICA_SIMULATOR` overrides). It is
  addressed by identifier, because a name alone means "on the latest iOS",
  which that device may not have: `Tools/simulator-id.sh`.
- Always pass `-derivedDataPath <ios>/build/DerivedData` to xcodebuild.
  Xcode creates an empty, git-ignored `.swiftpm/xcode/` inside `../core` when
  it resolves the local package; it is harmless (remove the empty directories
  if you want `core/` exactly as you found it: `find ../core/.swiftpm -type d
  -empty -delete`, which leaves anything that is not empty).
- While the core is being edited by its own engineer a build may fail in a
  `core/src/*.c` file for a minute: wait and retry, do not work around it.

**Launch arguments** (`App/Model/LaunchArguments.swift`). Any of them makes
the launch "pinned": nothing is written to the preferences.

| Argument | Effect |
|---|---|
| `--t <unix seconds>` | freezes time (SPEC vector A: `1791460800`) |
| `--cursor <unix seconds>` | a scrubbed cursor: the moment shown, away from now (clamped to the catalogue) |
| `--mode pure\|earth` | the mode |
| `--screen now\|ladder\|lens\|wave` | the screen |
| `--focus <level>` | the focus, 0…13 (a level, not a depth: the Helion is 6) |
| `--rung <level>` | the rung of interest, 0…62: what the lens inspects and the ladder is turned to (default: the focus) |
| `--theme astrolabe\|basalt` | the token table |
| `--layout phone\|desktop` | forces the arrangement |
| `--zone <identifier>` | Earth mode's time zone (`UTC`, `Europe/Paris`); default: the device's |
| `--size <W>x<H>` | a view size in points: the Mac window opens at it; with `--snapshot`, the four screens in both modes are rendered at that size instead of the usual set |
| `--snapshot <dir>` | renders the pictures there and exits 0; no window |
| `--icon <dir>` | draws the icon's two master pictures there and exits 0 (`Tools/icon.sh` cuts the sizes) |

```
# on the simulator, at vector A:
UDID=$(Tools/simulator-id.sh); xcrun simctl boot $UDID
xcrun simctl install $UDID build/DerivedData/Build/Products/Debug-iphonesimulator/Fractonica.app
xcrun simctl launch $UDID org.fractonica.clock --t 1791460800 --mode earth --zone UTC
xcrun simctl io $UDID screenshot build/screenshots/now.png

# on the Mac:
build/DerivedData/Build/Products/Debug/Fractonica.app/Contents/MacOS/Fractonica --t 1791460800 --focus 9
```

**Snapshots** (`App/Snapshot/SnapshotRunner.swift`): the real `RootView`
rendered by `ImageRenderer`, at `--t` (default: vector A), in UTC unless
`--zone` says otherwise.

```
<screen>-<layout>-<mode>.png          now ladder lens wave × phone desktop × pure earth   (16 pictures)
now-phone-pure-focus<L>.png           L = 0 3 5 6 7 9 12 13
ladder-<layout>-<mode>-rung<L>.png    the wheel at the top, the Helion, ζ1 and the bottom: L = 0 6 29 62
lens-<layout>-<mode>-rung<L>.png      the lens on L = 0 6 12 13 29 30 62
wave-<layout>-<mode>-focus<L>.png     the wave re-scaled to L = 3 6 9
<screen>-<layout>-<mode>-scrubbed.png every screen with the cursor away from now (the NOW mark shows `+3η 12ι`)
```

96 pictures in all. Another instant: `Tools/snapshot.sh build/snapshots/B
--t 946684800` (SPEC vectors B and C are 946684800 and 2886085800; an
instant outside the catalogue, say 100000000000, shows ruling 7). Another
window shape: `--size 2560x1080` (8 pictures at that size). Compare `ladder-phone-*-rung29.png` with
`../design/astrolabe/screen3.png` / `screen3_pure.png`,
`lens-phone-*-rung6.png` with `screen4.png` / `screen4_pure.png`, and
`wave-phone-pure.png` / `wave-phone-earth.png` with `screen5.png` /
`screen5_greg.png`.

Phone pictures are 393 × 852 at 3x, desktop 1280 × 800 at 2x. A new `Screen`
case, or a placeholder that gets filled, is in the pictures with no change to
the runner. **Look at the PNGs** (and at `../design/astrolabe/*.png` beside
them) before saying a screen is right.

## 5. Tests (`FractonicaKit/Tests/FractonicaKitTests`)

| File | Holds the kit against |
|---|---|
| `Support.swift` | the instants of SPEC §12 (`Vector.a/.b/.c/.anchorPlusOneSecond`), `XCTAssertInstant` (SPEC's millisecond rounding), `XCTAssertThrows` |
| `SpecClockVectorTests.swift` | SPEC §12 typed in literally: A, B, C, the anchor, Pentads |
| `SpecNotationVectorTests.swift` | SPEC §15.6 literally; §15.2 – §15.5 examples; the pure wordings; date ↔ instant ↔ text round trips; stamp stepping |
| `SpecLadderVectorTests.swift` | SPEC §16.5 literally; §16.2 bands, §16.3 media, §16.4 devices |
| `GeometryTests.swift` | glyph paths against SPEC §9.1 (the table typed in); arcs against the `child()` formulas of DESIGN.md §5; CGPath builders; the half-cycle recipes |
| `CatalogueEdgeTests.swift` | outside the catalogue, the opening and closing instants, "next" instants, tiling and nesting, a custom series, `Instant` conversions (a `Date` rounded to the nearest microsecond, within 1 µs back near 1613, clamped instead of trapping) |
| `HierarchyTests.swift` | SPEC §3.1 factors, §3.4 names, §15.1 units, §16.4 prefixes |
| `CivilTimeTests.swift` | civil fields and ISO text for an offset; the offset of a time zone per instant, against Foundation's calendar; the wall clock on both sides of both daylight-saving changes; fields the core's struct cannot hold refused, not clamped |
| `TextCoverageTests.swift` | every public String API returns text across all 63 levels (and 22 clock levels, all units / media / bands / forms); pure wordings carry no Earth unit |
| `CoreAdditionsTests.swift` | one test per function the core gained in stage 7, against the header's examples and vector A: the word `light`, level kinds, signed counts, `8 of 9`, `9 θ`, `11 in ζ`, `77 in ε`, P with its factors, stamp terms, signed spans, a span in one unit (the drift `−6 235λ`), a countdown's next change and an elapsed span's (`<0.001ν` one microsecond after its origin), the Pentad numeral, `Sync.helion` and `Pentad.first`, the glyph at a threshold, the instant at a phase (cycle, sync), band edges, the 14 Earth forms (a year before 1 with U+2212 but in the ISO date; an offset of a day refused), durations, civil validation and parsing (tabs refused, `THU , 8 OCT 2026` read, shape before range before weekday) |

The app's tests (`AppTests/`, run by `Tools/test-app.sh`, `@testable import Fractonica`):

| File | Holds the app against |
|---|---|
| `ReadingTests.swift` | vector A: the instrument's reading (beads 8 of 9, 29 of 36 graduations, ζ's ring 1 of 11, the Sun's slot 7 of 19), the NOW reading (terms, countdowns, the Sun, next thresholds), every focus 0…13, out of the catalogue, the Earth texts of the design; pure-mode speech carries no Earth text |
| `GeometryAndStateTests.swift` | the ring radii of DESIGN.md §5, rings fit for every focus, a nest is built for every focus, launch arguments, the model's rules (clamping, the lens), the scheduler's bounds |
| `LadderLensTests.swift` | vector A: the ladder's 63 rungs (ζ1 the one rung of visible light, the design's figures in both modes), the band rule, the wheel's geometry (DESIGN.md §7), the lens of the Helion (rows, thresholds `−20ι 21λ … +6ι 43λ`, glyph states, the seven media) and of every rung, the Earth translations; no pure text of either screen carries an Earth unit; the rung of interest in the model (`inspect`, `step(by:)`, `closeLens`) |

| `GeometryAndStateTests.swift` (again) | the hero's arcs, with everything nested on them, stay inside the first counter ring for every focus on both instruments (`testHeroStaysInsideTheCounterRings`) |
| `EarthAndEdgeTests.swift` | every Earth second is a wake of the scheduler, and every change of a countdown's text (`frc_span_next_change`), of an elapsed threshold's on the lens and of the NOW mark's offset on both sides of the cursor (`frc_span_next_change_since`); durations rounded before their wording (the core's); the moment cut to its second, a threshold rounded; `31 FEB` refused; far thresholds carry their day (bezel and countdowns); civil hours across Lord Howe's and Cairo's changes; day ticks placed by the core; nothing listed at the closing instant; no Sun reading in the partial syncs; `WaveTrack` agrees with the core's phase |
| `InputAndFitTests.swift` | the pinch is not changed by a stray twist, a twist counts past 15°; a refused tumbler step says so; NOW and a typed moment stop a coasting wave; the design's own phone fitted as designed, an SE given its bands back with engraved words at 6.2 pt; the arrangement of windows and iPads; the mode toggle's one hit frame holds its word and its ring, 44 view points on every phone, clear of what lies beneath |
| `WaveTests.swift` | vector A: the wave's reading (stamp terms, `33η 34η 35η`, the Sun's lane, the list and its design figures), every focus 0…13 and outside the catalogue, the Earth translation; `WaveTrack` is its own inverse and clamps; snapping; the lit wave meets the hairline; DESIGN.md §7's phone numbers; stepping the tumblers and their ghosts; what "go to" reads in each mode; time travel in the model; no pure text of the screen carries an Earth unit |

The UI tests (`AppUITests/InstrumentTourUITests.swift`, run by
`Tools/test-ui.sh`) launch the real app at vector A with time frozen and
drive it: `testTourOfTheInstrument` reads NOW, drags the limb, toggles the
mode (the Earth date appears in the spoken text and goes again), opens each
screen from its sigil, drags the wave (the NOW mark turns into "Return to
now"), taps it and returns to NOW; `testTheModeRingToggles` taps the mode
control on its ring (centre, top, right edge) and on its word, each tap
toggling, and holds it at 44 points or more; `testEveryScreenOnAnIPadOnItsSide`
turns an iPad to landscape (the desktop arrangement) and opens every screen. They
find elements by `accessibilityIdentifier` (`now.date`, `limb`, `mode`,
`sigil.<screen>`, `ladder.rung`, `lens.title`, `wave.moment`, `wave.track`,
`wave.now`, `return.now`) and assert on what assistive technology would say.
A screenshot of each step is kept in `build/ui-tests.xcresult`
(`xcrun xcresulttool export attachments --path … --output-path …`).

Test vector A, the deterministic instant used everywhere: Unix 1791460800 s
(2026-10-08T12:00:00Z), stamp `α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν`.

## 6. The app: what is where

**How it hangs together.** `AppModel` (one `@Observable` object in the
environment) says which moment is shown and how. A view reads
`model.clock` and `model.instant`, builds a small value-type *reading* from
the kit, and hands it to a *renderer*: a pure function that draws with an
`Ink` in the design's own coordinates. `RootView` fits the design
(393 × 852 or 1280 × 800) into the window once (`DesignSpace`), so every
number of DESIGN.md §7 is used as written.

```
AppModel ──instant, focus, mode──▶ Reading (kit calls) ──▶ Renderer (Ink, design coordinates) ──▶ DesignCanvas / MotionCanvas
                                                              ▲ theme (tokens)      hit areas + accessibility: .designFrame(rect)
```

| File (`App/…`) | Holds |
|---|---|
| `FractonicaApp.swift` | `@main` (snapshot mode, icon mode or the app), the window, the menu (← → ⌘1–4 ⌘E ⌘0), `TextRendering` (Mac font smoothing off) |
| **Model/** | |
| `AppModel.swift` | THE state: `clock`, `now`, `cursor`, `instant`, `mode`, `focus`, `lensLevel` (the rung of interest), `screen`, `layout`, `timeZone`; `scrub(to:)` and `returnToNow()` (both stop a coasting wave), `stopGlide()`, `setFocus`, `stepFocus(by:)`, `step(by:)` (whatever the screen in front scales by), `openLens(on:)`, `setLensLevel`, `inspect(_:)`, `focusOnRung()` (⌘↩), `closeLens()`, `setMode`; the scheduler (`start` / `stop`, paced by `movingLevel`, woken on a mode change) |
| `AppModel+Bindings.swift` | `focusBinding`, `lensLevelBinding` |
| `AppModel+TimeTravel.swift` | the ways the cursor moves: `step(_:by:) -> Bool` (a tumbler; false when refused at the catalogue's edge), `stepStamp(by:)` and `selectStampField(by:)` (the keys), `scrub(alongWaveOf:from:cycles:)` (a drag), `glide(alongWaveOf:velocity:cycleWidth:)` (the coast after a flick, owned by the model), `settleOnWave(cycleWidth:)` (the snap), `stepThreshold(by:)`; `WaveSnap` |
| `StampField.swift` | `StampField` (a term of the stamp or an Earth field), `EarthField` |
| `GoTo.swift` | reading a typed moment: the core's parser, then (Earth mode only) an Earth date |
| `AppTypes.swift` | `Screen` (and its hover `hint`), `DisplayMode`, `LayoutClass` (design sizes, safe bands, `fitting(_:)`: an iPad or a view 700 pt wide is the desktop on iOS; a Mac window wider than tall the desktop, a narrow one the phone arrangement) |
| `ClockSchedule.swift` | when the next visible change is (from the core's next-change instants, the countdowns' included: `frc_span_next_change`; the signed spans that cross zero, the moving level's four thresholds and the cursor's offset: `frc_span_next_change` before, `frc_span_next_change_since` after; in Earth mode also the next Earth second, and the hundredths of a countdown under ten seconds) |
| `EarthText.swift` | Earth mode's texts (not a shim): which of the core's Earth forms each line uses (`dateLine`, `clock`, `dayClock`, `when` / `bezelWhen`, `duration`, `earthFields`), the moment cut to its second and a threshold rounded to its nearest, the zone's abbreviation (the platform's), `nextEarthSecond`, `instant(parsing:zone:)` (`frc_parse_civil`) |
| `WaveTrack.swift` | an instant ↔ a distance in cycles of a level along a drawing of them (the wave, the Sun's lane, the day ticks on the Sun's ring): the core's index and phase, `frc_time_at_phase` back |
| `LaunchArguments.swift`, `Preferences.swift` | pins for tests (`--t`, `--cursor`, …); what persists (mode, focus) |
| `Readings/InstrumentReading.swift` | everything the instrument draws for a focus at an instant; `CounterReading` |
| `Readings/SunReading.swift` | the sync, its glyphs, the running Helion's slot, the Pentad starts |
| `Readings/NowReading.swift` | the NOW panel: Pentad, majors, terms, countdowns, the Sun's figures, next thresholds, the out-of-catalogue line |
| `Readings/LadderReading.swift` | `RungReading`: the static facts of one rung (name, kind, band, "n in parent", made of, length, rate; Earth: period, frequency, length); `LadderReading`: all 63 for a Saros interval |
| `Readings/LensReading.swift` | everything the lens shows: lineage, prefix, the data rows (each a list of wordings, longest first), the seven media, and for levels 0…13 the live ring with its four thresholds |
| `Readings/WaveReading.swift` | everything WAVE shows: the stamp's terms, the laps of the focused level around the moment, the nested running cycles, the Sun's lane (`SunLane`, `PentadMark`), the list; `StampGhosts` (a tumbler's neighbours); `WaveStepping` |
| `Readings/WaveEarth.swift` | WAVE's Earth translations (Earth mode only): the tumbler fields, the dates under the Sun's quarters, the times under the wave's, the list's column |
| `Readings/LevelWords.swift` | (a level's kind has no word here: it is the core's `LevelKind.text`, engraved in capitals) `Band.neighbours` (the order of `frc_band_t`), `Band.edgeTexts` (Earth: the core's edges, two digits), `Level.title`, `Level.finerUnit` |
| `ShimCoreGaps.swift` | THE SHIM (rule 9), what the core still lacks: `spanIsLegible`, `placeInBand`, `timerTicks` / `oscillatorStep`, `seconds` (the drift in s), `civilHours`, `step(_:field:by:zone:)` (an Earth tumbler) |
| **Design/** | |
| `Theme.swift`, `Theme+Astrolabe.swift`, `Theme+Basalt.swift` | the token table: `Palette`, `Typography`, `LineWeights`, `Glow`; `\.theme` |
| `SystemFace.swift` | the system font at the display optical size, tabular figures, cached |
| `Motion.swift` | the durations of DESIGN.md §10; `nil` with Reduce Motion |
| `DesignSpace.swift` | design ↔ view coordinates; `\.designSpace`; `.designFrame(rect)`; the phone design gives back its safe bands on a phone that has none (an SE), and `engravedFloor` keeps engraved words at 6.2 view points or more on a phone |
| `InstrumentMetrics.swift` | `.phone`, `.desktop`, `.inspector(center:radius:)`: R, gaps, limb, glyph unit … |
| **Drawing/** (renderers: `static func draw(…, in ink: inout Ink)`) | |
| `Ink.swift`, `InkText.swift` | the pen: `stroke`, `fill`, `line`, `circle`, `layer`, `text` (baseline-anchored), `line` of `TextPiece`s; text styles `theme.engraved / value / letter / earthText`; `ink.fitting(wordings, style, width:)` (the longest wording that fits) |
| `DesignCanvas.swift` | `DesignCanvas { ink in }`, `MotionCanvas(value:) { ink, value in }` |
| `NestRenderer.swift` | the nested alternating arcs: `build(carrier:focus:running:depth:)` (a ring), `buildHalf(carrier:level:secondHalf:stage:running:depth:)` (one half-cycle of the wave), `paint(_:heroWidth:in:)`; built nests are cached by the running cycles' indices, and only the arcs on the path to now are split again each frame |
| `WaveArcs.swift` | the core's wave root (`Arc.waveRoot`) placed and sized on screen |
| `GlyphRenderer.swift` | `draw(_:center:unit:color:…)`, `drawRow(…)` (an odometer); pixel snapping |
| `CounterRingRenderer.swift` | a slotted ring with a planet; `.style(major:…)`, `.sunStyle(…)` |
| `SealRenderer.swift` | a level's icon: `draw(_:center:extent:color:…)` |
| `LimbRenderer.swift` | `drawCurved(metrics:position:selectable:in:)`, `drawStraight(center:position:…)` |
| `Marks.swift` | `nowPoint` (optionally in the Sun's colour), `beads`, `pentad` (square for the Hypopentad), `quarter`, `modeSign`, `earthSign` (heading of an Earth column), `fadingRule`, `angle(of:)` |
| `SigilRenderer.swift`, `PlateRenderer.swift` | the four sigils; the ground (`PlateView`) |
| **Instrument/** | |
| `InstrumentView.swift` | THE HERO as a view: canvas + motion + gestures + accessibility |
| `InstrumentRenderer.swift` | draws the whole instrument from a reading and a geometry |
| `InstrumentGeometry.swift` | ring radii for a focus (compression for deep ones), `heroRadius` (R, less for a level of few children with many ancestors), bezel, glyph unit, `ring(atRadius:)`; `HeroReach`: how far a focus's nested arcs reach, measured on the core's construction |
| `InstrumentMotion.swift` | the animated vector, `FadeClock`, `InstrumentSteps` |
| `EarthLayer.swift` | Earth mode on the instrument: when each threshold falls on the bezel words (`bezelWhen`), the zone's civil hours and days on the Sun's ring, placed among the Helions by the core |
| `InstrumentSpeech.swift` | what assistive technology says for each ring |
| `LimbControl.swift` | THE LIMB as a control: `LimbControl(level:selectable:shape:)`, `.curved(metrics)` / `.straight(center:)` |
| `ScrollWheel.swift` | `.onScrollWheelStep { steps in }` (a limb: both axes) and `.onScrollWheel { ScrollInput in }` (up-down steps and sideways pan apart, with the pointer's place); the monitor always calls the latest handler (Mac) |
| `TwoFingerSteps.swift` | the pinch OR the twist on the instrument, whichever means a step first (a twist only past 15°) |
| **Screens/** | |
| `RootView.swift` | measures the screen, shows the screen + chrome, the keys (← → ↑ ↓, Return, Escape), status bar |
| `ScreenKit.swift` | THE CONTRACT OF A SCREEN (read it before filling one); `PlaceholderScreen` |
| `Chrome/NavigationChrome.swift` | sigils + mode toggle (with `.help` hover hints on the Mac); `ChromePlaces` (`modeHitFrame(on:)`: one frame for the word and the ring) |
| `Chrome/ReturnMark.swift` | the NOW mark while the cursor is away, with the signed offset (absent on WAVE, which has its own) |
| `Now/NowScreen.swift` | layers of NOW; the panel's accessibility elements |
| `Now/NowPhoneRenderer.swift`, `Now/NowDesktopRenderer.swift` | the panel in each arrangement |
| `Now/NowPieces.swift`, `Now/NowEarth.swift` | shared blocks (also `upcomingRow`, the row of "next thresholds" that WAVE draws too); the Earth lines of NOW |
| `Ladder/LadderScreen.swift` | LADDER as a view: the wheel's motion (`LadderMotion`), drag / flick / tap / long press (a rung the instrument cannot show answers "finer than the instrument reads"), the spine scrubber, the one accessibility element |
| `Ladder/LadderGeometry.swift` | where things are: the rim, `rowY(offset:)` and its inverse, row opacity, the columns (the desktop's pure columns spread over the width and slide to their Earth places, `blended(earth:)`), the spine (`.phone`, `.desktop`) |
| `Ladder/LadderRenderer.swift` | title, headings, rim and band rail, a list row, the focused row with its band rule |
| `Ladder/LadderSpine.swift` | the 63 ticks, unit letters, the window bracket, the focus ring |
| `Ladder/LadderSpeech.swift` | what a rung says aloud |
| `Lens/LensScreen.swift` | LENS as a view: canvas, the straight limb over all 63 rungs, swipe down, accessibility elements |
| `Lens/LensLayout.swift` | where things are (`.phone`, `.desktop`) and the frames of the spoken blocks |
| `Lens/LensRenderer.swift` | title block, lineage strip, data rows (fits the wordings), the media with their logarithmic rule |
| `Lens/LensRing.swift` | the live ring R 54 with beads, glyphs and the four thresholds; the engraved seal of a rung with no live ring |
| `Lens/LensSpeech.swift` | what each block of the lens says aloud |
| `Wave/WaveScreen.swift` | WAVE as a view: the layers, the gestures (drag the wave with inertia and snapping, drag or tap the Sun's lane, pull a tumbler, the scroll wheel), the accessibility elements |
| `Wave/WaveLayout.swift` | where things are (`.phone` as DESIGN.md §7, `.desktop`), the slide of the lower screen in Earth mode, hit frames |
| `Wave/WaveStampRenderer.swift` | the nine tumblers with ghosted neighbours; the Earth row on the same columns |
| `Wave/WaveSunRenderer.swift` | the Sun's lane: 19 Helions as a wave, Pentad brackets, quarters, the window of the wave |
| `Wave/WaveRenderer.swift` | the wave: carriers, nest, cycle names, hairline, threshold rule, the mark of the present |
| `Wave/WaveListRenderer.swift` | the list of next thresholds (one or two columns) |
| `Wave/WaveNowMark.swift` | NOW at the right of the stamp: lit at the present, else the signed offset; a tap returns |
| `Wave/WaveGoToField.swift` | the "go to" field (engraving at rest with a ghosted ASCII example of the moment, a text field only while typing) |
| `Wave/WaveSpeech.swift` | what each block of WAVE says aloud (the word `Earth`, never the sign) |
| **Snapshot/** `SnapshotRunner.swift` | `--snapshot` (the 96 pictures, or the screens at `--size`); `rasterize`, `write` |
| **Snapshot/** `IconRenderer.swift` | `--icon`: the app icon, drawn by `InstrumentRenderer` (the bare hero ring of a Helion on the plate) |
| **Resources/** `Assets.xcassets` | `AppIcon` (PNGs written by `Tools/icon.sh`, committed), `LaunchPlate` (the `plate` token, the launch screen's colour) |
| **Resources/** `Info.plist` | the one key build settings cannot express: `UILaunchScreen` → `LaunchPlate`; merged with the keys of `project.yml` |

### I need X → it is in Y

| I need | Use |
|---|---|
| the moment to show | `model.instant` (the cursor, else now); `model.isAtNow`, `model.isInCatalogue` |
| to move through time | `model.scrub(to:)` (clamps), `model.returnToNow()`; the NOW mark appears by itself |
| to step one term of the moment | `model.step(.unit(.helion), by: 1)`; an Earth field: `.earth(.month)` (Earth mode only) |
| to move by a distance on a drawing of cycles | `WaveTrack.instant(in:level:from:movedBy:)`; the distance between two instants: `WaveTrack.cycles(in:level:from:to:)` |
| to read a typed moment | `GoTo.resolve(text, clock:at:earthZone:)` (`earthZone: nil` in pure mode) |
| the wave of a level somewhere | `WaveArcs.half(_:radius:origin:)` + `NestRenderer.buildHalf` + `.paint` (see `WaveRenderer`) |
| a signed span (`+3η 12ι`) | `try clock.span(from:to:).signedText()` |
| the focus / to change it | `model.focus`, `model.setFocus(_:)`, `model.stepFocus(by:)`, `model.focusBinding` |
| a rung the instrument cannot focus (lens, ladder) | `model.lensLevel`, `model.openLens(on:)`, `model.lensLevelBinding`; move it without touching the focus: `model.inspect(_:)` |
| the facts of a rung, in either mode | `RungReading.read(level, interval:earth:)`; the interval: `LadderReading.interval(clock, at:)` |
| everything about one rung at an instant | `LensReading.read(clock, at:level:zone:)` (`zone: nil` = pure: no Earth text is built) |
| a value that must fit a width | give the renderer a list of wordings, longest first (`LensReading.Row`), and let it take the first that fits |
| a column wholly in Earth units | one drawn sign in its heading: `Marks.earthSign(center:opacity:in:)` |
| the arrangement | `@Environment(\.designSpace) var space` → `space.layout` |
| to draw | `DesignCanvas { ink in … }` in design coordinates; animated: `MotionCanvas(value:)` |
| a colour, a font, a line weight | `ink.palette.…`, `ink.theme.engraved(size, colour)` / `.value(size)` / `.letter(size, colour)` / `.earthText(size)`, `ink.theme.line.…` |
| text at a baseline | `ink.text("…", at: point, style, anchor: .middle)`; mixed sizes: `ink.line([TextPiece…], at:)` |
| a reading with ash letters | `theme.value(size)` colours Greek letters and `#` by itself |
| the Earth sign | `Ink.earth("12:56")` → `⊕ 12:56`, drawn with `theme.earthText(size)` |
| a tappable / spoken area | a `Button` or `Color.clear` with accessibility modifiers, THEN `.designFrame(rect)` |
| the whole instrument somewhere | `InstrumentRenderer.draw(reading, geometry: InstrumentGeometry(metrics:focus:), in: &ink)` |
| a small bare ring (lens) | the same with `InstrumentMetrics.inspector(center:radius:)` |
| nested arcs on any carrier | `NestRenderer.build` + `.paint` |
| a level's icon | `SealRenderer.draw(level, center:extent:color:in:)` |
| glyphs | `GlyphRenderer.drawRow(odometer.glyphs, center:unit:color:in:)` |
| bead counter | `Marks.beads(center:count:local:pitch:in:)` |
| the limb | `LimbControl(level:selectable:shape:)` |
| an Earth text | `EarthText` (a form of the core's `frc_format_civil_text`); what no core function writes goes into `ShimCoreGaps` (Earth mode only) with a request for one |
| a new screen | a case in `Screen`, a view in `Screens/<Name>/`, a line in `RootView.screen`, a sigil in `SigilRenderer` |
| a new theme | another `Theme` value; `Theme.named(_:)` |

### Conventions of the app

- **Design coordinates.** Renderers use the numbers of DESIGN.md §7 directly.
  Text coordinates are baselines, as in the mockup's SVG.
- **Pure mode builds no Earth value.** `EarthLayer`, `NowEarth`,
  `RungReading.earth`, the Earth fields of `LensReading`, everything in
  `EarthText` and every `ShimCoreGaps` call not marked pure-safe in its
  header are made only when the mode is Earth (or fading out of it), and
  speech gets a zone only then.
- **Earth beside, never instead.** On the lens and on the desktop ladder an
  Earth value is set beside the Fractonica one (DESIGN.md §1, principle 5).
  The one exception is the phone ladder's value column, which the design
  draws as either pure or Earth under an Earth-sign heading.
- **A view that animates Earth in keeps its hit areas at the target.** On
  the phone WAVE the lower screen slides 27 pt in Earth mode: the canvas
  follows the animated value, the hit frames and the limb's offset use the
  mode itself.
- **A text field is not a drawing.** `ImageRenderer` cannot draw one, so the
  "go to" field is engraving on the canvas at rest and a `TextField` only
  while it has the keyboard; it sets `model.isTyping`, which hands the arrow
  keys back to the text (the menu's ← → are disabled meanwhile).
- **One rung of interest.** The ladder's wheel and the lens share
  `model.lensLevel`. The instrument's focus follows it only through the
  lens's limb (levels 0…13) or a long press on the ladder.
- **Readings are values, renderers are functions.** Neither holds state; all
  state is `AppModel` and a view's `@State` for motion.
- **Redraw on change.** The scheduler sleeps until the core's next change
  (`ClockSchedule`); no timer ticks at a fixed rate, no `TimelineView`.
- **Any focus 0…13.** Geometry adapts by itself: deep focus levels compress
  the ring gaps (`InstrumentGeometry`); levels of few children move the bezel
  in and the first ring out of the hero's way, measured on the nest itself
  (`HeroReach`: the arcs nested on the hero reach further than the hero);
  when that would press the counter rings under 0.45 of their designed gaps
  the hero ring itself is drawn smaller (`heroRadius`; θ on the phone is
  0.87 R); and a nesting depth whose arcs average under 3 pt is not drawn
  (`NestRenderer`). Draw the hero on `geometry.heroRadius`, never on
  `metrics.radius`.
- **Text carried along by time is never cut by an edge.** The wave's cycle
  names and threshold words fade out over their last 12 pt before the
  window's edge (`WaveRenderer.edgeFade`); when the view is wider than the
  design (an upright iPad, a wide Mac window) the wave itself dies away
  towards the design's edge instead of stopping there.
- **Swift 6, strict concurrency.** Views and the model are main-actor;
  readings, renderers and the theme are `Sendable` values usable anywhere.

## 7. Common mistakes

- **Passing a depth.** "Depth 7" is `Level.helion` (index 6).
- **Deriving a state from a phase.** Phases light arcs. Digits, quarters,
  counts and countdowns come from `Odometer`, `Cycle.quarter`, `Cycle.local`,
  `FractonicaDate` and `Span`.
- **Composing notation by hand** (`"\(n)η"`, grouping digits, a "+" or a unit
  letter added in a view), **or picking a core text apart** (splitting the
  stamp, `dropFirst` on a mark, counting the digits of a rate to choose a
  wording: offer the wordings longest first and let `ink.fitting` choose by
  width). Take the text the core writes. If a wording is missing, ask for a
  core function and put the stand-in in the shim.
- **A clock time without its day.** An Earth threshold is said with
  `EarthText.when` (or `bezelWhen` on the bezel), which adds the day when
  it is not the day shown. The moment shown is cut to its second, a
  threshold rounded to its nearest.
- **Moving the cursor around the model.** `scrub(to:)` and `returnToNow()`
  stop the wave's coast; only the coast's own frames use
  `moveCursorWhileGliding(to:)`.
- **Expecting `clock.sync(at:)` everywhere.** In the first and last partial
  sync it throws `.outOfRange`; `clock.pentad(at:)` still answers.
- **Showing `CivilTime`, `Quantity`, `periodText` … in pure mode.** They are
  Earth units. Pure mode has `Span`, `BlinkRate` and `Notation/PureWording.swift`.
- **Using `Float.pi` for a carrier.** See `Arc.pi` above.
- **Scheduling a span that grows with `spanNextChange(from:to:)`.** It
  answers `nil` once the boundary has passed. An elapsed time, a past
  threshold on the lens (`−20ι 21λ`) and the NOW mark behind the cursor
  grow: `spanNextChange(since: origin, at: now)`.
- **Spelling a level's kind yourself** (`minor unit`, `major unit`,
  `between units`). The kind is `level.kind.text`, the core's word.
- **Comparing a returned instant with an exact boundary.** It is the first
  microsecond at or after it; SPEC prints milliseconds (`XCTAssertInstant`).
- **Accessibility or a gesture after `.designFrame`.** A placed view fills
  its parent: put `.accessibilityElement()`, labels and `Button` content
  before `.designFrame(rect)`, and convert gesture locations with
  `space.designPoint(_:)`.
- **Two spaces in a drawn string.** The mockup's SVG collapses them; SwiftUI
  does not. Write `"\(name) · \(quarter)"` with single spaces.
- **`Font.system` or `Font.custom` in a view.** Use the theme's styles. The
  system face is built once per size in `SystemFace` (building a font per
  frame cost a whole core before it was cached).
- **Judging type weight on a Mac render with font smoothing on.** macOS
  thickens light text on dark by about a fifth; the app turns smoothing off
  for its own process (`TextRendering`), so screen and snapshots match iOS.
- **Expecting "44λ" or "−6 236λ" at vector A.** The design's figures; the
  core says `43λ 21ν` (spans are counted, not rounded) and the drift in
  whole Flavons, cut, `−6 235λ` (−48 469.99 s is 6 235.6 Flavons), and the
  app shows the core's text.
- **`import Foundation` beside `import FractonicaKit`.** Foundation has its
  own `Unit`; import what you need (`import struct Foundation.TimeZone`) or
  write `FractonicaKit.Unit`.
- **Setting the cursor on a tap.** `scrub(to: model.instant)` leaves the
  present for a cursor that no longer follows the clock. A gesture scrubs
  only once it has moved (see `WaveScreen.slop`).
- **Lighting the wave from a multiplied phase.** Which half-arc is lit, and
  how far, comes from the running cycles (`NestRenderer.buildHalf`); the
  phase only places the cycle under the hairline.

## 8. What has been verified, and what has not

By running (stage 8, 2026-11-13, the same Xcode, XcodeGen and Mac; core
0.2.0 adopted):

- From a clean state, the whole check (`rm -rf build Fractonica.xcodeproj
  FractonicaKit/.build && Tools/build.sh && Tools/test-kit.sh &&
  Tools/test-app.sh && Tools/test-ui.sh && Tools/snapshot.sh`), exit 0:
  both builds with no warnings in our code (the one "warning:" line is
  Xcode's appintentsmetadataprocessor); 92 kit tests and 58 app tests, no
  failures; the UI tests on the iPhone 16 Pro, 2 passed and the iPad-only
  one skipped; 96 snapshots. Then `Tools/test-ui.sh "iPad (A16)"`: all 3
  passed. The empty `../core/.swiftpm/` was removed afterwards.
- A mutant: with the `spanNextChange(since:at:)` candidates taken out of
  `ClockSchedule`, `testEveryElapsedChangeIsAWake` and
  `testTheCursorOffsetChangeIsAWake` fail (`−0.25ν` shown where `<0.001ν`
  was still due to change); restored, they pass.
- Looked at: the lens title blocks at rungs 0, 6, 12, 13 and 62
  (`DEPTH 1 · LEVEL 0 · MAJOR`, `… · UNIT`, `… · SUB-BLINK`), the phone
  ladder at rungs 0, 6 and 62 and the desktop ladder in pure mode
  (`HELION · UNIT`, `ALPHA · MAJOR`, `SUB-BLINK`). No other drawn text
  changed with this core: the Earth texts at vector A have positive years,
  and the app shows no offset text. `docs/overview.png` and the
  `docs/screens/` pictures that are snapshots were redrawn from these;
  `ipad-now-earth.png`, `mac-window-*.png`, `now-iphone-se-earth.png` and
  `now-phone-pure-out-of-catalogue.png` were not (no kind word on them).

By running (stage 7, 2026-11-13, the same Xcode, XcodeGen and Mac; the
core's new functions adopted, the mode toggle's hit frame fixed):

- From a clean state, the whole check (`rm -rf build Fractonica.xcodeproj
  FractonicaKit/.build && Tools/build.sh && Tools/test-kit.sh &&
  Tools/test-app.sh && Tools/test-ui.sh && Tools/snapshot.sh`): both builds
  with no warnings in our code (the one "warning:" line is again Xcode's
  appintentsmetadataprocessor); 91 kit tests and 56 app tests, no
  failures; the UI tests on the iPhone 16 Pro (iOS 18.6), 2 passed and the
  iPad-only one skipped; 96 snapshots. Then `Tools/test-ui.sh "iPad (A16)"`
  (iOS 27.0): all 3 passed.
- A mutant: without the `frc_span_next_change` candidates in
  `ClockSchedule` the new `testEveryCountdownChangeIsAWake` fails (`6ν` was
  shown where `6.4ν` was due); with them it passes.
- The mode toggle: by synthetic taps (the simulator's tap and an XCUITest
  coordinate tap) on the ring of an iPhone 17 (iOS 26.5) and an iPhone 16
  Pro (iOS 18.6) the old frame toggled too, so the failure found by hand
  was NOT reproduced; what was measurably wrong was the frame's size (33.7
  points tall on the iPhone, 37 on an upright iPad). The frame now holds the
  word and the ring with a margin, 44 points or more (unit-tested for the
  SE, the mini, the 16 Pro, three iPads and a small Mac window), and
  `testTheModeRingToggles` taps the ring's centre, top and right edge and
  the word on the running app.
- Looked at: contact sheets of the 16 phone pictures and of the lens at
  rungs 0, 13, 29, 62 and the ladder at 29 and 62 in both modes, the
  desktop ladder in pure mode full size (λ `1 per 25 Blinks`, μ `1 per 5
  Blinks`), the scrubbed NOW and WAVE tops (`+3η 12ι` from
  `frc_format_span_signed`), an iPhone SE (375 × 667) NOW in Earth mode and
  NOW outside the catalogue; on the iPhone 17 simulator NOW, LADDER and
  WAVE in both modes. The drift reads `−6 235λ` on NOW and WAVE, the
  ladder's captions `sub-Blink · …` fit their rows, the Earth texts read as
  before (`THU 8 OCT 2026 · 12:00:00 UTC`, `12:56:12 · 56 min 12 s`, `9 OCT
  01:34:05`). The guide's pictures (`docs/overview.png`, `docs/screens/`)
  were redrawn from these snapshots, except the iPad and Mac-window
  captures (`ipad-now-earth.png`, `mac-window-*.png`), which are stage 6's
  and still show the drift as `−2η 23ι`.

By running (stage 6, 2026-11-12, Xcode 27.1, XcodeGen 2.45, this Mac;
simulators: iPhone 16 Pro on iOS 18.6, iPad (A16) on iOS 27.0):

- From a clean state (`build/DerivedData`, the generated project and the
  kit's `.build` removed): both builds, no warnings in our code (the one
  "warning:" line in the logs is Xcode's own appintentsmetadataprocessor);
  69 kit tests and 54 app tests, no failures (`build/final-check.log`); the
  UI tests on the iPhone (the iPad-only one skipped) and on the iPad (both),
  no failures.
- The scripts' exit status: with a fake `xcodebuild` that fails (exit 65),
  `Tools/test-app.sh` and `Tools/test-ui.sh` now exit 65 (they exited 0).
- The two kit mutants a reviewer found surviving (no second offset look-up
  in `CivilTime.instant(in:)`; `Instant(Date)` cutting instead of rounding)
  now fail the kit tests.
- The 96 snapshots at SPEC vectors A, B and C, at an instant outside the
  catalogue (Unix 100000000000 s), at the closing instant (`--cursor
  99999999999`), one day into the catalogue (`--t -11253709086`, a partial
  sync), and vector A in Europe/Paris; and the four screens in both modes
  at 375 × 667 (iPhone SE), 1024 × 1366 (portrait iPad, desktop
  arrangement), 735 × 920 (half of a laptop's screen) and at focus α in
  Earth mode. All were looked at on contact sheets, the changed places in
  full-size crops.
- On the simulators: every screen in both modes on the iPhone 16 Pro and
  the iPad (A16) (`Tools/simulator-shots.sh`); Earth mode shows no status
  bar.
- On the Mac: the live window at 1280 × 800 in Earth mode, captured twice
  six seconds apart: the date line read `22:54:27` and `22:54:33` at
  `date -u` 19:54:27 and 19:54:33 (GMT+3), the reading went `54λ 20ν` →
  `55λ 15ν`; and a live window of 735 × 920 (the phone arrangement).

Not exercised (no way to inject the input from a script without asking for
control of the desktop):

- On the Mac: the arrow keys, the scroll wheel and trackpad (including the
  new sideways swipe on WAVE), the menu shortcuts (including ⌘↩), Return and
  Escape, typing in "go to", the hover hints, dragging with the mouse,
  resizing a window while scrolling. The UI tests compile for the Mac but
  were not run there (the runner needs the Accessibility permission).
- On the simulator by a UI test: the pinch and the twist (their arbitration
  is unit-tested only), a tap on a counter ring, the tumblers, "go to", the
  ladder's long press and its refusal, the ladder's wheel and spine.
- VoiceOver itself, Reduce Motion, iPad Split View. (The owner has run the app by hand on a physical iPhone, 2026-11-13; no automated test has run on a device.)
- CPU after the nest cache: not measured again (stage 5: about 29 % of a
  core at focus 12, 4 to 5 % at the Helion).

Where the app differs from the design, knowingly:

- **The core's text wins over the design's figures:** `43λ 21ν` (design
  `44λ`), drift `−6 235λ` (design `−6 236λ`: the core cuts, the design
  rounded), `BETWEEN` (design `BETWEEN UNITS`, ruling 4), a level's kind in
  the core's word on the lens and the ladder (`DEPTH 7 · LEVEL 6 · UNIT`,
  `ALPHA · MAJOR`; design `MINOR UNIT`), WAVE (design
  TIMELINE), light-spans carry the word `light` (ruling 2). λ and μ now
  read `1 per 25 Blinks` and `1 per 5 Blinks` (ruling 3), from the core.
- **LADDER, phone:** rows add the kind and the unit name; the pure value
  column shows the length and "made of" under it; no band rail for a rung
  outside every band.
- **LADDER, desktop, pure:** the three columns spread over the width and
  slide back as the Earth columns fade in (our arrangement).
- **LENS:** Earth values stand beside the Fractonica ones; no `4 ⁄ P Saros`
  row and no `18 188.943 s` (no core formatter). A sub-Blink rung's period
  row is left out once the core writes it as the bound `<0.001ν` (from ρ,
  level 16); its rate says it (`ShimCoreGaps.spanIsLegible`).
- **WAVE:** the Earth date-time line is a row of six Earth tumblers and the
  lower screen slides 27 pt in Earth mode; the MOMENT / NOW caption is at y
  103, not 115.
- **Earth thresholds far away** read with their day (`9 OCT 01:34`,
  `3 FEB 2028`; on the bezel `27 SEP`, `JAN 2028`); the design shows only the
  Helion's same-day `END 12:56`.
- **iPad:** the desktop arrangement in every orientation, as §7 says; in
  portrait it is letterboxed with large empty bands above and below (no
  portrait arrangement exists in the design).
- **Other sizes:** the design is scaled uniformly; a wide window gets air,
  not a wider column, and the instrument is not capped at R = 0.24 × height.
  A phone smaller than the design gets its unused safe bands back and its
  engraved words held at 6.2 pt (they grow a little relative to the rest).
- **Focus levels the design never drew:** see "Any focus" above; at focus
  9–13 on the phone the counter rings are 3–5 pt apart.
- **Type:** the system face applies its own size-specific tracking;
  ring-letter knock-outs are pads, not outlines.
- **The app icon** is not in the design: the instrument's own hero ring.
