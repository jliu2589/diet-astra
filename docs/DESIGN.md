# Design

## App shell

Use native SwiftUI navigation, system typography, SF Symbols, and system colors
to support familiar behavior, Dynamic Type, accessibility, and light/dark appearance.

| Tab | Intended purpose |
| --- | --- |
| Today | Daily calorie, macro, and activity overview |
| Food | Meal input and editable nutrition details |
| Weight | Weight history, trends, goals, and projections |
| Workouts | Strength exercises, sets, reps, weight, and intensity |
| Settings | App preferences |

Each tab currently has a navigation title and a native placeholder describing
its future purpose. No sample health values or inactive action buttons are shown.

## Bootstrap decisions

- Retain the existing Xcode project, app entry point, assets, and build settings.
- `MyApp` presents `ContentView`, which owns the five-tab `TabView`.
- Give each tab a small, separate SwiftUI view with its own `NavigationStack`.
- Add no models, view models, repositories, services, persistence, or dependencies
  until a working feature needs them. Keep future business logic out of views
  where practical.
- Keep deterministic calculations in Swift and preserve important decisions here
  as features are implemented.

Build the smallest usable vertical slice first. The next slice is manual weight
entry with local persistence; its storage choice should be documented when implemented.

## References

Store future visual references in `design/references/`. The directory is empty
apart from a Git placeholder; no custom visual system is established yet.
