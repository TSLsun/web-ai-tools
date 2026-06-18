# Summary · iOS App Icon Spec (React)

Interactive spec sheet for the **Summary** app icon — direction **C-1 "Masthead"**.
React/Vite port of `summary-icon-final.html` (the locked Open Design artifact). Visual
design, layout, colors, measurements, and the icon artwork are preserved verbatim.

## Icon

Cobalt masthead rule + ghost sub-rule over a bold `S` lettermark on a light squircle —
evoking a news article condensed to its headline. Source vector lives in
`src/IconSummary.jsx` (`IconArt`), reused at every iOS size by `Squircle`.

## Run

```bash
cd app-icon-spec
npm install
npm run dev          # dev server → http://localhost:5173
```

## Preview a production build

```bash
npm run build        # outputs dist/
npm run preview      # serves dist/ → http://localhost:4173
```

## Verify

- `npm run build` completes with no errors.
- Open the dev URL: header badge "Direction locked · C-1", 240px hero on light panel,
  dark-wallpaper strip, horizontally scrollable iOS size matrix (180→40px), and the
  Color / Measurements spec cards.

## Shipping note

Before App Store submission, replace the SVG `<text>` `S` with an outlined path
(SF Pro Display ExtraBold) and master-export at 1024×1024 (no rounded corners — Xcode
applies the squircle mask).
