// 재판매 소식 받기 — Catalog 보조 파일 atlas/restocks.json (Gunpula, 아직 공개 전일 수 있다).
// 없거나(404) 깨졌으면 빈 묶음 → 화면의 재판매 칸이 모두 숨는다. 같은 카탈로그 판 안에서는 한 번만 푼다
// (Catalog.aux 는 못 받은 파일을 기억하지 않아, 부를 때마다 다시 받으러 가지 않게).
import 'package:flutter/foundation.dart';

import '../logic/restock.dart';
import 'catalog.dart';

Future<RestockIndex>? _cached;
int _cachedVersion = -1;

Future<RestockIndex> loadRestocks() {
  final c = Catalog.instance;
  if (c.kits.isEmpty) return Future.value(RestockIndex.empty); // 카탈로그 전(테스트 · 첫 실행) — 기억하지 않는다
  if (_cached == null || _cachedVersion != c.version) {
    _cachedVersion = c.version;
    _cached = _load(c);
  }
  return _cached!;
}

Future<RestockIndex> _load(Catalog c) async {
  try {
    return RestockIndex.parse(await c.aux(restocksFile));
  } on Object catch (e) {
    debugPrint('[restocks] $e');
    return RestockIndex.empty;
  }
}
