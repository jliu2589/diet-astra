# Diet Astra

A native SwiftUI app for diet, fitness, and long-term health tracking.

## Current state

An iPhone-only SwiftUI UI prototype with Today and Trends navigation. Today offers
day/week/month reviews, a meal timeline, weight check-ins, and simulated text/photo
meal entry. Trends uses native Apple Charts. Goals and Settings live in the profile
menu. The palette supports light and dark appearance.

A Demo badge identifies sample data. New demo meals and check-ins stay in memory
and reset on relaunch. Native camera capture and photo-library selection are available; photos stay in
memory with the selected day’s meals. No microphone, HealthKit, AI, backend, or
third-party packages are connected. Camera capture needs a physical iPhone; the
simulator offers library selection and an explanatory camera alert. The existing persistent weight journal is available through
the profile menu and stays separate from sample data.

## Run

Open `Diet-Astra.xcodeproj` in Xcode, select the `Diet-Astra` scheme and an
iPhone simulator, then run. The existing project targets iOS 27.0; use Xcode 27
or a compatible newer version. Running on a physical device requires signing setup.

Build from the command line:

```sh
xcodebuild -project Diet-Astra.xcodeproj -scheme Diet-Astra \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/Diet-Astra-Build CODE_SIGNING_ALLOWED=NO build
```

Run the focused storage checks on macOS (no test target or dependencies needed):

```sh
xcrun swiftc -parse-as-library Diet-Astra/WeightEntry.swift \
  Diet-Astra/WeightStore.swift Tests/WeightStoreChecks.swift \
  -o /tmp/Diet-Astra-WeightStoreChecks
/tmp/Diet-Astra-WeightStoreChecks
```

Check the deterministic prototype summaries and date behavior:

```sh
xcrun swiftc -parse-as-library Diet-Astra/Prototype/DemoDiary.swift \
  Diet-Astra/Prototype/TrendSummary.swift Tests/DemoDiaryChecks.swift -o /tmp/Diet-Astra-DemoDiaryChecks
/tmp/Diet-Astra-DemoDiaryChecks
```

SwiftUI previews cover the main light/dark interface, Trends, photo entry, the
calendar, and the existing weight journal. Preview data does not write to disk.

## Simulator review

1. Review Today, scroll the meals/movement sections, and tap a meal for details.
2. Use date arrows; tap the date to choose a day, week, or month. Future days show
   empty states. Missing sample weights offer an add action.
3. Tap +, enter a meal or insert sample dictation, then send. Watch processing and
   confirmation, and check that the selected day's meal list/totals update.
4. Tap the camera, take or choose a photo (or keep the sample), add optional
   context, submit, and tap Done. Tap its thumbnail in that day’s Meal photos gallery.
5. Switch to Trends and compare all four metrics across 1 week, 4 weeks,
   3 months, 6 months, and 1 year. All compares three lines as percentages of goals.
   The histogram shows daily calories below/above target, excluding today.
6. Open the menu for Goals, Settings, and the separate saved weight journal.
7. Check dark appearance, larger text, and keyboard dismissal on your iPhone size.

The iPhone simulator build and all seven interaction scenarios pass: calendar modes,
menu/Goals/Settings, weight editing, all trend metrics/ranges, text/sample-voice
meals, photo submission with meal details, and library import into the daily gallery. Deterministic diary and weight
storage checks pass too. Photo context editing hides the preview while the keyboard
is open so the input remains visible. Demo changes reset when the app relaunches.

Run the interaction suite (one simulator at a time):

```sh
xcodebuild -jobs 1 -project Diet-Astra.xcodeproj -scheme Diet-Astra \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test
```

## Project notes

- [Product scope](docs/PRODUCT.md)
- [Design and implementation decisions](docs/DESIGN.md)
- [Development rules](AGENTS.md)

Source of truth: [GitHub repository](https://github.com/jliu2589/diet-astra).
Next step: test camera capture on a physical iPhone; simulator photo-library import is verified.
