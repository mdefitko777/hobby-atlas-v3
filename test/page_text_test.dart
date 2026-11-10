// J-5b 예고 원문 번역 — 고를 글 · 페이지 스크립트 결과 읽기 (번역 자체는 기기 ML Kit 라 테스트 밖)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/logic/page_text.dart';

void main() {
  test('일본어가 있는 글만, 앞뒤 빈칸 빼고, 한 번씩', () {
    expect(textsToTranslate(['  ガンダムエアリアル  ', 'HG 1/144', '', 'ガンダムエアリアル', '発売日：2026年3月', 'NEWS']), [
      'ガンダムエアリアル',
      '発売日：2026年3月',
    ]);
    expect(textsToTranslate(List.generate(1000, (i) => '商品$i'), max: 800), hasLength(800));
  });

  test('안드로이드는 JS 문자열을 한 번 더 JSON 으로 감싸 준다', () {
    final once = jsonEncode(['ガンダム', 'ニュース']);
    expect(decodeTextList(once), ['ガンダム', 'ニュース']);
    expect(decodeTextList(jsonEncode(once)), ['ガンダム', 'ニュース']);
    expect(decodeTextList(null), isEmpty);
    expect(decodeTextList('not json'), isEmpty);
  });

  test('바꿔 끼우는 스크립트에 번역표가 그대로 들어간다 (따옴표 · 줄바꿈도 안전하게)', () {
    final js = applyTranslationsJs({'「予約開始」': '"예약 시작"\n'});
    expect(js, contains(jsonEncode({'「予約開始」': '"예약 시작"\n'})));
    expect(collectTextsJs, contains('createTreeWalker'));
    expect(restoreTextsJs, contains('orig'));
  });

  test(r'번역 안의 $& · $$ 를 String.replace 가 바꾸지 않게 함수로 넣는다', () {
    final table = {r'置換 $& を使う': r'치환 $& 을 사용 · 가격 $$'};
    final js = applyTranslationsJs(table);
    expect(js, contains(jsonEncode(table)), reason: r'번역표의 $ 는 JSON 안에 그대로');
    expect(js, contains('function () { return m[k]; }'));
    expect(js, isNot(contains('o.replace(k, m[k])')), reason: '글로 넣으면 대체 패턴으로 읽힌다');
    // 스크립트 틀(번역표 밖)에는 $ 가 없다 — Dart 글이 r 이 아니라 넣으면 끼워 넣기로 읽힌다
    expect(js.replaceFirst(jsonEncode(table), ''), isNot(contains(r'$')));
  });

  test('원문 안에서 넘긴 페이지(SPA): 떨어진 조각은 버리고, 페이지가 바꾼 조각은 새 원문으로', () {
    expect(collectTextsJs, contains('isConnected'));
    expect(collectTextsJs, contains('cur'));
    // 모은 뒤 페이지가 바꾼 조각은 번역 · 되돌리기가 덮어쓰지 않는다
    expect(applyTranslationsJs(const {}), contains('nodeValue !== t.cur[i]'));
    expect(restoreTextsJs, contains('nodeValue !== t.cur[i]'));
  });
}
