# mboard

English / Burmese keyboard for iOS — product specification and discussion handoff.

Last updated: 2026-11-25 (Asia/Yangon).
Status: native iOS keyboard prototype implemented. The main typing and emoji flows were exercised on the iPhone simulator. Emoji picker layout and search were measured on the simulator. Physical iPhone trials are pending.
Project folder: `/Users/eimg/Desktop/mboard`.

## 1. Purpose

Create an iOS keyboard the user can comfortably use every day in English and Burmese, drawing on the Android Gboard layout and typing experience they already know.

The user switched to iOS after about a decade on Android. They find Apple's built-in keyboard frustrating in both languages. In their experience, Gboard on iOS does not support Burmese, so they currently use Gboard for English and Apple's keyboard for Burmese. This is awkward. Alternatives such as ttKeyboard have not met their expectations for layout and responsiveness.

The user considers Android Gboard particularly good for Burmese. It also supports voice input there, but they rarely use voice input. The immediate motivation is comfortable, familiar typing.

## 2. Confirmed requirements and preferences

### Languages and layout

- Support English and Burmese within the product.
- Capitalize the first letter of each English word in Burmese interface copy.
- Use the familiar Gboard layout as the primary interaction/layout reference, especially for Burmese.
- The user identified a layout called MyanSan and a font called Pyidaungsu as relevant references. They participated in the early initiative around these projects but later stepped away because of work/life constraints.
- Preserve familiar character access. The [Android Gboard reference](references/gboard-burmese/README.md) records the user's emulator configuration, portrait layers, and observed typing and deletion examples.
- Correct Unicode output and practical Burmese editing are essential to a usable result.
- The emoji picker should show one scrollable grid for the full catalog, with search at the top. Tapping search should open the regular keyboard, with space above for results.

### Suggestions

- Simple dictionary-based suggestions, or a comparable lightweight approach, are acceptable initially for both English and Burmese.
- Matching Gboard's advanced prediction quality is not required for the first version.

### Appearance

- Use native iOS styling for the keyboard and emoji picker. Use Gboard as the reference for layout and behavior.
- Provide exactly the useful baseline choices: **System**, **Light**, and **Dark**.
- A broad theme system is unnecessary.
- The keyboard should fit naturally when it appears in light or dark apps. Appearance is part of the initial scope.

### Quality

- Responsiveness and familiar layout are central product goals. Perceived lag is one reason the user rejected existing alternatives.
- Optimize for actual daily typing, including mixed English/Burmese use.

## 3. Proposed first-version behavior

These are implementation recommendations from the discussion, not all separately approved by the user.

| Area | Proposed behavior |
| --- | --- |
| Language switching | A direct English/Burmese control within our keyboard, alongside the required iOS keyboard-switching behavior. |
| English | Familiar QWERTY/Gboard-style arrangement; agree exact punctuation, long presses, and optional number-row behavior before finalizing. |
| Burmese | Gboard-familiar phone layout, with composition rules verified against actual typing examples. |
| Text output | Standard Unicode; do not equate a familiar visual typing order with legacy encoding. |
| Suggestions | A small candidate bar with local dictionary completions; keep the literal typed input available. |
| Correction | Start with explicit candidate selection; make automatic correction a later, optional decision. |
| Appearance | System as default, with explicit Light and Dark overrides. |
| Settings | A small containing app for setup guidance and essential preferences. |
| Connectivity | Core typing, composition, and initial dictionary suggestions work offline without requiring Full Access. |

System appearance should use the appearance information available to the extension, including the active text field's requested keyboard appearance and interface traits. Explicit Light/Dark selections override automatic selection. Verify actual behavior across apps; do not promise perfect matching to arbitrary host-app colors.

Both palettes must cover keyboard background, normal keys, modifiers, labels, suggestion bar, selected/pressed states, long-press menus, and readable contrast. Keep geometry stable when appearance changes.

The containing app follows iOS system appearance independently of the keyboard's override.

The Home Screen icon uses a double-arch mark that reads as both Latin m and Burmese က. The default artwork is white on blue. The dark icon appearance uses blue on charcoal and follows the iOS Home Screen icon setting.

The practice screen pairs a small version of the icon with the MBoard title in the navigation bar. Its icon follows the app’s light or dark appearance. Both section titles use regular weight. The setup section ends with the Settings link.

## 4. Burmese input requirements and risks

Keep these responsibilities separate:

1. **Layout:** positions, layers, long presses, and reachability of characters.
2. **Composition:** transforming a sequence of key actions into correct text while accommodating the user's familiar typing order.
3. **Editing:** backspace, repeated deletion, candidate replacement, selection replacement, and cursor movement through existing text.
4. **Rendering:** glyphs on our keys and candidate bar; host-app rendering remains outside our control.

Myanmar characters may display in a different order from their Unicode storage order. For example, the prebase vowel ေ (U+1031) is stored after its consonant. Keyboard-specific composition rules are needed; generic Unicode normalization alone is not a complete input engine.

Backspace behavior must be established from user expectations and reference behavior. Removing the last key action, one encoded component, and a whole visible cluster are different operations. Avoid blindly assuming a Swift Character or one deleteBackward call always corresponds to the intended Burmese edit.

The input engine must recover safely when the user moves the cursor, selects text, pastes content, changes apps/fields, or when the extension restarts. Never apply stale composition state to unrelated text.

MyanSan, Pyidaungsu MM, Myanmar3, and Gboard's mobile layout must not be assumed identical. The KeyMagic resource list includes MyanSan and Pyidaungsu MM separately. Validate the desired variant and any reusable rule sources.

## 5. Font policy

Use the iOS system font and its Myanmar glyph fallback for Burmese labels, suggestions, and long-press choices. Pyidaungsu remains a reference from the earlier discussion.

The keyboard inserts plain Unicode text into the host app. It cannot force the host app or recipient to render that text in Pyidaungsu. Layout compatibility must not depend on installing a particular font in every destination app.

## 6. Initial suggestion engine

Recommended starting approach:

- English: prefix lookup plus limited spelling-neighbor candidates, ranked by useful frequency information when available.
- Burmese: syllable-aware matching over recent input, with candidate word starts considered within a phrase. Do not assume a space-delimited English token model.
- Preserve literal input for names, slang, code, unfamiliar words, and dictionary gaps.
- Accepting a Burmese suggestion must not automatically add English-style word spacing.
- Normalize lookup keys consistently while preserving correct output and avoiding unintended changes to text outside the replacement span.
- Keep suggestion computation outside the immediate key-handling path. Discard stale results after input/context changes.
- Keep language-specific suggestion behavior initially; automatic language detection and unified mixed-language ranking are later choices.

Data sourcing is unresolved. Assess licences, spelling consistency, coverage, frequency/ranking quality, and bundled size before selecting English/Burmese word lists. Do not assume any public dictionary or Google's data is freely redistributable.

Personal dictionaries and usage-based learning are possible later additions; retention, reset controls, and storage behavior have not been agreed.

## 7. iOS platform boundaries

Verified from Apple documentation during the feasibility discussion:

- A custom keyboard is delivered as an extension inside a containing iOS app and enabled in Settings.
- It can operate across apps where third-party keyboards are permitted.
- Secure text fields and certain phone-pad fields use the system keyboard. Apps can prohibit third-party keyboards.
- The extension interacts with the host through UITextDocumentProxy, including insertion/deletion, insertion-point adjustment, surrounding text context, and marked-text composition APIs. This is not unrestricted access to the host document or UI.
- The extension cannot directly access the microphone. Do not promise Android-style in-keyboard voice capture.
- Keyboard extensions have memory limits and can be terminated by iOS. Limits vary; do not hardcode a universal memory budget based on anecdotal figures.
- Core local typing can work without Full Access. Network access and certain shared-container writes require Full Access. Design the baseline around the restricted mode and verify actual storage needs.
- A custom keyboard does not automatically inherit Apple's complete native prediction/correction engine.
- Host apps control how inserted text is displayed.

App Store rules and SDK behavior must be rechecked when implementation/distribution decisions depend on them. No distribution path has been selected.

## 8. Recommended architecture

The prototype uses native Swift/UIKit.

Suggested separation:

- **Containing app:** onboarding, enable-keyboard instructions, essential preferences, and an optional typing test area.
- **Keyboard extension:** key views/hit handling, language modes, candidate bar, appearance handling, and host-text integration.
- **Burmese composition core:** independently testable rules and composition/edit state.
- **Suggestion core:** compact local dictionaries and language-specific lookup/ranking.
- **Shared preferences/resources:** use only supported access patterns; do not require Full Access just for basic operation.

No backend, cloud AI, PHP stack, login, or analytics is needed for the proposed first version. Do not introduce them without a concrete requirement.

## 9. Deferred or unresolved features

Not required to demonstrate the initial product:

- Voice input.
- Gboard-level neural prediction or personalization.
- Glide/swipe typing.
- GIF search and translation features.
- Extensive themes.
- Cloud sync or accounts.

Still open rather than implicitly approved or rejected:

- Exact English punctuation/number-row/long-press preferences.
- Cursor gestures and deletion gestures.
- Haptics, sound, key previews, and timing preferences.
- The user selected Android Gboard as the English and emoji picker reference. Compare remaining behavior using the [English and emoji captures](references/gboard-english/README.md).
- Automatic correction behavior and controls.
- Personal dictionary and learned ranking.
- iPad support, orientation scope, minimum iOS version, and initial target iPhone.
- Larger licensed dictionaries and reusable composition rule sources.
- Personal installation, TestFlight, or eventual App Store release.

## 10. Validation and acceptance direction

The first meaningful milestone is a keyboard the user can try in normal apps for several days.

Validate:

- Reference layout fidelity on base/alternate layers, including long presses.
- Burmese compositions covering medials, vowels, tone marks, asat, kinzi, and stacked consonants as appropriate to the chosen rules.
- Backspace during composition and inside already committed text.
- Cursor/selection changes, paste, language switching, and host field changes without text loss or duplication.
- Suggestion replacement boundaries and preservation of Burmese spacing.
- Typing unknown words without forced replacement.
- Light/dark states across the complete UI, app switching, and changes while visible.
- Responsiveness on a real iPhone, extension cold start, rapid tapping, and bounded memory use.
- Core operation offline with Full Access disabled.
- Representative native text fields, browser fields, and the user's everyday messaging apps.

Use meaningful automated tests for composition, deletion, and suggestion replacement. Device testing is required for host compatibility and perceived typing quality. Performance targets should be measured and recorded during implementation; no benchmark has been established yet.

## 11. Suggested next steps when implementation is requested

1. Inspect the project folder/toolchain and confirm available Xcode/device support.
2. Use the captured Gboard layers and keystroke examples for the first prototype. Extend the reference for untested composition and editing cases as needed.
3. Inspect relevant MyanSan/Pyidaungsu resources and licences; select or implement the composition rules.
4. Establish a minimal native keyboard extension and containing app, with English/Burmese modes and both appearance palettes from the beginning.
5. Prove Burmese composition and editing on the user's iPhone before expanding features.
6. Add small local dictionaries and candidate selection, then iterate from actual daily use.

The earlier discussion gave only a rough planning impression: weeks for a narrowly scoped useful prototype and months of refinement for publication, assuming experienced iOS development. This is not a delivery commitment; the exact layout, engine reuse, toolchain, and device results determine the estimate.

## Prototype implementation

Open `MBoard.xcodeproj`, select the MBoard scheme, and run on an iPhone simulator. Enable MBoard in Settings → General → Keyboard → Keyboards → Add New Keyboard. Focus the practice field in the app and select MBoard from the system globe. If the simulator uses a hardware keyboard, enable the software keyboard in Device Hub. Run core regression tests with `swift test`. The MBoard scheme also includes a UI typing and emoji search test that expects MBoard to be selected.

- The containing app has a Home Screen icon, Myanmar setup instructions, and a native practice text view. Myanmar instructions use additional line spacing and retain the original iOS Settings labels. Tapping outside the practice field or dragging the list dismisses the keyboard and preserves the practice text. VoiceOver users can also use the escape gesture. The **Settings ဖွင့်ရန်** row below the setup instructions uses the public iOS app settings URL. The instructions show the full path to enable the keyboard.
- The extension targets iPhone on iOS 16 and later. Portrait is the reference geometry. The minimum version and English interaction details are prototype choices.
- Burmese base, Shift, default long presses, and two symbol pages use the emulator captures. English uses staggered QWERTY, digit hints, and sampled long presses. Some sliding alternates, the dedicated numeric keypad, automatic capitalization, and caps lock remain open.
- Burmese composition uses marked text and the captured prebase-vowel, medial, kinzi, and stack sequences. The engine keeps Gboard's intermediate U+200C for a pending prebase vowel. Leaving it unfinished can commit the placeholder. Owned segments support scalar backspace. Outside a segment, a host deletion that can be identified precisely as a whole Burmese cluster has its preceding scalars restored. Actual host deletion granularity still needs per-app testing.
- The toolbar switches languages and offers System, Light, and Dark. Choices persist in the extension's own defaults without requiring a shared container. System follows the input field's explicit appearance or the current interface traits. The keyboard and emoji picker use UIKit materials, semantic iOS colors, system fonts, and SF Symbols.
- Local prefix suggestions use small hand-entered English and Burmese word lists. Explicit selection appends the missing suffix, preserving text and spacing. Suggestions run separately from insertion. No automatic correction, learning, or network access is enabled.
- The smiley opens one scrollable, eight-column emoji grid on an opaque surface with flat scroll edges. Session recents appear at the top when reopening the picker. Long-press an emoji for its skin-tone variants. Tapping search opens the full-size keyboard in the active language, and typing extends the results above the query. Search supports English names and Myanmar keywords offline. Selecting a result inserts the emoji. Back returns to the original scroll position and ABC returns to regular typing. The catalog includes 3,624 fully-qualified Unicode Emoji 14.0 sequences and search annotations from CLDR 47. GIFs and stickers remain deferred. [Unicode emoji data](https://unicode.org/Public/emoji/14.0/emoji-test.txt) · [CLDR Myanmar annotations](https://www.unicode.org/cldr/charts/47/summary/my.html) · [Unicode license](Keyboard/Resources/Unicode-LICENSE.txt)
- The picker reuses fixed-size cells, builds its browse list and variation index once per extension process on a background task, and cancels obsolete searches as the query changes.
- The Android emulator supplied reference data. iOS testing is simulator-only at the user's request.

On the iPhone 17 Pro simulator, manual checks in the practice text view covered Burmese composition and suggestions, English suggestions, language switching, the three appearance options, and emoji search, insertion, recents, variants, backspace, and return to letters. The search-first picker and updated native styling were checked in light and dark appearances. Six core tests passed. Xcode's automated UI test runner had simulator connection errors, so the build and manual interaction checks provided separate evidence. Cross-app editing and physical-device performance remain pending.

An optimized simulator harness scrolled the actual picker through all 1,849 browse entries, verified the last row, searched for `cat`, and returned to the saved scroll position. Up to 48 cells were visible in a 278-point panel. Across four runs, the 95th-percentile scroll layout cost was 0.38–0.44 ms per one-row step. Handling three search keystrokes took 0.46–1.22 ms on the main thread, down from 63–75 ms. These timings measure UIKit layout and key handling in the harness. End-to-end frame delivery and physical-device latency remain unmeasured.

## 12. Reference material

These were consulted during discussion; they are references, not proof that a particular code/data asset is licensed for reuse.

- Apple — Creating a custom keyboard: https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard
- Apple — Handling text interactions: https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards
- Apple — Open/Full Access: https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- Apple — Custom Keyboard guide (archived; cross-check current APIs): https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
- Apple — Input traits, including keyboardAppearance: https://developer.apple.com/documentation/uikit/uitextinputtraits
- Apple — Interface appearance: https://developer.apple.com/documentation/uikit/uitraitcollection/userinterfacestyle
- Apple — App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Unicode — Myanmar FAQ: https://www.unicode.org/faq/myanmar.html
- Unicode — CLDR keyboard specification, including Myanmar reordering/backspace examples: https://www.unicode.org/reports/tr35/tr35-keyboards.html
- Unicode — Chapter 16, Myanmar ordering/spacing reference: https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-16/
- KeyMagic — Keyboard list including MyanSan and Pyidaungsu MM: https://kokoye2007.github.io/keymagic.net/keyboards/
- Myanmar Computer Federation listing — Pyidaungsu fonts/keyboards: https://myanmar.gov.mm/en/-/pyidaungsu-fonts-and-keyboards
- Pyidaungsu manual: https://mmunicode.org.mm/downloads/docs/Pyidaungsu_Font_User_Manual_05.pdf
