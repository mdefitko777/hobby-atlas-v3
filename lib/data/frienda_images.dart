// 프렌다 픽 그림 — 이 기기에서 공식 페이지를 읽어 기기에만 둔다 (개인 사용).
// Gunpula 공개 데이터에는 그림 주소가 없다: 사이트 약관(https://pokemonfrienda.com/policy/)이 다른 사이트의
// 그림 직링크를 삼가 달라고 해서. 앱은 탄을 열 때 그 탄의 공식 페이지 한 장만 받아(lib/logic/frienda_page.dart)
// {픽 id: 그림 주소} 를 BlobStore 에 7일 둔다. 매너: 봇 이름 User-Agent 하나 · 페이지 사이 1.1초 · 실패하면 조용히 공식 아트워크.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../clock.dart';
import '../logic/frienda_page.dart';
import 'blob_store.dart';
import 'gunpula.dart' show gunpulaUserAgent;
import 'tag_atlas.dart';

typedef PageFetcher = Future<String?> Function(Uri page);

Future<String?> _httpGet(Uri page) async {
  final r = await http
      .get(page, headers: kIsWeb ? null : const {'User-Agent': gunpulaUserAgent})
      .timeout(const Duration(seconds: 15));
  return r.statusCode == 200 ? utf8.decode(r.bodyBytes, allowMalformed: true) : null;
}

class FriendaImages extends ChangeNotifier {
  FriendaImages._();
  static final instance = FriendaImages._();

  static const storeKey = 'frienda_images';
  static const maxAge = Duration(days: 7);
  static const gap = Duration(milliseconds: 1100);

  /// 테스트에서 바꿔 끼운다
  @visibleForTesting
  static PageFetcher fetch = _httpGet;

  final Map<String, PickImage> _byId = {};
  final Map<String, String> _fetchedAt = {};
  final Set<String> _busy = {};
  Future<void>? _loading;
  bool _ready = false;
  DateTime _last = DateTime(2000);

  /// 받아 둔 그림 (없으면 null → 포켓몬 공식 아트워크)
  PickImage? of(String pickId) => _byId[pickId];

  /// 받아 둔 그림을 입힌 카드 (프렌다가 아니거나 아직 없으면 그대로)
  TagCard apply(TagCard c) {
    final p = c.game == TagGame.frienda ? _byId[c.id] : null;
    return p == null ? c : c.withImages(image: p.thumb, large: [p.full]);
  }

  Future<void> _load() async {
    try {
      final m = jsonDecode(await BlobStore.read(storeKey) ?? '{}') as Map<String, Object?>;
      for (final e in ((m['pages'] as Map?) ?? const {}).entries) {
        _fetchedAt['${e.key}'] = '${e.value}';
      }
      for (final e in ((m['images'] as Map?) ?? const {}).entries) {
        final v = e.value;
        if (v is List && v.length == 2) _byId['${e.key}'] = (thumb: '${v[0]}', full: '${v[1]}');
      }
    } on Object {
      // 망가진 캐시 — 다시 받는다
    }
    if (_byId.isNotEmpty) notifyListeners();
  }

  Future<void> _save() => BlobStore.write(
    storeKey,
    jsonEncode({
      'pages': _fetchedAt,
      'images': {
        for (final e in _byId.entries) e.key: [e.value.thumb, e.value.full],
      },
    }),
  );

  /// 이 카드들의 공식 페이지를 (7일 넘었거나 처음이면) 한 장씩 받는다. 받을 때마다 알린다
  Future<void> ensureFor(Iterable<TagCard> cards) async {
    if (!_ready) {
      await (_loading ??= _load());
      _ready = true;
    }
    final pages = <String>{
      for (final c in cards)
        if (c.game == TagGame.frienda && c.url.startsWith('https://pokemonfrienda.com/')) c.url.split('#').first,
    };
    for (final page in pages) {
      final at = DateTime.tryParse(_fetchedAt[page] ?? '');
      if (at != null && appNow().difference(at) < maxAge) continue;
      if (!_busy.add(page)) continue;
      try {
        final wait = _last.add(gap).difference(DateTime.now());
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        _last = DateTime.now();
        final html = await fetch(Uri.parse(page));
        if (html == null) continue;
        _byId.addAll(friendaPageImages(html, Uri.parse(page)));
        _fetchedAt[page] = appNow().toIso8601String();
        notifyListeners();
        await _save();
      } on Object {
        // 인터넷 없음 · 사이트 바뀜 — 공식 아트워크 그대로, 다음에 다시
      } finally {
        _busy.remove(page);
      }
    }
  }

  /// 테스트: 비우고, 기기 캐시는 읽은 셈 친다 (화면 테스트의 가짜 시간 안에서는 파일 읽기가 끝나지 않는다)
  @visibleForTesting
  void debugReset() {
    _byId.clear();
    _fetchedAt.clear();
    _busy.clear();
    _loading = null;
    _ready = true;
    _last = DateTime(2000);
  }
}
