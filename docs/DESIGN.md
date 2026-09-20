# Design

## Direction: ink and sage

An iPhone-only interface for a calm daily review. Warm off-white (deep charcoal
in dark mode), a restrained sage accent, native system body typography, and serif
numerals/headings establish hierarchy without a wall of dashboard cards.

A card-heavy alternative was considered. The chosen layout uses one shared
nutrition surface, open weight/activity rows, and divided meal rows, making the
page easier to scan. Components use SF Symbols, semantic secondary text, native
materials, accessible labels, and generous primary touch targets. The meal
composer respects Reduce Motion and uses a short spring transition otherwise.

## Navigation and hierarchy

- Native Today and Trends tabs are the two primary destinations. The profile
  menu opens as an iPhone sheet, with a sample identity, Goals, Settings, and the
  existing saved weight journal. A persistent Demo badge identifies the prototype.
- Today starts with the selected date and adjacent period arrows. Calories lead
  a cohesive nutrition summary; protein, carbs, and fat share the same baseline
  and visual language. Weight follows, then chronological meals and movement.
- Tapping a meal opens a detail sheet. Tapping weight opens an in-memory sample
  check-in; missing measurements show a clear add action.
- The calendar sheet supports Day, Week, and Month. Week mode highlights a whole
  row and offers a row selection arrow. An explicit Show action applies the
  selection; closing cancels. Month arrows allow navigation across years.
- Weekly/monthly intake uses daily averages over logged days, excluding missing
  days and including a partially logged today. Workout count and lifted volume
  are totals. Weight shows the average and first-to-last measurement change.
  Labels explain these denominators and comparisons.
- Trends shows one metric at a time: weight, calories, training, or All. All overlays weekly weight and calorie averages
  and workout counts as percentages of their respective sample goals (140 lb,
  2,500 kcal/day, four workouts/week), with a legend and explicit units.
  A daily calorie-deviation histogram follows every metric; it excludes today
  and unlogged days, and counts below/above/exact-target days.
  One-week, four-week, three-month, six-month, and one-year ranges apply to the
  charts (7/28/90/180/365 sample days). Training’s one-week view shows the current Monday–Sunday week with daily
  bars centered on categorical weekday labels. Longer ranges use weekly totals
  and weekly ticks, thinning labels for longer ranges. Training's sample squat progression also
  follows the selected range. Apple Charts
  provides all chart rendering; no chart dependency is added.

## Meal interaction prototype

- A floating circular Add Meal action expands into a compact focused composer
  above the safe area/keyboard. The camera action sits directly above it.
- Text entry and a labeled sample-dictation action feed a simulated submission.
  Empty text cannot be submitted. Processing and success states precede return
  to the collapsed button; the meal and totals update for the selected day.
- Photo entry uses a bundled SwiftUI illustration clearly labeled as a sample
  image, optional context, and sample dictation. Processing prevents duplicate
  submission/dismissal, then presents a confirmation with Done.
- Every newly submitted meal uses the same sample estimate (620 kcal, 42 g
  protein, 65 g carbs, 21 g fat). This is explicitly disclosed in meal details;
  the prototype does not interpret the input. Editable nutrition confirmation
  must be implemented before any real AI meal-saving feature is introduced.
- Native photo-library selection and camera capture are now available at the user's
  request. The camera requests permission only when tapped; simulator/unavailable
  and denied-access cases explain the alternative. PhotosPicker exposes only the
  selected photo. No microphone, health, AI, or backend integration is added.
- Photos are resized to at most 1,600 pixels, re-encoded without original metadata,
  and retained in memory on their meal. Today's gallery follows the selected date;
  thumbnails open meal details. Photo meals without an imported image retain the
  explicitly labeled sample illustration. Photos, demo meals, and check-ins reset
  on relaunch; nothing is uploaded or saved to the user's photo library.

## Implementation boundary

`ContentView` owns one observable `DemoDiary`, shared by Today and Trends.
`DemoDiary` supplies 366 deterministic days relative to the launch date and small
in-memory mutations. Calendar-based date arithmetic handles local day boundaries.
Simple value types and `ReviewSummary` keep aggregation outside SwiftUI views.
Reusable UI is limited to the shared palette, nutrition summary, section heading,
round action button, and meal submission states. No service/repository layer.

The Xcode target supports iPhone only. Existing Food/Workouts placeholder files
remain outside primary navigation. Real on-device weights and sample data never
merge. There is no automatic commit, deployment, or backend work in this phase.

## Existing manual weight tracking

- `WeightEntry` stores an ID, timestamp, and pounds; `WeightStore` owns validation,
  ordering, add/delete operations, and persistence.
- The saved weight journal remains reachable through the profile menu. It stores
  JSON at `Application Support/DietAstra/weights.json` inside the app sandbox,
  using atomic writes and complete file protection on iOS. Failed reads block
  writes, preserving the existing file; failed writes leave displayed data intact.
- Device backups may include that file; the app does not sync or send it elsewhere.
- Positive pounds with up to two decimal places use the locale decimal separator.
  Multiple measurements per day are retained. Previews use in-memory storage.

## Review boundary

Review the interface in the iPhone simulator before adding functional integrations.
Check Today scrolling, date arrows, day/week/month selection, empty future days,
meal details, composer focus/dismissal, simulated voice, photo processing/success,
Trends categories/ranges, Goals, Settings, dark mode, and larger text sizes.

The app builds and runs on the iPhone 17 simulator. Native UI tests verify the seven
interaction scenarios: tabs/metrics/all five ranges; menu/Goals/Settings; date
arrows and calendar modes; typed/sample-voice meals; photo submission and meal
details; mock-weight editing; and camera-unavailable/library-import/gallery flow.
The physical-iPhone target also builds, but hardware camera capture still needs
a device test. Combined charts and the calorie histogram were screenshot-reviewed. Demo aggregation/date checks and the separate
weight-storage checks also pass. Screenshot review caught keyboard overlap in the
photo composer: the illustration now hides while context is focused, and a Done
editing action dismisses the keyboard. Dark mode and larger text remain manual
visual review items; the interaction tests use the default simulator appearance.

Future visual references belong in `design/references/`.
