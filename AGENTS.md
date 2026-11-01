# AGENTS.md — Hobby Atlas v3 (개인용)

중간고사 제출본은 `mdefitko777/gunpula-flutter` 에 그대로 있다. 이 저장소(`hobby-atlas-v3`, private)는 **내가 실제로 쓰는 앱**이고, 수업 규칙(GET만 · setState만 · 저장 금지 · 패키지 금지)은 적용하지 않는다.

## 무엇을 만드나
- 안드로이드 앱 `com.mdefitko.hobbyatlas`. 옛 Gunpula 앱(`com.mdefitko.gunpula`, Capacitor WebView)을 **대체**한다. 옛 앱과 나란히 설치해 두고, 다 옮긴 뒤에 옛 앱을 지운다.
- 데이터는 Gunpula 저장소(공개, `C:\Users\Windows11\Documents\Gundam\_upload_repo`)의 GitHub Actions 가 매일 만들고, 앱은 GitHub Pages 에서 읽는다.
  - 데이터: `https://mdefitko777.github.io/Gunpula/data/…` (먼저 `split/manifest.json` 의 `updated_at`·`total` 로 바뀌었는지 본다. Pages ETag 는 배포마다 바뀌어 쓸모없다)
  - 이미지: `./assets/…` → `https://mdefitko777.github.io/Gunpula/app/assets/…`
  - `kits.json` · `search-index.json` 은 받지 않는다 (split 과 같은 내용이고 너무 크다).
- 계정 · 공유는 Gunpula 의 Supabase 프로젝트를 같이 쓴다 (`docs/supabase-setup-v2.sql` · `-v3.sql`, 이메일 6자리 코드 로그인). 옛 앱과 같은 계정이라 **로그인만 하면 옛 컬렉션이 온다**.
  - 코드: `lib/sync/` — `collection_merge.dart`(옛 `collection-store.js` 를 그대로 옮김, `test/collection_merge_js_test.dart` 가 JS 결과와 비교), `sync_service.dart`, `friends_service.dart`, `account.dart`(AccountScope), `supabase_backend.dart`(supabase_flutter 를 부르는 유일한 파일).
  - 친구 = v3 (`@아이디` 로 찾기 → 요청 → 수락, 서로의 컬렉션 읽기만). v2 초대 코드는 쓰지 않는다.

## 데이터 약속 (옛 앱과 함께 쓰는 동안)
- 키는 Gunpula 의 `kit_id` · gget `unit_id` · phstudy `part_id` 그대로. 가짜 id(gu01 …)를 새로 만들지 않는다.
- 수집 기록 모양은 옛 앱 `app/collection-store.js` 와 같다: `{status: owned|wanted|deleted, quantity 1–99, updated_at, updated_by, note?, storage?, purchase_price?}`. 한 상품에 상태는 하나(좋아요 = wanted, 구매함 = owned).
- 동기화 payload 의 `overrides` · `series_label_overrides` · `appearance` · 다른 멤버 버킷 · `custom_items` · 모르는 키는 읽은 그대로 돌려준다. Hobby Atlas 에만 있는 값(베이 부품 · 베이 연결 · 도감 손으로 켜기)은 payload 에 넣지 않는다 (지금은 기기에만).
- 동기화 순서 (`lib/sync/sync_service.dart`): v2 `get_state` → 내 버킷만 상품별로 합침(늦은 `updated_at`, 지움 = `deleted`, 별칭 `member`·`ttungyimu…` 는 나에게, `냐아` 버림) → 달라졌으면 v2 `save_state` → 같은 payload 를 v3 `save_state(p_base_revision)` 에 복사, `40001` 이면 `get_me` → 합침 → 재시도(최대 3번). v2 공유 공간이 없는 계정은 v3 내 행이 원본.
  - 내 버킷 이름 = 서버 `members[is_self].name` 의 버킷, 없으면 `items` 와 같은 버킷(옛 앱이 이름을 안 정했으면 `member`).
  - 언제: 로그인 직후 · 앱으로 돌아올 때 · 앞에 있는 동안 15초마다(v2 만, v3 는 1분에 한 번) · 바꾸고 0.7초 뒤. 오프라인이면 기기에 남겨 두고(`cloudDirty`) 다음에 다시.
  - 기기 기록의 주인 = 처음 로그인한 계정(`UserStore.syncedAccount`, Supabase user id). 다른 계정으로 로그인하면 앞 계정 기록을 새 계정에 합치지 않고 비운 뒤 새 계정 것을 받는다 (베이 부품 등 기기에만 있는 값은 둔다).
- 테스트는 진짜 서버에 닿지 않는다: `test/support/fake_backend.dart` 의 가짜 서버 · 가짜 로그인. 진짜 계정으로 로그인해 보는 것은 사람만.

## 비밀
- 옛 백업 JSON 의 `github_token` 은 읽자마자 버린다. 저장 · 로그 · 커밋 금지. 백업 파일은 저장소에 넣지 않는다.
- `data/market_secrets.local.json` (Gunpula) 값은 출력하지 않는다.
- Supabase 주소 · anon key 는 `config/supabase.json` 에 커밋한다 — 옛 앱 `app/sync-config.js` 와 같은 **공개용** 값이다 (데이터는 RLS + authenticated 전용 RPC 가 지킨다). `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` 를 주면 그 값이 먼저. service_role key 는 절대 넣지 않는다 (`test/backend_config_test.dart` 가 role=anon 인지 본다).
- 로그인 세션(refresh token)은 `flutter_secure_storage` 에만. 로그 · `user.json` · 백업 파일 · 커밋에 남기지 않는다 (supabase `debug: false`).
- 서명 키(keystore)와 비밀번호는 저장소 밖, GitHub Actions secrets 에만 둔다.

## 작업 방식
- 상태: 앱 전체 한 벌은 위쪽 Host(InheritedWidget) + 저장소 객체(ChangeNotifier), 화면 안 표시는 `setState`. 내 기록 = `MarksHost`/`UserStore`, 계정 · 동기화 · 친구 = `AccountScope`/`Account`.
- 사진 벽(내 정보 · 친구 보기): 내 사진은 기기(앱 문서 폴더 `photos/`, 목록은 `UserStore` local_state `photos`), 친구에게 보이기를 켠 것만 Supabase Storage `photos` 버킷 `<user_id>/<photo_id>.jpg` 로 (`lib/sync/photo_share.dart`). 서버 SQL = `docs/supabase-v3-photos.sql` — 안 돌렸으면 사진은 기기에만 · ⚠ 하나. 취향 태그 = v3 `preferences.tags` (+ 기기 `profile_tags`).
- 알 수도 있는 친구 · 공유 공간 탭은 서버가 없어 화면에서 뺐다.
- 무거운 JSON(kits-gundam 9 MB)은 `Isolate.run` 으로 푼다.
- 확인: 경로에 한글이 있어 `flutter analyze` 가 멈춘다 → `dart analyze lib test tool` 0 issues + `flutter test`.
- 커밋은 `v3: …` 로 시작하고, 단계마다 commit + push (origin = hobby-atlas-v3).
- Gunpula 저장소는 다른 세션도 동시에 커밋한다. 거기서 작업할 땐 내 파일만 stage 하고 push 전에 fetch.
