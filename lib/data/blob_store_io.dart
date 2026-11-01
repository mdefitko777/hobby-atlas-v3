import 'dart:io';

import 'package:path_provider/path_provider.dart';

class BlobStore {
  static Directory? _dir;

  static Future<Directory> _root() async {
    final d = _dir ??= Directory('${(await getApplicationSupportDirectory()).path}/hobby_atlas');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  static Future<String?> read(String key) async {
    try {
      final f = File('${(await _root()).path}/$key');
      return f.existsSync() ? await f.readAsString() : null;
    } on Exception {
      return null;
    }
  }

  /// 다 쓴 뒤에 이름을 바꿔서, 쓰다가 앱이 꺼져도 예전 파일이 남는다.
  static Future<bool> write(String key, String value) async {
    try {
      final root = await _root();
      final tmp = File('${root.path}/$key.tmp');
      await tmp.writeAsString(value, flush: true);
      await tmp.rename('${root.path}/$key');
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<void> delete(String key) async {
    try {
      final f = File('${(await _root()).path}/$key');
      if (f.existsSync()) await f.delete();
    } on Exception {
      // 없으면 그만
    }
  }
}
