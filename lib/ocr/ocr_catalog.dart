// 글자로 찾기의 상품 쪽 준비 — 찾기 표(OcrIndex)를 다른 isolate 에서 한 번 만들고, 건담 형식번호 표는 도감 데이터에서.
// 규칙은 lib/logic/ocr_lookup.dart (순수 Dart), 여기는 앱 데이터(Catalog)와 잇는 곳만.
import 'package:flutter/foundation.dart';

import '../data/catalog.dart';
import '../data/gundam_atlas.dart' show atlasKitMsFile, atlasMsFile;
import '../logic/ocr_lookup.dart';
import '../models.dart';

/// 접은 형식번호 → 상품 id (테스트는 빈 표를 넣는다)
typedef OcrModelSource = Future<Map<String, List<String>>> Function();

OcrModelSource ocrModelSource = fetchOcrModels;

Object? _ms;
Object? _km;
Map<String, List<String>> _models = const {};

/// 건담 도감 데이터(gundam-ms · gundam-kit-ms)의 형식번호 ↔ 상품. 못 받았으면 빈 표 (이름에 있는 형식번호로만 찾는다)
Future<Map<String, List<String>>> fetchOcrModels() async {
  try {
    final ms = await Catalog.instance.aux(atlasMsFile);
    final km = await Catalog.instance.aux(atlasKitMsFile);
    if (ms == null || km == null) return const {};
    if (!identical(ms, _ms) || !identical(km, _km)) {
      _models = atlasModelIndex(ms, km);
      _ms = ms;
      _km = km;
    }
    return _models;
  } on Object {
    return const {};
  }
}

/// 이보다 적으면 그냥 이 isolate 에서 (테스트 · 작은 목록)
const _isolateFrom = 500;

/// 찾기 표 — 같은 상품 목록이면 지난번 것, 아니면 compute() 로 만든다 (약 1만 개에 0.5초쯤, 화면은 그동안 "읽는 중")
Future<OcrIndex> loadOcrIndex(List<Kit> kits) async {
  final models = await ocrModelSource();
  if (OcrIndex.reuse(kits, models: models) case final i?) return i;
  final msg = (rows: ocrRows(kits), models: models);
  final data = kits.length < _isolateFrom ? buildOcrIndexData(msg) : await compute(buildOcrIndexData, msg);
  return OcrIndex.withData(kits, data, models: models);
}
