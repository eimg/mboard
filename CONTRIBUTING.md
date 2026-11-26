# Contributing to MBoard

## Try a change

Build the app using the [README](README.md#build-from-source). The app and extension use UIKit. The Swift package contains the composition, layout and completion logic and can be tested independently from the repository root.

```sh
swift test
```

For the UI tests, use an iPhone simulator running iOS 17 or later. Run the practice app once, enable MBoard in iOS Settings, and select it in the practice field using the globe. Make sure the software keyboard is visible, then choose **Product → Test** in Xcode with the **MBoard** scheme.

## Report a typing issue

Include the iOS version, host app, keyboard language, and shortest sequence of taps that reproduces the issue. For editing bugs, mark the caret or selection and include the expected and actual text. A made-up example such as `သူကျော|` is enough. For layout issues, identify the key, layer, and whether you tapped or held it.

## Propose a change

Keep key feedback and text insertion responsive. Preserve surrounding text and Burmese spacing. If a change affects composition, deletion or completion, add a regression case under `Tests/` and try it in the practice field. For new dictionary or emoji data, include its upstream version, provenance and redistribution notices.
