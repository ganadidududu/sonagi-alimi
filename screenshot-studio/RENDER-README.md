# 광고형 스크린샷 렌더 (Chrome 방식)

편집기의 "Export bundle"(html-to-image)은 폰 화면 스크린샷을 검게 렌더하는 버그가
있어, 슬라이드 전체를 Chrome 헤드리스로 직접 렌더한다.

## 사용법
1. 편집기(`npm run dev`)에서 문구/레이아웃 편집 → 자동으로 `app-store-screenshots.json` 저장
2. 슬라이드 HTML 생성:  `python3 render-slides.py`  (→ scratchpad/slides/*.html)
3. 각 HTML을 Chrome으로 1320x2868 렌더 후 1284x2778(App Store 6.5") 리사이즈
   (render-slides.py 상단 OUT 경로 참고)

결과물: `App_Store_스크린샷_광고형/` (프로젝트 루트, 1284x2778)
