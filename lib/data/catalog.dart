// Gunpula 상품 카탈로그 — 기기 캐시를 먼저 보여 주고, 뒤에서 GitHub Pages 의 새 데이터를 받는다.
//   1) split/manifest.json (176 B) 의 updated_at · total 이 같으면 아무것도 받지 않는다
//   2) 다르면 보조 파일 9개 → split/kits-<채널>.json 5개를 받아 compute() 에서 가벼운 모양으로 바꿔 저장
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../json_util.dart';
import '../models.dart';
import 'blob_store.dart';
import 'gunpula.dart';
import 'user_store.dart';

enum CatalogPhase { empty, loading, ready, error }

class Catalog extends ChangeNotifier {
  Catalog._() {
    UserStore.instance.listPrice = listPriceKrw; // 구매가를 안 적은 상품 = 정가 × 환율
  }
  static final instance = Catalog._();

  static const _kitsKey = 'catalog_kits.json';
  static const _metaKey = 'catalog_meta.json';

  /// 상품 매핑 규칙(lib/data/gunpula.dart)을 바꾸면 +1 → 기기 캐시를 버리고 다시 받아 정리한다
  static const mapVersion = 3;

  CatalogPhase phase = CatalogPhase.empty;
  String error = '';

  /// 첫 다운로드 중 진행 문구 ("건담 받는 중 …")
  String progress = '';

  /// 새 데이터를 받을 때마다 +1 (앱 셸이 화면을 다시 불러온다)
  int version = 0;

  List<Kit> kits = const [];
  Map<String, Kit> byId = const {};
  Map<String, Object?> manifest = const {};
  List<Map<String, Object?>> _slim = const [];
  final Map<String, Object?> _aux = {};

  /// 최근 추가 = 이 날짜 이후 처음 들어온 상품 (데이터의 가장 새 날짜 기준 3일)
  String recentSince = '';
  String recentUntil = '';

  /// 데이터 기준일 (manifest updated_at)
  String get updatedAt => manifest['updated_at'] is String ? manifest['updated_at']! as String : '';

  Future<void>? _loading;
  bool _refreshing = false;

  /// 화면이 데이터를 쓰기 전에 기다린다. 캐시가 있으면 바로, 없으면 첫 다운로드가 끝날 때까지.
  Future<void> ensureLoaded() async {
    if (kits.isNotEmpty) return;
    await (_loading ??= _start());
    if (kits.isEmpty) {
      _loading = null; // 다시 시도할 수 있게
      throw CatalogException(error.isEmpty ? '상품 데이터를 받지 못했어요.' : error);
    }
  }

  Future<void> _start() async {
    await _loadCache();
    if (kits.isEmpty) {
      await refresh();
    } else {
      // 캐시로 먼저 보여 주고 뒤에서 새로 받는다
      refresh().ignore();
    }
  }

  Future<void> _loadCache() async {
    final meta = await BlobStore.read(_metaKey);
    final slim = await BlobStore.read(_kitsKey);
    if (meta == null || slim == null) return;
    try {
      // 예전 규칙으로 정리한 캐시 (예: 굿즈가 전부 가샤폰이던 때) → 쓰지 않고 새로 받는다
      if ((jsonDecode(meta) as Map<String, Object?>)['map_version'] != mapVersion) return;
      manifest = (jsonDecode(meta) as Map<String, Object?>)['manifest'] as Map<String, Object?>? ?? const {};
      _slim = await compute(_decodeSlim, slim);
      _rebuild();
    } on Object catch (e) {
      debugPrint('[catalog] 캐시를 못 읽음: $e');
    }
  }

  /// 테스트: 네트워크 없이 실제 모양의 데이터를 바로 넣는다
  @visibleForTesting
  void debugSet({required List<Map<String, Object?>> slim, required Map<String, Object?> aux}) {
    _slim = slim;
    _aux
      ..clear()
      ..addAll(aux);
    _rebuild();
  }

  /// 보조 파일(JSON) — 필요한 화면이 처음 부를 때 푼다
  Future<Object?> aux(String file) async {
    if (_aux.containsKey(file)) return _aux[file];
    final text = await BlobStore.read('aux_$file');
    Object? v;
    if (text != null) {
      try {
        v = jsonDecode(text);
      } on FormatException {
        v = null;
      }
    }
    if (v == null) {
      // 웹 미리보기처럼 캐시가 없으면 바로 받는다
      final t = await _get('data/$file');
      if (t != null) v = jsonDecode(t);
    }
    return _aux[file] = v;
  }

  /// 새 데이터 확인. [force] = manifest 가 같아도 다시 받기 (설정 › 지금 새로 받기)
  Future<bool> refresh({bool force = false}) async {
    if (_refreshing) return false;
    _refreshing = true;
    if (kits.isEmpty) {
      phase = CatalogPhase.loading;
      progress = '새 데이터 확인 중';
      notifyListeners();
    }
    try {
      final mText = await _get('data/split/manifest.json');
      if (mText == null) throw const CatalogException('인터넷에 연결하지 못했어요.');
      final m = jsonDecode(mText) as Map<String, Object?>;
      final same = m['updated_at'] == manifest['updated_at'] && m['total'] == manifest['total'];
      if (same && kits.isNotEmpty && !force) return false;

      final aux = <String, String>{};
      for (final f in auxFiles) {
        _step('보조 데이터 $f');
        final t = await _get('data/$f');
        if (t != null) aux[f] = t;
      }
      final slim = <Map<String, Object?>>[];
      for (final f in franchiseIds) {
        _step('${_label[f]} 상품 받는 중');
        final raw = await _get('data/split/kits-$f.json');
        if (raw == null) throw CatalogException('${_label[f]} 상품을 받지 못했어요.');
        slim.addAll(
          await compute(mapKitsJob, {
            'raw': raw,
            'grades': aux['grades.json'] ?? '{}',
            'firstSeen': aux['kit-first-seen.json'] ?? '{}',
          }),
        );
      }
      _step('정리하는 중');
      final slimText = await compute(jsonEncode, slim);
      // first-seen 은 상품에 녹였으니 따로 두지 않는다
      for (final e in aux.entries) {
        if (e.key == 'kit-first-seen.json' || e.key == 'grades.json') continue;
        await BlobStore.write('aux_${e.key}', e.value);
        _aux.remove(e.key);
      }
      await BlobStore.write(_kitsKey, slimText);
      await BlobStore.write(
        _metaKey,
        jsonEncode({'manifest': m, 'map_version': mapVersion, 'fetched_at': DateTime.now().toIso8601String()}),
      );
      manifest = m;
      _slim = slim;
      _rebuild();
      version++;
      return true;
    } on Object catch (e) {
      error = e is CatalogException ? e.message : '데이터를 정리하다 멈췄어요: $e';
      debugPrint('[catalog] $error');
      if (kits.isEmpty) phase = CatalogPhase.error;
      return false;
    } finally {
      _refreshing = false;
      progress = '';
      notifyListeners();
    }
  }

  void _step(String s) {
    if (kits.isNotEmpty) return; // 뒤에서 받는 중엔 문구를 바꾸지 않는다
    progress = s;
    notifyListeners();
  }

  /// slim → Kit (최근 추가 · 이번 달은 오늘 날짜로 다시 계산)
  void _rebuild() {
    var latest = '';
    for (final s in _slim) {
      final f = s['firstSeen'];
      if (f is String && f.compareTo(latest) > 0) latest = f;
    }
    recentUntil = latest;
    recentSince = latest.isEmpty
        ? ''
        : DateTime.parse(latest).subtract(const Duration(days: 2)).toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final list = [for (final s in _slim) Kit.fromSlim(s, recentSince: recentSince, monthPrefix: monthPrefix)]
      // 발매일 새것부터, 발매일 없는 것은 뒤로
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.firstSeen.compareTo(a.firstSeen);
      });
    kits = list;
    byId = {for (final k in list) k.id: k};
    phase = CatalogPhase.ready;
    error = '';
    _applyAliases().ignore();
    _loadRates().ignore();
  }

  /// 1엔 = ? 원 (data/exchange-rates.json · Frankfurter, 매일). 못 받았으면 대략값
  double jpyToKrw = 9.0;

  Future<void> _loadRates() async {
    final r = jMap(jMap(await aux('exchange-rates.json'))['rates_to_krw'])['JPY'];
    if (r is num && r > 0) jpyToKrw = r.toDouble();
  }

  /// 정가를 원으로 (정가가 없으면 null)
  int? listPriceKrw(String id) => switch (byId[id]?.priceJpy) {
    final int p => (p * jpyToKrw).round(),
    _ => null,
  };

  /// 구매함 한 상품에 쓴 돈 — 적어 둔 구매가, 없으면 정가 × 환율 (estimate = true)
  ({int? krw, bool estimate}) paidOf(Kit k) => switch (UserStore.instance.entry(k.id)?['purchase_price']) {
    final num v => (krw: v.toInt(), estimate: false),
    _ => (krw: k.purchaseKrw ?? listPriceKrw(k.id), estimate: k.purchaseKrw == null),
  };

  /// 합쳐진 kit_id → 남은 kit_id (data/kit-aliases.json). 옛 id 로도 찾히게 하고, 내 기록을 옮긴다
  Map<String, String> aliases = const {};

  Future<void> _applyAliases() async {
    final raw = await aux('kit-aliases.json');
    final m = raw is Map<String, Object?> ? raw['aliases'] : null;
    if (m is! Map<String, Object?> || m.isEmpty) return;
    String resolve(String id) {
      var cur = id;
      for (var i = 0; i < 8 && m[cur] is String; i++) {
        cur = m[cur]! as String; // a → b → c 도 끝까지
      }
      return cur;
    }

    final map = {for (final k in m.keys) k: resolve(k)};
    aliases = map;
    byId = {
      ...byId,
      for (final e in map.entries)
        if (!byId.containsKey(e.key) && byId[e.value] != null) e.key: byId[e.value]!,
    };
    UserStore.instance.applyAliases(map);
  }

  static const _label = {
    'gundam': '건담',
    'beyblade': '베이블레이드',
    'pokemon': '포켓몬',
    'armored_core': '아머드 코어',
    'fate': 'Fate',
  };

  static Future<String?> _get(String path) async {
    for (final base in [gunpulaBase, gunpulaRawBase]) {
      try {
        final res = await http.get(Uri.parse('$base$path')).timeout(const Duration(seconds: 60));
        if (res.statusCode == 200) return utf8.decode(res.bodyBytes);
        debugPrint('[catalog] $base$path → HTTP ${res.statusCode}');
      } on Exception catch (e) {
        debugPrint('[catalog] $base$path → $e');
      }
    }
    return null;
  }
}

List<Map<String, Object?>> _decodeSlim(String text) => [
  for (final e in jsonDecode(text) as List<Object?>)
    if (e is Map<String, Object?>) e,
];

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}
