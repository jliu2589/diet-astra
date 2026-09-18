# Diet Astra

A native SwiftUI app for diet, fitness, and long-term health tracking.

## Current state

A minimal app shell with Today, Food, Weight, Workouts, and Settings tabs.
Each screen contains placeholder content; logging and persistence are not implemented.
There are no third-party dependencies or service integrations.

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

No test target exists yet.

## Project notes

- [Product scope](docs/PRODUCT.md)
- [Design and implementation decisions](docs/DESIGN.md)
- [Development rules](AGENTS.md)

Source of truth: [GitHub repository](https://github.com/jliu2589/diet-astra).
The smallest next step is manual weight entry with local persistence.
