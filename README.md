# Yomu

A native SwiftUI app for learning Japanese through books. Built for iPhone and iPad (iOS 17+) and Mac (macOS 14+, using Mac Catalyst), with Swift orange, warm light surfaces, and a dark theme.

## Run the app

1. Open **Yomu.xcodeproj** in Xcode.
2. Choose the **Yomu** scheme and an iPhone or iPad simulator.
3. Press **⌘R**. The app includes an original six-page Japanese starter story.

No API key, server, account, or third-party Swift dependency is required. The complete offline dictionary is already bundled. To run on a physical device, select your development team under the Yomu target’s **Signing & Capabilities**, and use a unique bundle identifier if needed.

The working name is **Yomu** (読む, “to read”). The current emblem and app icon are placeholders for my Procreate logo. Will replace the icon in `App/Assets.xcassets/AppIcon.appiconset` and the in-app `BrandMark` in `App/Components/Theme.swift` when the artwork is ready.

Previews: [iPhone, light](Documentation/Previews/iphone-library-light.png) · [iPhone, dark](Documentation/Previews/iphone-library-dark.png) · [iPad](Documentation/Previews/ipad-library-light.png) · [Mac library](Documentation/Previews/mac-library.png) · [Mac reader](Documentation/Previews/mac-reader.png).

## Run on your Mac

With Xcode installed and its first-launch setup completed, run these commands from the project folder:

```sh
bash Scripts/build-mac.sh
open Dist/Yomu.app
```

The script produces a standalone, locally signed app for your Mac's processor. You can drag `Dist/Yomu.app` into your Applications folder and launch it from Finder or Spotlight without opening Xcode. Building and using this local Mac version requires no Apple Developer Program membership. Rebuild after source changes; previous generated apps are preserved in `Dist/`. This script packages the app for local use; signing and notarization for distribution to other people are separate steps.

To develop in Xcode, choose **Yomu → My Mac (Mac Catalyst)** and press **⌘R**. The desktop version has a sidebar, a resizable window, a native file picker, and these menu shortcuts:

| Shortcut | Action |
| --- | --- |
| ⌘O | Import PDF, EPUB, or TXT books |
| ⌘1 / ⌘2 / ⌘3 | Library / Words / Activity |
| ⌘, | Settings |

Use the mouse to select text in the reader, then choose **Look up** or **Highlight**. Books, saved words, and progress are stored locally; Mac and iPad libraries do not sync. On Mac, the sandboxed library lives under `~/Library/Containers/com.yomu.reader/Data/Library/Application Support/Yomu/` and survives replacing the app.

## Install on your iPad with TestFlight

Uploading to TestFlight requires an active **Apple Developer Program** membership and access to App Store Connect. A free Xcode Personal Team can install directly on your iPad, but cannot distribute through TestFlight. See [Apple's developer account guide](https://developer.apple.com/help/account/basics/about-your-developer-account).

1. **Configure signing.** In Xcode, sign in under **Settings → Accounts**, then open the Yomu target's **Signing & Capabilities**. Enable automatic signing, select your enrolled team, and replace `com.yomu.reader` with a unique bundle identifier you own, such as `com.yourname.yomu`. If you use XcodeGen, also save the identifier and `DEVELOPMENT_TEAM` in `project.yml` so regeneration preserves them.
2. **Create the app record.** In [App Store Connect](https://appstoreconnect.apple.com), go to **Apps → + → New App**, choose **iOS**, enter the name, choose the same bundle identifier, and enter a unique SKU such as `yomu-ios`. iPhone and iPad use the same iOS app record.
3. **Archive and upload.** In Xcode, select the **Yomu** scheme and **Any iOS Device (arm64)** as the destination. Choose **Product → Archive**. In Organizer, select the archive, choose **Distribute App → App Store Connect**, and follow the upload prompts. See [Apple's build upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).
4. **Add yourself as an internal tester.** After Apple processes the upload, open the app's **TestFlight** tab. Complete any requested test information and export-compliance questions. Create a group under **Internal Testing**, add your own App Store Connect user, and add the uploaded build. Apple documents [the internal tester steps here](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).
5. **Install on the iPad.** Install Apple's **TestFlight** app from the App Store. Open the invitation email on the iPad, accept it in TestFlight, and tap **Install** for Yomu. You can then open Yomu from your Home Screen.

TestFlight builds expire after **90 days**. Increase the build number (`CURRENT_PROJECT_VERSION` in `project.yml`, or **Build** in Xcode) for subsequent uploads. Inviting external testers introduces Apple's beta review process. See [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview).

## What works

- **Persistent library:** import multiple PDF, EPUB, or TXT files through Files; search and sort books; keep a local copy, covers where provided by EPUB, reading position, highlights, and completion status. Remove books from their context menu. Saved vocabulary and session history survive removing the source book.
- **Paced reading:** start from any page or chapter. Choose a page count, the current chapter, the rest of the book, or free reading. Automatic scrolling and page turns start at **120 Japanese characters/minute**, adjustable from 30–600. Pause/resume, step between pages, change text size, or finish at any time. Selecting text, scrolling manually, opening a sheet, and leaving the app pause reading.
- **Selection and lookup:** long-press to select text, then choose **Look up in Yomu** or **Highlight** in the selection menu. A selection toolbar also provides these actions. Definitions include Japanese word readings, English meanings, part of speech, individual kanji on’yomi/kun’yomi, and Japanese speech synthesis. Other matching readings/senses are available in the lookup sheet. Save a word with its original sentence and source page.
- **Session quizzes:** multiple-choice readings and meanings from visited pages. Looked-up and saved words receive priority, followed by highlighted passages and extracted Japanese vocabulary. Quizzes use dictionary entries for answers, show corrections and source sentences, and summarize missed answers. An insufficient-text state appears when a useful quiz cannot be formed.
- **Vocabulary and activity:** review or remove saved words, practice them again, view page counts and reading sessions, and see activity for the last seven days.
- **Appearance:** system, light, and dark modes; persistent reading speed and text size; support for Dynamic Type and labeled controls.

## Format and learning boundaries

- PDFs must have selectable text. Original PDF page numbers and outline chapters are kept; content is reflowed into the reader. Complex vertical layouts may have an imperfect extraction order. Image-only pages are identified, and fully scanned documents are rejected with an explanation.
- EPUB 2/3: stored/deflated ZIP members, container/package metadata, spine order, chapter headings, and cover metadata. Ruby annotation text is omitted from extraction so furigana is not duplicated into the reading text. Encrypted chapters are rejected; font-only obfuscation does not block text import. Invalid markup and unsupported archive formats produce errors.
- TXT supports UTF-8, UTF-16 with a byte-order mark, and Shift-JIS. EPUB and TXT are divided into stable logical pages of roughly 650 characters, independent of display size. Long paragraphs can break at page boundaries.
- Import limits: 75 MB source file, 16 MB per EPUB member, 200 MB total declared uncompressed EPUB content, fewer than 5,000 ZIP members, and up to 5,000 PDF pages. Archive members are read in memory, never extracted to filesystem paths; integrity checks and traversal checks reject malformed archives.
- Dictionary lookup includes common inflection handling. Names, slang, unusual conjugations, and context-dependent senses may require selecting a shorter word or choosing a different dictionary match. On’yomi and kun’yomi are **kanji-level** readings; whole-word pronunciation is shown separately.
- Quiz selection uses local Japanese tokenization, adjacent-token matching for conjugations, and simple difficulty heuristics. Automatic selection is conservative with kana-only words to avoid homophones and auxiliary endings; explicitly saved words can still be practiced. It is not JLPT-level assessment or context-aware sense disambiguation. English definitions can include more than one sense. Essay questions, RAG, OCR/manga support, vertical typesetting, cloud sync, and spaced repetition are future work.
- Japanese pronunciation requires an available Japanese system speech voice. The app never sends book text to an application server. Device-level backups may include local app data.

## Project layout

| Path | Purpose |
| --- | --- |
| `App/` | SwiftUI screens, app state, speech, native text selection, assets |
| `Sources/YomuCore/` | Models, persistence, importers, ZIP reader, dictionary, quiz engine |
| `Sources/YomuCore/Resources/` | Bundled SQLite dictionary and its license |
| `Tests/YomuCoreTests/` | Core tests and small original import fixtures |
| `Tests/YomuUITests/` | Simulator tests of reading, lookup, quizzes, and relaunch |
| `project.yml` | XcodeGen source for the checked-in Xcode project |
| `Scripts/` | Local Mac app build script, dictionary, fixture, and placeholder icon generators |

The app stores a small atomic `library.json` index in Application Support/Yomu, with book text and source files in UUID-named subdirectories. The dictionary uses indexed, read-only SQLite access through an actor. Parsing runs outside the UI actor. A corrupt library index is reported and preserved rather than silently reset.

## Validation

Baseline verified with Xcode 26.6: **15 core tests pass**, and **5 UI tests pass on both iPhone 17 Pro and iPad Pro 11-inch simulators**. Both light and dark screens were reviewed.

The Mac port was built and locally signed with **Xcode 27.0**, launched on **macOS 26.6.2**, and verified with a desktop UI test covering keyboard navigation, Settings, the native import panel, opening a book, pausing, page navigation, and quiz feedback. The settings and complete reading/quiz/persistence regression tests also pass on an **iPad Pro 11-inch simulator running iPadOS 27.0**. Physical-device audio and imports of your own books remain useful hands-on checks.

Core tests can run on macOS without an iOS simulator:

```sh
swift test
```

Build and run UI tests with an installed iOS simulator:

```sh
xcodebuild -project Yomu.xcodeproj -scheme Yomu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/Xcode CODE_SIGNING_ALLOWED=NO test
```

Run the Mac UI test with local test signing:

```sh
xcodebuild -project Yomu.xcodeproj -scheme Yomu \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath .build/MacTests \
  -only-testing:YomuUITests/YomuUITests/testMacNavigationImportPanelAndReading \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO ENABLE_HARDENED_RUNTIME=NO test
```

The UI tests use a fresh temporary library, separate from the normal app library, and attach screenshots to the test results. Core tests cover EPUB spine order, deflate/stored entries, ruby exclusion, encryption, corruption, traversal, Japanese text encodings, PDF extraction, dictionary data, inflections, quiz correctness, goals, pagination, and persistence.

After changing the project definition, regenerate with `xcodegen generate`. XcodeGen is unnecessary for opening or running the existing project.

## Dictionary attribution and updates

This app uses **JMdict and KANJIDIC2**, copyright © James William BREEN and the **Electronic Dictionary Research and Development Group (EDRDG)**, under **Creative Commons Attribution-ShareAlike 4.0**. The SQLite adaptation remains under that license. See [EDRDG’s license and documentation](https://www.edrdg.org/edrdg/licence.html), the bundled license file, and the app’s Settings → Dictionary sources & licenses.

The current bundle includes **324,835 word/reading pairs** and **13,108 kanji**. `Scripts/build_dictionary.py` preserves writing/reading and sense restrictions, retains Japanese readings and English glosses, and omits unrelated KANJIDIC2 fields.

Refresh the data **before every release**:

```sh
mkdir -p .cache
curl --fail --location https://www.edrdg.org/pub/Nihongo/JMdict_e.gz --output .cache/JMdict_e.gz
curl --fail --location https://www.edrdg.org/pub/Nihongo/kanjidic2.xml.gz --output .cache/kanjidic2.xml.gz
python3 Scripts/build_dictionary.py
swift test
```

The database records its build date in the `metadata` table. Dictionary-derived data and the app’s source code have separate licensing concerns; the bundled dictionary license does not assert ownership over the app’s source code or imported books.
