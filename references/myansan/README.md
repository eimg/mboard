# Burmese typing rule audit

MBoard uses the existing Gboard phone layout. MyanSan Smart supplies the reference for combining behavior. When the two keyboards produce different text, the Android Gboard behavior observed for that sequence takes precedence.

The desktop comparison used the compiled MyanSan.km2 in the upstream KeyMagic engine. The line numbers below refer to the matching source revision. MyanSanMobile.kms is a separate keyboard with a different placeholder and double-tap bindings. A second tap on MBoard follows Gboard's handling of that mark. [MyanSan Smart rules](https://github.com/thantthet/keymagic-keyboards/blob/61da86297fdb99da56b2892190f73009dfe8bc07/MyanSan/MyanSan.kms) · [Mobile variant](https://github.com/thantthet/keymagic-keyboards/blob/61da86297fdb99da56b2892190f73009dfe8bc07/MyanSan/MyanSanMobile.kms) · [Reference engine](https://github.com/thantthet/keymagic/tree/6a662fb071e1f0e0c9271f84e28712b9e78962ab)

| MyanSan Smart lines | Rule | MBoard decision and observed examples |
| --- | --- | --- |
| 9, 153–158, 211 | Smart Backspace and commented deletion examples | Remove one output scalar at a collapsed caret when the host deletion can be verified. Backspace after ေ + က leaves က. Backspace after စ + ျ removes the resulting ဈ. A selection is deleted by the host. |
| 11–100, 103–106, 210 | Bind pretyped ေ, place it after a base or stack, order medials before it | An unfinished ေ is U+200C U+1031. It accepts ဿ and independent letters. ေ + ဥ gives ဉေ. With no intervening base, ေ + ျ retains the joiner and tap order. |
| 103–106 | Virama and stacks | ေ + က + ္ gives U+200C U+1031 U+1000 U+1039. Tapping ဏ gives က္ဏေ. Backspace while waiting removes the virama. The direct ဏ္ဍ shortcut and long-press kinzi are each a single tap. ေ + kinzi + က gives င်္ကေ. |
| 108–114, 129–131, 151 | Base, digit, vowel, medial and tone key mappings | Use the phone's base, Shift, symbol and long-press outputs. The existing key map records each character position. |
| 116–117, 165–168 | Single-letter spellings | စ + ျ gives ဈ. ဥ + ိ or ီ gives ဦ. သ + ြ gives ဩ, and ေ + သ + ြ + ာ + ် gives ဪ. The standalone ဥ remains available. |
| 118–123 | Upper/lower vowels, anusvara, ai and dot | Both vowel orders give ကို. A new upper vowel can replace the previous one across a lower vowel. Retapping the same lower vowel keeps one copy. All six orders of ိ, ု and ့ after က give ကို့. |
| 124–126, 160–161 | Ai, anusvara, aa, dot, visarga and asat | Gboard replaces ံ with ဲ when ဲ is tapped next. က + း + ့ keeps that order, while က + ် + ့ gives က့်. The fixture includes both tap orders for every mark pair. |
| 133–140 | Medial pairs and triples | The editable syllable orders ျ, ြ, ွ and ှ. က + ွ + ှ + ျ gives ကျွှ. A repeated medial occupies one position. |
| 142–149 | Medials before pretyped ေ | ေ + က + ွ + ှ + ြ gives ကြွှေ. The same marks before any base retain their literal order after the placeholder. |
| 172–208 | Desktop Shift shortcuts, dead key, ASCII punctuation, keypad and space | Phone shortcuts emit the strings on their keys. Space and symbols remain available on the existing layout. Desktop physical-key combinations do not define additional touch gestures. |

## Verification

On 26 November 2026, 458 distinct tap sequences were recorded from the Burmese Gboard on a disposable Android API 35 emulator running Gboard 14.2.09.629370537. The expected text came from a local Android EditText after actual key taps. Coverage includes all 225 ordered pairs of 15 marks after က, additional multi-mark sequences, direct shortcut keys, kinzi, stacks and deletion. The fixture uses an explicit token for an invisible joiner or an empty result. The host regression test replays each sequence between surrounding text with both scalar-deleting and grapheme-deleting hosts. Earlier Gboard 18.6.3 observations cover the user’s layout and additional editing examples. [Recorded taps](../../Tests/Fixtures/GboardBurmese.tsv) · [Gboard 18 reference](../gboard-burmese/README.md)

The separate MyanSan comparison exercised 7,622 generated sequences, including repeated and conflicting inputs. It enumerated all one-, two- and three-mark combinations of the same 15 marks after က and ကေ, plus selected base, shortcut and deletion cases. MBoard matched the desktop engine on 3,086 sequences and differed on 4,536. Of the 339 tap sequences common to both comparisons, the two reference keyboards disagreed on 151. MBoard followed Gboard in all 151. The larger generated corpus includes sequences that were never typed on Android.

On the iPhone 17 Pro simulator, the installed extension produced ကို with either vowel first. Touch checks also covered long-press kinzi, an unfinished stack after a preceding word and space, Backspace, deleting a selection, and accepting ကျောင်း from ကျော. The Swift package passed all 23 tests.
