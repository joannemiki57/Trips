# Selection — 바이브 코딩 전에 확정해야 할 결정 체크리스트

> 작성일: 2026-05-17 · 관련: `mvp.md`, `decisions.md`, `visuals.md`
>
> `decisions.md`는 **제품·전략** 10건을 확정했다. 이 문서는 그 다음 단계 —
> **에이전트에게 코딩을 전적으로 맡기기 전에 사람이 골라줘야 하는 디자인 / 알고리즘 / 아키텍처 결정**을 모은다.
>
> 이걸 비워두고 "MVP 만들어줘"라고 하면 에이전트는 **가장 generic한 기본값**(밋밋한 SwiftUI 기본 룩,
> 임의의 임계값, 임의의 아키텍처)으로 만들어버린다. 아래 항목을 골라줄수록 결과물이 우리 의도에 가까워진다.
>
> 표기: 🔴 **BLOCKING** (코딩 시작 전 필수) · 🟡 권장 (1주 안에) · 🟢 나중에 가능
> 각 항목: **선택지 → 추천(★)**. 추천만 따라가도 일관된 MVP가 나오도록 구성함.

---

## A. 디자인 / 비주얼 아이덴티티

### A1. 🔴 앱 이름 (현재 "Trips" 가칭)
- (a) **Trips** — 직관적이나 일반명사라 ASO·상표 약함
- (b) 새 브랜드명 (예: 조어형) — 검색·상표 유리, 각인 필요
- (c) ★ **임시로 "Trips" 유지하고 코드 네임은 `Trips`, 출시명은 Phase 0 후 확정**
- → 코드/번들 ID는 지금 정해야 함. 추천: 번들 `com.<you>.trips`, 표시명은 후속 결정.

### A2. 🔴 디자인 무드 (가장 generic해지기 쉬운 항목)
에이전트가 알아서 하면 "파란 버튼 + 시스템 폰트"가 나온다. 한 방향 골라야 함.
- (a) ★ **Editorial / 필름 감성** — 여백 큼, 세리프 제목, 사진이 주인공, 채도 낮은 톤. *Polarsteps·Journi 톤, 1차 타겟(인스타 메이커)에 적합*
- (b) Minimal 시스템 룩 — Apple HIG 그대로, 빠르지만 차별성 약함
- (c) Bold / 인스타 그리드형 — 강한 대비·꽉 찬 그리드, 활기차나 감성↓
- → 추천: **(a)**. Visual Spine 컨셉과도 결이 맞음.

### A3. 🔴 컬러 & 타이포 토큰
- 코딩 전에 **디자인 토큰 표 1장**은 있어야 함 (없으면 에이전트가 임의 색 남발).
- 추천 최소 정의: 배경/표면/텍스트 3단계, 강조색(♥·favorite) 1개, 시맨틱(성공/경고) 2개, 폰트 패밀리(제목 세리프 / 본문 산세리프), 크기 스케일 5단.
- → **이 표를 selection.md 하단 §F에 채워 넣고 시작** (지금 비워둠).

### A4. 🟡 라이트/다크 모드
- (a) ★ 둘 다 지원 (SwiftUI면 토큰만 잘 잡으면 저비용)
- (b) 라이트 only로 v1 단축
- → 추천 (a), 단 토큰 시스템(A3) 전제.

### A5. 🟡 모션 / 피드백 철학
`mvp.md` §6.3 "favorite → Spine 마디 크로스페이드 즉시 전환"이 핵심 UX. 모션 강도 결정 필요.
- (a) ★ 절제된 스프링 + 크로스페이드 (감성 무드와 일치)
- (b) 화려한 전환 (산만 위험)
- (c) 전환 없음 (싸구려 느낌)
- → 추천 (a). "즉각적이되 조용하게."

### A6. 🟡 디자인 소스 오브 트루스
- (a) Figma 먼저 → 코드 (Phase 0 프로토타입 재활용, mvp 로드맵과 일치) ★
- (b) 코드 우선 (SwiftUI 프리뷰로 바로) — 빠르나 비주얼 표류 위험
- → 추천 (a) 최소 핵심 3화면(Trips 목록 / Visual Spine / 클러스터)만 Figma, 나머지는 코드.

### A7. 🟢 앱 아이콘 / 브랜딩
- Phase 3(베타) 전까지 placeholder 허용. 🟢 deferrable.

### A8. 🟡 출시 언어 (localization)
- (a) ★ 영어 우선 (1차 타겟·ASO 글로벌) + 한국어 i18n 구조만 미리
- (b) 한국어 우선
- → 추천 (a). 단 문자열 하드코딩 금지, `String(localized:)` 강제 (에이전트 지침에 명시).

---

## B. 알고리즘 로직 (확정 안 하면 결과가 무조건 generic·부정확)

> 이 절이 이 문서에서 가장 중요. 임계값을 비워두면 에이전트가 임의 숫자를 박는다.
> v1은 **간단한 휴리스틱**으로 충분 (커스텀 ML은 v1.5).

### B1. 🔴 Trip 자동 그루핑 규칙
- 입력: `PHAsset`의 `creationDate` + `location`.
- 추천 1차 규칙(★):
  - **시간 갭 분할**: 연속 사진 간 간격이 **≥ 2일(48h)** 이면 새 trip 후보
  - **거리 조건**: 촬영 군집의 중심이 **사용자 "집" 좌표에서 ≥ 100km** 떨어진 구간만 trip으로 승격 (집 근처 일상 사진 제외)
  - **집 좌표 추정**: 야간(0~6시) 사진 빈도 최다 지역 또는 사용자가 1회 지정
  - **최소 크기**: trip당 사진 **≥ 15장 & 기간 ≥ 1일** (스팸 trip 방지)
  - 사용자가 trip 경계(시작/끝)를 수동으로 합치기/나누기 가능
- 대안: 머신러닝 클러스터링(DBSCAN on time+geo) → v1.5로 미룸.
- → **위 숫자(48h / 100km / 15장)를 확정하거나 조정해 주세요.**

### B2. 🔴 Day 분할 규칙
- (a) ★ **촬영지 로컬 타임존 기준 캘린더 날짜**로 분할 (시차 이동 시 EXIF offset 사용, 없으면 GPS→타임존 추정)
- (b) 단순 기기 타임존 — 시차 여행에서 Day가 어긋남(나쁨)
- → 추천 (a). 자정 넘긴 야간 사진은 "전날 Day"에 붙일지 옵션(추천: 03:00 이전은 전날로).

### B3. 🔴 중복/유사 사진 그룹핑 방식
- (a) **Vision `VNGenerateImageFeaturePrintRequest` + 거리 임계값** ★ — Apple 1st-party, 의미적 유사도 우수
- (b) perceptual hash(pHash/dHash) — 가볍지만 구도 약간만 달라도 못 묶음
- (c) 둘 다(해시로 1차 필터 → feature print로 정밀) — 정확하나 복잡, v1.5
- 추천 v1: **(a)**, 단 **같은 장면 후보 = "feature print 거리 ≤ T" AND "촬영 간격 ≤ 5분" AND "GPS 50m 이내"** 의 AND 조건.
- → **거리 임계값 T는 PoC에서 실측해 확정**(Phase 1). 지금은 placeholder로 두되 "PoC에서 튜닝" 명시.

### B4. 🔴 베스트샷(대표컷) 랭킹 휴리스틱 — v1 (커스텀 ML 없음)
그룹에서 자동 대표 1장 고르는 점수 식. 가중합 추천(★):
- `score = w1·aesthetics + w2·sharpness − w3·blurPenalty + w4·faceQuality`
  - aesthetics: iOS 18 `VNCalculateImageAestheticsScoresRequest` (→ B7 iOS 버전 결정 의존)
  - sharpness: Laplacian variance (Metal/Accelerate)
  - faceQuality: 얼굴 있으면 눈 뜸/정면도 가산 (`VNDetectFaceCaptureQualityRequest`)
- Live Photo: Apple 추천 still 우선 채택, 위 점수는 tie-break.
- → **가중치 w1~w4 초기값을 정해 주세요** (추천 시작값: 0.4 / 0.3 / 0.2 / 0.1). 없으면 균등.

### B5. 🟡 Trip 자동 이름 생성
- (a) ★ reverse geocode 최빈 도시 → "Toronto Trip" / 다국가면 "Toronto–Montreal Trip"
- (b) 날짜만 "2026.05 여행"
- → 추천 (a), 사용자 수정 가능. 지오코딩은 `CLGeocoder`(오프라인 캐시).

### B6. 🟢 미정리/임시 대표 상태 규칙
- favorite 미지정 슬롯 = 알고리즘 대표(흐린 ♥). 사용자가 ♥ 누르면 확정. (mvp §6.2와 일치, 추가 결정 불필요 — 확인만.)

### B7. 🔴 최소 iOS 버전 (mvp.md 내부 모순 해소 필요)
- `mvp.md` §7.1 "iOS 17+" vs §7.3가 쓰는 `VNCalculateImageAestheticsScoresRequest`는 **iOS 18+** API.
- (a) ★ **iOS 18+ 최소** — aesthetics API 그대로 사용, 단 2024년 이전 기기 일부 제외
- (b) iOS 17+ 유지 + aesthetics는 iOS18 한정 분기(없으면 sharpness만)
- → 추천 (a) 단순함 우선(1인 개발). **이 결정이 B4 점수식에 직접 영향 → BLOCKING.**

---

## C. 데이터 / 아키텍처 (에이전트가 제멋대로 정하기 쉬운 곳)

### C1. 🔴 상태관리 / 아키텍처 패턴
- (a) ★ **SwiftUI + Observation(`@Observable`) + 얇은 MVVM** — iOS17+ 표준, 1인 유지보수 쉬움
- (b) TCA(The Composable Architecture) — 강력하나 러닝커브·과설계 위험
- (c) MVC 비스무리 — 비추
- → 추천 (a). 에이전트 지침에 **"TCA·Redux·외부 아키텍처 라이브러리 금지"** 명시(anti-generic 가드).

### C2. 🔴 SwiftData ↔ CloudKit 스키마
- 코딩 전 엔티티 정의 합의 필요. 추천 최소 모델(★):
  - `Trip`(id, name, startDate, endDate, coverAssetLocalId, homeAnchor?)
  - `Scene`(id, tripId, day, representativeAssetLocalId, memo?, labels[])
  - `Photo`(id, sceneId, assetLocalIdentifier, isFavorite, sharpness?, score?)
  - `Label`(id, name) — N:N with Scene/Photo
- 원본 사진 비저장, `PHAsset.localIdentifier`만 보관 (mvp §7.2 일치).
- → **이 스키마 확정/수정해 주세요.** CloudKit 동기화 대상/제외는 decisions #8 그대로.

### C3. 🔴 사진이 삭제/누락됐을 때 (localIdentifier 깨짐)
- 정책: (a) ★ 깨진 참조는 "사진 없음" placeholder + 메모/라벨은 보존, 사용자에 안내
- (b) 메타데이터까지 삭제 (데이터 손실, 비추)
- → 추천 (a). iCloud Photos 꺼진 타기기 케이스도 동일 처리(mvp §7.2 제약과 연결).

### C4. 🟡 사진 권한 범위
- (a) ★ Full Library 접근 요청 (전체 자동 그루핑에 필수) + 거부 시 limited 모드 안내
- (b) Limited selection only — 자동 그루핑 가치 훼손
- → 추천 (a). Info.plist 사유 문구도 미리 작성.

### C5. 🟡 대용량 라이브러리 성능 예산
- 1만~3만 장 기준. 결정 필요: 백그라운드 인덱싱 + 페이지네이션 + 썸네일 캐시(`PHCachingImageManager`).
- → 추천: 최초 인덱싱은 점진/백그라운드, UI는 trip 단위 lazy 로드. "전량 동기 로드 금지" 에이전트 지침화.

### C6. 🟢 동기화 충돌 해결
- 멀티 기기 메모/♥ 충돌: v1은 last-write-wins(타임스탬프) 충분. 🟢 deferrable.

---

## D. 에이전트 가드레일 (anti-generic 컨텍스트)

> 이 절을 에이전트 시스템 프롬프트/CLAUDE.md에 그대로 넣으면 generic 결과를 크게 줄인다.

### D1. 🔴 절대 만들지 말 것 (v1 스코프 밖)
- 백엔드 서버 / 자체 API (CloudKit만)
- AI 인물 수정 (영구 보류 — decisions #9)
- 영상 생성 (v2.0)
- 물리 포토북 인쇄 (v1.5+)
- AI 자동 라벨링 (v1.5)
- 외부 아키텍처/UI 라이브러리 (C1)

### D2. 🔴 빌드 순서 (수직 슬라이스 우선)
generic한 에이전트는 "모델 다 만들고 → UI" 식으로 간다. 강제 순서:
1. PhotoKit 읽기 + Trip 그루핑(B1) **알고리즘 단위 테스트 먼저**
2. 최소 UI: Trips 목록 → Visual Spine (가짜 데이터 OK)
3. 중복 그룹핑(B3) + 클러스터 화면 + ♥↔대표 동기화(mvp §6.2)
4. 메모/라벨 + SwiftData 영속
5. CloudKit 동기화
6. PDF/카메라롤 export
7. Freemium 게이팅
- → mvp.md §10 W1~W8과 일치. 에이전트엔 "한 슬라이스 끝낼 때마다 빌드+테스트 통과 확인" 명시.

### D3. 🟡 개발용 테스트 데이터 전략
- 시뮬레이터엔 여행 사진이 없음 → 에이전트가 검증을 못 해 generic 추정만 함.
- 결정: (a) ★ EXIF/GPS 박힌 **샘플 사진 세트 + 시드 스크립트** 준비 (b) 실기기 본인 사진으로만
- → 추천 (a) 먼저. 알고리즘 단위 테스트는 합성 메타데이터 픽스처로.

### D4. 🟡 테스트 기대치
- 알고리즘(B1~B4)은 **단위 테스트 필수**, UI는 스냅샷/수동 허용.
- → 에이전트 지침: "B절 로직은 테스트 없이는 완료로 보지 않는다."

### D5. 🟢 분석/크래시 SDK
- mvp §7.4대로 Sentry or Crashlytics 1개. 🟢 베타 전 결정 가능.

---

## E. 결정 요약 — 코딩 시작 전 최소 체크 (🔴만)

코딩 전 반드시 답해야 하는 것:
- [x] A1 번들 ID / 코드네임 — **코드네임 `Trips` 유지, 출시명 Phase 0 후 확정 / 번들 `com.<you>.trips`**
- [x] A2 디자인 무드 — **(c) Bold / 인스타 그리드형 채택** ⚠️ 추천(a Editorial)과 다름 — §G 비고 참조
- [ ] A3 컬러·타이포 토큰 표 (§F 채우기)
- [x] B1 Trip 그루핑 임계값 — **(b) 느슨: 24h / 50km / 10장** (짧은 근거리 여행도 포함)
- [x] B2 Day 분할 기준 — **로컬 타임존 + 03:00 이전은 전날로 귀속**
- [x] B3 유사 그룹핑 방식 — **Vision FeaturePrint + (≤5분 & GPS 50m) AND 조건**, T는 PoC 튜닝
- [ ] B4 베스트샷 가중치 초기값 (0.4/0.3/0.2/0.1)
- [x] B7 최소 iOS 버전 — **iOS 18+**
- [x] C1 아키텍처 — **SwiftUI + Observation(@Observable) + 얇은 MVVM**, 외부 라이브러리 금지
- [ ] C2 SwiftData/CloudKit 스키마 확정
- [x] C3 깨진 사진 참조 정책 — **(a) placeholder + 메타데이터 보존**. 메타데이터 이관 기능은 **v1.1로 분리** (2차 결정에서 변경)
- [x] D2 빌드 순서 — **mvp.md §10 W1~W8 수직 슬라이스 순서**
- [ ] D1 에이전트 가드레일을 CLAUDE.md에 주입 (D2와 함께)

### 🟡 권장 결정 (2차 라운드 — 2026-05-17)

- [x] A4 라이트/다크 모드 — **둘 다 지원** (토큰 시스템 전제)
- [x] A5 모션 / 피드백 철학 — **Bold용 이해된 탄력 + 스냅 제스처 강조** (인스타 느낌)
- [x] A6 디자인 소스 오브 트루스 — **Figma 먼저 → 코드** (핵심 3화면: Trips/Spine/클러스터)
- [x] A8 출시 언어 — **영어 우선 + 한국어 i18n 구조 미리** (`String(localized:)` 강제)
- [x] B4 베스트샷 가중치 — **0.4/0.3/0.2/0.1로 시작 → Phase 1 PoC에서 튜닝**
- [x] C4 사진 권한 — **Full Library 요청 + 거부 시 limited 모드 안내**
- [x] C5 성능 예산 — **점진 인덱싱 + Trip 단위 lazy 로드 + PHCachingImageManager 캐시**
- [x] D3 테스트 데이터 — **EXIF/GPS 박힌 샘플 세트 + 시드 스크립트** (단위테스트는 합성 픽스처)
- [x] D4 테스트 기대치 — **알고리즘(B1~B4)은 단위테스트 필수, UI는 스냅샷/수동**

🟢는 베타 전 결정해도 무방.

---

## G. 결정 기록 (Decisions Log)

> 2026-05-17 1차 결정. §A~D의 🔴 BLOCKING 항목 중 객관식 9건 확정.

### 확정 사항

| ID | 결정 | 추천과 비교 |
| --- | --- | --- |
| A1 | 코드네임 `Trips`, 번들 `com.<you>.trips`, 출시명은 Phase 0 후 | ★ 추천 그대로 |
| A2 | **Bold / 인스타 그리드형** | ⚠️ 추천(a Editorial)과 다름 |
| B1 | **24h / 50km / 10장** (느슨) | 추천 (a 48h/100km/15장) 보다 완화 |
| B2 | 로컬 타임존 + 03:00 룰 | ★ 추천 그대로 |
| B3 | Vision FeaturePrint + AND 조건(≤5분 & GPS 50m) | ★ 추천 그대로 (T는 PoC 튜닝) |
| B7 | iOS 18+ | ★ 추천 그대로 |
| C1 | SwiftUI + Observation + 얇은 MVVM | ★ 추천 그대로 |
| C3 | placeholder 유지 (v1) / 메타데이터 이관은 **v1.1로 분리** | ★ 추천 그대로 (2차 라운드에서 스코프 축소) |
| D2 | mvp.md §10 W1~W8 순서 | ★ 추천 그대로 |

### 비고

**A2 (Bold 채택)** — 추천은 Editorial/필름 감성이었으나 Bold/인스타 그리드형 선택. 영향:
- Visual Spine 컨셉(`mvp.md` §6.3)의 "조용한 크로스페이드" 톤과 재조정 필요
- 1차 타겟이 "인스타 메이커"라면 친화적, "여행 아카이비스트"라면 충돌 가능 → 타겟 재확인 권장
- §F 디자인 토큰 표를 채울 때 **고대비·꽉 찬 그리드·강한 강조색**으로 잡아야 함

**B1 (느슨 임계값)** — 24h/50km/10장은 다음을 의미:
- 1박 2일 근거리 여행도 trip으로 잡힘
- 주말 카페 투어나 데이트도 trip 후보가 될 수 있음 → trip 개수↑, 수동 정리 필요성↑
- "여행" 정의가 사용자별로 넓어지므로 §A2의 Bold 톤(=일상 큐레이션 친화)과는 결이 맞음

**C3 (메타데이터 이관 기능)** — 단순 placeholder 표시를 넘어:
- 깨진 사진 참조에 붙어 있던 메모·라벨·♥를 사용자가 다른 사진으로 옮길 수 있는 UI 필요
- 자동 추천(가장 유사한 남은 사진 제안) + 사용자 확정 흐름
- 스키마(C2)에 `migratedFromAssetLocalId?` 같은 추적 필드 고려
- **2차 라운드 결정: v1.1로 분리** (v1은 placeholder 표시만)

---

### 2차 라운드 (2026-05-17) — 🟡 권장 + 남은 BLOCKING

| ID | 결정 | 추천과 비교 |
| --- | --- | --- |
| A4 | 라이트/다크 둘 다 지원 | ★ 추천 그대로 |
| A5 | **Bold용 이해된 탄력 + 스냅 제스처 강조** | ⚠️ 추천(a 절제된 스프링)에서 Bold 톤에 맞게 재조정 |
| A6 | Figma 먼저 (핵심 3화면) → 코드 | ★ 추천 그대로 |
| A8 | 영어 우선 + 한국어 i18n 구조 미리 | ★ 추천 그대로 |
| B4 | 0.4/0.3/0.2/0.1 시작 → Phase 1 PoC 튜닝 | ★ 추천 그대로 (튜닝 명시) |
| C3 스코프 | v1은 placeholder만, 이관은 v1.1 | 1차 결정 축소 |
| C4 | Full Library + limited fallback 안내 | ★ 추천 그대로 |
| C5 | 점진 인덱싱 + lazy 로드 + PHCaching 캐시 | ★ 추천 그대로 |
| D3 | 샘플 세트 + 시드 스크립트 + 합성 픽스처 | ★ 추천 그대로 |
| D4 | 알고리즘 단위테스트 필수, UI 스냅샷/수동 | ★ 추천 그대로 |

### 2차 라운드 비고

**A5 (Bold용 모션)** — A2 Bold 선택에 맞춰 모션 톤도 재조정:
- "절제된 크로스페이드"에서 "이해된 탄력 + 스냅 제스처 강조"로 변경
- Visual Spine 전환은 여전히 짧되, 인터랙션 피드백(♥ 누를 때, 스와이프 등)에 스프링·하프틱 강조
- 산만하지 않도록 **전환 시간 ≤ 250ms, easeOut 위주** 가이드 (코드 작성 시 토큰화)

**C3 스코프 축소 (v1 → v1.1)** — 1차에서 잡았던 메타데이터 이관 기능을 v1.1로 분리:
- v1에서는 깨진 참조에 "사진 없음" placeholder만 표시 + 메모/라벨/♥ 보존
- 이관 UI·자동 추천 로직·`migratedFromAssetLocalId?` 필드는 v1.1
- v1 개발 부담 축소, mvp.md §10 W1~W8 일정 유지에 유리

**B4 (가중치는 시작값 유지)** — Phase 1 PoC에서 본인 사진 셋으로 튜닝:
- 시작값 0.4/0.3/0.2/0.1로 코딩
- PoC 단계에서 베스트샷 결과를 본인이 평가 → 가중치 조정
- 향후 사용자가 가중치를 옵션으로 조절하는 기능은 v1.5+

---

### 3차 라운드 (2026-05-17) — C2 스키마 의미 결정 (1차)

| 항목 | 결정 |
| --- | --- |
| **라벨 입력 방식** | **둘 다** — 고정 목록(여행/카페/사람 등) + 자유 입력 |
| **메모 부착 단위** | **둘 다** — 사진별 메모 + Scene별 메모 |
| **♥(favorite) 단위** | **사진별 단일 상태** — 누르면 상위 레벨(슬롯·Spine 마디)의 대표 사진으로 자동 승격 |
| **♥ 인터랙션** | favorite 사진을 탭하면 같은 Scene의 다른 사진들이 펼쳐져 보임 |
| **메모 첨부 (v1)** | **텍스트만** |
| **메모 첨부 (향후)** | README에 명시 — 스티커, 위치 핀, 음성 메모 등 v1.5+ 확장 후보 |

---

### 4차 라운드 (2026-05-17) — Scene 운용 규칙

> Scene의 정의 (mvp.md §6.2): **한 슬롯 = 한 '장면(중복 그룹의 대표 1장)'**.
> 즉 Scene = B3 클러스터링 결과물(같은 장면에서 찍힌 사진 묶음).

| ID | 결정 | 추천과 비교 |
| --- | --- | --- |
| Q1 Scene 경계 조정 | **자동 + 사용자 합치기/나누기 가능** | ★ 추천 그대로 (멀티선택 → '합치기'/'분리') |
| Q2 단일 사진 (중복 없음) | **사용자 토글로 결정** — 기본은 Scene 없이 Day 직속, 토글 ON 시 1장짜리 Scene 생성 | ⚠️ 추천(a 항상 Scene)이 아님 — 스키마 영향 있음 |
| Q3 같은 Day 내 Scene 정렬 | **시간순 (EXIF 촬영 시각)** | ★ 추천 그대로 |
| Q4 cross-day Scene | **Day 경계 따라 분할** (B2 03:00 룰 적용) | ★ 추천 그대로 |

### 4차 라운드 비고

**Q2 (단일 사진 토글) — 스키마 영향**:
- 추천 (a)는 모든 Photo가 반드시 Scene에 속함 → 스키마 단순
- 선택 (c)는 Photo가 Scene OR Day에 직접 소속 → 둘 중 하나
- 스키마 필드:
  - `Photo.dayId` (required) — 항상 Day에 속함
  - `Photo.sceneId?` (optional) — Scene이 있을 때만
- UI 영향: 설정 화면에 "단일 사진도 묶음(Scene)으로 표시" 토글 1개
- 기본값: OFF (단일 사진은 Day 그리드에 직접 표시)

**Q1 (수동 합치기/나누기) — UI 영향**:
- 클러스터 화면에서 사진 멀티선택 → "이 사진들만 분리해서 새 Scene 만들기" 액션
- Day 그리드에서 슬롯 멀티선택 → "이 Scene들 합치기" 액션
- 합쳤다 나눴다 한 결과를 어떻게 추적할지(원본 알고리즘 경계 vs 사용자 수정)는 v1에서는 단순히 마지막 상태만 저장

**Q3·Q4 — 단순**:
- 시간순 정렬은 기본값, 별도 정렬 옵션 없음 (v1)
- Day 경계 따라 Scene 분할 = B2 결정(03:00 룰)과 일관
- 23:50~01:20 같은 케이스: 03:00 이전이면 전날 Day로, 동일 Day 내면 같은 Scene 후보(B3 조건 만족 시)

---

### 5차 라운드 (2026-05-20) — A3 디자인 토큰 락 · C2 스키마 코드 락

#### C2 스키마 코드 (LOCKED)

| 항목 | 결정 |
| --- | --- |
| Entity 목록 | `Trip`, `Day`, `Scene`, `Photo`, `Label`, `UserSettings` (6개) |
| **homeAnchor 위치** | **UserSettings 단일 인스턴스 전역** (Trip에서 제거) |
| **Scene/Day CloudKit 동기화** | **하이브리드** — 자동 묶음은 기기별 재계산, 수동 수정(합치기·나누기·메모·label·♥)만 동기 |
| **Photo.memo (v1 포함 여부)** | **v1 포함** → mvp.md §6에 Photo Detail 화면 신규 추가 |
| representative/cover 참조 | `Photo?` 직접 참조 (ID 문자열 X) — dangling 회피 |
| Label 분류 | `source: LabelSource` enum (`.builtIn` / `.userDefined`, v1.5+ `.recommended`·`.shared`) |
| Label 전파 | 쿼리 시 union (저장 시 전파 X). `Photo.allLabels` computed |
| score 캐시 무효화 | `scoreVersion: Int?` + `BestShotScorer.currentVersion` 비교 |
| 사라진 사진 캐시 | `Photo.isMissing: Bool` + `lastVerifiedAt: Date?` |
| 타임존 | Day 경계 = EXIF tz → GPS tz → 사용자 tz 폴백 순 |
| 03:00 룰 재계산 | Photo 추가/삭제/이동 시 capturedAt이 02:00~04:00일 때만 인접 Day 재평가 |
| 명명 | `assetLocalId`로 통일 (PHAsset.localIdentifier 매핑은 Photo만 보유) |

```swift
import Foundation
import SwiftData

// MARK: - Trip
@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var coverPhoto: Photo?  // nil → 첫 Day의 첫 Scene 대표로 폴백 (UI 레이어)

    @Relationship(deleteRule: .cascade, inverse: \Day.trip)
    var days: [Day] = []

    init(id: UUID = UUID(), name: String, startDate: Date, endDate: Date, coverPhoto: Photo? = nil) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.coverPhoto = coverPhoto
    }
}

// MARK: - Day
@Model
final class Day {
    @Attribute(.unique) var id: UUID
    var date: Date  // 로컬 캘린더 날짜 (B2 03:00 룰 적용 후, EXIF tz 기준)
    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Scene.day)
    var scenes: [Scene] = []

    @Relationship(deleteRule: .cascade, inverse: \Photo.day)
    var photos: [Photo] = []

    init(id: UUID = UUID(), date: Date, trip: Trip? = nil) {
        self.id = id
        self.date = date
        self.trip = trip
    }
}

// MARK: - Scene
@Model
final class Scene {
    @Attribute(.unique) var id: UUID
    var representativePhoto: Photo?  // ♥ 누르면 자동 승격
    var memo: String?  // Scene 단위 메모 (v1, 텍스트만)
    var day: Day?

    @Relationship(deleteRule: .nullify, inverse: \Photo.scene)
    var photos: [Photo] = []

    @Relationship(inverse: \Label.scenes)
    var labels: [Label] = []

    init(id: UUID = UUID(), day: Day, representativePhoto: Photo? = nil, memo: String? = nil) {
        self.id = id
        self.day = day
        self.representativePhoto = representativePhoto
        self.memo = memo
    }
}

// MARK: - Photo
@Model
final class Photo {
    @Attribute(.unique) var id: UUID
    var assetLocalId: String  // PHAsset.localIdentifier
    var capturedAt: Date  // EXIF 촬영 시각, Scene 내 정렬용
    var isFavorite: Bool

    // Memo (v1 포함, 5차 라운드)
    var memo: String?

    // B4 베스트샷 점수 캐시
    var sharpness: Double?
    var score: Double?
    var scoreVersion: Int?  // BestShotScorer.currentVersion과 다르면 stale

    // C3 사라진 사진 캐시
    var isMissing: Bool
    var lastVerifiedAt: Date?

    // Relations
    var day: Day?    // init(day:)로 강제 — 의미상 필수
    var scene: Scene?  // 단일 사진 토글 OFF면 nil

    @Relationship(inverse: \Label.photos)
    var labels: [Label] = []

    init(
        id: UUID = UUID(),
        day: Day,
        assetLocalId: String,
        capturedAt: Date,
        scene: Scene? = nil,
        isFavorite: Bool = false,
        memo: String? = nil
    ) {
        self.id = id
        self.day = day
        self.scene = scene
        self.assetLocalId = assetLocalId
        self.capturedAt = capturedAt
        self.isFavorite = isFavorite
        self.memo = memo
        self.isMissing = false
    }

    /// Scene 라벨 전파를 쿼리 시 union으로 (저장 시 전파 X)
    var allLabels: [Label] {
        let own = Set(labels.map(\.id))
        let sceneLabels = scene?.labels ?? []
        return labels + sceneLabels.filter { !own.contains($0.id) }
    }
}

// MARK: - Label
@Model
final class Label {
    @Attribute(.unique) var id: UUID
    var name: String
    var source: LabelSource

    @Relationship var scenes: [Scene] = []
    @Relationship var photos: [Photo] = []

    init(id: UUID = UUID(), name: String, source: LabelSource) {
        self.id = id
        self.name = name
        self.source = source
    }
}

enum LabelSource: String, Codable {
    case builtIn       // 고정 목록 (여행/카페/사람 등)
    case userDefined   // 사용자 자유 입력
    // v1.5+: case recommended, case shared
}

// MARK: - UserSettings (singleton)
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID  // 항상 단일 인스턴스
    var homeAnchorLat: Double?
    var homeAnchorLon: Double?
    var showSinglePhotoAsScene: Bool  // C2 Q2 토글, 기본 false

    init(
        id: UUID = UUID(),
        homeAnchorLat: Double? = nil,
        homeAnchorLon: Double? = nil,
        showSinglePhotoAsScene: Bool = false
    ) {
        self.id = id
        self.homeAnchorLat = homeAnchorLat
        self.homeAnchorLon = homeAnchorLon
        self.showSinglePhotoAsScene = showSinglePhotoAsScene
    }
}
```

#### A3 디자인 토큰 락 (별도)

| 항목 | 결정 |
| --- | --- |
| 토큰표 §F | 12행 모두 채움 (라이트/다크 분리) |
| **워드마크** | **SF Pro Rounded Black 900** (V2). V1 Italic / V3 Wide Caps / V4 Heart Fused 4종 비교 후 선택 |
| accent | `#FF3040` (Instagram heart red) |
| font/title | 산세리프 (§F 템플릿의 "세리프 추천" 폐기 — A2 무드 우선) |
| 하단 ♥ 단독 버튼 | 없음. ♥는 사진 단위(C2). 화면 하단은 iOS 탭바(Trips/Spine/Settings) |
| 미리보기 산출물 | `design-tokens-preview.html` (라이트/다크 목업 + 로고 4종 + 팔레트 + 타이포 + 여백) |

### 다음으로 결정할 것

- [x] **C2 최종 스키마 코드** — 2026-05-20 락 (5차 라운드 위, Swift 코드 블록)
- [x] **A3 디자인 토큰 표** (§F) — 2026-05-20 락
- [ ] **D1 가드레일 CLAUDE.md 주입** — 두 blocker 해제됨, 필요 시 진행
- [ ] **🟢 deferrable** — A7(앱 아이콘) / B6(미정리 상태) / C6(동기화 충돌) / D5(분석 SDK)
- [ ] **W1 시작** — Xcode 스캐폴딩 + B1 알고리즘 + PhotoKit 권한 (코드 작업)

---

### 7차 라운드 (2026-05-20) — Scene 사용자 수정 보존 (`userModifiedAt`)

| 항목 | 변경 |
| --- | --- |
| Scene 모델 | `userModifiedAt: Date?` 필드 추가. 사용자가 직접 묶기/나누기/이름 변경 등으로 Scene을 손댔을 때 `Date.now` 기록. |
| Rescan 시 generateScenes | `userModifiedAt != nil`인 Scene과 그 멤버 사진은 보존 — B3 재계산 대상에서 제외. 나머지 사진들만 B3 돌려서 새 Scene 생성. |
| Scene 분리 (split) | ClusterView 컨텍스트 메뉴 "Scene에서 빼기"로 한 사진을 Scene 밖으로 분리. 남은 Scene이 1장이면 Scene 자체 삭제. 두 동작 모두 영향받는 Scene의 `userModifiedAt` 갱신. |

#### 변경 이유

- 6차 라운드 직후 첫 실측에서 발견: 사용자가 드래그로 Scene 병합해도 Rescan 시 `generateScenes`가 처음부터 B3를 다시 돌려 사용자의 수정이 날아감.
- B3는 보조 신호이지 절대 기준이 아니어야 함 — 사용자 의사가 항상 우선.
- `userModifiedAt` 단일 필드로 "auto vs user" 구분. CloudKit 동기화에도 잘 맞음(사용자 수정만 동기, 자동 결과는 기기별 재계산).

#### 반영

- `Trips/Core/Persistence/Scene.swift` — `userModifiedAt: Date?` 추가
- `Trips/Core/Grouping/TripImporter.swift` `generateScenes` — 보존된 Scene 멤버 제외 후 B3
- `Trips/Core/Similarity/SceneMerger.swift` — 병합 후 `userModifiedAt = .now`
- `Trips/Core/Similarity/SceneSplitter.swift` — 분리 헬퍼 신규
- `Trips/Features/Cluster/ClusterView.swift` — 컨텍스트 메뉴 "Scene에서 빼기"
- `.claude/rules/persistence.md` — Scene 운용 규칙에 보존 정책 명시
- `TripsTests/` — Merger persists, Splitter, Importer-preserves 통합 테스트 추가

---

### 6차 라운드 (2026-05-20) — B3 GPS 조건 완화 (옵셔널화)

| 항목 | 변경 전 (1차 §B3) | 변경 후 (6차) |
| --- | --- | --- |
| 같은 Scene 판정 | `featureprint ≤ T` **AND** `interval ≤ 5min` **AND** `GPS ≤ 50m` | `featureprint ≤ T` **AND** `interval ≤ 5min` **AND** (둘 다 GPS 있으면 `≤ 50m`, 한쪽이라도 없으면 GPS 조건 스킵) |

#### 변경 이유

- W3 슬라이스 첫 실측에서 발견: 실제 사용자 라이브러리에 GPS 없는 사진이 압도적으로 많음 (메신저·AirDrop·다른 앱 공유 = EXIF GPS 보통 제거됨). 해당 라이브러리에서 57장 중 5장만 GPS 보유, 메인 trip 51장은 0장.
- 엄격 AND 규칙은 GPS 없는 사진 쌍을 영원히 "다른 Scene"으로 판정 → B3가 무용지물.
- 완화 규칙은 GPS *있을 때*는 더 엄격(이전과 동일), *없을 때*는 시간+화면 비슷도로만 판정. 즉 GPS는 *추가 신뢰 조건*이지 *필수 조건*이 아니라는 해석.

#### 반영

- `.claude/rules/algorithms.md` B3 섹션 — 같은 변경 반영 (2026-05-20)
- `Trips/Core/Similarity/SceneGrouping.swift` — `sameScene(_:_:)` GPS 분기 추가
- `TripsTests/SceneGroupingTests.swift` — "한쪽 GPS 없음" / "둘 다 GPS 없음" 케이스가 *같은 Scene*을 기대하도록 수정 + GPS-only 거리 위반 케이스 보강

#### 비고

- T(featureprint threshold) 자체는 여전히 `TODO(poc): tune T`. 6차 라운드는 *AND 구조* 변경 한정.
- 추가 토론 필요 항목 없음 — 단순 옵셔널화로 의도 명확.

---

## F. 디자인 토큰 표 — A3 LOCKED (2026-05-20)

> A2(Bold / Instagram-grid) 무드 기준. 미리보기: `design-tokens-preview.html`.
> 변경 시: §G에 로그 → `.claude/rules/swiftui-ui.md` 갱신 → 코드 반영 순서.

| 토큰 | 라이트 | 다크 | 비고 |
| --- | --- | --- | --- |
| color/bg | `#FFFFFF` | `#000000` | 배경. 순백/순흑 (인스타 풍 고대비) |
| color/surface | `#FAFAFA` | `#1C1C1E` | 카드·시트. 배경 대비 살짝만 구분 |
| color/text-primary | `#000000` | `#FFFFFF` | 본문 글자 |
| color/text-secondary | `#737373` | `#A8A8A8` | 메타·캡션 (Instagram gray) |
| color/accent (♥/favorite) | `#FF3040` | `#FF3040` | 시그니처. Instagram heart red |
| color/success | `#34C759` | `#34C759` | iOS system green |
| color/warning | `#FF9500` | `#FF9500` | iOS system orange |
| font/brand | SF Pro Rounded · Black 900 | 동일 | 워드마크 ("Trips") · V2 Rounded 채택 |
| font/title | SF Pro Display · Bold 700 | 동일 | 화면 제목·카드 헤더 |
| font/body | SF Pro Text · Regular 400 | 동일 | 본문 |
| size scale | 12 / 14 / 17 / 22 / 34 | 동일 | Apple HIG. 17 = 본문 기준 |
| radius | 12pt (카드/시트), 8pt (버튼), 4pt (칩) | 동일 | |
| spacing unit | 4pt 그리드 | 동일 | 4·8·12·16·24·32·48 |

### 결정 근거 (2026-05-20)

- **font/title 산세리프**: §F 템플릿의 "추천: 세리프"는 A2 갱신 전 잔재. Instagram은 세리프 안 씀 → A2(Bold/Instagram) 일관성 우선.
- **font/brand = SF Pro Rounded Black**: V1(Italic Black)·V2(Rounded)·V3(Wide Caps)·V4(Heart Fused) 4종 비교 후 V2 선택. 친근함 + Bold 무드 양립.
- **accent #FF3040**: 인스타 ♥ 톤. 너무 분홍이면 약하고 너무 진홍이면 무거움.
- **하단 ♥ 좋아요 단독 버튼 없음**: ♥는 사진 단위(C2 결정) → 그리드 셀의 우상단에만 표시. 화면 하단은 iOS 표준 탭바(Trips/Spine/Settings).
