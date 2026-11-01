import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';

class BlobStore {
  static Directory? _dir;

  /// 테스트: path_provider 없이 임시 폴더에 쓴다
  @visibleForTesting
  static set debugDirectory(Directory d) => _dir = d;

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

  // 임시 파일 이름은 쓰는 쪽(isolate)마다 · 쓸 때마다 다르게 — 앱 화면과 백그라운드(WorkManager)가 같은 파일을
  // 동시에 써도 서로의 반쯤 쓴 임시 파일을 옮기지 않는다 (예전: 둘 다 `<key>.tmp` → 깨진 JSON 이 남을 수 있었다)
  static final _tag = Random().nextInt(0x7fffffff).toRadixString(36);
  static var _seq = 0;

  /// 다 쓴 뒤에 이름을 바꿔서, 쓰다가 앱이 꺼져도 예전 파일이 남는다.
  static Future<bool> write(String key, String value) async {
    File? tmp;
    try {
      final root = await _root();
      tmp = File('${root.path}/$key.$_tag-${_seq++}.tmp');
      await tmp.writeAsString(value, flush: true);
      await tmp.rename('${root.path}/$key');
      return true;
    } on Exception {
      try {
        if (tmp != null && tmp.existsSync()) await tmp.delete();
      } on Exception {
        // 못 지워도 그만
      }
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

  /// [key] 를 "읽고 → 합치고 → 쓰는" 동안 다른 쪽(같은 앱의 다른 isolate 포함)이 끼어들지 못하게.
  /// `<key>.lock` 을 O_EXCL 로 만든다 — RandomAccessFile.lock 은 같은 프로세스의 isolate 끼리는 막지 못한다.
  /// [stale] 보다 오래된 잠금은 쓰다 죽은 것으로 보고 지운다. [wait] 안에 못 잡으면 그냥 진행한다
  /// (알림이 멈추는 것보다 낫다 · 읽음 표시는 다음 저장에서 다시 합쳐진다).
  static Future<T> locked<T>(
    String key,
    Future<T> Function() body, {
    Duration wait = const Duration(seconds: 10),
    Duration stale = const Duration(seconds: 30),
  }) async {
    File? lock;
    try {
      final f = File('${(await _root()).path}/$key.lock');
      final until = DateTime.now().add(wait);
      while (true) {
        try {
          await f.create(exclusive: true);
          lock = f;
          break;
        } on FileSystemException {
          // 다른 쪽이 잡고 있다
        }
        try {
          if (f.existsSync() && DateTime.now().difference(f.lastModifiedSync()) > stale) f.deleteSync();
        } on FileSystemException {
          // 그 사이 풀렸다
        }
        if (DateTime.now().isAfter(until)) break;
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    } on Exception {
      lock = null;
    }
    try {
      return await body();
    } finally {
      try {
        if (lock != null && lock.existsSync()) await lock.delete();
      } on Exception {
        // 다음 쪽이 stale 로 지운다
      }
    }
  }
}
