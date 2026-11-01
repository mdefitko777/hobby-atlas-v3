// 사진 → 글자 (찍어서 찾기 E-11) — 기기 안 ML Kit 글자 인식. 서버 · 인터넷 · 돈이 들지 않는다.
// 일본어 모델(가나 · 한자 · 영숫자) + 한국어 모델(한글) 을 앱에 넣어 둔다 (android/app/build.gradle.kts).
// 안드로이드 · iOS: ML Kit / 웹(미리보기) · 테스트: 읽지 못함 → 화면이 이름 찾기로 이어 준다
library;

import 'dart:typed_data';

import 'text_reader_io.dart' if (dart.library.js_interop) 'text_reader_web.dart' as impl;

/// 사진(JPEG · PNG 바이트) → 읽은 글자 (줄마다 \n). 글자가 없으면 ''
typedef TextReader = Future<String> Function(Uint8List image);

/// 테스트는 가짜 읽기를 넣는다
TextReader textReader = impl.readTextOnDevice;
