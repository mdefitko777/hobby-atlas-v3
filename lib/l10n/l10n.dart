// 화면 언어 — 한국어(기본) · 중국어(간체). 화면 글은 한국어가 원본이고, 중국어 화면에서는 번역 표(zh_text.dart)로 바꾼다.
//
// 쓰는 법 (AGENTS.md "쓰는 법", docs/terms.md):
//   Text(tr('구매함'))                       — 고정 글
//   Text(trf('새 상품 {n}개', {'n': count}))  — 값이 들어가는 글: 자리 이름은 {영문}, 번역에도 같은 자리
// 번역 표에 없는 글은 한국어 그대로 나온다 (debug 에서는 missingZh 에 모인다 — test/l10n_coverage_test.dart).
// 언어는 기기에만 저장한다 (BlobStore 'lang.json'): 두 사람이 각자 고르고, 백그라운드 알림 확인도 같은 파일을 읽는다.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/blob_store.dart';
import 'zh_text.dart';

enum AppLang { ko, zh }

class L10n {
  L10n._();

  static const storeKey = 'lang.json';
  static final ValueNotifier<AppLang> notifier = ValueNotifier(AppLang.ko);

  static AppLang get current => notifier.value;
  static bool get isZh => notifier.value == AppLang.zh;

  /// MaterialApp 의 locale — 중국어 화면은 한자를 중국어 글꼴 모양으로 그린다
  static Locale get locale => isZh ? const Locale('zh', 'CN') : const Locale('ko', 'KR');
  static const supportedLocales = [Locale('ko', 'KR'), Locale('zh', 'CN')];

  /// 앱 시작 · 백그라운드 확인 처음에 한 번 (파일이 없거나 깨졌으면 한국어)
  static Future<void> load() async {
    try {
      final raw = await BlobStore.read(storeKey);
      final code = raw == null ? '' : (jsonDecode(raw) as Map)['lang'];
      notifier.value = code == 'zh' ? AppLang.zh : AppLang.ko;
    } catch (_) {
      notifier.value = AppLang.ko;
    }
  }

  static Future<void> set(AppLang lang) async {
    if (notifier.value == lang) return;
    notifier.value = lang;
    await BlobStore.write(storeKey, jsonEncode({'lang': lang.name}));
  }

  /// 테스트 · 미리보기용 (저장하지 않음)
  @visibleForTesting
  static void debugSet(AppLang lang) => notifier.value = lang;
}

/// debug 실행 중 번역 표에 없던 한국어 글 (테스트가 빠진 번역을 찾는 데 쓴다)
final Set<String> missingZh = {};

/// 고정 화면 글 — 중국어 화면이면 번역, 없으면 한국어 그대로
String tr(String ko) {
  if (!L10n.isZh || ko.isEmpty) return ko;
  final zh = zhText[ko];
  if (zh != null) return zh;
  if (kDebugMode && _hasHangul(ko)) missingZh.add(ko);
  return ko;
}

/// 값이 들어가는 글 — `{이름}` 자리를 [args] 로 채운다 (번역에도 같은 이름의 자리가 있다)
String trf(String ko, Map<String, Object?> args) {
  var s = tr(ko);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  return s;
}

/// 언어마다 다른 값 고르기 (단위 · 순서가 크게 다를 때)
T byLang<T>({required T ko, required T zh}) => L10n.isZh ? zh : ko;

final _hangul = RegExp(r'[가-힣]');
bool _hasHangul(String s) => _hangul.hasMatch(s);
