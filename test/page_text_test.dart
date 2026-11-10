// J-5b 예고 원문 번역 — 고를 글 · 페이지 스크립트 결과 읽기 (번역 자체는 기기 ML Kit 라 테스트 밖)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/logic/page_text.dart';

void main() {
  test('일본어가 있는 글만, 앞뒤 빈칸 빼고, 한 번씩', () {
    expect(
      textsToTranslate(['  ガンダムエアリアル  ', 'HG 1/144', '', 'ガンダムエアリアル', '発売日：2026年3月', 'NEWS']),
      ['ガンダムエアリアル', '発売日：2026年3月'],
    );
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
}
