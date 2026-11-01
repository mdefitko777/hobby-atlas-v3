// lib/sync/collection_merge.dart ↔ 옛 Gunpula app/collection-store.js: 같은 입력에 같은 결과인지.
// 시험 값(test/fixtures/collection_store_js_vectors.json)은 tool/gen_collection_vectors.mjs 가 JS 로 만든 것
// (별칭 버킷 · 냐아 · 같은 시각 · +09:00 · 이상한 수량/가격 문자열 · 모르는 상태 · 옛 items 모양 포함).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/sync/collection_merge.dart';

void main() {
  final cases = jsonDecode(File('test/fixtures/collection_store_js_vectors.json').readAsStringSync()) as List;

  test('시험 값 ${cases.length}개가 있다', () => expect(cases.length, greaterThanOrEqualTo(50)));

  for (final (i, c) in cases.indexed) {
    final m = c as Map<String, Object?>;
    test('#$i (나 = ${m['self']}) normalize · merge · mergeTimestampedMap', () {
      final o = CollectionOptions.forSelf(m['self']! as String);
      expect(jsonEncode(_sorted(normalizeCollection(m['local'], o))), jsonEncode(_sorted(m['norm'])));
      expect(jsonEncode(_sorted(mergeCollectionState(m['local'], m['remote'], o))), jsonEncode(_sorted(m['merged'])));
      expect(jsonEncode(_sorted(mergeTimestampedMap(m['ol'], m['or']))), jsonEncode(_sorted(m['mtm'])));
    });
  }
}

/// 키 순서만 맞춘다 (배열 순서는 그대로 비교 — owned/wanted 순서도 JS 와 같아야 한다)
Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final x in v) _sorted(x)];
  if (v is double && v == v.truncateToDouble()) return v.toInt();
  return v;
}
