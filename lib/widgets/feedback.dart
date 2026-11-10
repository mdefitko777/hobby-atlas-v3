// 짧은 알림(토스트) · 목록 아래 여백
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

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
