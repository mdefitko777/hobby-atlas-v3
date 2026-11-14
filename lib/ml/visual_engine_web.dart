import 'dart:typed_data';

import '../l10n/l10n.dart';
import '../logic/photo_crop.dart';
import 'visual_index.dart';
import 'visual_manifest.dart';

/// 웹(미리보기)에는 기기 안 모델 실행기가 없다
const visualSupported = false;

Future<VisualModel?> installed() async => null;
String? installedId() => null;
Future<int?> pendingBytes() async => null;
Future<int?> offerBytes() async => null;
Future<int?> refresh() async => null;
Future<void> install(void Function(double) onProgress) async => throw UnsupportedError(tr('이 기기에서는 생김새로 찾기를 못 해요'));
Future<void> remove() async {}
Future<({String model, List<VisualHit> hits})> search(
  Uint8List photo, {
  CropBox? crop,
  Map<String, String> alias = const {},
}) async => (model: '', hits: const <VisualHit>[]);
