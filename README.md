# ImageFlow — Codeway Flutter Case (POC)

This is a small Flutter POC for the Codeway case study: **Image Processing & Analysis App**.

## Features

- **Home**: history list (thumbnail, type, date) + delete
- **Capture**: camera / gallery
- **Processing**: shows original image + progress step text
- **Auto routing**: Face vs Document
- **Face flow**: detect faces → grayscale face regions → save composite
- **Document flow**: text detection → simple crop → PDF export
- **History detail**: preview + metadata + open PDF externally

### Bonus implemented

- **Multi-page PDF**: add/remove/reorder pages, open PDF
- **Batch processing**: multi-select from gallery, queue processing, progress + summary screen

## Tech stack / dependencies

Required by case:

- `get` (state management, no `setState`)
- `google_mlkit_face_detection`
- `google_mlkit_text_recognition`
- `hive` / `hive_flutter` (local history metadata)

Used to keep the POC short:

- `image_picker` (camera/gallery)
- `image` (simple crop + grayscale + compositing)
- `pdf` (PDF export)
- `open_filex` (open PDFs)
- `path_provider` + `path` (file paths)

## Setup

### Prerequisites

- Flutter SDK installed
- Xcode (for iOS)
- Android Studio + SDK (for Android)
- CocoaPods (iOS):

```bash
sudo gem install cocoapods
```

### Install dependencies

```bash
flutter pub get
```

### iOS (first time)

```bash
cd ios
pod install --repo-update
cd ..
```

Then open `ios/Runner.xcworkspace` and set a **Development Team** for signing if running on a real device.

### Run

```bash
flutter run
```

## How to test flows quickly

- **Face**: pick a selfie → should end at Face Result (before/after)
- **Document**: pick a page photo → should end at Document Result (PDF)
- **Multi-page PDF**: in Document Result, tap **Add Page**, reorder, remove, then **Open PDF**
- **Batch**: Capture → **Batch (Bonus)** → select multiple images → wait → review screen → Done

## Notes (POC trade-offs)

- The app aims to be **lean** and **interview-explainable**.
- Face vs Document routing is best-effort (good enough for a POC).
- Document pipeline is intentionally simple (no heavy CV math).
