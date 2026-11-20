# 데이터 이름 · 数据名称

Gunpula 가 만든 데이터에서 오는 이름 — 라인 · 종류 · 굿즈 종류 · 베이 상품 형태 · 시리즈 · 작품 · 묶음 · 상품 이름 · 출처 — 이 한국어 · 중국어 화면에서 어떻게 보이고, 어디서 오나.
말 자체는 [terms.md](../terms.md) 「상품 종류」 · 「라인 이름」 · 「종류 · 세대 묶음 이름」 · 「출처 이름」 표.

## 큰 규칙: 값은 그대로, 보일 때만 표준 이름
코드가 비교 · 저장하는 값은 옛 한국어 모양 그대로 둔다. 바꾸면 이미 저장된 알림 조건 · 필터 · 조립 여부 · OCR · 설명으로 찾기 꼬리표가 어긋난다.

| 값 | 어디서 비교 · 저장하나 (바꾸지 않는 까닭) |
| --- | --- |
| `k.line` (`lineLabel` · `_lineLabels`) | KitFilter.lines · 알림 조건(feed_rules · notify_models) · build_status 조립 라인 · lineCovers 키 · category_browse 묶음 키 · sentence_search · OCR |
| `k.type` (`typeLabel`) | KitFilter.types · 묶음 types · cellKind |
| `k.goodsKind` (`goodsKindLabels`) | KitFilter.goodsKinds · 묶음 키 · 카탈로그 캐시(models.dart toJson) |
| `k.subline` (`cleanSubline` · `_beyForms`) | 세부 시리즈 줄 · 베이 종류 칸 키 |

화면에 보일 때는 한 곳 `dataLabel(값)` (`lib/logic/data_labels.dart`):

```dart
// 값 → 표준 한국어 이름 → 중국어 화면이면 번역 (번역 표에 없으면 그대로, 빠진 번역으로 치지 않음)
String dataLabel(String value) => trData(_shown[value] ?? value);
```

- `_shown` = terms.md 의 「데이터 값 → 한국어」 (`No Grade` → `무등급`, `제일복권` → `이치방쿠지`, `인형` → `봉제인형`, `스케일` → `스케일 피규어`, `RE100` → `RE/100` …). 옛 `category_browse.dart` `_labels` 도 여기로.
- 번역 표(zh)의 키는 **표준 한국어 이름** (`'스케일 피규어': '比例手办'`) — 값(`스케일`)이 아니다. 그래서 숫자 비율 `스케일` = `比例` 와 부딪히지 않는다.
- `tr(k.line)` · `tr(k.type)` · `tr(k.goodsKind)` · `lineGroupLabel` · `KitFilter.labels` 의 `map(tr)` 은 모두 `dataLabel` 로.
- grades.json 의 새 등급(`useGradeNames`): 값 = name_ko, 번역 = name_zh (`gradeZhNames` 가 번역 표에 더한다). `_shown` 에 없으면 받은 이름 그대로.
- 묶음 제목(`_Sec.title`) · 세대 묶음 이름(`worldSectionOf`)은 비교하지 않는 글이라 표준 이름을 바로 쓰고 `tr`.

## 이름 표
| 무엇 | 한국어 화면 | 중국어 화면 | Gunpula 어디서 |
| --- | --- | --- | --- |
| 상품 이름 `k.name` | names.ko → ja → en → zh | `k.nameZh`: names.zh (한글이 든 zh 는 건너뜀) → ja → en → ko | `split/kits-<채널>.json` `names` (zh 는 `apply_zh_names.mjs`) |
| 일본어 이름 `k.nameJa` | 상세 공식 정보 시트 `일본어 이름` 한 줄 · 복사 · 시세 찾기 | 같음 (`日文名`) | names.ja → en → ko |
| 라인 `k.line` | `dataLabel` | `dataLabel` | 등급 코드 → `_lineLabels` / grades.json name_ko |
| 종류 `k.type` · 굿즈 종류 `k.goodsKind` | `dataLabel` | `dataLabel` | `typeLabel` (등급 분류 + 이름 낱말) · `goods_kind` → `goodsKindLabels` |
| 세부 시리즈 `k.subline` | `dataLabel` (HGUC · ver. A.N.I.M.E. · 초합금혼 · 스타터 …) | `dataLabel` | `subline` → `cleanSubline` |
| 작품 `k.seriesLabel` | series_labels.ko, 건담은 칸 · 제목 · 알림 · 친구 줄에서 `shortWorkName` | series_labels.zh → 번역 표 | `series_labels` |
| 채널 | `tr(channelOf(id).label)` | 번역 표 | `lib/channels.dart` |
| 시대 · 작품 · 기체 (건담 도감) | `atlasName` ko → en → ja | zh → zh_tw → en → ja | gundam atlas `names` |
| 화 제목 (작품 도감) | ko → en, 없으면 `{n}화` 만 (일본어 제목 쓰지 않음) | zh → en, 없으면 `第 {n} 集` | gundam atlas `title_ja` · `title_en` (+ ko · zh 가 생기면) |
| 세계관 묶음 (포켓몬 세대 · Fate 작품 …) | atlas-groups `names.ko` | `names.zh` | `atlas-groups.json` |
| 베이 부품 · 상자 | bbx-database names.ko → en → ja | names.zh → en → ja | `bbx-database` (`PartMold.name`) |
| 태그(메자스타 · 프렌다) | names.ko → en (일본판 `local` 은 찾기에만, 부제에 쓰지 않음) | names.zh → en | `atlas/mezastar-*.json` · `frienda` |
| 태그 변형(variant · art) | ko 가 있을 때만 | zh 가 있을 때만 (일본어뿐이면 감춤) | frienda 데이터 |
| 예고 제목 | names.ko → ja | names.zh → ja | `announcements.json` (지금 475개 모두 ja 뿐 — Gunpula 할 일) |
| 예고 출처 `a.source` | `sourceLabel` (terms.md 「출처 이름」) | `sourceLabel` 의 번역 | `source_name` (일본어) |
| 브랜드 | `프리미엄 반다이` · `반다이 가샤폰` … | 번역 표 (`Premium Bandai` · `万代扭蛋`) | `_brandBySource` |

이름을 고르는 순서의 까닭: 상품 이름은 공식 이름이 일본어라 ko 다음 ja. 부품 · 기체 · 화 제목처럼 고유 이름은 en(로마자)이 가나보다 읽기 쉬워 en 먼저. 중국어 화면은 Gunpula 가 ko 를 zh 칸에 그대로 복사한 상품(포켓몬스토어 한국 · 닌텐도 한국)이 있어 한글이 든 zh 는 건너뛴다.

## 데이터에서 다듬는 것 (lib/data/gunpula.dart)
- 상품 이름 앞의 가게 말머리 `[예약 판매]` · `[사전 예약]` · `[예약판매]` 는 뺀다 (예약 상태는 앱이 따로 보여 준다).
- 베이 상품 형태 `_beyForms`: Starter · Booster · Random Booster · Set · Tool (2026-11-20 데이터에 이 다섯뿐). 타카라토미의 ダブルスターター · カラーチョイスブースター 가 데이터에 오면 `더블 스타터` · `컬러 초이스 부스터` 를 terms.md 에 먼저 넣는다.
- 묶음 types 의 죽은 값(`툴` — typeLabel 이 내지 않는다)은 쓰지 않는다.

## 하지 말 것
- `_lineLabels` · `goodsKindLabels` · `_beyForms` 의 **값**을 표준 이름으로 바꾸기 (저장된 조건이 깨진다 — 표준 이름은 `_shown` 에).
- 데이터 값을 `tr` 로 찾기 (`trData` / `dataLabel`).
- 화면마다 따로 이름 표 만들기 (이름 표는 `data_labels.dart` 하나, 번역은 `zh/common.dart`).
- 한국어 화면에서 일본어 데이터를 가나 그대로 부제 · 꼬리표에 넣기 (찾기용 값은 괜찮다).

## Gunpula 쪽 할 일 (앱이 못 고침)
- 포켓몬 1,941 · 닌텐도 207 상품의 names.zh 가 한국어 복사본 → `apply_zh_names` 가 `pokemon_store_kr` · `nintendo_kr` 출처도 번역.
- `announcements.json` 475개 names.ko · zh 없음.
- Fate 146 상품 names.ko 가 일본어.
- atlas-groups `pokemon_general` 「여러 세대 포켓몬 굿즈」 · `pokemon_common` 「포켓몬 공통 굿즈」 거의 같은 이름 → 하나로.

## 글이 있는 파일
`lib/logic/data_labels.dart`(만들 것) · `lib/logic/category_browse.dart` · `lib/data/gunpula.dart` · `lib/data/derive/announcements.dart` · `lib/data/gundam_atlas.dart` · `lib/data/tag_atlas.dart` · `lib/bbx/parts.dart` · 번역 `lib/l10n/zh/common.dart` (데이터 표준 이름) · `browse.dart` (묶음 이름) · `catalog.dart` (브랜드 · amiibo 시리즈).
