// 짧은 알림(토스트) · 오류 글 · 목록 아래 여백
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// 실패 이유 → 화면 글 (고른 언어). 우리가 던진 한국어 글만 보이게 — `'$e'` 는 "FormatException: …" · "Bad state: …" 같은
/// 타입 머리가 붙는다 (2026-11-11 품질 점검). HttpException 은 dart:io 라 (웹 빌드) 글 머리로 뗀다.
/// 던질 때는 한국어로 두고 여기서 번역한다 — 서버가 준 글처럼 표에 없는 글은 그대로 (빠진 번역으로 치지 않게 trData)
String errorText(Object e) => trData(switch (e) {
  FormatException(:final message) => message,
  StateError(:final message) => message,
  UnsupportedError(message: final String m) => m,
  _ => '$e'.replaceFirst(_errorHead, ''),
});

final _errorHead = RegExp(r'^\w*(Exception|Error): ');

/// 짧은 알림(토스트) — 흰 바탕 · 검정 글자, 2.5초 뒤 사라진다. [onUndo]가 있으면 "되돌리기" (P03)
void showToast(BuildContext context, String message, {VoidCallback? onUndo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2500),
        persist: false, // 되돌리기가 있어도 몇 초 뒤 저절로 사라지게
        action: onUndo == null ? null : SnackBarAction(label: tr('되돌리기'), onPressed: onUndo),
      ),
    );
}

/// 목록 맨 아래 여백 — 하단 탭 바 · 카메라 버튼에 가려지지 않게
double navClearance(BuildContext context) => MediaQuery.paddingOf(context).bottom + 100;
