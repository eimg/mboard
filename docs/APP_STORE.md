# App Store submission preparation

Draft for MBoard 0.1. The listing and reviewer steps describe the revised bottom row and toolbar. The archive and screenshot audit on November 26, 2026 covered build 9 at `db8e100`. The iPhone and iPad app has bundle ID `com.eimg.mboard` and embeds `com.eimg.mboard.keyboard`. Minimum OS is 16.0. This document is a draft for the account holder.

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

Type Burmese and English on your iPhone or iPad. Switch languages with one tap. Double-tap Space after a word to add the sentence ending for that language. To type ကို, enter က and then the two vowels in either order. You can also type ေ before its consonant, hold a key for alternate characters, and tap a suggestion to complete a Burmese word without adding a space.

MBoard remembers the suggestions you choose on this device. Hold a learned suggestion to forget it, or clear all your choices in keyboard settings. Search emoji with English or Burmese keywords and hold an emoji to see its available skin tones.

Select text and tap Backspace once to delete the selection. English auto-capitalization follows the text field and can be turned off in keyboard settings.

Choose System, Light, or Dark appearance. The companion app includes a practice field and Burmese setup instructions. Typing, suggestions, and emoji search work offline, with Full Access off.

## App Review notes to paste

1. In Settings → General → Keyboard → Keyboards → Add New Keyboard, add MBoard. Open the MBoard app and tap its practice field. Hold the system globe to select MBoard. On iPad with an external keyboard, show the onscreen keyboard. Leave Full Access off. No account or purchase is required.
2. If English is active, tap ကခ at the far left of the bottom row to choose Burmese. Tap က, then ု, then ိ. Insert a space and tap က, then ိ, then ု. The field should read ကို ကို. Select both words and tap Backspace once to clear them.
3. Tap ေ, က, ျ, ာ to type ကျော. Tap the ကျောင်း suggestion to complete the word. Move the caret between ကျော and င်း in the completed word. The suggestion bar should clear. Tap at the end to continue typing.
4. Switch to English, try the smiley key and emoji search, then use the system globe to switch keyboards. The gear at the top right opens keyboard settings. Support and Privacy Policy are available in the containing app.

## Privacy and compliance answers

- **App Privacy** — The keyboard checks text on both sides of the caret to order Burmese marks and avoid completing a word twice. This context stays in memory. Only explicit suggestion choices contribute to the locally stored ranking. Proposed answer to whether the app or its partners collect data through the app is **No**. Tracking is off. Email initiated separately by the user is covered in the policy. Recheck disclosures if adding analytics, accounts, or remote suggestions. [Apple’s privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- **Privacy manifests** — The app and extension each bundle a manifest. The extension declares UserDefaults reason CA92.1 for settings and ranking history in its private container. [Apple’s required-reason guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- **Export compliance** — The app sets `ITSAppUsesNonExemptEncryption` to false. The current app has no custom cryptography or bundled encryption libraries.
- **Content rights** — The binary bundles Unicode/CLDR emoji data and ICU Burmese word data with their notices. Development reference images are outside the app bundle. [Third-party notices](../THIRD_PARTY_NOTICES.md)
- **Age rating** — Answer Apple’s questionnaire for the shipped app. It has no account, social feed, unrestricted web browser, advertising, or in-app purchases. Apple calculates the rating.
- **Custom keyboard** — Review switching, offline operation, and the handling of learned selections against guideline 4.4.1. The containing app provides setup, practice, support and the privacy policy. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Screenshots

Use the local, Git-ignored `screenshots/` directory. Use full-resolution opaque PNG files. Apple accepts one to ten images for each supplied display size. Its current required-size summary calls for a medium Dynamic Island iPhone and a 13-inch iPad. The detailed table also calls for a large Face ID set when a large Dynamic Island set is absent. Supply the large Dynamic Island set alongside the two sizes in the summary. [Apple’s screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

| Local folder | Device and slot | Portrait pixels | Contents |
| --- | --- | --- | --- |
| `screenshots/iphone/iphone-*.png` | iPhone 17 Pro, medium Dynamic Island | 1206 × 2622 | Burmese typing, English typing, emoji |
| `screenshots/iphone/max-*.png` | iPhone 17 Pro Max, large Dynamic Island | 1320 × 2868 | Burmese typing, English typing, emoji. Recaptured from the audited revision. |
| `screenshots/ipad/` | iPad Pro 13-inch (M5) | 2064 × 2752 | Burmese typing, English typing, emoji |

These captures document the audited revision. Refresh the typing screenshots for the revised bottom-row language key and toolbar before uploading the new layout. All nine PNGs passed dimension and opacity checks. The new large iPhone captures show the MBoard settings logo, the text `ကျောင်း` and `ကျောင်း school`, and the emoji picker. The medium iPhone and 13-inch iPad captures come from an earlier revision of build 9 with the same visible layouts. The iPad simulator previously produced `ကျောင်း school😀` using the installed extension.

## Verification for archived revision db8e100

- An unsigned Release archive contains MBoard and its keyboard extension at 0.1 (9). Both declare iPhone and iPad support and a minimum OS of 16.0. Each bundles its privacy manifest. The extension includes both Unicode data notices and declares `RequestsOpenAccess = false`. The app declares `ITSAppUsesNonExemptEncryption = false`.
- The public support and privacy URLs returned HTTP 200 without credentials. The support page lists the maintainer’s email address, and both links are available in the containing app.
- All 30 core tests passed, including 458 recorded Burmese typing sequences replayed with two host deletion behaviors. On the iPhone 17 Pro simulator, the latest keyboard repeatedly produced ကို after a 440-character paragraph, preserved ကျောင်း with the caret inside it, and cleared selected text with one Backspace. An iPhone 15 Plus reported build 9 installed.
- The draft name, subtitle, promotional text and description fit their field limits. Keywords use 77 of 100 UTF-8 bytes, and the App Review notes fit the 4,000-byte limit. [App Store Connect version metadata](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

## Before the eventual upload

1. Confirm developer membership, agreements, app name availability, SKU, legal copyright holder, pricing, storefronts and trader declarations. Enter the review contact’s name, email and telephone number privately in App Store Connect.
2. Verify support and privacy URLs while signed out. Enter the final privacy, rights, accessibility and age questionnaire answers for the shipping build. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information) · [Version metadata and support contact requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
3. Test on physical hardware in everyday apps, including rapid typing, cursor movement and deletion. Archive with distribution signing and an Apple-accepted release of Xcode. Apple currently requires Xcode 26 or later and the iOS/iPadOS 26 SDK or later. The local simulator build used Xcode 27 beta. Inspect the final archive’s privacy report and validate the distribution archive before uploading. Build 9 has been reused for local revisions. If that version/build pair is already in App Store Connect, increment both the app and extension build numbers together before archiving. [SDK requirements](https://developer.apple.com/news/upcoming-requirements/)
