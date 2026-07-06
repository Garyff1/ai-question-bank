# AI Question Bank (Android)

Android standalone app for AI-powered question generation.

**Latest Version: v2.7.5+38**

**Download APK**: https://aichuti.ccwu.cc/download/android.apk

## v2.7.5 (2026-07-06)

Listening question root cause fix:
- Force enable rich_content when listening is enabled (avoid prompt contradiction)
- Allow listening block in plain text mode prompt
- Loosen fallback regex: 15-300 chars / 4+ words (was 30-200 / 6+)
- Add question text fallback for English segment extraction
- Add listening detection to _detectRichContentFallback
- Pin flutter_edge_tts to exact 0.0.2

## v2.7.4

- 40% listening ratio, paper listening count input, hidden listening text in question view, chart data extraction, error rate Top5

## v2.7.3

- TTS voice mapping, paper rich_content always visible, batch delete unification, weekly practice trend persistence, splash app logo

## v2.7.2

- Listening question generation, wrong book IndexedStack, paper per-question knowledge point, splash min display time, paper audio mp3 rewrite

## v2.7.1

- Section header layout, listening fallback, chart/rich content over-generation tightening, splash animation, paper PDF chart rendering, paper audio mp3 download

## v2.7.0

- Rich content rendering system (6 types), collapsible lists, paper page rich content switch

## v2.6.x

- AI question generation, exam paper templates, PDF export, wrong question book, practice history
