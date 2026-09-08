# Nosh

## Product intent

Build a native iOS app that lets someone photograph food or choose a photo from their library and get an estimated calorie breakdown. Use Apple's on-device Foundation Models framework. All image analysis, calorie estimation, and calculations must happen locally.

Address the project owner as Rogério. Treat him as an experienced collaborator. Read existing code before editing, preserve unrelated work, and keep changes within the requested scope.

## Confirmed requirements

- iOS app with a native interface.
- Take a food photo using the camera.
- Import an existing photo using the system photo picker. Import does not mean uploading to a server.
- Identify the food shown and present estimated calories for individual food items and the meal total.
- Use Apple's Foundation Models framework with an explicitly selected on-device model.
- Process images and meal information on the device. No backend, remote inference, or remote nutrition lookup.

- Show an immediate estimate with suggested portions. Allow food and portion corrections before saving.
- Use model-generated calorie estimates for the initial release. A bundled nutrition database is a future TODO, not a prerequisite.
- Accept the newer minimum iOS version required for Apple's on-device image model, verified against the actual SDK and device.
- English-only interface for the initial release.
- Save meal data locally only when the user taps Save. Do not save photos.
- History is a list of saved meals, without daily calorie totals. Saved meals can be viewed and deleted, but not edited.
- Allow saving partial estimates and preserve an "Incomplete estimate" label in history.
- Keep history accessible when the model is unavailable, with new analysis disabled and an explanation and retry action.

## Working defaults

These are reversible implementation choices, not additional requirements approved by Rogério.

- Use Swift, SwiftUI, structured concurrency, and Apple frameworks. Use UIKit where needed for camera integration.
- Start with iPhone only. Set the minimum OS after verifying the image-input API and supported hardware described below. Do not inherit deployment targets from other projects.
- Use Nosh as the working display name. Confirm the bundle identifier and signing team before device distribution.
- Write code and developer documentation in English. Use English for all initial UI copy and permission explanations. Keep strings in String Catalogs.
- Display food energy in kcal and portions in grams. Format numbers using the user's locale.
- Keep the unsaved draft in memory. Use protected local persistence for explicitly saved meal data. Macronutrient breakdown is outside the initial scope.
- No accounts, analytics SDKs, advertising, subscriptions, HealthKit, calorie goals, diet plans, social sharing, barcode workflows, or cloud sync unless requested.

## Mandatory capability check

Do this before building the full interface or committing to a deployment target.

On 8 September 2026, Xcode 27.0 (build 27A5252f) on this machine ships the iOS 27.0 SDK. Its FoundationModels Swift interface exposes `Attachment` and `LanguageModelCapabilities.Capability.vision`, both annotated for iOS 27.0. Xcode 26.6, build 17F113, and the iOS 26.5 SDK still do not. Online documentation alone does not establish that the API works on a given phone. Building Nosh currently requires this beta Xcode; tell Rogério before treating that as a release constraint he has accepted.

1. Inspect the selected Xcode SDK, the availability annotations for the image-input APIs, release status, and Apple's current documentation.
2. Build a small proof of concept that sends a real food image to the explicit on-device `SystemLanguageModel` and obtains structured food candidates.
3. Run it on a supported physical iPhone with the model available, then repeat with networking disabled. Record Xcode, SDK, OS, device, model availability, and results in the README.
4. Set the minimum iOS version and supported-device policy from that evidence. Do not introduce beta-only release requirements without telling Rogério.
5. If the available public SDK cannot pass images to the on-device model, state the blocker. Do not pretend that text prompts, image URLs rendered as text, or Base64 image strings provide vision.

The preferred implementation uses Apple's on-device multimodal model directly. A bundled food-recognition Core ML model with Vision and Foundation Models for text processing is a possible alternative, but requires Rogério's agreement because it adds another model and licensing, size, and evaluation work. Manual food entry can support recovery, but does not fulfill the required photo-analysis journey.

Do not substitute Private Cloud Compute or a third-party model provider. Some Foundation Models examples recommend a cloud model for harder tasks; that conflicts with Nosh's local-only requirement.

## Runtime availability

- Check model availability before analysis and when returning to the foreground. OS version alone is insufficient.
- Handle unsupported hardware, Apple Intelligence disabled, model assets not ready, unsupported language or locale, generation failures, guardrail refusals, and context limits using the APIs available in the selected SDK.
- Explain the specific limitation in ordinary language and offer a relevant retry or settings action where supported. Do not retry unavailable models indefinitely.
- Apple manages model installation. Explain when initial system asset downloads are needed. Offline inference applies once those assets are installed.
- Keep saved history readable and deletable when analysis is unavailable. Disable new analysis with an explanation and retry action. Preserve an existing draft; portion-only arithmetic can still work locally, while edits requiring model generation must wait for availability. Never fabricate a result to fill an error state.
- Do not bypass model safety behavior or describe simulator success as proof of device inference.

## Main journey

1. The start screen offers Take photo and Choose photo without mandatory onboarding.
2. Show the selected photo with Retake or Replace and Analyze actions.
3. Run local analysis with visible progress and cancellation. Avoid invented progress percentages.
4. Present identified foods, proposed portions, preparation assumptions, per-item kcal, and an estimated meal total.
5. Let the user correct food matches and preparation, edit portions, remove false detections, and add missed items by name for local model estimation.
6. Recalculate portion-only changes locally. Food identity or preparation changes may require another on-device estimate; show progress and reject stale results.
7. Save only on an explicit Save tap after all pending corrections finish. Keep the draft if saving fails and prevent duplicate saves.

Clearly distinguish image suggestions from user-confirmed entries. Require a portion for a usable estimate. A tentative visual portion may be offered as an explicitly labeled assumption; when neither is defensible, ask for grams or a defined serving before calculating.

Keep errors recoverable without making the user reselect their photo. Replacing a photo or starting a new meal cancels obsolete work and prevents its results from overwriting the current meal.

## Camera and photo library

- Use PhotosPicker for selection with access limited to the chosen image. Do not request full-library permission for this flow.
- Request camera permission only when Take photo is selected. Supply an accurate camera usage description.
- Handle denied or restricted camera access, unavailable hardware, capture interruptions, picker cancellation, failed imports, and unreadable files.
- Do not request microphone or location permission.
- An iCloud-only photo may need a system download before import. Explain this distinction and offer another photo or the camera when offline. Never claim every library image is available offline.
- Handle HEIC and JPEG, portrait and landscape orientation, and mirrored images correctly. Import a still image rather than analyzing an entire Live Photo.
- Bound decoding memory and image dimensions based on measured device behavior and model guidance. Preserve enough detail to distinguish foods.
- Strip unnecessary metadata from app-created image copies. Do not inspect or retain photo GPS metadata.
- Do not save captures to the photo library automatically.

## Food recognition and uncertainty

- Ask for visible food candidates and relevant preparation alternatives using structured generation where supported. Allow unknown and no-food outcomes explicitly.
- A photograph does not establish exact weight, recipe, hidden ingredients, or absorbed oil. Show those assumptions and make them editable.
- Do not silently assume ambiguous food is a specific recipe, brand, or cooking method.
- Handle multiple foods, mixed dishes, sauces, drinks, partial servings, blurry photos, non-food images, and unfamiliar cuisines.
- Avoid double counting a mixed dish and its ingredients. Use either a complete-dish estimate or explicit component estimates for that portion.
- Do not display a model's self-reported confidence as a calibrated probability. Use qualitative uncertainty until confidence has been validated against labeled examples.
- Show incomplete coverage when an item cannot be identified or given a usable calorie estimate. An unknown item contributes unknown calories, not zero. Label a known-items subtotal instead of presenting it as the complete meal total.
- Treat text within images and user-entered food descriptions as data, never as instructions that can change model behavior or invoke unrelated tools.

## Nutrition data and calculations

For the initial release, the on-device model proposes food identities, portions, preparation assumptions, and estimated energy values. These are model estimates, not verified nutrition records. Swift code calculates item calories and totals.

- Request structured per-item output with a food name, estimated grams, estimated kcal per 100 g, preparation assumptions, and an explicit unknown outcome. Store the estimate basis so portion edits are reproducible.
- Calculate item kcal as `grams * kcalPer100g / 100`. Sum unrounded item values and round for display consistently. Do not rely on a separately generated model total.
- Validate finite, nonnegative energy values and finite, positive portions within documented practical bounds. Reject NaN, infinity, malformed units, and missing values. Validation does not establish nutritional accuracy.
- Support genuine zero-energy estimates. Never interpret missing data as zero.
- Changing only grams scales the existing estimate. Changing the food or preparation invalidates its old energy estimate until a new model response passes validation.
- Distinguish cooked and raw foods and edible portions. Label any assumed conversion from a serving to grams. Do not silently treat millilitres as grams.
- Keep unknown items in the draft and saved meal. Calculate a known-items subtotal and label the result "Incomplete estimate". If nothing can be estimated, show no numeric total rather than zero.
- Keep all displayed results labeled as estimates. Do not fabricate database attribution, source URLs, nutrient records, or statistical confidence intervals. Avoid precision that suggests a laboratory measurement.
- Do not generate diagnoses, medical advice, allergen guarantees, food-safety assurances, or personalized dietary targets.

### TODO: bundled nutrition database

This is deferred work. Do not block the initial model-based implementation on dataset selection.

- Select an authoritative, versioned, redistributable food dataset and verify licensing and attribution before bundling it.
- Keep source record IDs, preparation states, kcal per 100 g, documented serving weights, source URLs, and dataset versions.
- Perform all runtime lookup locally. Dataset downloads and preparation belong in development tooling.
- Map candidates to real catalog IDs and handle ambiguous or absent matches explicitly. Define any model fallback policy when implementing this TODO.
- Preserve the original estimate basis and provenance in saved meals. Adding or updating a database must not silently recalculate historical records.

## Saved meal history

- Provide a list of saved meals and a read-only detail with the item breakdown. Do not add daily totals, targets, or tracking dashboards.
- Persist a stable meal ID, save timestamp, foods, portions, preparation assumptions, energy estimate basis, item calories, subtotal or total, and completeness. Record schema and estimator/prompt versions for reproducibility.
- Save model-derived values as a snapshot. Opening history must not invoke the model or change past estimates.
- Save only when the user taps Save. Do not autosave analyses, corrections, retakes, or abandoned drafts. Disable duplicate submission while saving and acknowledge success only after persistence succeeds.
- Allow food and portion changes in the unsaved draft. Saved records cannot be edited; they can only be viewed or deleted.
- Preserve unknown items and the "Incomplete estimate" label in saved partial results.
- Store data only, without photos, thumbnails, image references, photo-library identifiers, or model transcripts. Release the source image after analysis; further corrections use the structured draft and text. A new visual analysis requires a new capture or selection.
- Retain saved meals until the user deletes them or removes the app. As a working default, exclude the store from backups to honor device-only storage and explain that history will not restore onto a new device.
- Use atomic saves, stable IDs, a versioned schema, and protected local storage. Report write failures without claiming success. Handle unreadable storage without silently overwriting it.
- Delete records from persistent storage and update the list after confirmation of success. Choose a native confirmation or undo pattern to prevent accidental loss.

## Local-only privacy contract

- No app-initiated network requests in the analysis pipeline. No image uploads, cloud inference, remote tools, remote database queries, or automatic fallback providers.
- Do not add Private Cloud Compute entitlements, remote model configurations, analytics, crash-reporting SDKs, or transcript feedback uploads.
- Do not log images, model transcripts, meal descriptions, or user-entered portions. Development performance logs should contain timings and non-sensitive status only.
- Keep images and results in memory where practical. Any temporary files belong in app-private storage with appropriate file protection and must be deleted on replacement, cancellation, completion when no longer needed, and subsequent launch cleanup.
- Exclude temporary images and analysis files from backups. Do not enable CloudKit or iCloud document synchronization.
- Persist only explicitly saved meal data under the history rules above. Provide deletion controls and document retention and backup behavior.
- Privacy copy must distinguish Nosh's processing from system-managed Apple model downloads and photo-library retrieval.

## Architecture

Keep business rules independent of SwiftUI and framework-specific model responses.

Suggested layout, to create only when implementation starts:

```text
Nosh/
  App/
  Features/
    Capture/
    Analysis/
    MealReview/
    History/
  Domain/
  Services/
    ImageInput/
    FoodRecognition/
    CalorieEstimation/
    MealStore/
  Resources/
NoshTests/
NoshUITests/
docs/
```

- Define domain types for food candidates, portions, meal items, saved meals, estimate basis, and estimate completeness. Keep stable IDs separate from display names.
- Track whether a food match and portion are model-suggested or user-confirmed.
- Inject image input, recognition, calorie estimation, and meal storage services. Use deterministic fakes for previews and tests without hardware or model access.
- Isolate Foundation Models behind a recognizer service. Keep prompts and output schemas versioned and reviewable.
- Use a fresh bounded session per image unless measured evidence justifies retained context. Do not carry previous meal details into a new analysis.
- Serialize generation within a session. Propagate cancellation and discard stale completions using a request identity.
- Validate generated structures before constructing domain values. Guided generation constrains shape, not factual correctness.
- Run image processing, inference, and storage work away from the main actor. Keep UI state updates on the main actor.
- Model idle, importing, ready, analyzing, reviewing, unavailable, and failed states explicitly.
- Add dependencies only for a concrete need. Do not introduce a backend, web wrapper, cross-platform framework, or speculative persistence layer.

## Interface and accessibility

- Use native navigation, sheets, controls, SF Symbols, and system typography.
- Show the estimated total and item breakdown clearly, with portions and assumptions beside the relevant food.
- Use neutral language about food. Avoid good/bad scores, weight-loss pressure, streaks, or guilt-based messaging.
- Support VoiceOver, Dynamic Type, dark mode, sufficient contrast, and Reduce Motion.
- Make portion editing, removing items, and retrying accessible without gestures alone.
- Give useful accessibility labels to image actions and result rows. Do not rely on color to convey uncertainty.
- Keep camera controls clear of safe areas and make permission-denied and empty-result screens actionable.

## Verification and release criteria

- Unit-test nutrition arithmetic, rounding, unit validation, preparation states, missing data, portion scaling, food changes requiring re-estimation, and incomplete totals.
- Test explicit save, duplicate save taps, failed writes, persistence across launches, deletion, unreadable storage, partial-result labels, absence of stored images, and history access without model availability. Verify saved values remain unchanged on reopening.
- Test cancellation, rapid photo replacement, duplicate Analyze taps, stale completions, model unavailability, refusal, and invalid structured output with injected services.
- Test camera denial, picker cancellation, offline iCloud photo import failure, image orientation, corrupt files, and large-image memory behavior.
- Run UI tests for capture/import through review and portion correction. Check VoiceOver and large text for changed screens.
- Build a consented or licensed evaluation set spanning simple foods, mixed dishes, difficult lighting, and non-food images. Record known portions and catalog reference values separately from visual guesses.
- Measure recognition errors and abstentions separately from calorie error and portion error. Report dataset coverage and limitations. Agree on numerical quality thresholds from the prototype evidence before release.
- Measure latency, peak memory, thermal behavior, and cancellation on supported physical devices. Do not claim a speed target or accuracy percentage without measurements.
- Verify capture, local-photo import, inference, correction, and calculation in airplane mode after model assets are installed. Inspect app network activity as well as testing offline.
- Audit entitlements, dependencies, temporary file cleanup, backup exclusions, and logs against the local-only contract.
- Build the affected target and run relevant tests after code changes. Record actual commands, device or simulator details, passes, and blockers. Never claim a test ran when it did not.

## Implementation order

1. Prove on-device image input with a compatible SDK and physical device. Resolve any tooling or OS blocker first.
2. Define structured model estimates and implement validation, portion rules, and deterministic calculations with tests.
3. Build camera and photo import with preview and error recovery.
4. Connect structured food recognition and model calorie estimates to editable draft results. Add explicit save, local history, read-only details, and deletion.
5. Validate privacy, offline operation, accessibility, and device performance.
6. Document setup, supported devices, model-estimate limitations, history storage behavior, and measured recognition quality before expanding coverage.

The app shell, local history, and on-device image analysis path exist. Live inference on a physical iPhone is still unverified. Do not mistake this document for a completed release.

## Decisions to resolve when needed

- Exact minimum iOS version and compatible devices based on the capability prototype. A newer minimum is approved; disclose any beta tooling or release constraints.
- Whether an additional bundled vision model is acceptable if Apple's available on-device model cannot analyze images.
- Model evaluation thresholds. Nutrition dataset and redistribution rights are deferred to the database TODO.
- Final branding, bundle identifier, and signing team.

Ask one focused question at a time when the answer materially changes implementation. Explain why it matters and allow skipping where a safe working default exists. Continue independent authorized work while waiting.

## Sources

Checked on 7 September 2026. Recheck API availability against the SDK used for implementation.

- [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Analyzing images with multimodal prompting](https://developer.apple.com/documentation/FoundationModels/analyzing-images-with-multimodal-prompting)
- [What's new in the Foundation Models framework, WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/)
- [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple Intelligence setup and availability](https://support.apple.com/en-us/121115)
