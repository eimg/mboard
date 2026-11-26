# App Store submission preparation

Prepared November 26, 2026 for MBoard 0.1 (build 4). The iPhone and iPad app has bundle ID `com.eimg.mboard` and embeds `com.eimg.mboard.keyboard`. Minimum OS is 16.0. This document is a draft for the account holder.

## Product page · English (U.S.)

| Field | Proposed entry |
| --- | --- |
| Name | MBoard |
| Subtitle | Burmese & English Keyboard |
| Primary category | Utilities |
| Keywords | myanmar,unicode,typing,emoji,bilingual,suggestions,offline,မြန်မာ |
| Support URL | https://github.com/eimg/mboard/blob/main/SUPPORT.md |
| Privacy Policy URL | https://github.com/eimg/mboard/blob/main/PRIVACY.md |
| Promotional text | Switch between Burmese and English, complete a word, or find an emoji without leaving the keyboard. Typing works offline with Full Access off. |

### Description

Type Burmese and English on your iPhone or iPad. Switch languages with one tap. In Burmese, long-press a key for alternate characters and tap a suggestion to finish a word while keeping the spacing you typed.

MBoard remembers the suggestions you choose on this device. Hold a learned suggestion to forget it, or clear all your choices in keyboard settings. Search emoji with English or Burmese keywords and hold an emoji to see its available skin tones.

Choose System, Light, or Dark appearance. The companion app includes a practice field and Burmese setup instructions. Typing, suggestions, and emoji search work offline, with Full Access off.

## App Review notes to paste

Open Settings → General → Keyboard → Keyboards → Add New Keyboard and choose MBoard. Open MBoard, tap the practice field, then hold the system globe to select MBoard. On an iPad with an external keyboard attached, show the onscreen keyboard. Use the toolbar language switch to change between Burmese and English. Try typing a few letters, tapping a suggestion, opening the emoji picker, and switching back using the system keyboard control. No sign-in, purchase, or Full Access is needed. The containing app links to support and the privacy policy.

## Privacy and compliance answers

- **App Privacy** — The current binary processes text and learned choices on device. Proposed answer to whether the app or its partners collect data through the app is **No**. Tracking is off. Email initiated separately by the user is covered in the policy. Recheck disclosures if adding analytics, accounts, or remote suggestions. [Apple’s privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- **Privacy manifests** — The app and extension each bundle a manifest. The extension declares UserDefaults reason CA92.1 for settings and ranking history in its private container. [Apple’s required-reason guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- **Export compliance** — The app sets `ITSAppUsesNonExemptEncryption` to false. The current app has no custom cryptography or bundled encryption libraries.
- **Content rights** — The binary bundles Unicode/CLDR emoji data and ICU Burmese word data with their notices. Development reference images are outside the app bundle. [Third-party notices](../THIRD_PARTY_NOTICES.md)
- **Age rating** — Answer Apple’s questionnaire for the shipped app. It has no account, social feed, unrestricted web browser, advertising, or in-app purchases. Apple calculates the rating.
- **Custom keyboard** — Review switching, offline operation, and the handling of learned selections against guideline 4.4.1. The containing app provides setup, practice, support and the privacy policy. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Screenshots

Use the local, Git-ignored `screenshots/` directory. Use full-resolution opaque PNG files. Apple accepts one to ten images for each supplied display size. Its current required-size summary calls for a medium Dynamic Island iPhone and a 13-inch iPad. The large iPhone set is another supported slot. [Apple’s screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

| Local folder | Device and slot | Portrait pixels | Contents |
| --- | --- | --- | --- |
| `screenshots/iphone/iphone-*.png` | iPhone 17 Pro, medium Dynamic Island | 1206 × 2622 | Burmese typing, English typing, emoji |
| `screenshots/iphone/max-*.png` | iPhone 17 Pro Max, large Dynamic Island | 1320 × 2868 | Burmese typing, English typing, emoji |
| `screenshots/ipad/` | iPad Pro 13-inch (M5) | 2064 × 2752 | Burmese typing, English typing, emoji |

The images show the installed extension in the practice app. On the 13-inch iPad simulator, input checks produced `ကျောင်း`, then `ကျောင်း school`, then `ကျောင်း school😀`. The medium iPhone simulator also produced the bilingual text. Both targets in the local unsigned device archive declare iPhone and iPad compatibility and contain their privacy manifests.

## Before the eventual upload

1. Confirm developer membership, agreements, app name availability, SKU, legal copyright holder, pricing, storefronts and trader declarations. Enter the review contact’s name, email and telephone number privately in App Store Connect.
2. Verify support and privacy URLs while signed out. Enter the final privacy, rights, accessibility and age questionnaire answers for the shipping build. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information) · [Version metadata and support contact requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
3. Test on physical hardware in everyday apps, including rapid typing, cursor movement and deletion. Archive with distribution signing and an Apple-accepted release of Xcode. Apple currently requires Xcode 26 or later and the iOS/iPadOS 26 SDK or later. The local simulator build used Xcode 27 beta. Inspect the archive’s privacy report and validate the distribution archive before uploading. [SDK requirements](https://developer.apple.com/news/upcoming-requirements/)
