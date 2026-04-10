# MyCuKey

A Custom iOS Keyboard application built with SwiftUI.

## Overview

This project is a Custom Keyboard app that provides a foundation for implementing a rich, interactive keyboard using Swift and SwiftUI on iOS.

## Getting Started

1. Clone the repository.
2. Open `MyCuKey.xcodeproj` in Xcode.
3. Build and run the app scheme on an iOS Simulator or connected device.
4. **Note:** Ensure you have added the Custom Keyboard Extension target. (To do so: **File -> New -> Target... -> Custom Keyboard Extension**).

## Enabling the Keyboard

To use the custom keyboard on your device or simulator:
1. Run the app target.
2. Open the device **Settings**.
3. Navigate to **General > Keyboard > Keyboards > Add New Keyboard...**
4. Select *MyCuKey* from the list of third-party keyboards.
5. Tap on the newly added keyboard and toggle **Allow Full Access** (if your keyboard features require it).
6. Open any app with a text field (e.g. Messages, Notes) and tap the globe icon on the default keyboard to switch to MyCuKey.

## Current Features
- Modern, dynamic SwiftUI interface rendered atop standard `UIInputViewController` constraints
- Support for Light and Dark modes
- Automatic Auto-capitalization based on sentence context (periods, line breaks, empty text)
- Built-in "Globe" switch for transitioning to native keyboards
- Minimalist standard keyboard view leveraging SF Symbols

## Roadmap

- Implement advanced haptics for key presses
- Add settings in the `MyCuKey` host app to configure themes
- Support international layouts beyond QWERTY

## Requirements

- iOS 26.0+ (minimum deployment)
- Xcode 15.0+
- Swift 5+
