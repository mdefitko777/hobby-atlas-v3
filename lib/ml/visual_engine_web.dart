import 'dart:typed_data';

import '../l10n/l10n.dart';
import 'visual_index.dart';

/// 웹(미리보기)에는 기기 안 모델 실행기가 없다
const visualSupported = false;

Future<int?> installedBytes() async => null;
Future<int?> pendingBytes() async => null;
Future<bool> refreshVectors() async => false;
Future<void> install(void Function(double) onProgress) async => throw UnsupportedError(tr('이 기기에서는 생김새로 찾기를 못 해요'));
Future<void> remove() async {}
Future<List<VisualHit>> search(Uint8List photo, {int k = 12, Set<String>? only}) async => const [];
