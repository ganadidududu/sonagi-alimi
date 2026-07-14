# weather-app Planning Document (PRD)

> **Summary**: "앞으로 2시간 내 위치 소나기/비 알림"(기상청 초단기예보) + "3개 예보 출처 다수결 일별 날씨"가 킬러 기능인 날씨 웹앱(PWA)
>
> **Project**: weather-app (가칭: 소나기 — Sonagi)
> **Version**: 0.1.0
> **Author**: son-inseong
> **Date**: 2026-07-08
> **Status**: Draft

---

## 1. Overview

### 1.1 Purpose

기존 날씨 앱은 "오늘 비 올 확률 60%" 수준의 정보만 주기 때문에, **정확히 언제·어디서 비가 시작되는지** 알기 어렵다.
이 앱은 기상청 초단기예보(`getUltraSrtFcst`)를 활용해 **사용자의 현재 위치 기준으로 앞으로 2시간 내 소나기/비 시작 시점을 푸시 알림**으로 알려준다.

또한 일별 날씨는 **출처가 서로 다른 3개 예보(기상청 + 해외 모델 2개)를 교차 검증**해, 3개 중 2개 이상이 일치하는 예측을 보여준다.
예보가 엇갈릴 때는 이를 숨기지 않고 "2개 모델은 비, 1개는 맑음"처럼 투명하게 표시한다.

핵심 가치 제안 (Value Proposition):

```
"우산 챙길지 고민하지 마세요.
비 오기 전에 앱이 먼저 알려드립니다."

"예보 하나만 믿지 마세요.
3개 예보가 합의한 날씨를 보여드립니다."
```

### 1.2 Background

- 기상청 단기예보 조회서비스 2.0(`VilageFcstInfoService_2.0`)은 10분 단위로 갱신되는 초단기 실황/예보를 무료로 제공하지만, 이를 "선제적 알림"으로 풀어낸 소비자용 앱은 드물다.
- 초단기예보의 `PTY`(강수형태) 코드는 소나기(4)를 별도 코드로 구분하므로, "소나기 알림"이라는 차별화된 UX가 가능하다.
- 레이더영상 조회서비스(`RadarImgInfoService`)로 시각적 강수 확인 화면까지 보강할 수 있다.

### 1.3 Related Documents

- API 명세: `~/Downloads/kma_weather_api_spec.md` (기상청 단기예보/레이더영상 OpenAPI 정리본)
- 원본 가이드: 기상청41_단기예보 조회서비스_오픈API활용가이드, 기상청16_레이더영상_조회서비스_오픈API활용가이드
- 격자 좌표표: 기상청 격자_위경도 엑셀 (nx/ny 변환용)

### 1.4 Target Users (Persona)

| 페르소나 | 상황 | 니즈 |
|---|---|---|
| 도보/자전거 출퇴근족 (주 타깃) | 매일 30분~1시간 야외 이동 | "출발 전에 2시간 내 비 여부만 알면 됨" |
| 야외 활동 계획자 | 산책, 운동, 빨래, 나들이 | "몇 시부터 몇 시까지 비가 오는지" 시간 단위 정보 |
| 일반 날씨 확인 사용자 | 아침에 오늘/내일 날씨 확인 | 기온, 하늘상태, 강수확률 요약 |

---

## 2. Scope

### 2.1 In Scope (MVP)

- [ ] **F1. 현재 날씨 화면** — 초단기실황(`getUltraSrtNcst`) 기반: 기온(T1H), 습도(REH), 풍속(WSD), 강수형태(PTY), 1시간 강수량(RN1)
- [ ] **F2. 6시간 초단기예보 타임라인** — `getUltraSrtFcst` 기반: 시간별 기온/하늘상태/강수형태/강수확률 카드 UI
- [ ] **F3. 오늘~모레 합의 예보 (킬러 기능 2)** — 3개 출처(기상청 `getVilageFcst` + 해외 모델 2개) 교차 검증: 강수 여부는 2/3 다수결, 기온은 평균/범위 표시, 엇갈림 시 "예보 엇갈림" UI
- [ ] **F4. 소나기/비 푸시 알림 (킬러 기능)** — 2시간 윈도우 내 PTY 감지 → Web Push 알림, 중복 방지 포함
- [ ] **F5. 위치 처리** — GPS 위경도 → Lambert 변환식으로 nx/ny 산출 + 행정구역명 검색(격자 엑셀 → JSON 변환)
- [ ] **F6. 레이더 영상 뷰어** — `getCmpImg` 전국 합성영상 표시, 최근 프레임 애니메이션 재생
- [ ] **F7. 서버 프록시 + 캐싱** — serviceKey 은닉, base_time 단위 응답 캐싱, 에러코드 매핑
- [ ] **F8. PWA 설치 지원** — 홈 화면 추가, 오프라인 시 마지막 캐시 데이터 표시

### 2.2 Out of Scope (MVP 이후 검토)

- 네이티브 iOS/Android 앱 (MVP는 PWA로 검증 후 결정)
- 다중 위치 즐겨찾기 (MVP는 현재 위치 + 수동 지역 1곳)
- 레이더 개별 관측소 영상(`getRadarIndvdlzImg`)
- 미세먼지/자외선 등 타 API 연동
- 계정 시스템/소셜 로그인 (알림 구독은 브라우저 단위 익명 토큰으로 처리)
- 위젯, Wear OS/watchOS 지원

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | 사용자 위치 권한 요청 후 위경도를 획득하고, Lambert Conformal Conic 변환식(Re=6371.00877, grid=5.0, slat1=30, slat2=60, olon=126, olat=38, xo=43, yo=136)으로 nx/ny를 산출한다 | High | Pending |
| FR-02 | 위치 권한 거부 시 행정구역명(시/도 > 시/군/구 > 읍/면/동) 검색으로 nx/ny를 선택할 수 있다 (격자 엑셀 → 정적 JSON 변환하여 번들) | High | Pending |
| FR-03 | 현재 날씨 화면에 초단기실황 값(T1H, REH, WSD, PTY, RN1)을 표시한다 | High | Pending |
| FR-04 | 초단기예보를 fcstDate+fcstTime 기준으로 그루핑해 6시간 타임라인(시간별 기온·SKY·PTY·POP·RN1)을 표시한다 | High | Pending |
| FR-05 | 현재 시각 +2시간 윈도우 내 PTY=4 감지 시 소나기 알림, PTY=1/2/5 감지 시 비 알림을 Web Push로 발송한다 | High | Pending |
| FR-06 | 알림 문구에 예상 시간대, POP(강수확률), RN1(예상 강수량 범주)을 포함한다 | High | Pending |
| FR-07 | `subscriptionId + fcstDate + fcstTime + PTY` 키로 동일 예보에 대한 중복 알림을 방지한다 | High | Pending |
| FR-08 | 알림 스케줄러가 10분 간격으로 구독자별 초단기예보를 확인한다 (동일 nx/ny 구독자는 API 호출 1회로 묶음) | High | Pending |
| FR-09 | base_time 계산 규칙 준수 — 실황: 매시 10분 이후 정시(`HH00`), 초단기예보: 매시 45분 이후 `HH30`, 단기예보: 02/05/08/11/14/17/20/23시 +10분 | High | Pending |
| FR-10 | 일별 날씨 화면에 3개 출처(기상청 단기예보 + 해외 모델 2개)의 예보를 병합해 오늘/내일/모레 날씨를 표시한다 | High | Pending |
| FR-10a | 강수 여부(비/눈 유무)는 3개 출처 중 2개 이상 일치하는 판정을 채택한다 (2/3 다수결) | High | Pending |
| FR-10b | 기온·강수확률 등 수치는 다수결이 아닌 평균 또는 범위("21~24℃")로 표시한다 | High | Pending |
| FR-10c | 3개 출처가 엇갈리면 숨기지 않고 "예보 엇갈림 — 2개 모델 비, 1개 맑음" 형태로 표시하고, 탭하면 출처별 예보 상세를 보여준다 | Medium | Pending |
| FR-10d | 외부 출처 1개 이상 장애 시 남은 출처만으로 표시하고 "일부 예보 미수신" 배지를 붙인다 (2개 남으면 만장일치만 합의 처리, 1개면 단독 출처 표기) | Medium | Pending |
| FR-11 | 레이더 합성영상(`getCmpImg`, data=CMP_WRC) 최근 이미지들을 불러와 순차 재생(애니메이션)한다 | Medium | Pending |
| FR-12 | 알림 설정 화면 — 알림 on/off, "비 가능성 알림(PTY=0 + POP≥60)" 옵션, 야간 방해금지 시간대(기본 23:00~07:00) | Medium | Pending |
| FR-13 | API 응답 resultCode ≠ 00 시 코드별(03 NODATA, 22 한도초과, 30 미등록키 등) 사용자 친화 메시지와 폴백 UI를 표시한다 | Medium | Pending |
| FR-14 | 강수량 표기 규칙 준수 — `-`/`null`/`0` → "강수 없음", "1mm 미만", "30.0~50.0mm", "50.0mm 이상" 범주 그대로 표기, ±900 이상/이하 값은 Missing 처리 | Medium | Pending |
| FR-15 | PWA 설치 배너 및 오프라인 시 마지막 캐시 데이터 + "오프라인" 배지 표시 | Low | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| 성능 | 첫 화면 날씨 표시 < 2초 (캐시 히트 시 < 500ms) | Lighthouse, 서버 로그 |
| API 쿼터 | 공공데이터포털 일일 트래픽(개발계정 10,000회) 내 운영 — nx/ny 단위 캐싱으로 사용자 수와 호출 수 분리 | 프록시 서버 호출 카운터 |
| 보안 | serviceKey는 서버 환경변수로만 보관, 클라이언트 번들에 미포함 | 번들 grep 검사 |
| 신뢰성 | KMA API 실패 시 3회 재시도(지수 백오프) 후 직전 base_time 데이터로 폴백 | 프록시 에러율 모니터링 |
| 알림 적시성 | 예보 발표(매시 30분) 후 15분 이내 알림 도달 | 스케줄러 실행 로그 |
| 접근성 | WCAG 2.1 AA — 날씨 아이콘에 텍스트 대체, 색상 외 정보 전달 수단 병행 | axe-core 검사 |
| 호환성 | iOS Safari 16.4+ (Web Push 지원), Android Chrome, 데스크톱 브라우저 | 실기기 테스트 |

---

## 4. Core Logic Specification

### 4.1 소나기/비 알림 판정 로직

```text
1. 스케줄러가 10분마다 실행 (cron)
2. 활성 구독을 nx/ny로 그루핑 → 격자당 getUltraSrtFcst 1회 호출
3. 응답을 fcstDate+fcstTime으로 그루핑
4. now ~ now+2h 범위의 예보만 필터
5. 판정 (우선순위 순):
   - PTY = 4          → [소나기 알림]
   - PTY ∈ {1, 2, 5}  → [비 알림]
   - PTY = 0 AND POP ≥ 60 → [비 가능성 알림] (사용자 opt-in 시에만)
6. 문구 보강: RN1 범주 → "예상 강수량", POP → "강수확률", LGT > 0 → "낙뢰 가능성" 추가
7. 중복 체크: subscriptionId + fcstDate + fcstTime + PTY 키가 발송 이력에 있으면 skip
8. 방해금지 시간대면 skip (다음 아침 요약으로 대체하지 않음, MVP에서는 단순 skip)
9. Web Push 발송 및 발송 이력 저장 (TTL 24h)
```

### 4.2 알림 문구 템플릿

```text
[소나기 알림 ☔]
약 {N}분 뒤 현재 위치에 소나기 예보가 있어요.
예상 시간: {HH}시~{HH+1}시 · 강수확률 {POP}% · 예상 강수량 {RN1범주}

[비 알림 🌧]
{HH}시부터 현재 위치에 비 예보가 있어요. 우산을 챙기세요.
강수확률 {POP}% · 예상 강수량 {RN1범주}
```

### 4.3 base_time 계산 유틸 (공통 모듈)

| API | base_time 규칙 | 안전 마진 |
|---|---|---|
| `getUltraSrtNcst` | 정시 `HH00` | 매시 10분 이후 사용, 이전이면 -1시간 |
| `getUltraSrtFcst` | `HH30` | 매시 45분 이후 사용, 이전이면 -1시간 30분 |
| `getVilageFcst` | 02/05/08/11/14/17/20/23시 | 발표시각 +10분 이후, 자정 경계 시 전날 2300 |

### 4.4 API 요청 정책

| API | numOfRows | 캐시 TTL | 용도 |
|---|---|---|---|
| `getUltraSrtNcst` | 100 | 10분 | 현재 날씨 |
| `getUltraSrtFcst` | 1000 | 10분 | 타임라인 + 알림 판정 |
| `getVilageFcst` | 1000 | 1시간 | 오늘~모레 예보 (합의 출처 1) |
| Open-Meteo (ECMWF/GFS) | - | 1시간 | 오늘~모레 예보 (합의 출처 2·3) |
| `getCmpImg` | 10 | 5분 | 레이더 뷰어 |

캐시 키: `{endpoint}:{base_date}{base_time}:{nx}:{ny}` — 동일 격자·동일 발표분 응답은 재호출하지 않음.

### 4.5 일별 날씨 3출처 합의(Consensus) 로직

**데이터 소스** (서로 독립적인 예보 모델이어야 함):

| 출처 | API | 비고 |
|---|---|---|
| 기상청 (한국) | `getVilageFcst` | 국내 정확도 기준점, 기존 프록시 재사용 |
| ECMWF (유럽) | Open-Meteo `forecast?models=ecmwf_ifs` | API 키 불요, 무료 |
| GFS (미국) | Open-Meteo `forecast?models=gfs_global` | API 키 불요, 무료. Open-Meteo 1회 호출로 두 모델 동시 수신 가능 |

**합의 규칙**:

```text
1. 3개 출처의 예보를 동일 시간축(KST, 일 단위 + 시간대 단위)으로 정규화
   - 기상청: nx/ny 격자 / 해외 모델: 위경도 → 같은 위치 기준으로 매칭
   - 강수 판정 정규화: 기상청 PTY>0 또는 POP≥60 ↔ 해외 모델 precipitation>0 또는 precip_probability≥60
2. 강수 여부(이진 판단): 2/3 다수결 채택
3. 수치(기온, 강수확률): 다수결 불가 → 평균 또는 범위 표시
4. 판정 결과에 합의 수준 태그 부착:
   - 3/3 일치 → "확실" (기본 표시)
   - 2/3 일치 → 다수 예측 표시 + 소수 의견 접힘 처리
   - 출처 장애로 2개 이하 → FR-10d 폴백 규칙 적용
5. 캐시: 출처별 TTL 1시간, 합의 결과도 별도 캐시
```

**적용 범위 주의**: 합의 로직은 **일별 날씨(F3)에만** 적용한다.
소나기 알림(F4)과 6시간 타임라인(F2)은 기상청 초단기예보 단독으로 간다 —
2시간 윈도우를 커버하는 국내 고해상도 예보가 그것뿐이고, 알림은 속도가 우선이라 투표 대기 비용이 손해이기 때문.

---

## 5. Screen Map (IA)

```
┌─ 홈 (현재 날씨 + 2시간 알림 상태 배너)
│   ├─ 6시간 타임라인 (가로 스크롤 카드)
│   └─ 오늘/내일/모레 요약 → 상세
├─ 레이더 (전국 합성영상 애니메이션)
├─ 지역 설정 (GPS 버튼 + 행정구역 검색)
└─ 알림 설정 (on/off, 비 가능성 옵션, 방해금지 시간)
```

---

## 6. Success Criteria

### 6.1 Definition of Done (MVP)

- [ ] FR-01 ~ FR-09 (High) 전체 구현
- [ ] 실기기(iOS Safari, Android Chrome)에서 Web Push 수신 확인
- [ ] 위경도 → nx/ny 변환 단위 테스트 (기상청 예시 좌표 대조: 서울 60/127 등)
- [ ] base_time 계산 단위 테스트 (자정 경계, 발표 전 시각 케이스 포함)
- [ ] 합의 로직 단위 테스트 (3/3·2/3 일치, 출처 장애 폴백, 시간축 정규화)
- [ ] 알림 중복 방지 통합 테스트
- [ ] 코드 리뷰 및 문서화 완료

### 6.2 Quality Criteria

- [ ] 핵심 유틸(좌표 변환, base_time, 알림 판정) 테스트 커버리지 90% 이상
- [ ] Lint 에러 0건, 빌드 성공
- [ ] serviceKey 클라이언트 노출 0건

### 6.3 Product Metrics (출시 후)

| 지표 | 목표 |
|---|---|
| 알림 허용률 | 방문자의 30% 이상 |
| 알림 → 앱 재방문 전환율 | 20% 이상 |
| 소나기 알림 정확도 (알림 후 실제 강수) | 체감 만족도 설문으로 추적 |
| 일일 API 호출 수 | 쿼터의 70% 이하 유지 |

---

## 7. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 공공데이터포털 API 지연/장애 | High | Medium | 재시도 + 직전 base_time 폴백, 상태 배지 표시 |
| 일일 트래픽 한도(10,000회) 초과 | High | Medium | nx/ny 단위 캐싱·그루핑 호출, 운영계정 승급 신청(활용사례 등록) |
| iOS Web Push 제약 (홈 화면 설치 필수) | High | High | PWA 설치 유도 온보딩, 미설치 시 인앱 배너 알림으로 대체 |
| base_time 계산 오류로 NODATA(03) 빈발 | Medium | Medium | 계산 유틸 단위 테스트 + NODATA 시 자동으로 이전 발표분 재시도 |
| 초단기예보 자체 정확도 한계 (허탕 알림) | Medium | Medium | 문구에 "예보" 표현 유지, 비 가능성 알림은 opt-in으로 분리 |
| CORS/serviceKey 노출 | High | Low | 모든 KMA 호출을 서버 프록시로 강제, 클라이언트 직접 호출 금지 |
| 위치 권한 거부율 | Medium | Medium | 지역명 검색 폴백(FR-02), 권한 요청 전 가치 설명 화면 |
| 외부 예보 출처(Open-Meteo) 장애/정책 변경 | Medium | Low | FR-10d 폴백(남은 출처만으로 표시), 출처 어댑터 패턴으로 교체 용이하게 설계 |
| 출처 간 시간축/단위 불일치로 잘못된 합의 | Medium | Medium | 정규화 레이어 단위 테스트(KST 변환, 강수 판정 기준 통일), 출처별 원본값 로깅 |

---

## 8. Architecture Considerations

### 8.1 Project Level Selection

| Level | Characteristics | Recommended For | Selected |
|-------|-----------------|-----------------|:--------:|
| **Starter** | 정적 구조 | 정적 사이트 | ☐ |
| **Dynamic** | 기능 모듈 + 서버리스 백엔드 | 알림/스케줄러가 있는 풀스택 앱 | ☑ |
| **Enterprise** | 레이어 분리, MSA | 대규모 트래픽 | ☐ |

**선정 근거**: 푸시 알림 구독 저장·10분 주기 스케줄러·API 프록시가 필요하므로 백엔드가 있는 Dynamic. 다만 트래픽 규모상 서버리스로 충분.

### 8.2 Key Architectural Decisions

| Decision | Options | Selected | Rationale |
|----------|---------|----------|-----------|
| Framework | Next.js / React SPA / Vue | **Next.js 15 (App Router)** | API Route로 프록시·스케줄러 엔드포인트 통합, Vercel 배포 용이 |
| 상태 관리 | Context / Zustand / Redux | **Zustand** | 위치·설정 등 소규모 전역 상태에 적합, 보일러플레이트 최소 |
| API Client | fetch / axios / react-query | **TanStack Query + fetch** | base_time 단위 캐싱·리페치 정책과 자연스럽게 결합 |
| Styling | Tailwind / CSS Modules | **Tailwind CSS** | 빠른 UI 반복, 기존 프로젝트들과 스택 통일 |
| 일별 예보 출처 | 기상청 단독 / 다중 출처 | **기상청 + Open-Meteo(ECMWF·GFS) 3출처 합의** | 독립 모델 간 2/3 다수결로 신뢰도·차별화 확보, Open-Meteo는 키 불요·무료 |
| Push | FCM / web-push(VAPID) | **web-push (VAPID)** | 계정 시스템 없는 익명 구독에 단순·무료 |
| 구독/이력 저장 | Firestore / Supabase / KV | **Firebase Firestore** | 기존 프로젝트(Firebase) 경험 재사용, 무료 티어 충분 |
| 스케줄러 | Vercel Cron / Cloud Functions | **Vercel Cron (10분 간격)** | Next.js API Route 재사용, 별도 인프라 불요 |
| Testing | Jest / Vitest | **Vitest** | 좌표 변환·base_time 유틸 단위 테스트 중심 |
| 배포 | Vercel / Firebase Hosting | **Vercel** | Cron + Edge 캐싱 + Next.js 네이티브 지원 |

### 8.3 Folder Structure Preview (Dynamic)

```
weather/
├── src/
│   ├── app/                    # Next.js App Router (홈, 레이더, 설정)
│   │   └── api/
│   │       ├── weather/        # KMA 프록시 (ncst, fcst, vilage, radar)
│   │       ├── subscribe/      # Push 구독 등록/해제
│   │       └── cron/notify/    # 10분 주기 알림 판정 (Vercel Cron)
│   ├── components/             # WeatherCard, Timeline, RadarViewer ...
│   ├── features/
│   │   ├── forecast/           # 예보 그루핑·표시 로직
│   │   ├── consensus/          # 3출처 정규화·다수결·엇갈림 판정
│   │   ├── alert/              # 알림 판정·문구 생성
│   │   └── location/           # GPS, 격자 변환, 지역 검색
│   ├── lib/
│   │   ├── kma/                # API 클라이언트, base_time, 코드 매핑
│   │   ├── sources/            # 예보 출처 어댑터 (kma, open-meteo) 공통 인터페이스
│   │   ├── grid.ts             # Lambert 위경도↔nx/ny 변환
│   │   └── push.ts             # web-push 래퍼
│   ├── data/regions.json       # 격자 엑셀 변환본 (행정구역 → nx/ny)
│   └── types/                  # KMA 응답, 도메인 타입
├── public/ (manifest.json, sw.js)
└── docs/ (PDCA 문서)
```

---

## 9. Convention Prerequisites

### 9.1 Existing Project Conventions

- [ ] `CLAUDE.md` 코딩 컨벤션 — 없음 (신규 프로젝트, 정의 필요)
- [ ] ESLint / Prettier / tsconfig — 프로젝트 초기화 시 생성

### 9.2 Conventions to Define

| Category | To Define | Priority |
|----------|-----------|:--------:|
| Naming | 컴포넌트 PascalCase, 유틸 camelCase, KMA category 코드는 원문 대문자 유지(`PTY`, `RN1`) | High |
| 폴더 구조 | 8.3 구조 준수, feature 단위 응집 | High |
| KMA 코드 매핑 | PTY/SKY 코드 → 한글 라벨·아이콘 매핑은 `lib/kma/codes.ts` 단일 소스로 관리 | High |
| 에러 처리 | 프록시에서 resultCode → HTTP 상태 + 도메인 에러 타입으로 정규화 | Medium |
| 시간 처리 | 모든 KMA 시각은 KST 고정 — `date-fns-tz`로 서버 타임존 무관하게 계산 | High |

### 9.3 Environment Variables Needed

| Variable | Purpose | Scope | To Be Created |
|----------|---------|-------|:-------------:|
| `KMA_SERVICE_KEY` | 공공데이터포털 인증키 (URL 인코딩 전 원본 보관) | Server | ☐ |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Web Push 서명 키쌍 | Server(공개키는 Client 노출 가능) | ☐ |
| `FIREBASE_*` (admin 자격증명) | 구독/발송 이력 저장 | Server | ☐ |
| `CRON_SECRET` | Vercel Cron 엔드포인트 보호 | Server | ☐ |

---

## 10. Milestones

| 단계 | 기간(안) | 산출물 |
|---|---|---|
| M1. 기반 구축 | 3일 | Next.js 셋업, KMA 프록시, 격자 변환 유틸 + 테스트 |
| M2. 날씨 화면 | 4일 | F1~F2 (현재 날씨, 타임라인 UI) |
| M2.5. 합의 예보 | 3일 | F3 (출처 어댑터, 정규화, 2/3 다수결, 엇갈림 UI) |
| M3. 알림 파이프라인 | 5일 | F4~F5 (Push 구독, Cron 판정, 중복 방지) — 킬러 기능 |
| M4. 레이더 + PWA | 3일 | F6, F8, 알림 설정 화면 |
| M5. 안정화 | 3일 | 에러 처리(FR-13), 실기기 테스트, 배포 |

**총 예상: 약 3.5주 (1인 개발 기준)**

---

## 11. Next Steps

1. [ ] 공공데이터포털에서 단기예보/레이더영상 API 활용신청 및 `serviceKey` 발급
2. [ ] 격자 엑셀 → `regions.json` 변환 스크립트 작성
3. [ ] 설계 문서 작성 (`/pdca design weather-app`)
4. [ ] 구현 시작 (`/pdca do weather-app`)

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-07-08 | 최초 작성 (KMA API 명세 기반, 미정 항목 자체 결정으로 충전) | son-inseong |
| 0.2 | 2026-07-08 | 일별 날씨를 3출처(기상청+ECMWF+GFS) 2/3 다수결 합의 구조로 변경, FR-10a~d·합의 로직(4.5)·리스크 추가 | son-inseong |
