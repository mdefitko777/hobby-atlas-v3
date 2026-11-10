// 점검(2026-11-11): 한국어 이름에 전각 영숫자(ＨＷＳ Ｖｅｒ．Ｋａ · ［Ｕ.Ｃ.００８８］ · Ｍｋ－ＩＩＩ)가 남아 있어
// 'hws' · 'ver.ka' · '0088' 로 찾으면 안 나왔다 → 찾기 글자(blob)와 검색어를 둘 다 반각으로 접는다
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/format.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/models.dart';

Kit _kit(String ko, {String ja = ''}) {
  final doc = {
    'kits': [
      {
        'kit_id': 'mg-mg-1-100-hws-ver-ka-4549660148326000',
        'franchise': 'gundam',
        'names': {'ko': ko, 'ja': ja},
        'grade_code': 'MG',
        'images': {'box_art_url': ''},
      },
    ],
  };
  return Kit.fromSlim(mapKitsJob({'raw': jsonEncode(doc)}).single, recentSince: '', monthPrefix: '2026-11');
}

void main() {
  test('halfWidth: 전각 영숫자 · 기호 · 빈칸만 반각, CJK 괄호는 그대로', () {
    expect(halfWidth('ＭＧ 1/100 ν건담 ＨＷＳ Ｖｅｒ．Ｋａ'), 'MG 1/100 ν건담 HWS Ver.Ka');
    expect(halfWidth('제타건담［Ｕ.Ｃ.００８８］'), '제타건담[U.C.0088]');
    expect(halfWidth('건담Ｍｋ－ＩＩＩ　【한정】「세트」'), '건담Mk-III 【한정】「세트」');
  });

  test('전각 이름도 반각 검색어로 찾힌다 (이름 · 일본어 이름 모두)', () {
    final k = _kit('ＭＧ 1/100 ν건담 ＨＷＳ Ｖｅｒ．Ｋａ', ja: 'ＨＧ 1/144 ゼータガンダム［Ｕ.Ｃ.００８８］');
    expect(k.name, 'ＭＧ 1/100 ν건담 ＨＷＳ Ｖｅｒ．Ｋａ', reason: '보이는 이름은 그대로 (데이터 쪽에서 고친다)');
    for (final q in ['hws', 'ver.ka', 'HWS Ver.Ka', '0088', 'u.c.0088', 'mg ν건담']) {
      expect(kitMatches(k, q), isTrue, reason: q);
    }
    expect(kitMatches(k, 'zaku'), isFalse);
  });

  test('전각으로 친 검색어도 반각 이름을 찾는다', () {
    final k = _kit('HG 1/144 건담Mk-III');
    expect(kitMatches(k, 'ＨＧ'), isTrue);
    expect(kitMatches(k, 'Ｍｋ－ＩＩＩ'), isTrue);
    expect(kitMatches(k, '건담　mk-iii'), isTrue, reason: '전각 빈칸 = 낱말 사이');
  });

  test('blob 이 없는 가짜 상품도 같은 규칙', () {
    final k = Kit.fromSlim({'id': 'x', 'name': 'ＨＧ 건담Ｍｋ－ＩＩＩ', 'line': 'HG'}, recentSince: '', monthPrefix: '');
    expect(k.blob, isEmpty);
    expect(kitMatches(k, 'mk-iii'), isTrue);
  });
}
