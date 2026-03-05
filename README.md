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

## Setup

### Clone on a new machine

```bash
git clone <your-repo-url>
cd codeway-flutter
```

Run all Flutter commands from the project root (the folder containing `pubspec.yaml`).

### Prerequisites

- Flutter SDK installed
- Xcode (for iOS)
- Android Studio + SDK (for Android)

### Install dependencies

```bash
flutter pub get
```

Regenerate platform folders once:

```bash
flutter create .
```

### Run

```bash
flutter run
```

## How to test flows quickly

- **Face**: pick a selfie → should end at Face Result (before/after)
- **Document**: pick a page photo → should end at Document Result (PDF)
- **Multi-page PDF**: in Document Result, tap **Add Page**, reorder, remove, then **Open PDF**
- **Batch**: Capture → **Batch (Bonus)** → select multiple images → wait → review screen → Done

