# Food identification and catalog verification

## Environment

Checked on November 10, 2026. This machine selects `/Library/Developer/CommandLineTools`. It has Swift 6.4 targeting arm64 macOS and the macOS 27 SDK. Xcode is absent from `/Applications`. `xcodebuild -version` and `xcrun simctl list devices booted` fail because the selected tools do not include Xcode or simctl. XCTest is also absent from the Command Line Tools installation. A Foundation Models type-check attempt against the macOS 27 SDK fails because this installation lacks the FoundationModelsMacros compiler plugin.

The existing iOS 27 deployment target and Foundation Models image API are unchanged. Their current iPhone availability and Xcode release status were not reverified here. No physical iPhone inference, airplane-mode test, accuracy evaluation, or simulator result is claimed.

## Checks run here

- `scripts/test-domain.sh` compiles the production `Meal`, `MealEstimateMapping`, and `NutritionCatalog` code in Swift 6 mode and runs executable assertions. It covers recognition alternatives, duplicate alternative removal, unknown and no-food outcomes, arithmetic, local matching, ambiguity, preparation compatibility, model fallback, provenance invalidation, gram scaling, true zero energy, and JSON snapshot isolation after catalog replacement. It reads the actual bundled catalog and verifies the USDA banana record's source value.
- `python3 scripts/test_nutrition_builder.py` checks the converter's energy selection order, rejection of missing or invalid energy and kJ values, true zero energy, source IDs, and preparation extraction.
- `python3 scripts/build_nutrition_catalog.py` verifies both pinned archive checksums and builds the resource. Rebuilding to a separate directory produces identical catalog and manifest bytes.
- `swiftc -frontend -parse TinyLunch/*.swift TinyLunchTests/*.swift TinyLunchUITests/*.swift` checks syntax. It does not type-check the SwiftUI, UIKit, or Foundation Models integration.
- `plutil -lint TinyLunch.xcodeproj/project.pbxproj` checks project syntax. A path audit also verifies that new source and resource references resolve beneath their target groups.
- `git diff --check` checks whitespace.

The portable check does not test iOS protected file storage. Attempting the existing XCTest suite through a temporary Swift package fails because XCTest is missing. A macOS persistence probe also cannot write the app's iOS complete-protection store. These failures are environment limitations, not passing persistence tests.

## Added iOS tests, execution blocked

`NutritionCatalogTests` adds exact and ambiguous matching, raw/cooked/breaded separation, unknown fallback, zero and invalid energy, correction invalidation, catalog replacement without changing saved history, and bundled-resource loading.

`AppModelTests` adds catalog selection while Apple Intelligence is off, portion changes without generation, fresh model fallback after a food correction, failed correction recovery, and cancellation that cannot overwrite a new meal.

The existing unit tests now also cover recognition alternatives and independent validation of grams and energy. UI tests add visible alternative selection without duplicate food and a catalog choice while Apple Intelligence is off. The rest of the existing unit and UI suites remain in the scheme.

Run the README's complete `xcodebuild test` command with Xcode 27 and an iOS 27 simulator. This remains required before distribution. Check the new editor at large text sizes and with VoiceOver. Run consented meal photos on a supported iPhone, including offline inference after model assets are installed, before claiming improved recognition accuracy.

## Review

A read-only Codex review found remaining callers of the old correction API and unsafe automatic matching of plain foods with preparation modifiers. The callers were migrated, and executable checks now cover peanut-butter toppings and uncertain banana/plantain descriptions. Four redundant internal comments were removed. A review from another model family could not run because the configured Claude and Grok provider instances are disabled.
