// 공유로 받기 (안드로이드 "공유 → Hobby Atlas") — 다른 앱에서 보낸 사진(스크린숏) · 글 · 주소를 받아 둔다.
// 앱이 꺼져 있다가 공유로 켜진 경우(처음 받은 것) · 켜져 있던 경우(이어서 받는 것) 둘 다 [ShareIntake.incoming] 하나로.
// 앱 셸(lib/screens/s_app_shell.dart)이 듣다가 사진 · 공유로 찾기(E-15)를 연다.
// 받는 쪽 안드로이드: AndroidManifest.xml 의 ACTION_SEND / SEND_MULTIPLE intent-filter (image/* · text/plain) +
// MainActivity.kt 가 MethodChannel `hobbyatlas/share` 로 넘긴다 ("initial" = 공유로 켜졌을 때, "shared" = 켜져 있을 때).
// (receive_sharing_intent 는 1.9 가 compileSdk 37, 1.8 이 JVM 대상 불일치로 빌드가 안 돼 직접 받는다)
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logic/kit_link.dart';

import 'shared_file_io.dart' if (dart.library.js_interop) 'shared_file_web.dart' as impl;

/// 공유로 받은 것 하나
sealed class SharedItem {
  const SharedItem();
}

/// 사진 (MainActivity 가 앱 캐시 폴더에 복사해 둔 파일)
final class SharedImage extends SharedItem {
  const SharedImage(this.path);
  final String path;
}

/// 글 · 주소 (가게 앱의 "공유" 는 보통 상품 이름 + 주소)
final class SharedText extends SharedItem {
  const SharedText(this.text);
  final String text;
}

/// 상품 링크 (Hobby Atlas 의 공유 링크를 눌렀을 때 · 그 링크가 든 글을 공유받았을 때) — 그 상품 상세로
final class SharedKitLink extends SharedItem {
  const SharedKitLink(this.kitId);
  final String kitId;
}

/// MainActivity 가 보낸 것 `{type: image, path}` · `{type: text, text}` → 받은 것 하나 (모르는 모양이면 null)
SharedItem? sharedItemFrom(Object? raw) {
  if (raw is! Map) return null;
  final type = raw['type'];
  final path = raw['path'];
  final text = raw['text'];
  if (type == 'image' && path is String && path.isNotEmpty) return SharedImage(path);
  final id = raw['id'];
  if (type == 'kit' && id is String && id.isNotEmpty) return SharedKitLink(id);
  if (type == 'text' && text is String && text.trim().isNotEmpty) {
    // 친구가 보낸 「이름 + 상품 링크」 글을 다시 공유받았으면 그 상품으로
    final linked = kitIdFromLink(text);
    return linked != null ? SharedKitLink(linked) : SharedText(text.trim());
  }
  return null;
}

/// MainActivity 와 이어진 통로 (테스트는 TestDefaultBinaryMessengerBinding 으로 흉내 낸다)
const shareChannel = MethodChannel('hobbyatlas/share');

/// 받은 사진 파일 → 바이트 (읽은 뒤 캐시의 복사본은 지운다). 테스트는 바꿔 끼운다
typedef SharedFileReader = Future<Uint8List> Function(String path);

SharedFileReader readSharedFile = impl.readSharedFile;

class ShareIntake {
  ShareIntake._();
  static final instance = ShareIntake._();

  /// 아직 열지 않은 공유 (연 쪽이 [take] 로 비운다)
  final incoming = ValueNotifier<SharedItem?>(null);

  bool _started = false;

  /// main() 에서 한 번: 켜져 있는 동안 받는 것 + 공유로 켜졌으면 그 처음 것
  Future<void> start() async {
    if (kIsWeb || _started) return;
    _started = true;
    shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'shared') _put(call.arguments);
    });
    try {
      _put(await shareChannel.invokeMethod<Object?>('initial'));
    } on Object {
      // 안드로이드가 아닌 곳 (테스트 · 데스크톱) — 공유로 받기만 없다
    }
  }

  @visibleForTesting
  void debugReset() {
    _started = false;
    incoming.value = null;
  }

  void _put(Object? raw) {
    final item = sharedItemFrom(raw);
    if (item != null) incoming.value = item;
  }

  /// 받은 것을 꺼내고 비운다 (없으면 null)
  SharedItem? take() {
    final v = incoming.value;
    if (v != null) incoming.value = null;
    return v;
  }
}
