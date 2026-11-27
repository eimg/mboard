# MBoard product specification

MBoard is a native, offline English and Burmese keyboard for iPhone and iPad running iOS or iPadOS 16 or later. The containing app provides keyboard setup, a practice field and links to support and privacy information. The UIKit keyboard extension handles typing in apps that permit third-party keyboards.

## Layout and editing

- In ordinary text fields, starting a Burmese word immediately after an English word or an English word immediately after a Burmese word inserts one space. This applies to typed words and accepted suggestions, including Burmese input starting with ေ. Switching layouts alone does not insert text. Punctuation, digits and existing whitespace do not trigger this shortcut.
- On the Burmese base layer, holding a key and lifting in place chooses its Gboard default. Slide to select additional iOS Burmese compounds, including က္က and က္ခ on က, and all five န stacks on န. On top-row keys, added compounds appear above the original Gboard choices so existing horizontal slides keep their targets.
- Preserve the familiar Android Gboard phone key positions and language layers. Use the captured layouts for key placement and long presses. Use MyanSan Smart as a composition reference, with observed Gboard output taking priority when rules differ. [Burmese layout](references/gboard-burmese/README.md) · [English layout and emoji](references/gboard-english/README.md) · [Composition examples](references/myansan/README.md)
- The bottom-left key shows the destination language. The adjacent symbol key uses the current language. Symbol pages stay open for consecutive symbols. After entering a symbol, Space or Return goes back to letters.
- Double-tapping Space after a word inserts the active language’s sentence ending and a space. Holding Space and dragging moves the caret. English Shift supports one-shot capitalization and Caps Lock. Automatic capitalization follows the field’s mode. In sentence mode, English words in Burmese text start with a capital.
- Insert standard Unicode and preserve neighboring text and selections. Both က + ိ + ု and က + ု + ိ produce ကို. Burmese composition and deletion must account for scalar order, active syllables and host editing behavior. Invalidate stale composition after caret, selection or field changes.
- Use the system font and its Myanmar fallback. The host app controls the font used for inserted text. Capitalize English words in Burmese interface copy.

## Offline suggestions

- Show up to three suggestions in fixed columns. Place the first choice in the center, the second on the left and the third on the right. Preserve the tap target when additional results arrive. Corrections and word splits require an explicit tap.
- English combines the available on-device English text checker with a bundled vocabulary and contraction list. Support prefix completion, spelling correction at the caret or inside a word, and missed spaces such as `thankyou`. Typing `Im` offers `I'm`. For ambiguous forms such as `well`, keep the contraction as an alternative. Space preserves the typed spelling.
- After accepting an English suggestion at the end of ordinary text, the next English letter starts a new word. Punctuation attaches directly. Changing fields, moving the caret, opening the emoji picker or switching language clears pending spacing.
- Burmese uses conversational entries and 41,120 ICU word-list entries. Look for prefixes inside continuous text, avoid duplicating text to the right of the caret and preserve Burmese spacing. [Dictionary and license notices](THIRD_PARTY_NOTICES.md)
- Learn confirmed single-word suggestion taps in both languages. For English, also learn words completed through the keyboard’s own keys. Everyday words qualify after two uses and other words after three. Preserve deliberately entered capitalization and avoid promoting repeated common typos. A tap contributes a weight of 1 and a typed word contributes 0.3.
- Store up to 256 word records locally, with up to six preceding-word associations per English word. Weights halve every 30 days. Skipping suggestions in sensitive fields, forgetting a word, clearing history and disabling Word Suggestions apply to personal learning as described in the [privacy policy](PRIVACY.md).
- Keep key feedback and insertion responsive. Debounce lookup and discard stale results. Run dictionary indexing, candidate merging and history persistence off the input thread. UIKit text checking runs on its required main actor after the typing pause.

## Appearance and emoji

The keyboard offers System, Light and Dark appearances for keys, modifiers, suggestions, key previews, alternate menus and the emoji picker. System mode follows the keyboard container’s traits and active field. The practice app follows the system appearance independently.

The emoji picker uses a single scrollable grid, session recents, skin-tone choices and offline English and Burmese search. Focusing search shows the typing keyboard with results above it. Switching languages during search updates the return key.

## Validation and scope

Core regressions cover composition, deletion, replacement, spelling, personal ranking and persistence. The Burmese fixture includes 458 Gboard input sequences. Simulator UI tests exercise mixed-script spacing, compound selection, language switching, appearance-dependent controls, suggestions and emoji in the practice field. Daily typing comfort and cross-app compatibility require physical-device testing. [Test instructions](CONTRIBUTING.md)

Typing requires no account, network or Full Access. iOS supplies its own keyboard in secure fields and some numeric fields, and apps can restrict third-party keyboards. Automatic correction, swipe typing, cloud sync and voice input are outside the current implementation. See the [changelog](CHANGELOG.md) for version status.
