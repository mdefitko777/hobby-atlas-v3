import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 공유로 받은 사진 읽기 — 플러그인이 캐시 폴더에 복사해 둔 것이면 읽은 뒤 지운다 (다른 곳의 원본은 두고)
Future<Uint8List> readSharedFile(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  try {
    final cache = (await getTemporaryDirectory()).path;
    if (file.absolute.path.startsWith(cache)) file.delete().ignore();
  } on Object {
    // 캐시 위치를 몰라도 읽기는 됐다
  }
  return bytes;
}
