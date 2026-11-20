// 데이터 값 → 화면 이름 (라인 · 종류 · 굿즈 종류 · 세부 시리즈 · 예고 출처). 이름 표는 이 파일 하나 (docs/writing/data-names.md).
// 값 자체는 바꾸지 않는다 — 알림 조건 · 필터 · 조립 라인 · 묶음 키가 옛 값으로 저장 · 비교된다.
// 번역 표(zh/common.dart)의 키는 값이 아니라 표준 한국어 이름이다 (데이터 `스케일` ≠ 숫자 비율 `스케일` = 比例).
import '../l10n/l10n.dart';

/// 값 → 표준 한국어 이름 (docs/terms.md 「상품 종류」 · 「라인 이름」). 표에 없는 값은 그 이름 그대로
const _shown = {
  'No Grade': '무등급',
  'EX': 'EX 모델',
  'MEGA': '메가사이즈',
  'FM': '풀 메카닉스',
  'HAROPLA': '하로프라',
  'UCHG': 'U.C. HARD GRAPH',
  'BMC': '베스트 메카 컬렉션',
  'SDW': 'SDW HEROES',
  'BB': 'BB전사',
  '元祖 SD': '원조 SD건담',
  'ROBOT魂': 'ROBOT혼',
  'METAL ROBOT魂': 'METAL ROBOT혼',
  '超合金': '초합금',
  '超合金の塊': '초합금의 덩어리',
  '超合金魂': '초합금혼',
  'DX超合金': 'DX 초합금',
  '魂 기타': 'TAMASHII NATIONS 기타',
  '魂EFFECT': 'TAMASHII EFFECT',
  'the simple effect': 'THE SIMPLE EFFECT',
  'RE100': 'RE/100',
  'PGU': 'PG UNLEASHED',
  '스케일': '스케일 피규어',
  '미니 · 트레이딩': '미니 · 트레이딩 피규어',
  '인형': '봉제인형',
  '제일복권': '이치방쿠지',
  '포켓프라': '프라모델',
  '미니피규어': '미니피겨',
  '책 · 화보': '도서',
  '아크릴': '아크릴 굿즈',
  '공구 · 재료': '공구 · 도색용품',
  '티켓 · 이벤트': '티켓',
  '런처 · 도구': '런처 · 스타디움',
};

/// 예고 출처(source_name, 일본어로 온다) → 한국어 이름 (docs/terms.md 「출처 이름」)
const _sources = {
  'プレミアムバンダイ': '프리미엄 반다이',
  'コトブキヤショップ': '고토부키야 숍',
  'タカラトミー ポケモン': '타카라토미 포켓몬',
  'ガンダムチャンネル YouTube': 'GUNDAM CHANNEL YouTube',
  'コロコロコミック': '코로코로 코믹',
  'ポケモンフレンダ': '포켓몬 프렌다',
  '電撃オンライン': '전격 온라인',
  '電撃ホビーウェブ': '전격 하비 웹',
  'スタッズ': '스터즈',
};

/// 값의 표준 한국어 이름 (언어와 상관없이 — 같은 이름이 되는 칸을 한 칸으로 모을 때)
String dataName(String value) => _shown[value] ?? value;

/// 화면에 보이는 이름 (고른 언어). 번역이 없으면 그대로 — 데이터라 빠진 번역으로 치지 않는다
String dataLabel(String value) => trData(dataName(value));

/// 예고 출처의 표준 한국어 이름 — 알림 기록에 남겨 두면 언어를 바꿔도 따라 바뀐다 (NoticePart.value)
String sourceName(String source) => _sources[source] ?? source;

/// 예고 출처의 화면 이름 (고른 언어). 표에 없는 출처는 받은 그대로
String sourceLabel(String source) => trData(sourceName(source));
