# MBoard privacy policy

Effective November 28, 2026. This policy covers the MBoard practice app and keyboard extension on iPhone and iPad.

MBoard processes typing, suggestions, and emoji searches on the device. The keyboard extension does not request Full Access. MBoard has no accounts, analytics, or service that receives keystrokes.

## What the keyboard remembers

- The extension saves the selected language and typing preferences in its own preferences. The submitted 0.1 store build also saves an appearance preference. The 0.1.1 keyboard follows the system appearance and ignores any previously saved choice.
- In the submitted 0.1 store build (11), MBoard learns from single-word suggestions you tap. The 0.1.1 source and the 0.1 development build (12) also learn English words you finish typing on the keyboard when **Word Suggestions** is on. It keeps up to 256 word records across both languages, including spelling, capitalization, usage counts, a ranking weight and the time of the latest use. Recent use carries more weight.
- In versions with typed-word learning, an English word can have up to six associated preceding words and their weights. For example, repeatedly typing “good morning” can move “morning” up when you next type “good m”. The keyboard stores these associations locally. It does not save a transcript.
- The keyboard reads nearby text to compose Burmese, determine capitalization and find suggestions. The 0.1.1 source and development build 12 skip suggestions and learning on numeric keypads and in fields the app marks for usernames, passwords, verification codes, card numbers, email addresses, URLs or phone numbers. Pasted text and emoji searches do not train the personal vocabulary. In 0.1.1, up to 32 recently chosen emoji are saved locally across keyboard sessions; the submitted 0.1 store build keeps them only in memory.

## Manage learned choices

Hold a learned suggestion and select **Forget This Suggestion** to remove its personal record and associated word pairs. To remove all learned choices, open the keyboard menu and select **Clear Learned Words → Clear for Both Languages**. Open the menu from the MBoard logo in 0.1.1 or the settings gear in the submitted 0.1 build. A word in the bundled dictionary or Apple’s English completions can still appear after clearing. **Word Suggestions** can be turned off to stop suggestions and new learning.

The app where you type receives the text you insert and handles that text under its own privacy practices.

## Collection, sharing and retention

MBoard does not transmit, sell or share typed text, learned suggestions, or identifiers. It has no advertising or third-party tracking SDKs. The practice field follows the same keyboard learning settings as an ordinary text field. Emoji searches stay in memory. Keyboard preferences, recent emoji and learned choices stay in local extension storage until cleared or the app is deleted. Clearing learned words leaves your recent emoji and other keyboard preferences in place.

Opening a support or policy link takes you to GitHub in your browser. GitHub handles visits under its own [privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). If you email support, the maintainer receives your email address and the information you choose to send, uses them to respond, and retains the correspondence only as needed to handle the request. Please use invented text in examples.

For a privacy question or a request to delete support correspondence, email [eimg@fairwayweb.com](mailto:eimg@fairwayweb.com). The maintainer cannot access learned words on your device. Changes to this policy will appear on this page with an updated effective date.
