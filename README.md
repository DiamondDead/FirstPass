# FirstPass

A fast, focused photo culling app for macOS — built as a spiritual replacement for Lightroom's library module.

FirstPass lets you open a folder of RAW files, browse them quickly, rate and flag each shot, then export your picks. Nothing more, nothing less.

---

## Why

After leaving Adobe, there's no standalone macOS app that does just the culling part well. FirstPass fills that gap — it pairs naturally with editors like Pixelmator Pro, keeping concerns separated: you cull here, you edit there.

---

## Features

- **Open any folder** of RAW, JPEG or TIFF files — no import, no catalog
- **Thumbnail grid** with fast JPEG preview extraction
- **Full RAW decode** in the background for accurate colour rendering
- **Flags** — Pick (P), Rejected (X), Unflagged (U)
- **Star ratings** — 1 to 5 via keyboard
- **Colour labels** — Red, Yellow, Green, Blue, Purple
- **Filter & sort** by any combination of the above
- **Export selection** — copy picks to a new folder
- **Open in...** — send any photo directly to Pixelmator Pro or any other editor
- **XMP sidecars** — all metadata written as `.xmp` files alongside your RAW files, compatible with Lightroom and Capture One

---

## Stack

- **Language** — Swift
- **UI** — SwiftUI
- **Image decoding** — CGImageSource (system RAW codecs)
- **Metadata** — XMP sidecar files
- **Persistence** — UserDefaults (last folder, UI preferences)
- **Platform** — macOS 14+

---

## Supported formats

CR3, CR2, ARW, NEF, RAF, RW2, ORF, DNG, RAW, HEIC, JPG, JPEG, TIFF, TIF

---

## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| Pick | P |
| Reject | X |
| Unflag | U |
| Rate 1–5 stars | 1 – 5 |
| Remove rating | 0 |
| Next photo | → |
| Previous photo | ← |
| Open in external editor | ⌘ ↵ |

---

## Project status

Early development. Personal project — built for my own workflow first.

---

## License

Private — all rights reserved.
