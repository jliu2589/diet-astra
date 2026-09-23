# Design

## Ink and sage

Preserve the warm off-white/deep-charcoal palette, sage accent, native system body
type and serif headings/numerals. Today and Trends remain the primary tabs. Native
sheets, forms, menus and date navigation support editing without a redesign.
The profile sheet contains actual profile details, Goals, Settings, weight history
and strength history. The badge reads PRIVATE for accounts and DEMO for fixtures.

Today leads with the date and nutrition summary, followed by weight, meals and
movement. Meal rows open editable structured foods. Add and camera actions open
native composers with clear Analyze → Review → Save stages. This replaces immediate
mock saves: the extra review step is required to correct uncertain estimates.
Native form editors favor legibility, system keyboards and accessibility over
custom controls. Destructive records require confirmation; failed saves retain drafts.

## Dates and charts

Calendar days use a Gregorian calendar in the device time zone. Weeks begin Monday;
week rows, week summaries and training chart buckets share that definition. Food and
strength logs retain their selected civil date across travel; timestamped weight
and Health measurements appear in the device's current local day.

Week/month nutrition averages use days with meals, including partial logs. Weight
averages use days with a measurement; change compares first/last. Strength count,
volume and steps are totals. Apple Health workout counts stay separate from logged
strength sessions, avoiding double counting.

Trends includes Weight, Calories, Protein, Training and All. All retains the three
original series, expressed as percentages of saved goals. A zero training goal
omits its percentage series. Training's one-week chart has seven categorical bars
aligned Mon–Sun; longer ranges aggregate weekly. Missing nutrition/weight points
are omitted, with empty states. Lines connect available measurements, not inferred
missing values. Calorie deviations exclude today and incomplete days.

## Architecture

`AppRoot` owns one observable `AccountStore`. It observes Supabase Auth, resets all
in-memory account state on identity change, and loads owned records atomically.
`Backend` wraps the official Supabase Swift SDK (2.55.2). Models and deterministic
calculations live in `Core/Records.swift` and `Core/ProgressMath.swift`; views invoke
store operations, not database queries. RLS is the authorization boundary.

The existing `DemoDiary` is retained as a lightweight presentation adapter for
Today/Trends. Authenticated stores initialize it with **no sample data**, then map
saved records into it. This avoids replacing the approved interface while keeping
backend models separate. Debug-only `--demo` seeds the old prototype for regression
tests. `--v1-ui-check` opens real editors without an account; all saves fail safely.

Saves are serialized, use stable UUIDs and update the UI only after server success.
In-memory records survive a failed refresh; no persisted account cache or offline
queue. The SDK persists auth tokens in Keychain. Old `WeightStore` JSON is left
untouched and separate; no automatic assignment/upload into a signed-in account.
The original journal is accessible from the Debug prototype. Migration of that
legacy file is not automatic and must be explicitly owned/reviewed before import.

`HealthService` requests only bodyMass, stepCount, workout, activeEnergyBurned and
appleExerciseTime read access. Results stay in memory and clear on sign out. A local
per-account opt-in flag (no health values) enables refresh on launch/foreground and
pull-to-refresh. Disconnect clears the flag and loaded Health records; system
permissions are managed in Health. Manual weight days override Health days.
The Apple Health screen is reachable from Today, the profile menu and Settings;
it includes selected-day readings, workout type/time/duration/source, last-read
status and scale setup instructions. Missing values are not presented as zero.
Daily energy/exercise use HealthKit statistics, not sums of overlapping raw samples.
Workout lists are separate from strength logs and assigned to their start day.
`Dictation` requests microphone/speech only when starting, requires on-device
recognition, stops when dismissed, and passes reviewed text to the same composer.

The meal Edge Function authenticates each request, enforces an atomic per-user
quota, validates input/output, calls OpenAI with structured output and `store:false`,
then deterministically scales estimates to portions. No photos or raw prompts are
written to the database. Provider retention remains separate from Astra storage.

## References and validation

No design reference assets were present under `design/references/`; the existing
working interface and the user's approved screenshots were the reference.
See [V1](V1.md) for configuration, tested behaviors, limitations and acceptance.
