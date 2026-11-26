# Changelog

## Unreleased

### MBoard 0.1

This first version brings English and Burmese typing to one keyboard for iPhone and iPad. It targets iOS and iPadOS 16 and later and works offline with Full Access off.

- Switch between English QWERTY and a Burmese Unicode layout with shifted keys and long-press alternatives. English auto-capitalization follows the active field and can be turned off.
- Burmese labels use smaller lettering on the same touch targets. Touch a character key in either language to see an enlarged preview above your finger.
- Tap one of up to three completions. English uses Apple’s on-device text checker and a bundled vocabulary. Burmese includes everyday phrases and 41,120 dictionary entries. For example, choosing `ကျောင်း` after `သူကျော` produces `သူကျောင်း` and preserves the surrounding text and spacing.
- Suggestions you choose can move up on later matches. Forget one choice by holding it, or clear both languages’ learned choices from the menu under the MBoard logo.
- Delete a text selection with one Backspace. At a Burmese insertion point, Backspace can remove one Unicode component at a time.
- Scroll the emoji catalog, search in English or Burmese, and hold an emoji for available skin tones.
- Choose System, Light, or Dark keyboard appearance. The companion app includes a practice field, Burmese setup instructions, and a Home Screen icon with light and dark artwork.

- Type ကို with either vowel first. Burmese composition follows Android Gboard for repeated marks, pretyped ေ with stacks or kinzi, and the letter sequences for ဈ, ဦ, ဩ and ဪ.
- The practice app links to the public privacy policy and support contact.

**Validation so far** · Simulator checks covered typing, deletion, completions and emoji. Build 9 adds verified Burmese vowel reordering and Backspace handling for bounded host context. English suggestions respect mid-word edits and learned casing. Emoji search clears host suggestions, and English Shift reuses the existing keys. Build 8 was installed on an iPhone 15 Plus. Cross-app editing and sustained typing performance on a physical iPhone still need testing. Portrait iPhone is the reference layout.
