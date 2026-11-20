// 상품 이름 고르기 (lib/data/gunpula.dart mapKitsJob) — 가게 예약 말머리 빼기 · 한글이 든 zh 건너뛰기 (docs/writing/data-names.md)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/json_util.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/models.dart';

Map<String, Object?> _rec(String id, Map<String, String> names) => {
  'kit_id': id,
  'franchise': 'pokemon',
  'grade_code': 'POKE_GOODS',
  'names': names,
  'source_urls': const <String>[],
  'source_refs': const <Object>[],
};

void main() {
  final slim = mapKitsJob({
    'raw': jsonEncode({
      'kits': [
        // 포켓몬스토어 한국: Gunpula 가 ko 를 zh 칸에 그대로 옮겼다
        _rec('kr-copy', {'ko': '[예약 판매] 피카츄 봉제인형', 'zh': '[예약 판매] 피카츄 봉제인형', 'ja': 'ピカチュウ ぬいぐるみ'}),
        _rec('zh-ok', {'ko': '[사전 예약]이브이 피규어', 'zh': '伊布 手办', 'ja': 'イーブイ フィギュア'}),
        _rec('ko-only', {'ko': '[예약판매] 몬스터볼 쿠션', 'zh': '[예약판매] 몬스터볼 쿠션'}),
        _rec('ja-only', {'ja': 'ゲンガー マスコット'}),
      ],
    }),
  });
  final kits = {for (final m in slim) jStr(m['id']): Kit.fromSlim(m, recentSince: '', monthPrefix: '2026-11')};
  tearDown(() => L10n.debugSet(AppLang.ko));

  test('한국어 이름: 가게 예약 말머리를 빼고 ko → ja → en → zh', () {
    expect(kits['kr-copy']!.name, '피카츄 봉제인형');
    expect(kits['zh-ok']!.name, '이브이 피규어');
    expect(kits['ko-only']!.name, '몬스터볼 쿠션');
    expect(kits['ja-only']!.name, 'ゲンガー マスコット');
  });

  test('중국어 이름: 한글이 든 zh 는 없는 것으로 치고 ja → en → ko', () {
    L10n.debugSet(AppLang.zh);
    expect(kits['kr-copy']!.name, 'ピカチュウ ぬいぐるみ');
    expect(kits['zh-ok']!.name, '伊布 手办');
    expect(kits['ko-only']!.name, '몬스터볼 쿠션'); // 다른 이름이 없으면 한국어라도
    expect(kits['ja-only']!.name, 'ゲンガー マスコット');
  });
}
