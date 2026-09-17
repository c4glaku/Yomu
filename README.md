# Yomu

Learn Japanese through reading. Yomu (読む, “to read”) is a native, offline app for iPhone and iPad (iOS/iPadOS 17+) and Mac (macOS 14+ via Mac Catalyst).

No account, API key, or server required. A Japanese starter story and offline dictionary are included.

[View screenshots](Documentation/Previews)

## Features

- **Personal library:** import PDF, EPUB, and TXT books; search, sort, highlight passages, and resume where you left off.
- **Paced reading:** set page or chapter goals, adjust reading speed, and use automatic scrolling and page turns.
- **Japanese lookup:** select words for readings, English definitions, kanji details, and pronunciation; save vocabulary with its source sentence.
- **Practice and progress:** take reading and meaning quizzes, revisit saved words, and track reading activity.
- **Native experience:** light and dark themes, adjustable text size, Dynamic Type, and Mac keyboard shortcuts.

Books and progress stay on each device; cloud sync is not supported. Imports are limited to 75 MB per file and require readable text: scanned PDFs and encrypted EPUB chapters are unsupported. Text is reflowed; original layouts and vertical typesetting are not preserved. Pronunciation requires an installed Japanese system voice.

## Setup

Requires a Mac with Xcode 16 or later and its initial setup completed.

1. Clone the repository and open the project:
   ```sh
   git clone https://github.com/c4glaku/Yomu.git
   cd Yomu
   open Yomu.xcodeproj
   ```
2. Select the **Yomu** scheme and an iPhone/iPad simulator or **My Mac (Mac Catalyst)**.
3. Press **⌘R** to build and run.

For a physical iPhone or iPad, choose your development team and a unique bundle identifier under **Signing & Capabilities**.

To build a standalone app for your Mac:

```sh
bash Scripts/build-mac.sh
open Dist/Yomu.app
```

The local Mac build requires no Apple Developer Program membership.

## Tech stack

- **App:** Swift 6, SwiftUI, UIKit, and Mac Catalyst.
- **Books and language:** PDFKit, Foundation XML, zlib, NaturalLanguage, and AVFoundation.
- **Storage:** SQLite for JMdict/KANJIDIC2; JSON and local files for the library.
- **Tooling:** Swift Package Manager, Swift Testing, XCTest, optional XcodeGen, and Python dictionary tooling. No third-party Swift dependencies.

Core logic lives in [Sources/YomuCore](Sources/YomuCore); screens live in [App](App). Run core tests with `swift test`, or UI tests with **⌘U** in Xcode. XcodeGen is optional; use `xcodegen generate` after editing [project.yml](project.yml).

## Dictionary attribution

JMdict and KANJIDIC2 © James William BREEN and the Electronic Dictionary Research and Development Group (EDRDG). Dictionary data and its SQLite adaptation are licensed under **CC BY-SA 4.0**; see the [dictionary license](Sources/YomuCore/Resources/Dictionary-LICENSE.txt) and [data build script](Scripts/build_dictionary.py).
