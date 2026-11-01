// 공유로 받기 (안드로이드 "공유 → Hobby Atlas") — 다른 앱에서 보낸 사진(스크린숏) · 글 · 주소를 받아 둔다.
// 앱이 꺼져 있다가 공유로 켜진 경우(처음 받은 것) · 켜져 있던 경우(이어서 받는 것) 둘 다 [ShareIntake.incoming] 하나로.
// 앱 셸(lib/screens/s_app_shell.dart)이 듣다가 사진 · 공유로 찾기(E-15)를 연다.
// 받는 쪽 안드로이드 설정: AndroidManifest.xml 의 ACTION_SEND / SEND_MULTIPLE intent-filter (image/* · text/plain).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'shared_file_io.dart' if (dart.library.js_interop) 'shared_file_web.dart' as impl;

/// 공유로 받은 것 하나
sealed class SharedItem {
  const SharedItem();
}

/// 사진 (플러그인이 앱 캐시 폴더에 복사해 둔 파일)
final class SharedImage extends SharedItem {
  const SharedImage(this.path);
  final String path;
}

/// 글 · 주소 (가게 앱의 "공유" 는 보통 상품 이름 + 주소)
final class SharedText extends SharedItem {
  const SharedText(this.text);
  final String text;
}

/// 플러그인 결과 → 받은 것 하나 (사진이 먼저 — 여러 장이면 첫 장, 없으면 글 · 주소를 모아서)
SharedItem? sharedItemFrom(List<SharedMediaFile> files) {
  for (final f in files) {
    if (f.type == SharedMediaType.image && f.path.isNotEmpty) return SharedImage(f.path);
  }
  final text = <String>{
    for (final f in files)
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) f.path.trim(),
    for (final f in files) (f.message ?? '').trim(),
  }.where((s) => s.isNotEmpty).join('\n');
  return text.isEmpty ? null : SharedText(text);
}

/// 받은 사진 파일 → 바이트 (읽은 뒤 캐시의 복사본은 지운다). 테스트는 바꿔 끼운다
typedef SharedFileReader = Future<Uint8List> Function(String path);

SharedFileReader readSharedFile = impl.readSharedFile;

class ShareIntake {
  ShareIntake._();
  static final instance = ShareIntake._();

  /// 아직 열지 않은 공유 (연 쪽이 [take] 로 비운다)
  final incoming = ValueNotifier<SharedItem?>(null);

  StreamSubscription<List<SharedMediaFile>>? _sub;

  /// main() 에서 한 번: 켜져 있는 동안 받는 것 + 공유로 켜졌으면 그 처음 것
  Future<void> start() async {
    if (kIsWeb || _sub != null) return;
    try {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_put, onError: (Object _) {});
      _put(await ReceiveSharingIntent.instance.getInitialMedia());
      await ReceiveSharingIntent.instance.reset(); // 다시 켤 때 같은 공유를 또 열지 않게
    } on Object {
      // 플러그인이 없는 곳 (테스트 · 데스크톱) — 공유로 받기만 없다
    }
  }

  void _put(List<SharedMediaFile> files) {
    final item = sharedItemFrom(files);
    if (item != null) incoming.value = item;
  }

  /// 받은 것을 꺼내고 비운다 (없으면 null)
  SharedItem? take() {
    final v = incoming.value;
    if (v != null) incoming.value = null;
    return v;
  }
}
