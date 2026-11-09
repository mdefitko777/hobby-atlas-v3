# AGENTS.md — Hobby Atlas

이 저장소(`hobby-atlas-v3`)는 **내가 매일 쓰는 개인용 앱**이다. 앱 소개 · 설치 · 개발 명령은 [README.md](README.md), 여기는 AI 와 같이 작업할 때 지킬 구조 · 약속.

## 무엇을 만드나
- 안드로이드 앱 `com.mdefitko.hobbyatlas`. 옛 Gunpula 앱(`com.mdefitko.gunpula`, Capacitor WebView)을 **대체**한다. 옛 앱과 나란히 설치해 두고, 다 옮긴 뒤에 옛 앱을 지운다.
- 데이터는 Gunpula 저장소(공개, `C:\Users\Windows11\Documents\Gundam\_upload_repo`)의 GitHub Actions 가 매일 만들고, 앱은 GitHub Pages 에서 읽는다.
  - 데이터: `https://mdefitko777.github.io/Gunpula/data/…` (먼저 `split/manifest.json` 의 `updated_at`·`total` 로 바뀌었는지 본다. Pages ETag 는 배포마다 바뀌어 쓸모없다)
  - 이미지: `./assets/…` → `https://mdefitko777.github.io/Gunpula/app/assets/…`
  - `kits.json` · `search-index.json` 은 받지 않는다 (split 과 같은 내용이고 너무 크다).
- 계정 · 공유는 Gunpula 의 Supabase 프로젝트를 같이 쓴다 (`docs/supabase-setup-v2.sql` · `-v3.sql`, 이메일 6자리 코드 로그인). 옛 앱과 같은 계정이라 **로그인만 하면 옛 컬렉션이 온다**.
  - 코드: `lib/sync/` — `collection_merge.dart`(옛 `collection-store.js` 를 그대로 옮김, `test/collection_merge_js_test.dart` 가 JS 결과와 비교), `sync_service.dart`, `device_state.dart` · `device_state_sync.dart`(기기 기록), `photo_restore.dart`(내 사진 되찾기), `friends_service.dart`, `account.dart`(AccountScope), `supabase_backend.dart`(supabase_flutter 를 부르는 유일한 파일).
  - 친구 = v3 (`@아이디` 로 찾기 → 요청 → 수락, 서로의 컬렉션 읽기만). v2 초대 코드는 쓰지 않는다 (공유 공간은 v2 get_state 의 멤버 · 역할을 **읽기만** — 만들기 · 초대 코드는 서버 함수가 없어 없음, 공유 공간이 없는 계정은 탭 · 칸 숨김).

## 데이터 약속 (옛 앱과 함께 쓰는 동안)
- 키는 Gunpula 의 `kit_id` · gget `unit_id` · phstudy `part_id` 그대로. 가짜 id(gu01 …)를 새로 만들지 않는다.
- 수집 기록 모양은 옛 앱 `app/collection-store.js` 와 같다: `{status: owned|wanted|deleted, quantity 1–99, updated_at, updated_by, note?, storage?, purchase_price?}`. 한 상품에 상태는 하나(좋아요 = wanted, 구매함 = owned).
- 동기화 payload 의 `overrides` · `series_label_overrides` · `appearance` · 다른 멤버 버킷 · `custom_items` · 모르는 키는 읽은 그대로 돌려준다. Hobby Atlas 에만 있는 값(베이 부품 · 베이 연결 · 도감 손으로 켜기 …)은 payload 에 **넣지 않는다** (옛 앱이 모르는 키를 지울 수 있음) — 따로 된 서버 행 `gunpula_v3_device_state` 에 (아래 "기기 기록 동기화").
- 동기화 순서 (`lib/sync/sync_service.dart`): v2 `get_state` → 내 버킷만 상품별로 합침(늦은 `updated_at`, 지움 = `deleted`, 별칭 `member`·`ttungyimu…` 는 나에게, `냐아` 버림) → 달라졌으면 v2 `save_state` → 같은 payload 를 v3 `save_state(p_base_revision)` 에 복사, `40001` 이면 `get_me` → 합침 → 재시도(최대 3번). v2 공유 공간이 없는 계정은 v3 내 행이 원본.
  - 내 버킷 이름 = 서버 `members[is_self].name` 의 버킷, 없으면 `items` 와 같은 버킷(옛 앱이 이름을 안 정했으면 `member`).
  - 언제: 로그인 직후 · 앱으로 돌아올 때 · 앞에 있는 동안 15초마다(v2 만, v3 는 1분에 한 번) · 바꾸고 0.7초 뒤. 오프라인이면 기기에 남겨 두고(`cloudDirty`) 다음에 다시.
  - 기기 기록의 주인 = 처음 로그인한 계정(`UserStore.syncedAccount`, Supabase user id). 다른 계정으로 로그인하면 앞 계정 기록을 새 계정에 합치지 않고 비운 뒤 새 계정 것을 받는다 (베이 부품 등은 아래 기기 기록 동기화가 같은 규칙으로 따로).
- 기기 기록 동기화 (`lib/sync/device_state_sync.dart`, 서버 `docs/supabase-v3-sync.sql`): 계정마다 한 줄 `gunpula_v3_device_state` (data jsonb + revision).
  - data = `{schema: 1, sections: {local_state 키: {항목: {t: 밀리초, v: 값} | {t, d: 1}}}}` (모음은 v 없음). 기기 장부 = `UserStore.deviceSync` (`user.json` 의 `device_sync`: account · revision · dirty · sections, 서버와 같은 모양).
  - 합치기: 항목마다 t 가 큰 쪽, 같으면 서버. 지운 것 = 지움 표시(d, 180일 뒤 버림). 장부와 지금 기록을 비교해 바뀐 항목만 지금 시각으로 적는다 (UserStore 의 쓰기 함수는 그대로). 이 기능 전에 모은 기록은 처음 맞출 때 t = 0 → 두 기기 것의 합집합, 시각이 붙은 변경이 이긴다.
  - 순서: get_device_state → 적기 → 합침 → 기기에 반영(`UserStore.applyLocalState`, 저장 파일 읽기와 같은 길) → 다르면 `save_device_state(p_base_revision)`, `40001` 이면 다시 받아 합치고 재시도(최대 3번). `54000` = 1 MB 넘음. 함수가 없는 서버면 아무것도 안 한다.
  - 언제: 로그인 직후(구매함 동기화가 계정 주인을 정한 뒤) · 앱으로 돌아올 때 · 맞추는 키를 바꾸고 1.5초 뒤(바뀐 게 있을 때만 서버) · 설정 "지금 동기화". 오프라인이면 dirty 로 남기고 1분 뒤 · 다음 번에.
  - 맞추는 키 = `lib/sync/device_state.dart` 의 `builtInDeviceSections`: bbx_owned_parts · bbx_manual_map · bbx_combos · bbx_decks · guide_manual_lit · tag_owned · tag_liked · special_friends · my_channels · dismissed_suggestions · profile_tags · recent_searches · search_counts · trash. 맞추지 않음(기기에만): recent_viewed · photos(아래 사진 되찾기) · profile_images · photo_privacy(서버 표 따로) · friends_seen_at · friend_avatars(캐시) · 알림 상태.
  - **새 local_state 키를 계정에 맞추려면** UserStore 의 toJson / _fromJson 에 키를 넣은 뒤 `builtInDeviceSections` 에 한 줄: `DeviceSection.set(키)`(순서 없는 모음) · `.map(키)`(키마다) · `.records(키, newFirst:)`(id 가진 목록) · `.value(키, empty:)`(통째로, 처음 기본값) · `.recent(키, cap:)`(최근 순서). 맞추는 쪽 코드는 손대지 않는다.
  - 계정: 장부 주인 = 처음 맞춘 계정. 다른 계정으로 로그인하면 맞추는 키를 새 계정 서버 것으로 바꾼다 (통째로 하나인 값 = 채널 · 취향 태그는 그대로). 서버 함수가 없으면 기기 것을 그대로 둔다.
- 내 사진 되찾기 (`lib/sync/photo_restore.dart`): 로그인 · 돌아올 때 `gunpula_v3_get_my_photos` → 목록에 없는 사진을 `restored` 로 넣는다(uploadedTo = 이 계정). 파일은 처음 볼 때 Storage `photos/<uid>/<id>.jpg` → 앱 문서 폴더 photos/ (`PhotoFiles.readOrFetch`). 지우기 · 숨기기는 원래 photo_share 길 (숨기기 전에 먼저 받아 둔다). 서버 목록에서 빠진 사진: 되찾은 것은 빼고, 이 기기에서 찍은 것은 "안 올림"으로. 친구에게 보이기를 끈 사진은 서버에 없어 되찾을 수 없다.
- 테스트는 진짜 서버에 닿지 않는다: `test/support/fake_backend.dart` 의 가짜 서버 · 가짜 로그인. 진짜 계정으로 로그인해 보는 것은 사람만.

## 비밀
- 옛 백업 JSON 의 `github_token` 은 읽자마자 버린다. 저장 · 로그 · 커밋 금지. 백업 파일은 저장소에 넣지 않는다.
- `data/market_secrets.local.json` (Gunpula) 값은 출력하지 않는다.
- Supabase 주소 · anon key 는 `config/supabase.json` 에 커밋한다 — 옛 앱 `app/sync-config.js` 와 같은 **공개용** 값이다 (데이터는 RLS + authenticated 전용 RPC 가 지킨다). `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` 를 주면 그 값이 먼저. service_role key 는 절대 넣지 않는다 (`test/backend_config_test.dart` 가 role=anon 인지 본다).
- 로그인 세션(refresh token)은 `flutter_secure_storage` 에만. 로그 · `user.json` · 백업 파일 · 커밋에 남기지 않는다 (supabase `debug: false`).
- 서명 키(keystore)와 비밀번호는 저장소 밖, GitHub Actions secrets 에만 둔다.

## 폴더 (층 나누기)
위층은 아래층만 부른다: 화면 → 공용 조각 → 규칙 → 데이터.
- `lib/data/` 데이터 — 받기 · 캐시 · 파싱 · 저장만. `catalog`(Gunpula Pages) · `gunpula` · `gundam_atlas` · `tag_atlas` · `blob_store` · `photo_files` · `social_local`.
  - `user_store.dart` = 내 기록 핵심(기록 · 저장 · 동기화) + part `user_store/` (atlas_local · history · trash · profile_local · import). 저장 파일 모양은 `test/user_store_golden_test.dart` 골든이 지킨다.
  - `derive.dart` = 카탈로그 + 내 기록 → 화면 모델, part `derive/` (guide · bbx · worlds · announcements · notifications · profile).
- `lib/logic/` 규칙 — 순수 Dart (위젯 없음): kit_filter · guide_filter · kit_rules(찾기 · 바코드 · 다가오는 날짜) · collection_rules · spend · level_math · friends · announcement_match · sentence_search · bbx_builder · market. 엔진은 `lib/bbx/` · 알림 규칙은 `lib/notifications/` 그대로.
- `lib/api.dart` `Loaders` = 화면이 데이터를 받는 입구 (테스트는 가짜 함수). 앱 전체 상태는 `MarksHost`/`UserStore` · `AccountScope` · `NotifyScope`.
- `lib/widgets/` 공용 조각 — 화면은 묶음 `lib/widgets.dart` 하나만 import. 아래 시트는 `showGpSheet` 로 열고, 고르는 시트는 `GpPickSheet`(제목 · 초기화 · "n개 보기"), 도감 칸은 `TierCell`, 찾기 + 필터 짝은 `KitFind`. 그림 경로(인터넷 · 앱 안 · `local:` 내 사진)는 `images.dart` 한 곳.
- `lib/screens/` 화면 — 맨 위 화면은 글자 머리(a_ … u_) + 파일 맨 위 디자인 가이드 대응표(`tool/make_guide.py` 가 읽는다). 큰 화면은 하위 폴더로: `guide/`(G 도감, 대응표는 `g_guide_view.dart`) · `bbx_builder/`(T 의 part 파일). 화면 안에 JSON 파싱 · HTTP · BlobStore 를 두지 않는다.
- 크기 · 색은 `lib/theme.dart` `Gp` 토큰만: 글자 t11–t24, 아이콘 iXS 12 · iS 16 · iM 20 · iL 24 · iXL 40, 모서리 rSmall · radius · rLarge, 옆 여백 gutter. 따로 둔 값: 상세 빈 칸 그림 · 첫 받기 앱 아이콘 72 · 진행 막대 캡슐 99 · 색 막대 2 · 견본 색 3.

## 작업 방식
- 상태: 앱 전체 한 벌은 위쪽 Host(InheritedWidget) + 저장소 객체(ChangeNotifier), 화면 안 표시는 `setState`. 내 기록 = `MarksHost`/`UserStore`, 계정 · 동기화 · 친구 = `AccountScope`/`Account`.
- 사진 벽(내 정보 · 친구 보기): 내 사진은 기기(앱 문서 폴더 `photos/`, 목록은 `UserStore` local_state `photos`), 친구에게 보이기를 켠 것만 Supabase Storage `photos` 버킷 `<user_id>/<photo_id>.jpg` 로 (`lib/sync/photo_share.dart`). 취향 태그 = v3 `preferences.tags` (+ 기기 `profile_tags`).
- 친구 쪽 2차(`lib/sync/profile_images.dart` · `lib/data/social_local.dart` · 화면 조각 `lib/screens/u_social.dart`):
  - 아바타 · 배경 = 기기 파일 먼저 → Storage `<user_id>/profile/avatar.jpg` · `cover.jpg`, 경로는 v3 `preferences.avatar` · `cover` (+ `_at` 고른 시각, update_profile 은 preferences 를 통째로 바꾸므로 합쳐서 보낸다). `users.avatar` 열(옛 앱 data URL)은 건드리지 않는다. 친구 아바타는 사진 벽의 `avatar_path` 를 기기에 받아 둔다. 못 받으면 첫 글자.
  - 사진 공개 범위(전체 끄기 · 친구별 숨기기) = 서버 표 `gunpula_v3_photo_privacy` · `gunpula_v3_photo_hidden` 이 get_friend_wall 과 Storage 읽기 정책에서 지킨다. 그 SQL 이 없으면: 전체 끄기는 앱이 올린 사진을 내려서 지키고, 친구별 숨기기는 지킬 수 없어 시트에 ⚠.
  - 알 수도 있는 친구 = `gunpula_v3_suggest_friends`(친구의 친구 + 함께 아는 친구 수), 없으면 칸 숨김. × 는 기기에만.
  - 기기 키(local_state): `profile_images` · `photo_privacy` · `dismissed_suggestions`(계정에 맞춤) · `friends_seen_at`(서랍 "새 사진 n") · `friend_avatars`. 다른 계정으로 로그인하면 비운다.
- 서버 SQL 순서 (Supabase SQL Editor): Gunpula `supabase-setup-v3.sql` · `supabase-v3-fix-grants.sql` → 이 저장소 `docs/supabase-v3-photos.sql` → `docs/supabase-v3-social.sql` → `docs/supabase-v3-sync.sql`(기기 기록 · 내 사진 목록). photos SQL 을 다시 돌렸으면 social SQL 도 다시 (Storage 읽기 정책을 social 이 바꿔 쓴다). 안 돌린 것이 있어도 앱은 기기에만 두고 ⚠ / 칸 숨김으로 버틴다.
- 친구 쪽 도감 비교(L-3)는 산 상품 기준 + 친구 사진 수. "손으로 켜기"는 내 기기 기록 행에만 있어(친구가 못 읽음) 친구 쪽엔 안 들어간다.
- 처음 설치(캐시 없음)면 앱 셸 대신 W 화면(`lib/screens/w_first_run_screen.dart`, main.dart `FirstRunGate`): 앱 아이콘 · 데이터 받는 중 · 받은 파일 n/m · MB(`Catalog.filesDone` · `bytesReceived`) · 실패면 다시 시도. 두 번째부터는 캐시로 바로 열고 뒤에서 새로 받는다.
- 아이콘만 있는 화면은 머리 줄 오른쪽 끝에 `HelpButton`(lib/widgets/help.dart, ToolIcon 한 칸) — 누르면 아이콘 + 한 줄씩. 새 아이콘을 넣으면 그 화면 도움말 목록에도 한 줄.
- 무거운 JSON(kits-gundam 9 MB)은 `Isolate.run` 으로 푼다.
- 확인: 경로에 한글이 있어 `flutter analyze` 가 멈춘다 → `dart analyze lib test tool` 0 issues + `flutter test`.
- 커밋은 `v3: …` 로 시작하고, 단계마다 commit + push (origin = hobby-atlas-v3).
- Gunpula 저장소는 다른 세션도 동시에 커밋한다. 거기서 작업할 땐 내 파일만 stage 하고 push 전에 fetch.
