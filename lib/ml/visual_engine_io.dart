// 생김새로 찾기 — 안드로이드 쪽: 파일 받기 · LiteRT 로 사진 → 벡터 · 다른 isolate 에서 표와 비교
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../data/gunpula.dart' show gunpulaUserAgent;
import '../l10n/l10n.dart';
import '../logic/photo_crop.dart';
import 'visual_index.dart';
import 'visual_manifest.dart';
import 'visual_search.dart' show visualManifestUrl, visualManifestV2Url;

final visualSupported = Platform.isAndroid;

/// 받은 표를 며칠마다 새로 확인하나 (Gunpula 는 매일 만들지만 바뀐 줄이 있을 때만 새 표를 올린다)
const _refreshEvery = Duration(days: 3);

/// 받아 둔 모델 (`{schema: 2, installed: 모델 칸, checked, offer?}`). 옛 판이 쓴 `imgsim.json` 은 처음 한 번 옮겨 읽는다
const _installedFile = 'installed.json';
const _legacyFile = 'imgsim.json';

Future<Directory> _dir() async {
  final d = Directory('${(await getApplicationSupportDirectory()).path}/hobby_atlas/imgsim');
  if (!d.existsSync()) await d.create(recursive: true);
  return d;
}

Future<Map<String, Object?>?> _readJson(File f) async {
  if (!f.existsSync()) return null;
  try {
    return jsonDecode(await f.readAsString()) as Map<String, Object?>;
  } on Object {
    return null;
  }
}

/// 받아 둔 것의 안내 (모델 · 표가 다 받아진 뒤에만 쓴다)
Future<Map<String, Object?>?> _local() async {
  final d = await _dir();
  return await _readJson(File('${d.path}/$_installedFile')) ?? await _readJson(File('${d.path}/$_legacyFile'));
}

Future<void> _writeLocal(Map<String, Object?> m) async {
  final d = await _dir();
  final tmp = File('${d.path}/$_installedFile.tmp');
  await tmp.writeAsString(jsonEncode(m), flush: true);
  await tmp.rename('${d.path}/$_installedFile');
  final legacy = File('${d.path}/$_legacyFile');
  if (legacy.existsSync()) legacy.deleteSync();
}

VisualManifest? _remoteMemo;

/// 새 안내(schema 2)를 먼저, 아직 안 올라왔으면(404) 옛 안내
Future<VisualManifest> _remote() async {
  if (_remoteMemo case final m?) return m;
  Future<http.Response> get(String url) =>
      http.get(Uri.parse(url), headers: {'User-Agent': gunpulaUserAgent}).timeout(const Duration(seconds: 20));
  var r = await get(visualManifestV2Url);
  if (r.statusCode == 404) r = await get(visualManifestUrl);
  if (r.statusCode != 200) throw HttpException(trf('안내 파일을 받지 못했어요 ({code})', {'code': r.statusCode}));
  final m = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>;
  return _remoteMemo = VisualManifest.parse(m, updateMessage: tr('앱을 업데이트해야 받을 수 있어요'));
}

/// 받은 표 머리의 model (표 전체를 읽지 않는다)
Future<String> _vectorsModel(File f) async {
  final raf = await f.open();
  final Uint8List bytes;
  try {
    final head = await raf.read(20);
    bytes = Uint8List.fromList([...head, ...await raf.read(VisualIndex.metaEnd(head) - 20)]);
  } finally {
    await raf.close();
  }
  return Isolate.run(() => '${VisualIndex.readMeta(bytes)['model'] ?? ''}');
}

/// 모델 · 표 파일이 크기대로 다 있고, 표가 그 모델로 만든 것인가 (B/32 · B/16 은 둘 다 768 차원이라 크기로는 못 가린다)
Future<bool> _complete(VisualModel e) async {
  final d = await _dir();
  final mf = File('${d.path}/${e.model.file}');
  final vf = File('${d.path}/${e.vectors.file}');
  if (!(mf.existsSync() && mf.lengthSync() == e.model.bytes && vf.existsSync() && vf.lengthSync() == e.vectors.bytes)) {
    return false;
  }
  try {
    return await _vectorsModel(vf) == e.id;
  } on Object {
    return false;
  }
}

VisualModel? _installedMemo;

/// 받아 둔 모델 (다 받아졌고 짝이 맞을 때만)
Future<VisualModel?> installed() async {
  final m = await _local();
  final e = m == null ? null : installedModel(m);
  return _installedMemo = e != null && await _complete(e) ? e : null;
}

/// 받아 둔 모델 id (짝 확인용)
String? installedId() => _installedMemo?.id;

/// 받을 크기 (처음 받기)
Future<int?> pendingBytes() async => (await _remote()).preferred.bytes;

/// 지난번 확인에서 본 새 모델 크기 (권하는 것이 없으면 null)
Future<int?> offerBytes() async => ((await _local())?['offer'] as Map?)?['bytes'] as int?;

/// [url] → [dest] (`.part` 에 쓰고 크기가 맞으면 이름 바꾸기)
Future<void> _download(String url, File dest, int expected, void Function(int got) onChunk) async {
  final part = File('${dest.path}.part');
  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url))..headers['User-Agent'] = gunpulaUserAgent;
    final res = await client.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException(trf('내려받지 못했어요 ({code})', {'code': res.statusCode}));
    final sink = part.openWrite();
    var got = 0;
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        got += chunk.length;
        onChunk(got);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (expected > 0 && got != expected) throw HttpException(tr('받은 파일 크기가 맞지 않아요'));
    await part.rename(dest.path);
  } finally {
    client.close();
    if (part.existsSync()) part.deleteSync();
  }
}

/// 안내 파일의 default 모델 받기 (처음 받기 · 새 모델 받기). 다 받은 뒤에야 옛 모델 · 옛 표를 지운다
Future<void> install(void Function(double) onProgress) async {
  _remoteMemo = null;
  final e = (await _remote()).preferred;
  final d = await _dir();
  final total = e.bytes;
  final mf = File('${d.path}/${e.model.file}');
  final vf = File('${d.path}/${e.vectors.file}');
  var done = 0;
  void report(int got) => onProgress(total == 0 ? 0 : ((done + got) / total).clamp(0, 1));
  // 이미 받은 같은 모델 파일(이름 · 크기가 같음)은 그대로 쓴다
  if (!(mf.existsSync() && mf.lengthSync() == e.model.bytes)) {
    await _download(e.model.url, mf, e.model.bytes, report);
  }
  done += e.model.bytes;
  await _download(e.vectors.url, vf, e.vectors.bytes, report);
  if (await _vectorsModel(vf) != e.id) throw FormatException(tr('모델과 표가 맞지 않아요'));
  await _closeModel();
  for (final f in d.listSync().whereType<File>()) {
    final p = f.path;
    if ((p.endsWith('.tflite') && p != mf.path) || (p.endsWith('.bin') && p != vf.path)) f.deleteSync();
  }
  await _writeLocal({'schema': 2, 'installed': e.json, 'checked': DateTime.now().toIso8601String()});
  _installedMemo = e;
}

/// 며칠에 한 번 안내 파일 확인: 같은 모델의 새 표면 조용히 받고, 새 모델(파일이 바뀜 · default 가 옮김)이면
/// 받지 않고 권하기만 한다 (약 95 MB 를 묻지 않고 받지 않는다). 권할 크기를 돌려준다
Future<int?> refresh() async {
  final local = await _local();
  final e = local == null ? null : installedModel(local);
  if (local == null || e == null) return null;
  final checked = DateTime.tryParse('${local['checked'] ?? ''}');
  if (checked != null && DateTime.now().difference(checked) < _refreshEvery) return offerBytes();
  final up = visualUpgrade(e, await _remote());
  var now = e;
  if (up.vectors case final next?) {
    final d = await _dir();
    // 다 받은 뒤 이름 바꾸기라 받는 동안에도 옛 표로 찾을 수 있다
    final vf = File('${d.path}/${next.vectors.file}');
    await _download(next.vectors.url, vf, next.vectors.bytes, (_) {});
    now = VisualModel({...e.json, 'vectors': next.vectors.json});
    final old = File('${d.path}/${e.vectors.file}');
    if (old.path != vf.path && old.existsSync()) old.deleteSync();
  }
  final offer = up.model;
  await _writeLocal({
    'schema': 2,
    'installed': now.json,
    'checked': DateTime.now().toIso8601String(),
    if (offer != null) 'offer': {'id': offer.id, 'bytes': offer.bytes},
  });
  _installedMemo = now;
  return offer?.bytes;
}

Future<void> remove() async {
  await _closeModel();
  _installedMemo = null;
  final d = await _dir();
  if (d.existsSync()) await d.delete(recursive: true);
}

Interpreter? _interpreter;
IsolateInterpreter? _runner;

Future<void> _closeModel() async {
  await _runner?.close();
  _interpreter?.close();
  _runner = null;
  _interpreter = null;
}

Future<IsolateInterpreter> _open(VisualModel e) async {
  if (_runner case final r?) return r;
  final file = File('${(await _dir()).path}/${e.model.file}');
  final it = Interpreter.fromFile(file, options: InterpreterOptions()..threads = 4);
  _interpreter = it;
  return _runner = await IsolateInterpreter.create(address: it.address);
}

/// 사진 → 모델 입력 (짧은 변 256 으로 줄여 풀기 → 가운데 256×256). [crop] 이 있으면 그 틀의 가운데 정사각형
@visibleForTesting
Future<Float32List> prepareVisualInput(Uint8List photo, CropBox? crop) async {
  final buf = await ui.ImmutableBuffer.fromUint8List(photo);
  final desc = await ui.ImageDescriptor.encoded(buf);
  ui.Codec? codec;
  ui.Image? image;
  try {
    if (crop == null || isFullCrop(crop)) {
      // 상품 표와 맞춰 본 길 그대로 (2026-11-14 비교: 코사인 0.96–0.999)
      final (w, h) = resizeForCrop(desc.width, desc.height);
      codec = await desc.instantiateCodec(targetWidth: w, targetHeight: h);
      image = (await codec.getNextFrame()).image;
    } else {
      final plan = cropPlan(desc.width, desc.height, crop);
      codec = await desc.instantiateCodec(targetWidth: plan.decodeW, targetHeight: plan.decodeH);
      final full = (await codec.getNextFrame()).image;
      try {
        // 틀의 가운데 정사각형 → 256×256. 투명은 그대로 두고 cropToInput 이 흰 바탕에 얹는다
        final rec = ui.PictureRecorder();
        ui.Canvas(rec).drawImageRect(
          full,
          ui.Rect.fromLTWH(plan.srcLeft, plan.srcTop, plan.srcSide, plan.srcSide),
          const ui.Rect.fromLTWH(0, 0, 256, 256),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final pic = rec.endRecording();
        image = await pic.toImage(256, 256);
        pic.dispose();
      } finally {
        full.dispose();
      }
    }
    final data = await image.toByteData(); // rawRgba (곱해진 알파)
    if (data == null) throw StateError(tr('사진을 풀지 못했어요'));
    return cropToInput(data.buffer.asUint8List(), image.width, image.height);
  } finally {
    image?.dispose();
    codec?.dispose();
    desc.dispose();
    buf.dispose();
  }
}

/// IsolateInterpreter 는 돌고 있는 동안 들어온 run 을 그냥 버린다 → 한 번에 하나씩
Future<void> _queue = Future.value();

/// 사진 → 표의 모든 상품 (비슷한 순서) + 그 표의 모델 이름
Future<({String model, List<VisualHit> hits})> search(
  Uint8List photo, {
  CropBox? crop,
  Map<String, String> alias = const {},
}) async {
  final e = _installedMemo ?? await installed();
  if (e == null) throw StateError(tr('모델을 아직 받지 않았어요'));
  final input = await prepareVisualInput(photo, crop);
  final turn = _queue;
  final mine = Completer<void>();
  _queue = mine.future;
  await turn;
  final List<double> raw;
  try {
    final runner = await _open(e);
    final dim = _interpreter!.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(dim, 0)];
    await runner.run(input.buffer.asUint8List(), output);
    raw = output.first;
  } finally {
    mine.complete();
  }
  final query = l2normalize(raw);
  final path = '${(await _dir()).path}/${e.vectors.file}';
  return Isolate.run(() {
    final index = VisualIndex.parse(File(path).readAsBytesSync());
    return (model: index.model, hits: index.nearest(query, k: null, alias: alias));
  });
}
