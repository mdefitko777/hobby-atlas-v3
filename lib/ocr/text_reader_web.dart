import 'dart:typed_data';

import '../l10n/l10n.dart';

/// 웹(미리보기)에는 기기 안 글자 인식이 없다
Future<String> readTextOnDevice(Uint8List image) async => throw UnsupportedError(tr('이 기기에서는 글자 읽기를 못 해요'));
