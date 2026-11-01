import 'package:web/web.dart' as web;

class BlobStore {
  static const _prefix = 'hobby_atlas/';

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
}
