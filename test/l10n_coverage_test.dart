// 중국어 화면 번역 표 검사 — 코드의 tr('…') · trf('…') 글이 모두 번역됐나, 번역끼리 어긋나지 않나.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/l10n/zh_text.dart';
import 'package:hobby_atlas/models.dart';

final _hangul = RegExp(r'[가-힣]');
final _call = RegExp(r"""\btrf?\(\s*'((?:[^'\\\n]|\\.)*)'""");
final _slot = RegExp(r'\{(\w+)\}');

Set<String> _slots(String s) => {for (final m in _slot.allMatches(s)) m[1]!};

void main() {
  test('코드에서 tr · trf 로 감싼 한국어 글은 모두 번역 표에 있다', () {
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final code = f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');
      for (final m in _call.allMatches(code)) {
        final ko = m[1]!.replaceAll(r"\'", "'");
        if (_hangul.hasMatch(ko) && !zhText.containsKey(ko)) missing.add('${f.path}: $ko');
      }
    }
    expect(missing, isEmpty, reason: '번역 표(lib/l10n/zh/*.dart)에 없는 글');
  });

  test('번역에는 한글이 없고, 값 자리 {이름} 이 원문과 같다', () {
    final bad = <String>[];
    zhText.forEach((ko, zh) {
      if (_hangul.hasMatch(zh)) bad.add('한글이 남음: $ko → $zh');
      if (_slots(ko).difference(_slots(zh)).isNotEmpty || _slots(zh).difference(_slots(ko)).isNotEmpty) {
        bad.add('자리가 다름: $ko → $zh');
      }
    });
    expect(bad, isEmpty);
  });

  test('같은 한국어는 어느 묶음에서나 같은 중국어', () {
    final seen = <String, (String, String)>{};
    final clash = <String>[];
    zhGroups.forEach((group, map) {
      map.forEach((ko, zh) {
        final before = seen[ko];
        if (before != null && before.$2 != zh) clash.add('$ko: ${before.$1}=${before.$2} · $group=$zh');
        seen[ko] = (group, zh);
      });
    });
    expect(clash, isEmpty);
  });

  test('언어를 바꾸면 tr · 상품 이름 · 작품 이름이 따라간다', () {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    const kit = Kit(
      id: 'k',
      franchiseId: 'gundam',
      name: '사자비',
      nameZh: '沙扎比',
      nameJa: 'サザビー',
      series: '역습의 샤아',
      seriesZh: '逆袭的夏亚',
      line: 'RG',
      type: '프라모델',
      scale: '1/144',
      universe: 'uc',
      date: '2019-11',
      priceJpy: 4950,
      image: '',
      gallery: [],
      limited: false,
      pb: false,
      status: CollectStatus.none,
      wantedQty: 0,
      recent: false,
      month: false,
      market: null,
      keywords: [],
    );
    L10n.debugSet(AppLang.ko);
    expect((tr('구매함'), kit.name, kit.seriesLabel), ('구매함', '사자비', '역습의 샤아'));
    L10n.debugSet(AppLang.zh);
    expect((tr('구매함'), kit.name, kit.seriesLabel), ('已购', '沙扎比', '逆袭的夏亚'));
    expect(trf('새 상품 {n}개', {'n': 3}), contains('3'));
    expect(kit.series, '역습의 샤아', reason: '묶기 · 비교에 쓰는 값은 한국어 그대로');
  });
}
