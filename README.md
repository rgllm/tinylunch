# TinyLunch

TinyLunch is an iPhone app that estimates the calories in a meal from a photo. Take a picture or choose one from your library. The app suggests the foods it sees, a portion in grams, and an energy estimate you can correct before saving. Saved meals appear in History, where you can open or delete them. The interface is English.

## Privacy

TinyLunch does not collect data. Its privacy manifest sets tracking off and lists no collected data types. Food photos and meal details stay on the iPhone.

Photo and text estimates use Apple’s on-device Foundation Models framework, `SystemLanguageModel(useCase: .general)`. The interface calls this Apple Intelligence. A photo is attached with `Attachment` when that model reports the vision capability. Apple may download the model assets through the system before the first estimate. Choosing an iCloud photo may also need a system download before import.

A meal is stored only when you tap Save. History is a JSON file under Application Support, written with complete file protection and excluded from backups. It keeps foods, portions, preparation assumptions, and estimates. It does not keep photos. Removing the app removes that history.

Privacy policy: https://tinylunch.engino.pt/privacy

## Requirements

- Xcode 27.0. `project.yml` sets `xcodeVersion` to 27.0. The iOS test workflow runs on the `xcode-27` runner and selects an Xcode whose iOS Simulator SDK is 27.0 or newer.
- iOS 27.0. `project.yml` sets `deploymentTarget.iOS` to 27.0, and the Xcode project sets `IPHONEOS_DEPLOYMENT_TARGET` to 27.0.
- iPhone. `TARGETED_DEVICE_FAMILY` is 1.

Photo analysis needs Apple Intelligence on that iPhone. The on-device model must be available and include vision. When the device is not eligible, Apple Intelligence is turned off, the model is still preparing, or vision is unavailable, TinyLunch explains the limitation and History stays available.

## Build and run

Open `TinyLunch.xcodeproj` in Xcode 27 and run the TinyLunch scheme.

Build from the command line for an iPhone simulator on iOS 27.0:

```sh
xcodebuild \
  -project TinyLunch.xcodeproj \
  -scheme TinyLunch \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the tests with the same project and scheme. The test command matches the iOS workflow: both test bundles, screenshot tests skipped, signing disabled:

```sh
xcodebuild \
  -project TinyLunch.xcodeproj \
  -scheme TinyLunch \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:TinyLunchTests \
  -only-testing:TinyLunchUITests \
  -skip-testing:TinyLunchUITests/ScreenshotTests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

If that simulator is not installed, use another iPhone simulator on iOS 27.0 or later. The workflow picks an available one.
