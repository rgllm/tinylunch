# TinyLunch App Store listing

Listing preparation was performed in App Store Connect on 20 September 2026. Screenshots are in `docs/screenshots/`. The privacy policy and support page are live at https://engino.pt/privacidade. The app has not been submitted for review.

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

food,meal,photo,nutrition,kcal,estimate,camera,privacy,portion,offline,history

## What's New

First release. Photograph a meal, correct the estimate, and save it on your iPhone.

## URLs

| Field | Suggested value |
| --- | --- |
| Privacy policy | https://engino.pt/privacidade |
| Support | https://engino.pt/privacidade#support |
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

Calories are model estimates. The start screen, review screen, saved-meal detail, and About privacy sheet state that TinyLunch is not a medical device, that figures are estimates only and not medical or dietary advice, and that a person should consult a qualified professional.

The home screen has small decorative interactions: tap the plate five times for the chef's table, or long-press the TinyLunch wordmark for a toast. These do not affect food estimates. Debug launch arguments for tests and screenshots are compiled out of Release.

## App Privacy answers

Select **Data Not Collected**.

Photos are processed in memory and discarded. Saved meals never leave the iPhone and are not available to the developer. There is no analytics, crash reporter, advertising, or tracking. `PrivacyInfo.xcprivacy` matches this: no tracking, no collected data types, no required-reason APIs.

Do not add App Tracking Transparency.

## Age rating

Apple calculated 9+ on 20 September 2026, with regional exceptions. The questionnaire declares Health or Wellness Topics, but no medical or treatment information. Other answers:

- No unrestricted web access
- No gambling, contests, or user-generated public content
- No frequent/intense medical treatment information; calorie estimates are informational
- No alcohol, tobacco, drugs, or violence

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false`. TinyLunch does not use custom encryption; standard iOS HTTPS/system crypto does not apply because the app has no network client.

## Connect preparation status

These cannot be done from the repo:

1. App record exists: TinyLunch, Apple ID `6811014228`, bundle `com.rgllm.tinylunch`.
2. Privacy and support are live at https://engino.pt/privacidade. App Privacy publication requires the publisher agreement.
3. Four 6.9-inch screenshots are uploaded in home, review, history, dark-mode order.
4. Upload 1.0.0 (25) with `.github/workflows/testflight.yml` (workflow_dispatch on `xcode-27`). It selects the release Xcode 27.0 SDK, not the beta toolchains on that image, and targets iPhone only. Existing build 23 was uploaded on 12 September using a beta SDK and declares iPhone and iPad support. Apple rejected it during Add for Review validation. Build 24 was a local iPhone-only archive with Xcode 27.0 (27A266a) and was not the store upload.
5. Fill all App Review contact fields together, including the phone number supplied by the publisher. The contact fields were not persisted while the phone number was absent.
6. Publish the Data Not Collected privacy answers after the publisher accepts Apple's declaration.
7. Re-run Add for Review validation after replacing the build. Leave the final Submit for Review action to Rogério.

Saved configuration: Food & Drink category, English (US), on-device calorie estimates subtitle, four screenshots, listing description, keywords, review notes, public support URL, and age rating 9+ with regional exceptions. Content rights are set to no third-party content. Price is free; all 175 countries or regions are available on release. Mac and Apple Vision Pro distribution are disabled. The existing automatic-release-after-approval setting was preserved.

Photo analysis has not been signed off on a physical iPhone yet. If Review’s device lacks Apple Intelligence, they can still open History and the privacy sheet; mention that in the notes.
