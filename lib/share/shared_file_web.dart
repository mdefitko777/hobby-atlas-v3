import 'dart:typed_data';

import '../l10n/l10n.dart';

/// 웹(미리보기)에는 공유로 받기가 없다
Future<Uint8List> readSharedFile(String path) async => throw UnsupportedError(tr('공유로 받은 파일을 열 수 없어요'));
