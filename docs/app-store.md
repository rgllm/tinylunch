# TinyLunch App Store listing

Paste these fields into App Store Connect. Screenshots belong in `docs/screenshots/` after `scripts/capture-screenshots.sh`. Host `docs/privacy-policy.md` on HTTPS and put that URL in both Privacy Policy and the app record.

## Identity

| Field | Value |
| --- | --- |
| Name | TinyLunch |
| Subtitle | On-device calorie estimates |
| Bundle ID | `com.rgllm.tinylunch` |
| SKU | `tinylunch` |
| Primary language | English (US) |
| Category | Food & Drink |
| Secondary category | Health & Fitness (optional) |
| Version | 1.0.0 |
| Copyright | 2026 Rogério Moreira |

## Promotional text

Photograph a meal. TinyLunch estimates calories on your iPhone. Photos are not saved. Nothing is sent to a server.

## Description

TinyLunch estimates the calories in a meal from a photo, on your iPhone.

Take a picture or choose one from your library. Apple Intelligence looks at the plate on-device and suggests foods, portions, and energy values. You can correct a name, change the grams, drop a false detection, or add something it missed. TinyLunch then does the arithmetic: grams × kcal per 100 g.

Save only when you want to. History keeps the meal details without the photo. Delete a meal, or delete the app, and it is gone. History is excluded from device backups.

TinyLunch does not create an account, run ads, or talk to a nutrition server. Photo analysis needs iOS 27 and Apple Intelligence with on-device vision. If that model is not ready yet, History still works and new estimates wait.

Calories are estimates, not lab measurements or medical advice. TinyLunch is not a medical device and does not replace professional nutrition guidance.

## Keywords

calorie,calories,food,meal,photo,nutrition,kcal,estimate,diet,camera,privacy,portion,local,offline,history

## What's New

First release. Photograph a meal, correct the estimate, and save it on your iPhone.

## URLs

| Field | Suggested value |
| --- | --- |
| Privacy policy | Public HTTPS URL for `docs/privacy-policy.md` |
| Support | Public HTTPS support page required. The GitHub repository is private. |
| Marketing | Optional |

App Review expects a privacy-policy URL even when the privacy answers are “Data Not Collected”.

## Screenshots

iPhone-only, portrait. Upload the 6.9-inch set; Apple accepts 1320 × 2868, 1290 × 2796, or 1260 × 2736 and scales it down. Capture on iPhone 17 Pro Max (1320 × 2868) with:

```sh
./scripts/capture-screenshots.sh
```

Do not upload the older `nosh` images. PNG files must have no alpha channel. iPad, Mac, Watch, and Apple TV screenshots are not required.

Suggested order:

1. Home — take or choose a photo
2. Review — editable estimate
3. History — saved meals, no photos
4. Dark Mode home

## App Review notes

TinyLunch has no account, IAP, or demo login.

To estimate a meal: allow Camera or pick a photo of food. Analysis uses Apple Intelligence on the device (iOS 27, on-device vision). If the model is unavailable, the app explains why and keeps History usable.

Saved history is local JSON in Application Support. Photos stay in memory and are not written to the archive.

Calories are model estimates. The Privacy sheet states that TinyLunch is not a medical device and does not give medical or dietary advice.

The home screen has small decorative interactions: tap the plate five times for the chef's table, or long-press the TinyLunch wordmark for a toast. These do not affect food estimates. Debug launch arguments for tests and screenshots are compiled out of Release.

## App Privacy answers

Select **Data Not Collected**.

Photos are processed in memory and discarded. Saved meals never leave the iPhone and are not available to the developer. There is no analytics, crash reporter, advertising, or tracking. `PrivacyInfo.xcprivacy` matches this: no tracking, no collected data types, no required-reason APIs.

Do not add App Tracking Transparency.

## Age rating

Aim for 4+. In the questionnaire:

- No unrestricted web access
- No gambling, contests, or user-generated public content
- No frequent/intense medical treatment information; calorie estimates are informational
- No alcohol, tobacco, drugs, or violence

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false`. TinyLunch does not use custom encryption; standard iOS HTTPS/system crypto does not apply because the app has no network client.

## Remaining Connect steps

These cannot be done from the repo:

1. Create the iOS app record for `com.rgllm.tinylunch` on team `F86KMMECSR`.
2. Publish the privacy policy on HTTPS and paste the URL.
3. Upload 6.9-inch screenshots from `docs/screenshots/`.
4. In Xcode: Window → Organizer → the TinyLunch archive → Distribute App → App Store Connect. Command-line export needs an Apple Distribution certificate, which is created the first time you distribute while signed into Xcode with the F86KMMECSR team.
5. Submit 1.0.0 for review.

Photo analysis has not been signed off on a physical iPhone yet. If Review’s device lacks Apple Intelligence, they can still open History and the privacy sheet; mention that in the notes.
