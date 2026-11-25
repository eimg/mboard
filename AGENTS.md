# mboard — agent handoff

## Start here

Read `PROJECT_SPEC.md` before planning or changing code. It preserves the product discussion that preceded this folder. The folder contains a native iOS prototype and Android Gboard reference captures. See the implementation status in the spec before changing behavior. Physical iPhone validation is pending.

Read `/Users/eimg/AGENTS.md` for this computer's network/VPN and Fairway XMP instructions. Those instructions apply in addition to this file. Do not change optional PATH integrations. Fairway's PHP stack is not needed for this native iOS keyboard; do not start its services without a concrete task requirement.

## User and product context

- The user moved to iOS after roughly a decade on Android and strongly prefers Android Gboard's English/Burmese typing experience.
- Their current workaround is Gboard for English and Apple's built-in keyboard for Burmese. They find switching between them awkward.
- Apple's layouts/interactions are frustrating to them. Alternatives such as ttKeyboard have not satisfied them because of perceived lag and layout differences.
- The primary target is the familiar Gboard layout and comfortable daily typing. Do not redesign the Burmese layout merely because another arrangement looks cleaner.
- The user identified MyanSan as a relevant layout and Pyidaungsu as a relevant font. They participated in the early initiative around those projects. Respect that domain knowledge; verify exact variants rather than explaining basic Unicode unnecessarily or assuming that every named layout is identical.
- Basic dictionary-based suggestions for both English and Burmese are acceptable initially. Gboard-level prediction is not a prerequisite.
- System / Light / Dark appearance is an explicit first-version requirement, not a stretch feature.

## Working rules

1. Preserve the distinction between confirmed requirements, implementation recommendations, and unresolved choices in the spec. Do not present suggestions from the prior discussion as user-approved details.
2. Keep `PROJECT_SPEC.md` aligned with implemented behavior and meaningful new decisions. Record material deviations and remaining limitations.
3. Favor a lightweight, offline typing path. Network calls and dictionary work must not block key feedback or text insertion.
4. Treat Burmese layout, composition, Unicode output, and deletion as separate responsibilities. A visually familiar keyboard is insufficient if its text or editing behavior is wrong.
5. Compare against the user's actual Android Gboard Burmese layout, including alternate layers and long presses. MyanSan/Pyidaungsu resources are references, not proof of identical phone layouts.
6. Do not assume access to Google's Gboard source, language packs, dictionaries, or prediction models. Review licences before reusing fonts, dictionaries, layout-rule implementations, or other code/data.
7. Preserve user-entered text. Suggestions must not silently introduce Burmese spaces or destructively rewrite uncertain input. Suggestion-only behavior before automatic correction is a recommendation awaiting confirmation.
8. Implement appearance throughout the keyboard, including suggestions, modifier keys, pressed states, and long-press menus. In automatic mode, consider the appearance information supplied by iOS and the active input field; do not rely solely on a global device setting.
9. Respect iOS extension boundaries. Do not promise availability in secure fields or apps that prohibit third-party keyboards, microphone access inside the extension, a fixed universal memory allowance, or control over host-app fonts.
10. Test composition/editing logic meaningfully and verify typing on an actual iPhone across real apps. A simulator screenshot is not sufficient evidence of responsiveness or host compatibility.

## Implementation direction

The prototype uses Swift/UIKit with a containing app and a keyboard extension. Avoid unnecessary frameworks, servers, accounts, cloud AI, themes, and feature expansion. Begin with the smallest complete daily-typing experience described in the spec.

Implementation is authorized. Keep iOS validation on simulators until the user requests physical installation.
