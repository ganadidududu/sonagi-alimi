# F3. 일별 3출처 합의 예보 — 설계

> Plan 근거: [weather-app.plan.md](../../01-plan/features/weather-app.plan.md) §4.5, FR-10~10d
> 대상 버전: **1.1.0** (아침 브리핑과 함께 릴리즈)
> 적용 범위: **일별(주간) 탭에만**. 소나기 알림·6시간 타임라인·현재 날씨는 기상청 단독 유지.

## 1. 목적

아이폰 기본 날씨앱(≈전지구 모델)이 "비"라고 할 때, 이 앱은 **서로 독립적인 세 예보를
투표**시켜 더 신뢰할 수 있는 판단을 보여준다. 셋이 갈리면 숨기지 않고 "예보가 엇갈린다"는
사실 자체를 드러내는 것이 차별점이다.

## 2. 데이터 소스 (확정)

| 출처 | 종류 | 취득 | 비고 |
|---|---|---|---|
| **기상청** | 국내 고해상도 | 기존 `getVilageFcst` 재사용 | 조합에서 **유일한 국내 모델** — 한반도 지형 반영, "다른 목소리"를 내는 핵심 |
| **ECMWF** | 전지구 (유럽) | Open-Meteo `models=ecmwf_ifs025` | 전지구 최고 정확도 |
| **ICON** | 전지구 (독일) | Open-Meteo `models=icon_seamless` | GFS보다 고해상도. 세션 검증 시 ECMWF와 다른 값을 내 다양성 확보 |

- ECMWF·ICON은 **Open-Meteo 1회 호출**로 동시 수신 (`models=ecmwf_ifs025,icon_seamless`).
- Open-Meteo: API 키 불요, 무료, 재배포 허용. AccuWeather/WeatherKit은 상업 재배포 불가라 제외.
- KMA/JMA 글로벌 모델은 Open-Meteo가 이 지역을 서빙하지 않아(검증 완료) 선택 불가.

### 2.1 Open-Meteo 요청

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}&longitude={lon}
  &daily=precipitation_probability_max,precipitation_sum,weather_code,
         temperature_2m_max,temperature_2m_min
  &models=ecmwf_ifs025,icon_seamless
  &timezone=Asia%2FSeoul
  &forecast_days=3
```

응답은 필드명에 모델 접미사가 붙는다: `precipitation_probability_max_ecmwf_ifs025` 등.

## 3. 합의 로직

### 3.1 시간축 정규화

- 세 출처를 **KST 일 단위**로 맞춘다 (오늘/내일/모레 — Open-Meteo `forecast_days=3`).
- 기상청은 nx/ny 격자, 해외 모델은 위경도. **같은 요청 좌표**(GPS 또는 선택 지역)에서
  기상청은 격자 변환, Open-Meteo는 위경도 직접 전달 → 동일 지점 기준.

### 3.2 강수 판정 정규화 (이진)

각 출처를 "그날 비 옴/안 옴"으로 환원한다:

| 출처 | "비 옴" 조건 |
|---|---|
| 기상청 | 그날 슬롯 중 `PTY>0` 존재 **또는** `POP≥60` |
| ECMWF·ICON | `precipitation_probability_max ≥ 60` **또는** `precipitation_sum ≥ 1.0mm` |

> POP 60% 기준은 Plan §4.5의 정규화 규칙을 그대로 따른다. `precipitation_sum` 하한(1mm)은
> 확률은 낮지만 실제 강수량이 잡히는 경우를 포착하기 위한 보조 조건.

### 3.3 다수결

- **강수 여부**: 3표 중 2표 이상이 "비 옴" → 그날은 "비". (이진 판단만 다수결)
- **합의 수준 태그**:
  - `3/3` 일치 → "확실" (꼬리표 없음)
  - `2/3` 일치 → 다수 예측 + **"3중 2" 꼬리표**, 소수 의견은 탭 시 상세에서 노출
- **수치는 다수결하지 않는다** (§3.4).

### 3.4 수치(기온·강수확률)

- **다수결 불가** → 세 출처의 **평균**을 대표값으로, 필요 시 **범위**로.
  - 최고기온: 세 값 평균을 표시, 상세에서 `25~27°` 범위.
  - 강수확률: 세 값 평균.
- 기온은 세 모델이 대체로 근접하므로 평균이 안전. 큰 편차(>3°)는 상세에서 출처별로 보여준다.

### 3.5 폴백 (FR-10d)

| 상황 | 처리 |
|---|---|
| Open-Meteo 장애 | 기상청 단독으로 일별 표시 (현행과 동일), 꼬리표에 "합의 일시 중단" |
| 기상청 장애 | 해외 2개 평균으로 표시 |
| 2개 이상 장애 | 남은 출처 단독, 합의 태그 숨김 |

**핵심 원칙:** 합의가 불가능해도 **일별 화면은 절대 비지 않는다.** 현재 기상청 단독 로직이
최종 폴백.

## 4. UI (확정: 다수결 + 작은 꼬리표)

- 기존 일별 카드 레이아웃 유지. 큰 아이콘/기온은 **다수결 결과**로 렌더.
- `2/3`인 날만 기온 옆에 작은 배지: **"3중 2"** (또는 아이콘). `3/3`은 배지 없음.
- 카드 **탭 → 출처별 상세 시트**: 기상청/ECMWF/ICON 각각의 강수 판정·강수확률·최고기온 3줄.
  "아이폰 날씨는 비라던데 기상청은 아니네?"를 사용자가 직접 확인하는 지점.

## 5. 서버 아키텍처

기존 `checkWeatherAlerts` 스케줄러와 `gridWeather/{nx}_{ny}` 캐시 구조를 재사용한다.

### 5.1 어디서 합쳐지나

- **서버(Cloud Functions)에서 합의 계산.** 위젯·앱이 같은 결과를 읽어야 하고, Open-Meteo
  호출도 사용자 수와 무관하게 격자당 1회로 묶어야 하기 때문 (기상청 트래픽 설계와 동일 사상).
- `processGrid`가 기상청 `getVilageFcst`를 이미 부르므로, 여기에 Open-Meteo 호출을 더해
  합의 결과를 `gridWeather/{nx}_{ny}.consensus`에 캐싱.
- 앱은 이 캐시를 읽는다. 앱이 직접 Open-Meteo를 부르지 않는다.

### 5.2 캐싱

| 데이터 | TTL | 키 |
|---|---|---|
| Open-Meteo raw (격자별) | 1시간 | `openMeteo:{nx}_{ny}` |
| 합의 결과 | 1시간 (기상청 발표 주기 종속) | `gridWeather/{nx}_{ny}.consensus` |

- Open-Meteo 무료 한도(약 10,000 호출/일)는 격자당 시간 1회로 캐싱하면 여유. 활성 격자
  수 × 24가 상한.

### 5.3 앱 취득 경로

- 앱은 `getWidgetWeather`류 엔드포인트(또는 신규 `getConsensus`)로 합의 결과를 읽는다.
- **온라인 폴백:** 서버 캐시에 아직 합의가 없으면(신규 격자 첫 조회) 앱은 기상청 단독
  일별을 그대로 보여주고, 다음 스케줄러 틱 이후 합의가 채워진다.

## 6. 코드 매핑

| 레이어 | 파일 | 변경 |
|---|---|---|
| 서버 | `firebase/functions/src/openMeteo.ts` (신규) | Open-Meteo 어댑터, 위경도→모델별 일별 파싱 |
| 서버 | `firebase/functions/src/consensus.ts` (신규) | 3출처 정규화·다수결·평균, 합의 태그 |
| 서버 | `firebase/functions/src/index.ts` | `processGrid`에 합의 계산·캐싱 추가, `getConsensus` 반환 |
| 앱 | `UbiWeather/Models/WeatherModels.swift` | `DailySummary`에 `consensusLevel`(확실/다수), 출처별 상세 필드 |
| 앱 | `UbiWeather/Services/WeatherRepository.swift` | 서버 합의 fetch → `vm.weekly` 병합, 실패 시 기상청 단독 폴백 |
| 앱 | `UbiWeather/Views/DailyView.swift` | "3중 2" 배지, 탭 → 출처별 상세 시트 |
| 앱 | `UbiWeather/Components/` | 출처별 상세 시트 뷰 (신규) |

## 7. 테스트 계획

- **정규화**: 기상청 PTY/POP → 이진, Open-Meteo pop/sum → 이진 각 경계값.
- **다수결**: (비/비/맑) → 비+2/3, (비/맑/맑) → 맑+2/3, (비/비/비) → 비+확실.
- **평균**: 기온 3값 평균·범위, 강수확률 평균.
- **폴백**: Open-Meteo null → 기상청 단독, 기상청 null → 해외 2개, 전부 null → 빈 화면 아님.
- **자정/시간축**: KST 일 경계에서 오늘/내일/모레 매칭.
- 서버 twin은 라이브 Open-Meteo+기상청 데이터로 실측 검증 (기존 방식).

## 8. 범위 밖 (이번 버전 안 함)

- 소나기 알림·타임라인·현재 날씨의 합의화 (기상청 단독 유지 — Plan §4.5 명시).
- 시간대 단위 합의 (일 단위만). 시간별 합의는 데이터량·복잡도 대비 효용이 낮음.
- 4번째 모델(GFS 등) 추가 — 전지구 모델이 서로 비슷해 기상청 표가 묻히는 것 방지.
