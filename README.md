# Diet Astra

Private, native iPhone nutrition, weight and strength tracking. The approved ink/sage
Today and Trends interface is retained. V1 implementation is in progress toward
live acceptance: backend/device configuration and end-to-end verification remain.

## Run

Use Xcode 27 and iOS 27 (the project's existing deployment target).

1. Follow [V1 setup and acceptance](docs/V1.md): configure Supabase, apply the
   migration, deploy the meal function, and create private accounts.
2. Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig`, and fill in
   only the Supabase URL and publishable key. The local file is ignored by Git.
3. Open `Diet-Astra.xcodeproj`, select the Diet-Astra scheme and run on an iPhone
   simulator. Real camera/Health/dictation validation requires a signed iPhone build.

Simulator builds must keep signing enabled (local ad-hoc signing requires no paid
Apple membership). Disabling signing removes the simulated Keychain entitlement
and prevents Supabase from storing or retrieving sessions.

Without configuration the app shows a setup screen, not invented health records.
The original visual prototype remains available only in Debug with `--demo` as a
launch argument. V1 forms have a separate Debug UI-test harness; it cannot fake a
successful account save. Neither harness is a substitute for live acceptance.

```sh
xcodebuild -jobs 1 -project Diet-Astra.xcodeproj -scheme Diet-Astra \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/Diet-Astra-V1-Build CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

## Checks

Run `bash Tests/run-checks.sh` for deterministic Swift and server arithmetic checks.
The migration/RLS checks need a disposable PostgreSQL cluster; see `docs/V1.md`.

```sh
xcodebuild -jobs 1 -project Diet-Astra.xcodeproj -scheme Diet-Astra \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

- [Product](docs/PRODUCT.md)
- [Design and architecture](docs/DESIGN.md)
- [V1 setup, security, mathematics and verification](docs/V1.md)
- [Development rules](AGENTS.md)

Repository: [jliu2589/diet-astra](https://github.com/jliu2589/diet-astra).
