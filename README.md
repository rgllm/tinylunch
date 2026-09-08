# Nosh

Native SwiftUI iPhone app for local food calorie estimates. English only. Meal data is saved explicitly on-device, without photos; history supports viewing and deletion.

## Current status

The Swift app shell, photo import and camera integration, editable estimate review, calorie arithmetic, protected local history, and on-device image analysis are implemented. No normal app flow returns fixture calories.

Photo analysis uses Apple's on-device `SystemLanguageModel(useCase: .general)` with the iOS 27 `Attachment` API. There is no Private Cloud Compute path and no remote nutrition lookup.

**Tooling is currently beta.** Building this tree requires Xcode 27.0 (this machine has `/Users/rgllm/Desktop/Xcode-beta.app`, build 27A5252f) and the iOS 27.0 SDK. The shipping Xcode 26.6 / iOS 26.5 SDK still lacks `Attachment`. The minimum OS is iOS 27.0, taken from that availability annotation.

The physical iPhone (`iPhone de Rogério`) reports iOS 27.0 but was offline during this change, so live inference, airplane-mode inference, and camera permission behavior are not yet verified on hardware. Simulator tests do not prove on-device vision.

The `local.nosh.app` bundle identifier is a local development placeholder; distribution requires the final identifier and signing team.

## Build and test

Requires Xcode 27 and XcodeGen. No third-party runtime packages.

```sh
export DEVELOPER_DIR=/Users/rgllm/Desktop/Xcode-beta.app/Contents/Developer
xcodegen generate
xcodebuild -project Nosh.xcodeproj -scheme Nosh -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath .build build
xcodebuild -project Nosh.xcodeproj -scheme Nosh -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath .build test
```

Open `Nosh.xcodeproj` with Xcode 27 and run the Nosh scheme. If the on-device model or its vision capability is unavailable, the app explains that and keeps History usable. In Debug only, the `--example-meal` launch argument opens a draft labeled as example data for review testing. UI tests use a separate temporary store through `--ui-testing`; `--reset-history` resets only that test store.

## Data and privacy

- Food energy is a model estimate. Swift calculates `grams * kcalPer100g / 100` and the known-item subtotal. Unknown values remain unknown.
- Portion sanity bounds are greater than zero through 10,000 g; energy bounds are zero through 1,000 kcal per 100 g. These prevent invalid arithmetic, not inaccurate model judgments.
- `MealStore` writes a versioned JSON archive atomically in Application Support/Nosh, using complete file protection and excluding its directory from backups. There is no CloudKit, backend, analytics, or network client.
- The archive contains meal IDs, timestamps, food data, assumptions, and estimator version. It contains no images or photo identifiers. Deleting a saved meal removes it from the archive. Device-only history is lost when the app is removed and is not backed up.
- Photo selection uses PhotosPicker; camera access is requested only on capture. Images remain in memory and are released after successful analysis or discard. An iCloud library image may need a system download to import.
- Model downloads are managed by Apple. Real offline inference, memory/thermal behavior, and camera permissions require device verification.

## Next implementation gate

1. Run photo analysis on the physical iPhone after it is connected. Repeat in airplane mode after Apple's model assets are installed. Record device, OS, model availability, and whether vision is present.
2. Evaluate real meals and non-food inputs. Establish quality thresholds with Rogério before claiming recognition accuracy.
3. Revisit the minimum OS if a later public Xcode ships the same `Attachment` API without remaining on the 27.0 beta toolchain.

TODO: add a licensed bundled nutrition database later. It is not required for the initial model-based estimator. See `docs/nutrition-catalog.md` for the dataset and matching exploration.

## Verification on 8 September 2026

Inspected Xcode 27.0 (27A5252f) iOS 27.0 SDK `FoundationModels.swiftinterface`: `Attachment` and `LanguageModelCapabilities.Capability.vision` are annotated `@available(iOS 27.0, ...)`. Xcode 26.6 (17F113) / iOS 26.5 still has no image `Attachment` API.

`xcodebuild -project Nosh.xcodeproj -scheme Nosh -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath .build test` with Xcode 27.0 (27A5252f) passed on the iPhone 17 simulator running iOS 27.0: four unit tests and five UI tests. The iOS 27 simulator may report the on-device model as available; tests no longer require a permanent unavailable banner. Simulator success is not proof of device inference.

Not yet verified on a physical device: real image inference, real text-model estimates, airplane-mode inference, camera permission handling, VoiceOver interaction, and thermal/performance behavior. UI fixtures are developer test data, not proof of food recognition.
