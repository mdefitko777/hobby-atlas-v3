import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:web/web.dart' as web;

class BlobStore {
  static const _prefix = 'hobby_atlas/';

  /// (안드로이드용 테스트 훅과 모양을 맞춤 — 웹에서는 쓰지 않는다)
  @visibleForTesting
  static set debugDirectory(Object _) {}

  static Future<String?> read(String key) async {
    try {
      return web.window.localStorage.getItem('$_prefix$key');
    } on Object {
      return null;
    }
  }

  static Future<bool> write(String key, String value) async {
    try {
      web.window.localStorage.setItem('$_prefix$key', value);
      return true;
    } on Object {
      return false; // 5 MB 를 넘는 상품 캐시 — 다음에 다시 받는다
    }
  }

  static Future<void> delete(String key) async {
    try {
      web.window.localStorage.removeItem('$_prefix$key');
    } on Object {
      // 없으면 그만
    }
  }

  /// (안드로이드용과 모양을 맞춤 — 웹 미리보기는 isolate 하나뿐이라 잠글 것이 없다)
  static Future<T> locked<T>(
    String key,
    Future<T> Function() body, {
    Duration wait = const Duration(seconds: 10),
    Duration stale = const Duration(seconds: 30),
  }) => body();
}
