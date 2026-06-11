# iOS News Summarizer — Design Spec

**Date:** 2026-06-10  
**Status:** Approved  
**Distribution:** Personal use, sideloaded via Xcode

---

## Problem

Dad sends news links via LINE. Links contain heavy ads, spam, and excessive text. Need a fast way to get clean structured summaries directly from iOS share sheet without paying for extra AI API subscriptions.

---

## Solution

Native iOS app (Swift/SwiftUI) with a Share Extension. Activated from LINE or any browser share sheet. Fetches article, strips ads via SwiftSoup (Readability-style), then summarizes via Mac HTTP server over Tailscale (primary) or Gemini Flash free tier (fallback).

---

## Architecture

Two Xcode targets in one project, sharing one App Group container:

### Target 1: Main App (SwiftUI)
Settings screen only. No other UI. Stores config so Share Extension can read it.

### Target 2: Share Extension
Core product. Runs entire summarize flow. Shows SwiftUI result view inline in share sheet.

### Mac Companion: HTTP Server
Tiny Python HTTP server (~50 lines) running on Mac as a LaunchAgent. Accepts POST requests, shells out to `claude -p` CLI (uses existing Claude Code subscription — no extra API cost), returns structured summary JSON.

### Shared Code
`SettingsStore` and `SummaryPromptBuilder` linked by both targets via common source group.

---

## Networking & Security

**Tailscale** (free personal tier) creates a WireGuard mesh VPN between Mac and iPhone.
- Both devices get stable private IPs (`100.x.x.x`) — never change
- Traffic is E2E WireGuard-encrypted — zero public internet exposure
- No open ports on Mac required — Tailscale handles NAT traversal
- Only devices on the user's tailnet can reach the server

Additional hardening: Mac server requires a shared secret header (`X-Secret: <token>`) to reject any accidental non-tailnet requests.

---

## Core Flow

```
Share URL (LINE / Safari / any app)
  → Share Extension activates
  → Extract URL from NSExtensionItem
  → Fetch raw HTML (URLSession)
  → SwiftSoup: strip nav / ads / footer → clean text + title
  → Attempt Mac server (3s timeout):
      POST { url, cleanText, language } to http://[tailscale-mac-ip]:8765/summarize
      Header: X-Secret: <shared token>
      Mac runs: claude -p "Summarize in [lang]: [cleanText]"
      ✓ response → display summary
      ✗ timeout or error → fallback
  → Fallback: Gemini Flash API
      POST prompt + clean text to gemini-2.0-flash free endpoint
      Header: x-goog-api-key: <key>
      ✓ response → display summary
      ✗ error → show error UI
  → Display structured result:
      [Article Title]
      • Key point 1
      • Key point 2
      • Key point 3
      [Original link]
```

Mac server call doubles as reachability probe — no separate ping needed. 3s timeout keeps fallback fast.

---

## Components

### iOS App

| Component | Target | Responsibility |
|---|---|---|
| `URLFetcher` | Extension | Async fetch raw HTML via URLSession |
| `ReadabilityParser` | Extension | SwiftSoup: extract title + main body, strip nav/ads/footer |
| `MacClient` | Extension | POST to Mac HTTP server with Tailscale IP + secret header |
| `GeminiClient` | Extension | REST call to Gemini Flash free endpoint |
| `SummaryPromptBuilder` | Shared | Build prompt with language instruction + clean text |
| `SummaryView` | Extension | SwiftUI: title + bullets + original link + copy/share buttons |
| `SettingsStore` | Shared | Keychain (secret token, Gemini key) + UserDefaults (language, Mac IP) |
| `SettingsView` | Main App | SwiftUI form for all config fields |

### Mac Companion

| Component | Responsibility |
|---|---|
| `server.py` | Python HTTP server, validates secret header, shells `claude -p` |
| `com.tslsun.newssummarizer.plist` | LaunchAgent plist — auto-starts server on Mac login |

---

## Settings

| Setting | Storage | Default |
|---|---|---|
| Language | UserDefaults | `zh-TW` (options: zh-TW, en-US, ja, de) |
| Mac Tailscale IP | UserDefaults | — (e.g. `100.x.x.x`) |
| Shared secret token | Keychain | — (user generates once) |
| Gemini API key | Keychain | — (free key from Google AI Studio) |

---

## Summary Output Format

```
[Article Title]

• Bullet point 1
• Bullet point 2  
• Bullet point 3

原文連結: https://...
```

AI prompt instructs: respond in selected language, structured as title + 3–5 bullets + no opinions.

---

## Mac Server API

```
POST http://[tailscale-ip]:8765/summarize
Headers:
  Content-Type: application/json
  X-Secret: <token>

Body:
  { "url": "...", "cleanText": "...", "language": "zh-TW" }

Response 200:
  { "title": "...", "bullets": ["...", "...", "..."], "url": "..." }

Response 401:
  { "error": "unauthorized" }
```

---

## Error Handling

| Failure | Behavior |
|---|---|
| URL fetch fails | Show "無法載入頁面" + retry button |
| SwiftSoup extracts empty body | Warn user; pass raw truncated HTML to AI anyway |
| Mac server timeout (3s) | Silent fallback to Gemini, no user-visible message |
| Gemini API fails | Show "摘要失敗" + retry + option to open original link |
| Both Mac and Gemini fail | Show error + original link as escape hatch |
| No settings configured | Prompt user to open main app to configure on first extension launch |

Rule: never leave user with blank screen. Original link always visible as escape hatch.

---

## Technical Notes

- **SwiftSoup** for HTML parsing (Swift port of Jsoup, MIT license, add via SPM)
- **Tailscale** free personal plan — install on Mac + iPhone, ~5min setup
- **Mac server:** Python 3 stdlib only (`http.server`, `subprocess`, `json`) — no pip installs
- **`claude -p` CLI:** non-interactive print mode, uses existing Claude Code subscription
- **Gemini endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent`
- **Gemini free tier:** 1,500 req/day — sufficient for personal use
- **App Group identifier:** `group.com.tslsun.newssummarizer` (shared between targets)
- **Minimum iOS:** 16.0 (SwiftUI features, async/await)
- **No third-party networking libs in iOS** — URLSession only

---

## Out of Scope

- App Store distribution
- Push notifications for async summaries
- History / saved summaries
- Multiple language auto-detection (user picks explicitly)
- Android / other platforms
