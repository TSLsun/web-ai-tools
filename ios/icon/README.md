# App Icon — source & regeneration

Master art for the **Summary** iOS app icon (direction **C-1 "Masthead"**).
Cobalt masthead rule + 30% ghost rule over a bold `S` lettermark on `#f4f5fa`.

The shipped asset lives in the catalog:
`../NewsSummarizer/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

This folder holds the **vector source** so the PNG can be rebuilt deterministically.

## Files

| File             | Role                                                       |
|------------------|------------------------------------------------------------|
| `AppIcon.svg`    | 1024-mapped master, opaque, no rounded corners             |
| `AppIcon-1024.png` | Last exported raster (mirror of the one in the catalog)  |
| `flatten.swift`  | CoreGraphics tool: strips alpha, flattens onto solid bg    |

## Regenerate the 1024 PNG

Requires macOS (QuickLook renders the SVG with the real **SF Pro** font; Xcode toolchain compiles the flattener):

```bash
cd ios/icon
qlmanage -t -s 1024 -o /tmp/ql AppIcon.svg            # SVG -> PNG (WebKit, system font)
swiftc -O flatten.swift -o /tmp/flatten               # build the alpha flattener
/tmp/flatten /tmp/ql/AppIcon.svg.png AppIcon-1024.png '#f4f5fa'   # opaque, no alpha
cp AppIcon-1024.png ../NewsSummarizer/Assets.xcassets/AppIcon.appiconset/
```

Verify: `sips -g pixelWidth -g pixelHeight -g hasAlpha AppIcon-1024.png`
→ must be `1024 × 1024`, `hasAlpha: no` (App Store rejects icons with an alpha channel).

## Why this setup (iOS best practice)

- **Single 1024×1024 source** in the asset catalog — Xcode 14+/iOS 17+ auto-derives every
  Home/Spotlight/Settings/Notification size at build (validated here with `actool`).
- **Opaque, sRGB, no alpha, square** (no pre-rounded corners) — the system applies the squircle mask.
- The repo's React page (`/app-icon-spec`) is the **design spec/preview only** — not a shipping
  artifact. The real icon is this raster baked into `Assets.xcassets`.

## Before App Store submission (optional hardening)

Replace the SVG `<text>` `S` with an **outlined path** (SF Pro Display ExtraBold) so the master
no longer depends on a font being installed at render time. Current pipeline already bakes the
glyph into the PNG, so the shipped asset is font-independent — this only future-proofs `AppIcon.svg`.
