import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';

TextRecognizer? _ja;
TextRecognizer? _ko;

final _hangul = RegExp('[가-힣]');

/// ML Kit 은 파일 경로로 읽는 것이 가장 단순하다 → 앱 임시 폴더에 잠깐 쓰고 지운다
Future<String> readTextOnDevice(Uint8List image) async {
  if (!Platform.isAndroid && !Platform.isIOS) throw UnsupportedError(tr('이 기기에서는 글자 읽기를 못 해요'));
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.img');
  await file.writeAsBytes(image, flush: true);
  try {
    final input = InputImage.fromFilePath(file.path);
    final ja = _ja ??= TextRecognizer(script: TextRecognitionScript.japanese);
    final ko = _ko ??= TextRecognizer(script: TextRecognitionScript.korean);
    // 일본어 모델: 상자 글자(가나 · 한자 · 영숫자). 한국어 모델: 한글 줄만 더한다 (영숫자는 겹치므로)
    final (jaText, koText) = await (
      ja.processImage(input),
      ko.processImage(input).catchError((Object _) => RecognizedText(text: '', blocks: const [])),
    ).wait;
    final lines = <String>[
      for (final b in jaText.blocks)
        for (final l in b.lines) l.text,
    ];
    for (final b in koText.blocks) {
      for (final l in b.lines) {
        if (_hangul.hasMatch(l.text) && !lines.contains(l.text)) lines.add(l.text);
      }
    }
    return lines.join('\n');
  } finally {
    file.delete().ignore();
  }
}
