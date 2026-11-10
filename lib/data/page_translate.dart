// 일본어 → 한국어 번역 (기기 안 Google ML Kit — 번역 서버를 거치지 않는다, 처음 한 번 모델을 받는다)
// translate.goog(구글 웹 번역)는 한국에서 "이 지역에서는 쓸 수 없다"로 막혀 있어(2026-11-10 확인) 기기 안 번역을 쓴다.
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class PageTranslator {
  PageTranslator._();
  static final instance = PageTranslator._();

  final _models = OnDeviceTranslatorModelManager();
  OnDeviceTranslator? _translator;

  /// 같은 글은 한 번만 (예고를 넘기며 같은 머리글 · 메뉴가 되풀이된다)
  final _done = <String, String>{};

  static final _ja = TranslateLanguage.japanese.bcpCode;
  static final _ko = TranslateLanguage.korean.bcpCode;

  /// 일본어 · 한국어 모델이 이 기기에 있나
  Future<bool> ready() async => await _models.isModelDownloaded(_ja) && await _models.isModelDownloaded(_ko);

  /// 받기를 이만큼 기다린다 — 인터넷이 끊기면 ML Kit 는 실패하지 않고 연결을 기다려서 (느린 데이터로 60 MB 도 넉넉히)
  static const downloadTimeout = Duration(minutes: 5);

  /// 모델 받기 (약 60 MB, 처음 한 번). 실패하거나 [downloadTimeout] 이 지나면 false.
  /// 멈춘 받기는 기기 안에서 이어지고, 다음에 누르면 받은 모델은 바로 확인된다
  Future<bool> download() async {
    try {
      return await _downloadBoth().timeout(downloadTimeout);
    } on Exception {
      return false; // TimeoutException 도 여기로
    }
  }

  Future<bool> _downloadBoth() async {
    final ja = await _models.downloadModel(_ja, isWifiRequired: false);
    final ko = await _models.downloadModel(_ko, isWifiRequired: false);
    return ja && ko;
  }

  /// [texts] 를 번역 — 원문 → 번역. [onProgress] 는 (끝낸 수, 전체).
  /// [shouldStop] 이 true 면 다음 조각부터 멈추고 거기까지 번역한 것을 돌려준다 (다른 페이지로 감 · 화면을 닫음)
  Future<Map<String, String>> translate(
    List<String> texts, {
    void Function(int done, int total)? onProgress,
    bool Function()? shouldStop,
  }) async {
    final t = _translator ??= OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.japanese,
      targetLanguage: TranslateLanguage.korean,
    );
    final out = <String, String>{};
    for (var i = 0; i < texts.length; i++) {
      if (shouldStop?.call() ?? false) break;
      final s = texts[i];
      final hit = _done[s];
      if (hit != null) {
        out[s] = hit;
      } else {
        try {
          final ko = await t.translateText(s);
          if (ko.isNotEmpty) out[s] = _done[s] = ko;
        } on Exception {
          // 한 조각이 안 되면 그 조각만 원문으로 둔다
        }
      }
      onProgress?.call(i + 1, texts.length);
    }
    return out;
  }
}
