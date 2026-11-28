# Third-party notices

MBoard’s original code is distributed under the [MIT license](LICENSE). The following materials have separate terms.

| Material | Source and use | Included notice |
| --- | --- | --- |
| Burmese dictionary | MBoard indexes entries from the [ICU 78.1 Burmese word-break dictionary](https://github.com/unicode-org/icu/blob/release-78.1/icu4c/source/data/brkitr/dictionaries/burmesedict.txt) for prefix completion. The dictionary credits the Myanmar Karen Word Lists project. | [Unicode and Myanmar Karen Word Lists notices](Core/Resources/BurmeseWords-LICENSE.txt) |
| Emoji catalog and search terms | The keyboard’s emoji table uses [Unicode Emoji 17.0](https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt) and CLDR 48 [annotations](https://github.com/unicode-org/cldr/tree/release-48/common/annotations) and [derived annotations](https://github.com/unicode-org/cldr/tree/release-48/common/annotationsDerived) for English and Burmese search. iOS renders the glyphs; MBoard bundles no vendor emoji artwork. | [Unicode license and CLDR notice](Keyboard/Resources/Unicode-LICENSE.txt) |

Regenerate the emoji table with `python3 Scripts/generate_emoji.py --cache /tmp/mboard-emoji-sources`. The generator pins source versions and SHA-256 checksums, retains fully qualified sequences and merges English/Burmese annotations without variation selectors in lookup keys. Add `--offline` to use an already downloaded, verified cache. The curated ordering and supplemental search aliases are MBoard’s original data under its MIT license.

The Android Gboard screenshots under `references/` document observed layouts and interactions. They are development references, are excluded from MBoard’s MIT license, and are not bundled in the app. Gboard is a trademark of Google.
