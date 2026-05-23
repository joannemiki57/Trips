# Trips (가칭)

> 여행이 끝난 후, 카메라롤만으로 자동 정리되는 **여행 단위 사진 큐레이션 · 스토리북 앱** (iOS Native)
>
> **약속**: *"자동으로 1차 완성, 마음에 들면 직접 다듬기."*

---

## 한눈에 보기

- **1차 타겟**: 인스타 콘텐츠를 만드는 20–30대 여행자
- **확장 타겟**: 여행 사진을 감성적으로 기록·큐레이션하고 싶은 광범위 여행자
- **차별점**:
  - 스토리지 정리 앱의 알고리즘 + 여행 저널 앱의 감성·수익 모델
  - **사후 자동 처리** (여행 중 로깅 불필요)
  - **사진 원본은 기기 안에**, 라벨·메모·favorite만 CloudKit 동기화
- **수익 모델**: Freemium 구독 (기본 + PDF/카메라롤 export까지 무료, Pro는 구독)
- **출시 목표**: 3–4개월 (1인 개발)

---

## 핵심 기능 (v1.0)

1. **Trip 자동 그루핑** — EXIF timestamp + GPS로 여행 단위 자동 묶음
2. **중복 사진 그룹핑** — Live Photo 베스트샷 자동 추천 + 사용자 favorite 지정
3. **메모 + 수동 라벨링** — 사진/그룹 단위 메모, 라벨 기반 필터
4. **Visual Spine 뷰 (기본)** — 여행 전체를 세로 척추로 압축, Day별 favorite 마디
5. **Export** — PDF 사진첩 + 카메라롤 저장

상세 명세는 [`mvp.md`](./mvp.md) 참고.

---

## 문서 구성

| 파일 | 내용 | 상태 |
| --- | --- | --- |
| [`mvp.md`](./mvp.md) | **단일 마스터** — 통합 MVP 기획서 | ✅ 최신 |
| [`decisions.md`](./decisions.md) | 통합 과정에서 발생한 충돌 10건의 결정 이력 | ✅ 결정 완료 (2026-05-17) |
| [`ideation.md`](./ideation.md) | 초기 아이디어 노트 | 📜 히스토리 (참고용) |
| [`evaluation.md`](./evaluation.md) | 시장·경쟁 분석, 실현 가능성 평가 | 📜 히스토리 (참고용) |
| [`visuals.md`](./visuals.md) | 초기 화면 명세 (Visual Spine 개념의 원전) | 📜 히스토리 (참고용) |

> `ideation.md` / `evaluation.md` / `visuals.md`의 모든 결정 사항은 `mvp.md`에 통합 반영되었습니다. 히스토리 참고용으로만 유지합니다.

---

## 개발 로드맵

| 단계 | 기간 | 산출물 |
| --- | --- | --- |
| Phase 0 — 검증 | 1–2주 | 인터뷰 5–10명, Figma 프로토타입 |
| Phase 1 — 기술 PoC | 1–2주 | PhotoKit / CloudKit / 유사 사진 그루핑 |
| Phase 2 — MVP 빌드 | 6–8주 | App 본체 |
| Phase 3 — 베타 | 2–3주 | TestFlight 20–50명 |
| Phase 4 — 출시 | — | App Store 출시 |

상세 주차별 작업은 [`mvp.md` §10](./mvp.md#10-개발-단계) 참고.

---

## 기술 스택

- Swift 5.9+ / SwiftUI (iOS 17+)
- PhotoKit · Vision · Core ML · PDFKit · CoreLocation
- **SwiftData ↔ CloudKit Private Database** (메타데이터 동기화)
- 외부 SDK 최소화 (분석/크래시 리포트 정도)
- 비용: Apple Developer Program **$99/년** + CloudKit 무료 할당량

상세는 [`mvp.md` §7](./mvp.md#7-기술-스택) 참고.

---

## 진행 상황

- [x] 아이디어 정의 (`ideation.md`)
- [x] 시장·경쟁 분석 (`evaluation.md`)
- [x] 화면 명세 (`visuals.md`)
- [x] 통합 MVP 기획서 (`mvp.md`)
- [x] 충돌 항목 10건 결정 (`decisions.md`)
- [ ] Phase 0 인터뷰
- [ ] Figma 프로토타입
- [ ] Phase 1 기술 PoC
