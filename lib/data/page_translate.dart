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

  /// 모델 받기 (약 60 MB, 처음 한 번). 실패하면 false
  Future<bool> download() async {
    try {
      final ja = await _models.downloadModel(_ja, isWifiRequired: false);
      final ko = await _models.downloadModel(_ko, isWifiRequired: false);
      return ja && ko;
    } on Exception {
      return false;
    }
  }

  /// [texts] 를 번역 — 원문 → 번역. [onProgress] 는 (끝낸 수, 전체)
  Future<Map<String, String>> translate(List<String> texts, {void Function(int done, int total)? onProgress}) async {
    final t = _translator ??= OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.japanese,
      targetLanguage: TranslateLanguage.korean,
    );
    final out = <String, String>{};
    for (var i = 0; i < texts.length; i++) {
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
