// 데이터 값 → 화면 이름 (lib/logic/data_labels.dart) · 그 이름을 쓰는 필터 · 날짜 꼬리표 (kit_filter · kit_rules)
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/l10n/zh_text.dart';
import 'package:hobby_atlas/logic/data_labels.dart';
import 'package:hobby_atlas/logic/kit_filter.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/notify_models.dart' show NoticePart;

final _hangul = RegExp(r'[가-힣]');

void main() {
  tearDown(() => L10n.debugSet(AppLang.ko));

  test('한국어 화면: 값 → 표준 이름, 표에 없는 값은 그대로', () {
    expect(dataLabel('No Grade'), '무등급');
    expect(dataLabel('스케일'), '스케일 피규어');
    expect(dataLabel('제일복권'), '이치방쿠지');
    expect(dataLabel('超合金の塊'), '초합금의 덩어리');
    expect(dataLabel('HG'), 'HG');
    expect(dataLabel('처음 보는 값'), '처음 보는 값');
    expect(dataName('인형'), dataName('봉제인형'));
  });

  test('중국어 화면: 표준 이름의 번역, 없는 값은 그대로 (빠진 번역으로 치지 않음)', () {
    L10n.debugSet(AppLang.zh);
    missingZh.clear();
    expect(dataLabel('제일복권'), '一番赏');
    expect(dataLabel('인형'), '毛绒玩偶');
    expect(dataLabel('HG'), 'HG');
    expect(dataLabel('처음 보는 값'), '처음 보는 값');
    expect(missingZh, isEmpty);
  });

  test('표준 이름은 모두 번역 표에 있다 (zh/common.dart)', () {
    const values = [
      'No Grade', 'EX', 'MEGA', 'FM', 'HAROPLA', 'BMC', 'BB', '元祖 SD', 'ROBOT魂', 'METAL ROBOT魂', '超合金', //
      '超合金の塊', '超合金魂', '魂 기타', '스케일', '미니 · 트레이딩', '인형', '제일복권', '포켓프라', '미니피규어', //
      '책 · 화보', '아크릴', '공구 · 재료', '티켓 · 이벤트', '런처 · 도구',
    ];
    expect([
      for (final v in values)
        if (_hangul.hasMatch(dataName(v)) && !zhText.containsKey(dataName(v))) dataName(v),
    ], isEmpty);
  });

  test('예고 출처: 일본어 이름 → 한국어 · 중국어, 표에 없는 출처는 그대로', () {
    expect(sourceLabel('プレミアムバンダイ'), '프리미엄 반다이');
    expect(sourceLabel('電撃ホビーウェブ'), '전격 하비 웹');
    expect(sourceLabel('どこかのサイト'), 'どこかのサイト');
    L10n.debugSet(AppLang.zh);
    expect(_hangul.hasMatch(sourceLabel('コトブキヤショップ')), isFalse);
    // 알림 기록에는 언어 없는 표준 이름 — 언어를 바꾸면 보이는 글이 따라 바뀐다
    expect(sourceName('プレミアムバンダイ'), '프리미엄 반다이');
    expect(const NoticePart.value('프리미엄 반다이').shown, 'Premium Bandai');
  });

  test('필터 한 줄: 라인 · 종류는 표준 이름 · 엔 가격대는 원과 같은 모양 · 기간은 붙여 쓴다', () {
    final f = KitFilter(lines: {'No Grade'}, types: {'제일복권'}, price: PriceBand.low, currency: PriceCurrency.jpy);
    expect(f.labels, ['이치방쿠지', '무등급', '3천엔 이하']);
    expect(PriceBand.high.shortIn(PriceCurrency.jpy), '¥1만 이상');
    expect(SaleState.base.label, '건담베이스 · 이벤트');
    expect((periodLabel('2023-01', ''), periodLabel('', '2024-06')), ('2023.01부터', '2024.06까지'));
    L10n.debugSet(AppLang.zh);
    expect(f.labels, ['一番赏', '无等级', '3千日元以下']);
    expect((periodLabel('2023-01', ''), periodLabel('', '2024-06')), ('2023.01 起', '截至 2024.06'));
  });

  test('PB 예약 마감이 오늘이면 「PB 오늘 마감」', () {
    fixedNow = DateTime(2026, 11, 20, 9);
    addTearDown(() => fixedNow = null);
    final k = Kit.fromSlim({'id': 'pb', 'name': 'HG', 'pbCloses': '2026-11-20'}, recentSince: '', monthPrefix: '');
    expect(upcomingOf(k)?.label, 'PB 오늘 마감');
  });
}
