# TinyLunch

Native SwiftUI iPhone app for local food calorie estimates. English only. Meal data is saved explicitly on-device, without photos; history supports viewing and deletion.

## Current status

The Swift app shell, photo import and camera integration, editable estimate review, calorie arithmetic, protected local history, and on-device image analysis are implemented. No normal app flow returns fixture calories.

Photo analysis uses Apple's on-device `SystemLanguageModel(useCase: .general)` with the iOS 27 `Attachment` API. There is no Private Cloud Compute path and no remote nutrition lookup.

**Tooling.** Building this tree requires Xcode 27 and the iOS 27.0 SDK (`/Applications/Xcode.app`, build 27A266a). The minimum OS is iOS 27.0, taken from the `Attachment` availability annotation. Photo analysis needs Apple Intelligence with on-device vision.

The bundle identifier is `com.rgllm.tinylunch` on team `F86KMMECSR`. Automatic signing is on. Confirm the Apple Distribution certificate in Xcode before the first App Store upload.

## Build and test

Requires Xcode 27 and XcodeGen. No third-party runtime packages.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project TinyLunch.xcodeproj -scheme TinyLunch -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath .build build
xcodebuild -project TinyLunch.xcodeproj -scheme TinyLunch -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath .build test
```

Open `TinyLunch.xcodeproj` with Xcode 27 and run the TinyLunch scheme. If the on-device model or its vision capability is unavailable, the app explains that and keeps History usable. In Debug only, the `--example-meal` launch argument opens a draft labeled as example data for review testing. UI tests use a separate temporary store through `--ui-testing`; `--reset-history` resets only that test store.

## App Store

Listing copy, review notes, privacy answers, and remaining submission steps: `docs/app-store.md`. Privacy and support are published at https://engino.pt/privacidade.

```sh
./scripts/capture-screenshots.sh   # 6.9-inch PNG set in docs/screenshots/
./scripts/archive.sh               # Release archive + IPA in .build/
```

Upload from Xcode Organizer (Distribute App → App Store Connect), or dispatch `.github/workflows/testflight.yml`. That workflow uses the release Xcode 27.0 iOS 27.0 SDK on the `xcode-27` runner, keeps the app iPhone-only, and cloud-signs with the App Store Connect API key. A local `scripts/archive.sh` export still needs an Apple Distribution certificate; this machine currently has only `Apple Development: Rogerio Moreira`. Prepared store version is 1.0.0 (build 25). Build 23 was rejected for a beta SDK and iPad support.

## Data and privacy

- Food energy is a model estimate. Swift calculates `grams * kcalPer100g / 100` and the known-item subtotal. Unknown values remain unknown.
- Portion sanity bounds are greater than zero through 10,000 g; energy bounds are zero through 1,000 kcal per 100 g. These prevent invalid arithmetic, not inaccurate model judgments.
- `MealStore` writes a versioned JSON archive atomically in Application Support/TinyLunch, using complete file protection and excluding its directory from backups. There is no CloudKit, backend, analytics, or network client.
- The archive contains meal IDs, timestamps, food data, assumptions, estimator version, each item's energy basis, and optional catalog id and version. This version saves every item as estimated and leaves the catalog fields empty. Archives written before those fields still open, and each omitted basis is read as estimated, without rewriting the file. It contains no images or photo identifiers. Deleting a saved meal removes it from the archive. Device-only history is lost when the app is removed and is not backed up.
- Photo selection uses PhotosPicker; camera access is requested only on capture. Images remain in memory and are released after successful analysis or discard. An iCloud library image may need a system download to import.
- Model downloads are managed by Apple. Real offline inference, memory/thermal behavior, and camera permissions require device verification.

## Next implementation gate

1. Run photo analysis on the physical iPhone after it is connected. Repeat in airplane mode after Apple's model assets are installed. Record device, OS, model availability, and whether vision is present.
2. Evaluate real meals and non-food inputs. Establish quality thresholds with Rogério before claiming recognition accuracy.
3. Verify the uploaded build against the release source. Apple opened iOS 27 App Store submissions on 9 September 2026; this checkout now builds with Xcode 27.0 (27A266a).

## Verification on 20 September 2026

`xcodebuild -project TinyLunch.xcodeproj -scheme TinyLunch -destination 'platform=iOS Simulator,id=D55EFB4A-5EDE-4609-8350-81974DE9AB65' -derivedDataPath .build test` passed four unit tests and five UI tests on iPhone 17 Pro Max, iOS 27.0. Four screenshot-generation tests were intentionally skipped because capture mode was not enabled.

`xcodebuild -project TinyLunch.xcodeproj -scheme TinyLunch -configuration Release -destination 'generic/platform=iOS' -archivePath .build/TinyLunch-release.xcarchive -allowProvisioningUpdates archive` succeeded. Export with `Config/ExportOptions.plist` failed with `No Accounts` and no matching distribution signing certificate. The archive is not an uploaded build.

App Store Connect contains TinyLunch (`6811014228`) with build 23, version 1.0.0, uploaded on 12 September. Apple rejects that build for review because it uses a beta SDK; it also includes iPad support. A fresh iPhone-only build 24 archive succeeded at `.build/TinyLunch-build24.xcarchive` using Xcode 27.0 (27A266a). Upload is pending Xcode account and distribution signing setup. Physical-device inference remains unverified.

TODO: add a licensed bundled nutrition database later. It is not required for the initial model-based estimator. See `docs/nutrition-catalog.md` for the dataset and matching exploration.

## Verification on 8 September 2026

Inspected Xcode 27.0 (27A5252f) iOS 27.0 SDK `FoundationModels.swiftinterface`: `Attachment` and `LanguageModelCapabilities.Capability.vision` are annotated `@available(iOS 27.0, ...)`. Xcode 26.6 (17F113) / iOS 26.5 still has no image `Attachment` API.

`xcodebuild -project TinyLunch.xcodeproj -scheme TinyLunch -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath .build test` with Xcode 27.0 (27A5252f) passed on the iPhone 17 simulator running iOS 27.0: four unit tests and five UI tests. The iOS 27 simulator may report the on-device model as available; tests no longer require a permanent unavailable banner. Simulator success is not proof of device inference.

Not yet verified on a physical device: real image inference, real text-model estimates, airplane-mode inference, camera permission handling, VoiceOver interaction, and thermal/performance behavior. UI fixtures are developer test data, not proof of food recognition.
