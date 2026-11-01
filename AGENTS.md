# AGENTS.md — Hobby Atlas v3 (개인용)

중간고사 제출본은 `mdefitko777/gunpula-flutter` 에 그대로 있다. 이 저장소(`hobby-atlas-v3`, private)는 **내가 실제로 쓰는 앱**이고, 수업 규칙(GET만 · setState만 · 저장 금지 · 패키지 금지)은 적용하지 않는다.

## 무엇을 만드나
- 안드로이드 앱 `com.mdefitko.hobbyatlas`. 옛 Gunpula 앱(`com.mdefitko.gunpula`, Capacitor WebView)을 **대체**한다. 옛 앱과 나란히 설치해 두고, 다 옮긴 뒤에 옛 앱을 지운다.
- 데이터는 Gunpula 저장소(공개, `C:\Users\Windows11\Documents\Gundam\_upload_repo`)의 GitHub Actions 가 매일 만들고, 앱은 GitHub Pages 에서 읽는다.
  - 데이터: `https://mdefitko777.github.io/Gunpula/data/…` (먼저 `split/manifest.json` 의 `updated_at`·`total` 로 바뀌었는지 본다. Pages ETag 는 배포마다 바뀌어 쓸모없다)
  - 이미지: `./assets/…` → `https://mdefitko777.github.io/Gunpula/app/assets/…`
  - `kits.json` · `search-index.json` 은 받지 않는다 (split 과 같은 내용이고 너무 크다).
- 계정 · 공유는 Gunpula 의 Supabase 프로젝트를 같이 쓴다 (`docs/supabase-setup-v3.sql`, email OTP).

## 데이터 약속 (옛 앱과 함께 쓰는 동안)
- 키는 Gunpula 의 `kit_id` · gget `unit_id` · phstudy `part_id` 그대로. 가짜 id(gu01 …)를 새로 만들지 않는다.
- 수집 기록 모양은 옛 앱 `app/collection-store.js` 와 같다: `{status: owned|wanted|deleted, quantity 1–99, updated_at, updated_by, note?, storage?, purchase_price?}`. 한 상품에 상태는 하나(좋아요 = wanted, 구매함 = owned).
- 동기화 payload 의 `overrides` · `series_label_overrides` · `appearance` · 다른 멤버 버킷은 읽은 그대로 돌려준다. Hobby Atlas 에만 있는 값은 payload 에 넣지 않는다.

## 비밀
- 옛 백업 JSON 의 `github_token` 은 읽자마자 버린다. 저장 · 로그 · 커밋 금지. 백업 파일은 저장소에 넣지 않는다.
- `data/market_secrets.local.json` (Gunpula) 값은 출력하지 않는다. Supabase anon key 는 공개용이지만 `--dart-define` 으로 넘긴다.
- 서명 키(keystore)와 비밀번호는 저장소 밖, GitHub Actions secrets 에만 둔다.

## 작업 방식
- 상태: 앱 전체 한 벌은 위쪽 Host(InheritedWidget) + 저장소 객체(ChangeNotifier), 화면 안 표시는 `setState`.
- 무거운 JSON(kits-gundam 9 MB)은 `Isolate.run` 으로 푼다.
- 확인: 경로에 한글이 있어 `flutter analyze` 가 멈춘다 → `dart analyze lib test tool` 0 issues + `flutter test`.
- 커밋은 `v3: …` 로 시작하고, 단계마다 commit + push (origin = hobby-atlas-v3).
- Gunpula 저장소는 다른 세션도 동시에 커밋한다. 거기서 작업할 땐 내 파일만 stage 하고 push 전에 fetch.
