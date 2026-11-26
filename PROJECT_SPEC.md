# mboard

English / Burmese keyboard for iOS — product specification and discussion handoff.

Last updated: 2026-11-26 (Asia/Yangon).
Status: native iOS keyboard prototype implemented. The main typing and emoji flows were exercised on the iPhone simulator. Emoji picker layout and search were measured on the simulator. Physical iPhone trials are pending.

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
- Preserve the Gboard phone key positions. Use MyanSan Smart as the combining reference and prefer observed Android Gboard behavior when the two differ. Tapping က, ိ, ု or က, ု, ိ must produce the identical three scalars for ကို.
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

The practice screen pairs a small version of the icon with the MBoard title in the navigation bar. Its icon follows the app’s light or dark appearance. Both section titles use regular weight. The setup section includes Settings, Privacy Policy, and Support links. The latter two open the public repository documents from the containing app.

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

Character keys use 19-point type for Myanmar glyphs and 23-point type for Latin letters. Myanmar digits, punctuation, and long-press choices follow the same optical size adjustment. Only the labels change size. Touching a character key shows an enlarged glyph inside the keyboard bounds. Lifting the finger briefly fades the preview, and a long press shows alternates with the same cell dimensions, font sizing, corners, and shadow. Longer menus wrap to fit the available width. Modifier keys use an in-place highlight.

The keyboard inserts plain Unicode text into the host app. It cannot force the host app or recipient to render that text in Pyidaungsu. Layout compatibility must not depend on installing a particular font in every destination app.

## 6. Initial suggestion engine

The suggestion bar displays up to three completions. Prefix completions append only the missing Unicode scalars. English matching supports straight and curly apostrophes and preserves the typed prefix. MBoard uses the available US English `UITextChecker` dictionary, falling back to another available English locale, and reserves a place for a matching everyday word when possible. If UIKit supplies no completions, the bundled English vocabulary still works.

After accepting an English suggestion at the end of ordinary text, typing the next English letter inserts one separating space. Punctuation attaches directly, Space inserts one space, and Backspace edits the accepted word. Moving the caret, switching keyboards or languages, opening emoji or symbols, and changing fields clear the pending space. The sentence shortcut still requires two Space taps.

With the caret inside or immediately before an English word, MBoard checks the whole word for spelling suggestions. Tapping one edits that word and places the caret at its end. Common joined phrases and exact two-word splits from the local spelling dictionary can also appear in the three slots, including at the end of a word. A split requires a tap. Email and URL fields and address-like tokens skip these suggestions.

Burmese lookup tries the longest plausible prefix first, including word starts inside continuous text. It hides completions when a known word spans the caret or a combining mark follows it. Between words it omits candidates whose ending would duplicate text on the right. Hand-ranked conversational forms take priority over the word-break dictionary’s UTF-8 order. The extension bundles 41,120 entries from ICU 78.1 and searches the sorted list by prefix off the input thread. The resource retains the original entries and ships with the Unicode and Myanmar Karen Word Lists notices. [Upstream dictionary](https://github.com/unicode-org/icu/blob/release-78.1/icu4c/source/data/brkitr/dictionaries/burmesedict.txt) · [Bundled notices](Core/Resources/BurmeseWords-LICENSE.txt)

Only explicit single-word suggestion taps contribute to personal ranking. The extension stores up to 256 choices across both languages in its own defaults, recording the word, language, decayed selection weight and last selection date. Each tap adds one to the current weight. The weight halves every 30 days and stops boosting an entry below 0.25. Learned matches are considered before the three slots are filled. Long-pressing a learned suggestion offers **Forget This Suggestion**, which resets its personal boost. The keyboard settings menu offers **Clear Learned Words → Clear for Both Languages**. Ordinary dictionary entries remain available after either reset. Learning manually typed words and saving selected phrases remain open.

Lookup waits for a short typing pause. UIKit’s synchronous text checker runs on its required main actor, outside the insertion action, with a bounded in-memory cache for repeated English prefixes. Burmese indexing, candidate merging and history persistence run off the input thread. The keyboard drops results for stale text, language or selection. Opening the emoji picker clears host completions immediately. Selecting a Burmese prefix enables a completion scoped to the selection. Burmese suggestions never add spaces. Learned English choices use the current prefix and field capitalization when displayed.

The iPhone 18 Pro Max simulator practice field verified prefix completion followed by punctuation or another letter, splitting `Thankyou`, correcting `helo` from inside and before the word, and continuing `ကျောင်း` directly with `က`.

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

App Store rules and SDK behavior must be rechecked when implementation/distribution decisions depend on them. Preparation for App Store distribution is documented in [the submission guide](docs/APP_STORE.md).

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
- Manually saved personal words and learning from literal typing.
- Additional keyboard refinements for resizable iPad windows and floating keyboards.
- Frequency-ranked Burmese corpora and reusable composition rule sources.
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
- The app and extension target iPhone and iPad on iOS/iPadOS 16 and later. The iPad app declares all four orientations. Portrait iPhone is the original layout reference. The minimum version and English interaction details are prototype choices.
- Burmese base, Shift, default long presses, and two symbol pages use the emulator captures. English uses staggered QWERTY, digit hints, and sampled long presses. Some sliding alternates, the dedicated numeric keypad, and caps lock remain open.
- Burmese composition uses the Gboard-first decisions in the [MyanSan rule audit](references/myansan/README.md). It handles out-of-order or repeated marks, pretyped ေ with stacks and kinzi, and the smart letters ဈ, ဦ, ဩ and ဪ. The emoji query uses the same combining engine. The host editor tracks the active syllable and caret, inserts a reordered mark at its scalar position in the owned text, and uses native marked text when the host hides the editable range. When replacing a mark, the editor stages the new spelling before removing old scalars. A field that filters the temporary grapheme separator receives the tapped key literally. UIKit handles selection deletion. Verified collapsed-caret deletion preserves a neighboring space, Latin letter or emoji even when it shares a grapheme with an unfinished Burmese vowel.
- The far-left key on the bottom row shows the destination language, abc for English or ကခ for Burmese. The adjacent 123 or ၁၂၃ key takes 11% of the row width, leaving the remaining flexible width to Space. It toggles symbols for the current language. Both symbol pages stay open for consecutive characters. After entering a symbol, Space or Return takes the user back to letters. An immediate Space or Return on a newly opened symbol page leaves it open, matching the [Gboard symbol-page checks](references/gboard-english/README.md#symbol-pages-and-sentence-endings). A quick double tap of Space after a word inserts the active language’s sentence ending and a space. Emoji search keeps its ordinary query spacing. The toolbar shows a noninteractive 27-point MBoard mark on the left, suggestions in the middle, and a 15-point settings gear on the right. **Auto-Capitalization** starts on and follows the host’s English capitalization mode, including sentence, word, and all-character fields. In sentence mode, the first letter of each English word in a Burmese sentence is capitalized, including when the scripts touch. Manual Shift remains available. **Word Suggestions** starts on and controls the existing offline candidates in both languages. These choices follow the [emulator settings](references/gboard-english/README.md#typing-settings-observed-on-november-26-2026). The menu also offers System, Light, and Dark appearance. Preferences persist in the extension’s own defaults. System appearance inherits the keyboard input view’s traits so it follows the host field and responds to appearance changes while the keyboard is visible.
- The offline suggestion bar combines Apple-backed English completions, a bundled Burmese dictionary and conversational phrases, and locally learned selections (section 6). English suggestions support deferred spacing, whole-word corrections and missed-space suggestions.
- The smiley opens one scrollable, eight-column emoji grid with flat scroll edges. Session recents appear at the top when reopening the picker. Long-press an emoji for its skin-tone variants. Tapping search opens the full-size keyboard in the active language. In System appearance, the keys, suggestion bar, and emoji picker use the native keyboard container as their backdrop. The suggestion bar and emoji picker sit 7 points below the keyboard’s top edge. Explicit Light and Dark use MBoard’s rounded material behind the keys, suggestion bar, and emoji search, with a solid surface for emoji browsing. A blue insertion caret follows the query in Light and Dark, stays steady with Reduce Motion or the non-blinking cursor preference, and disappears when search closes. Typing extends the results above the query. Search supports English names and Myanmar keywords offline. Selecting a result inserts the emoji. Back returns to the original scroll position and ABC returns to regular typing. The catalog includes 3,624 fully-qualified Unicode Emoji 14.0 sequences and search annotations from CLDR 47. GIFs and stickers remain deferred. [Unicode emoji data](https://unicode.org/Public/emoji/14.0/emoji-test.txt) · [CLDR Myanmar annotations](https://www.unicode.org/cldr/charts/47/summary/my.html) · [Unicode license](Keyboard/Resources/Unicode-LICENSE.txt)
- The picker reuses fixed-size cells, builds its browse list and variation index once per extension process on a background task, and cancels obsolete searches as the query changes.
- The Android emulator supplied reference data. Version 0.1 (build 8), including the native System backdrop, 7-point top inset, and emoji search caret, was installed on an iPhone 15 Plus. Cross-app typing and performance checks on that device are pending.

On a 13-inch iPad Pro (M5) simulator, the installed release keyboard composed ကျောင်း, switched to English to type school, and inserted an emoji in the practice field. The [store preparation guide](docs/APP_STORE.md) records the screenshot sizes and submission materials.

On the iPhone 17 Pro simulator, practice-field checks covered Burmese composition and suggestions, English suggestions, language switching, the three appearance options, and emoji search, insertion, recents, variants, backspace, and return to letters. The search-first picker and updated native styling were checked in light and dark appearances. On November 26, one Backspace removed the selected middle word in “Hi red go.” At the caret, Backspace changed “Hi ကျောင်း” to “Hi ကျောင်.” Select All followed by Backspace then cleared the field. Both typing switches were exercised. The completion engine passed its original 12-test suite. On the simulator, English completions came from UIKit, an accepted Burmese completion preserved the preceding text, a learned choice retained its ranking after reinstall and relaunch, and forgetting or clearing restored default rankings. Xcode's automated UI test runner previously had simulator connection errors, so the build and direct simulator interactions provided separate evidence. Cross-app editing and physical-device performance remain pending.

Build 9 passed 17 core regressions, including four host-editing cases also exercised inside the iPhone simulator runtime. The installed simulator keyboard composed ကျောင်း, deleted a selected pending ကေ, suppressed host completions in emoji search and inside an English word, and offered lowercase hello after learning HELLO. English Shift updates letter titles, alternate actions and the Shift symbol in place. On the iPhone 17 Pro simulator, 20 Release-mode Shift taps had median synchronous update and layout times of 24.9 ms before key reuse and 4.6 ms afterward (95th percentiles 27.4 ms and 12.1 ms). These measurements exclude event delivery and display latency. The updated build 9 passed all 30 core tests and was installed on the paired iPhone 15 Plus. Cross-app typing on the phone remains pending.

The Gboard-first audit records 458 Android typing sequences, including all 225 ordered pairs of the 15 tested marks after က. The automated host checks exercise both scalar and grapheme deletion. The iPhone 17 Pro simulator is the integration reference for this update. Cross-app use and sustained typing on a physical device remain to be checked. [Rule coverage and emulator versions](references/myansan/README.md)

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
