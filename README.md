# Trips

> An iOS native SwiftUI app that auto-organizes a photo curation and storybook from the camera roll after a trip ends.
>
> **Promise**: *"Auto-completed first pass; refine by hand if you like it."*

## Highlights

- **Primary target**: travelers in their 20s and 30s who create Instagram content
- **Secondary target**: anyone who wants to record and curate trip photos with mood and feel
- **What sets it apart**:
  - The algorithmic rigor of a storage-cleanup app combined with the mood and monetization of a travel-journal app
  - **Post-trip automation** (no in-trip logging required)
  - **Photo originals stay on device**; only labels, memos, and favorites sync via CloudKit
- **Business model**: Freemium subscription (basic flow plus PDF and camera-roll export are free; Pro is subscription)
- **Launch target**: 3 to 4 months (solo developer)

## Core Features (v1.0)

1. **Auto Trip grouping**: EXIF timestamp + GPS group photos into trips automatically
2. **Similar-photo grouping**: Live Photo best-shot suggestion plus user-pinned favorites
3. **Memo + manual labeling**: per-photo and per-group memos, label-based filters
4. **Visual Spine view (default)**: the whole trip compressed into a vertical spine with per-day favorite nodes
5. **Export**: PDF photobook + camera-roll save

Full spec: [`mvp.md`](./mvp.md).

## Tech Stack

- Swift 5.9+ / SwiftUI (iOS 18+)
- PhotoKit, Vision, Core ML, PDFKit, CoreLocation
- **SwiftData with CloudKit Private Database** (metadata sync)
- Minimal external SDKs (analytics and crash reporting only)
- Cost: Apple Developer Program $99 per year plus CloudKit free tier

Details: [`mvp.md` §7](./mvp.md#7-기술-스택).

## Roadmap

| Stage | Duration | Output |
| --- | --- | --- |
| Phase 0: validation | 1 to 2 weeks | 5 to 10 interviews, Figma prototype |
| Phase 1: technical PoC | 1 to 2 weeks | PhotoKit / CloudKit / similar-photo grouping |
| Phase 2: MVP build | 6 to 8 weeks | App body |
| Phase 3: beta | 2 to 3 weeks | TestFlight 20 to 50 users |
| Phase 4: launch | TBD | App Store release |

Weekly breakdown: [`mvp.md` §10](./mvp.md#10-개발-단계).

## Documents

| File | Role |
| --- | --- |
| [`mvp.md`](./mvp.md) | Consolidated master spec |
| [`selection.md`](./selection.md) | Pre-coding decisions, design tokens (§F), schema |

## Status

- [x] Idea definition
- [x] Market and competition analysis
- [x] Screen spec
- [x] Consolidated MVP spec (`mvp.md`)
- [x] Locked decisions (`selection.md`)
- [ ] Phase 0 interviews
- [ ] Figma prototype
- [ ] Phase 1 technical PoC
