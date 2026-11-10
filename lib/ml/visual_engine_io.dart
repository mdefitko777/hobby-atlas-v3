// 생김새로 찾기 — 안드로이드 쪽: 파일 받기 · LiteRT 로 사진 → 벡터 · 다른 isolate 에서 표와 비교
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../data/gunpula.dart' show gunpulaUserAgent;
import '../l10n/l10n.dart';
import 'visual_index.dart';
import 'visual_search.dart' show visualManifestUrl;

final visualSupported = Platform.isAndroid;

/// 받은 표를 며칠마다 새로 확인하나
const _refreshEvery = Duration(days: 3);
const _vectorsFile = 'imgsim-vectors.bin';

Future<Directory> _dir() async {
  final d = Directory('${(await getApplicationSupportDirectory()).path}/hobby_atlas/imgsim');
  if (!d.existsSync()) await d.create(recursive: true);
  return d;
}

/// 받아 둔 것의 안내 (모델 · 표가 다 받아진 뒤에만 쓴다)
Future<Map<String, Object?>?> _local() async {
  final f = File('${(await _dir()).path}/imgsim.json');
  if (!f.existsSync()) return null;
  try {
    return jsonDecode(await f.readAsString()) as Map<String, Object?>;
  } on Object {
    return null;
  }
}

Future<void> _writeLocal(Map<String, Object?> m) async {
  final d = await _dir();
  final tmp = File('${d.path}/imgsim.json.tmp');
  await tmp.writeAsString(jsonEncode(m), flush: true);
  await tmp.rename('${d.path}/imgsim.json');
}

Map<String, Object?>? _remoteMemo;

Future<Map<String, Object?>> _remote() async {
  if (_remoteMemo case final m?) return m;
  final r = await http
      .get(Uri.parse(visualManifestUrl), headers: {'User-Agent': gunpulaUserAgent})
      .timeout(const Duration(seconds: 20));
  if (r.statusCode != 200) throw HttpException(trf('안내 파일을 받지 못했어요 ({code})', {'code': r.statusCode}));
  final m = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>;
  if (m['schema'] != 1) throw FormatException(tr('앱을 업데이트해야 받을 수 있어요'));
  return _remoteMemo = m;
}

Map<String, Object?> _part(Map<String, Object?> m, String key) => (m[key] as Map?)?.cast<String, Object?>() ?? const {};
int _bytes(Map<String, Object?> p) => (p['bytes'] as num?)?.toInt() ?? 0;

Future<bool> _complete(Map<String, Object?> m) async {
  final d = await _dir();
  final model = _part(m, 'model');
  final vec = _part(m, 'vectors');
  final mf = File('${d.path}/${model['file']}');
  final vf = File('${d.path}/$_vectorsFile');
  return mf.existsSync() && mf.lengthSync() == _bytes(model) && vf.existsSync() && vf.lengthSync() == _bytes(vec);
}

Future<int?> installedBytes() async {
  final m = await _local();
  if (m == null || !await _complete(m)) return null;
  return _bytes(_part(m, 'model')) + _bytes(_part(m, 'vectors'));
}

Future<int?> pendingBytes() async {
  final m = await _remote();
  return _bytes(_part(m, 'model')) + _bytes(_part(m, 'vectors'));
}

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

Future<void> install(void Function(double) onProgress) async {
  _remoteMemo = null;
  final m = await _remote();
  final d = await _dir();
  final model = _part(m, 'model');
  final vec = _part(m, 'vectors');
  final total = _bytes(model) + _bytes(vec);
  final mf = File('${d.path}/${model['file']}');
  var done = 0;
  void report(int got) => onProgress(total == 0 ? 0 : ((done + got) / total).clamp(0, 1));
  if (!(mf.existsSync() && mf.lengthSync() == _bytes(model))) {
    await _download('${model['url']}', mf, _bytes(model), report);
  }
  done += _bytes(model);
  await _download('${vec['url']}', File('${d.path}/$_vectorsFile'), _bytes(vec), report);
  // 예전 모델 파일 정리
  for (final f in d.listSync().whereType<File>()) {
    if (f.path.endsWith('.tflite') && f.path != mf.path) f.deleteSync();
  }
  await _closeModel();
  await _writeLocal({...m, 'checked': DateTime.now().toIso8601String()});
}

/// 표만 새로 (같은 모델로 만든 새 표가 있으면). 모델이 바뀌었으면 그대로 둔다 (옛 모델 + 옛 표는 계속 맞는다)
Future<bool> refreshVectors() async {
  final local = await _local();
  if (local == null) return false;
  final checked = DateTime.tryParse('${local['checked'] ?? ''}');
  if (checked != null && DateTime.now().difference(checked) < _refreshEvery) return false;
  final m = await _remote();
  final lm = _part(local, 'model');
  final rm = _part(m, 'model');
  final lv = _part(local, 'vectors');
  final rv = _part(m, 'vectors');
  var next = {...local, 'checked': DateTime.now().toIso8601String()};
  if (rm['sha256'] == lm['sha256'] && rv['sha256'] != lv['sha256']) {
    final d = await _dir();
    await _download('${rv['url']}', File('${d.path}/$_vectorsFile'), _bytes(rv), (_) {});
    next = {...next, 'vectors': rv};
  }
  await _writeLocal(next);
  return true;
}

Future<void> remove() async {
  await _closeModel();
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

Future<IsolateInterpreter> _open() async {
  if (_runner case final r?) return r;
  final m = await _local();
  if (m == null) throw StateError(tr('모델을 아직 받지 않았어요'));
  final file = File('${(await _dir()).path}/${_part(m, 'model')['file']}');
  final it = Interpreter.fromFile(file, options: InterpreterOptions()..threads = 4);
  _interpreter = it;
  return _runner = await IsolateInterpreter.create(address: it.address);
}

/// 사진 → 모델 입력 (짧은 변 256 으로 줄여 풀기 → 가운데 256×256)
Future<Float32List> _prepare(Uint8List photo) async {
  final buf = await ui.ImmutableBuffer.fromUint8List(photo);
  final desc = await ui.ImageDescriptor.encoded(buf);
  final (w, h) = resizeForCrop(desc.width, desc.height);
  final codec = await desc.instantiateCodec(targetWidth: w, targetHeight: h);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(); // rawRgba (곱해진 알파)
    if (data == null) throw StateError(tr('사진을 풀지 못했어요'));
    return cropToInput(data.buffer.asUint8List(), image.width, image.height);
  } finally {
    image.dispose();
    codec.dispose();
    desc.dispose();
    buf.dispose();
  }
}

/// IsolateInterpreter 는 돌고 있는 동안 들어온 run 을 그냥 버린다 → 한 번에 하나씩
Future<void> _queue = Future.value();

Future<List<VisualHit>> search(Uint8List photo, {int k = 12, Set<String>? only}) async {
  final input = await _prepare(photo);
  final turn = _queue;
  final mine = Completer<void>();
  _queue = mine.future;
  await turn;
  final List<double> raw;
  try {
    final runner = await _open();
    final dim = _interpreter!.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(dim, 0)];
    await runner.run(input.buffer.asUint8List(), output);
    raw = output.first;
  } finally {
    mine.complete();
  }
  final query = l2normalize(raw);
  final path = '${(await _dir()).path}/$_vectorsFile';
  return Isolate.run(() => VisualIndex.parse(File(path).readAsBytesSync()).nearest(query, k: k, only: only));
}
