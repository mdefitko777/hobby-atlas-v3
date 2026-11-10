// 재판매(再販) — Gunpula data/atlas/restocks.json 을 kit_id 별로 묶는다. 순수 Dart.
// 모양 (schema 1): {schema, updated_at, generated_at, baseline, history_months, kinds, counts, sources, events: [...], by_kit: {kit_id: [번호]}}
//   event = {kit_id, date, kind, source_url, announced_at, seen, source, title, quiet?, date_estimated?, previous_date?}
//   date = 'YYYY-MM'(발송 달) 또는 'YYYY-MM-DD', kind = pb_resale · retail_resale · tamashii_resale · lottery
//   quiet = 지난 것 · 처음 모을 때 쌓인 것 → 알리지 않고 달력에도 넣지 않는다 (상세의 재판매 기록에는 보인다)
// by_kit 은 events 의 번호 목록이라 읽지 않고 events 에서 다시 묶는다.
// 파일이 없으면(404) 빈 묶음 → 상세 · 캘린더의 재판매 칸이 모두 숨는다.
import '../format.dart' show monthKey;
import '../json_util.dart';
import '../l10n/l10n.dart';

/// 보조 파일 이름 (lib/data/gunpula.dart auxFiles)
const restocksFile = 'atlas/restocks.json';

/// 재판매 종류 → 화면 글자
const restockKindLabels = {
  'pb_resale': 'PB 재판매',
  'retail_resale': '일반 재판매',
  'tamashii_resale': '혼 재판매',
  'lottery': '추첨',
};

String restockKindLabel(String kind) => tr(restockKindLabels[kind] ?? '재판매');

/// 재판매 소식 한 건
class RestockEvent {
  const RestockEvent({
    required this.kitId,
    required this.date,
    this.kind = '',
    this.sourceUrl = '',
    this.announcedAt = '',
    this.title = '',
    this.quiet = false,
    this.dateEstimated = false,
  });

  final String kitId;

  /// 'YYYY-MM' 또는 'YYYY-MM-DD'
  final String date;
  final String kind;
  final String sourceUrl;

  /// 소식이 나온 때 (ISO, 없으면 빈 글자)
  final String announcedAt;

  /// 출처의 원래 제목 (예: 「ＨＧ … 【再販】【３次：２０２７年１月発送】」)
  final String title;

  /// 지난 것 · 처음 모을 때 쌓인 것 — 알리지 않고 달력에도 넣지 않는다
  final bool quiet;

  /// 날짜를 제목 등에서 짐작했다 (화면에 "쯤")
  final bool dateEstimated;

  String get month => date.substring(0, 7);

  /// 하루까지 정해졌으면 그날, 아니면 null (달력의 "날짜 미정")
  int? get day => date.length >= 10 ? int.tryParse(date.substring(8, 10)) : null;

  String get label => restockKindLabel(kind);

  static RestockEvent? fromJson(Object? raw) {
    final m = jMap(raw);
    final id = jStr(m['kit_id']);
    final date = RegExp(r'^\d{4}-\d{2}(-\d{2})?').firstMatch(jStr(m['date']))?.group(0) ?? '';
    if (id.isEmpty || date.isEmpty) return null;
    final url = jStr(m['source_url']);
    return RestockEvent(
      kitId: id,
      date: date,
      kind: jStr(m['kind']),
      sourceUrl: url.startsWith('http') ? url : '',
      announcedAt: jStr(m['announced_at']),
      title: jStr(m['title']),
      quiet: m['quiet'] == true,
      dateEstimated: m['date_estimated'] == true,
    );
  }
}

/// kit_id → 재판매 소식 (날짜 새것부터)
class RestockIndex {
  const RestockIndex([this.byKit = const {}]);

  static const empty = RestockIndex();

  final Map<String, List<RestockEvent>> byKit;

  bool get isEmpty => byKit.isEmpty;

  List<RestockEvent> of(String kitId) => byKit[kitId] ?? const [];

  /// [ids] 중 [month] 에 재판매가 있는 소식 (quiet 빼고 — 달력)
  List<RestockEvent> inMonth(Iterable<String> ids, DateTime month) {
    final ym = monthKey(month);
    return [
      for (final id in ids)
        for (final e in of(id))
          if (e.month == ym && !e.quiet) e,
    ];
  }

  /// 파일 → 묶음. 목록 그대로 · {events: […]} · {restocks: […]} 셋 다 받는다. 같은 (상품 · 날짜 · 종류)는 한 번만
  static RestockIndex parse(Object? json) {
    final list = json is List
        ? json
        : jList(jMap(json)['events']).isNotEmpty
        ? jList(jMap(json)['events'])
        : jList(jMap(json)['restocks']);
    final out = <String, List<RestockEvent>>{};
    final seen = <String>{};
    for (final raw in list) {
      final e = RestockEvent.fromJson(raw);
      if (e == null || !seen.add('${e.kitId}|${e.date}|${e.kind}')) continue;
      (out[e.kitId] ??= []).add(e);
    }
    for (final l in out.values) {
      l.sort((a, b) => b.date.compareTo(a.date));
    }
    return RestockIndex(out);
  }
}
