// 생김새로 찾기 (E-18) — 사진 속 물건과 생김새가 비슷한 상품을 기기 안에서 고른다. 사진은 밖으로 나가지 않는다.
// 모델: SigLIP2 ViT-B/32-256 그림 부분 (Google, Apache-2.0) · int8 가중치 LiteRT 파일 (약 95 MB)
// 표: 상품 공식 그림마다 벡터 하나 (약 10 MB, Gunpula 가 매주 같은 모델로 만든다)
// 둘 다 처음 쓸 때 한 번 내려받는다 (설치 파일에는 실행기 tflite_flutter 만 들어 있다).
// 안드로이드: 기기 안 LiteRT / 웹(미리보기) · 테스트: 지원 안 함 → 화면이 이 칸을 숨긴다
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'visual_engine_io.dart' if (dart.library.js_interop) 'visual_engine_web.dart' as impl;
import 'visual_index.dart';

export 'visual_index.dart' show VisualHit;

/// Gunpula release `imgsim` 의 안내 파일 (모델 · 표 이름 · 크기 · 갱신 시각)
const visualManifestUrl = 'https://github.com/mdefitko777/Gunpula/releases/download/imgsim/imgsim.json';

enum VisualState {
  /// 이 기기에서는 못 함 (웹 · 테스트)
  unsupported,

  /// 아직 안 받음 (또는 새 모델이 나옴)
  absent,
  downloading,
  ready,

  /// 받다가 실패 — [VisualSearch.error]
  failed,
}

/// 받기 실패 이유 → 화면 글. 우리가 번역해서 던진 글만 보이게 — `'$e'` 는 "FormatException: …" · "Bad state: …" 같은
/// 타입 머리가 붙는다 (2026-11-11 품질 점검). HttpException 은 dart:io 라 (웹 빌드) 글 머리로 뗀다.
String visualErrorText(Object e) => switch (e) {
  FormatException(:final message) => message,
  StateError(:final message) => message,
  UnsupportedError(message: final String m) => m,
  _ => '$e'.replaceFirst(_errorHead, ''),
};

final _errorHead = RegExp(r'^\w*(Exception|Error): ');

class VisualSearch extends ChangeNotifier {
  VisualSearch._();

  static final instance = VisualSearch._();

  VisualState _state = impl.visualSupported ? VisualState.absent : VisualState.unsupported;
  VisualState get state => _state;

  /// 내려받는 중 0–1
  double progress = 0;
  String error = '';

  /// 받을 크기 (안내 파일을 읽었으면, 바이트)
  int? downloadBytes;
  bool _checked = false;

  void _set(VisualState s) {
    _state = s;
    notifyListeners();
  }

  /// 받아 둔 파일이 있나 확인 · 며칠에 한 번 표 새로 받기 (조용히)
  Future<void> check() async {
    if (_state == VisualState.unsupported || _checked) return;
    _checked = true;
    try {
      final have = await impl.installedBytes();
      if (have != null) {
        _set(VisualState.ready);
        unawaited(impl.refreshVectors().catchError((Object _) => false));
      } else {
        downloadBytes = await impl.pendingBytes();
        notifyListeners();
      }
    } on Object {
      // 확인 실패 = 안 받은 것으로
    }
  }

  /// 모델 · 표 내려받기 (사용자가 "받기"를 눌렀을 때)
  Future<void> install() async {
    if (_state == VisualState.downloading || _state == VisualState.unsupported) return;
    progress = 0;
    error = '';
    _set(VisualState.downloading);
    try {
      await impl.install((p) {
        progress = p;
        notifyListeners();
      });
      _set(VisualState.ready);
    } on Object catch (e) {
      error = visualErrorText(e);
      _set(VisualState.failed);
    }
  }

  /// 받은 모델 · 표 지우기 (약 100 MB 비우기)
  Future<void> remove() async {
    if (_state == VisualState.unsupported) return;
    await impl.remove();
    _checked = false;
    _set(VisualState.absent);
  }

  /// 사진(JPEG · PNG 바이트) → 비슷한 상품 [k]개. [only] 를 주면 그 상품 id 안에서만
  Future<List<VisualHit>> search(Uint8List photo, {int k = 12, Set<String>? only}) async {
    if (_state != VisualState.ready) return const [];
    return impl.search(photo, k: k, only: only);
  }

  @visibleForTesting
  void debugSet(VisualState s) => _set(s);
}
