// 앱 업데이트 — GitHub 릴리스 apk-latest 의 version.json(.github/workflows/android-apk.yml 이 만든다)을 보고
//   · 내 빌드보다 새것이면 위 줄에 ⬇ 아이콘 (빨간 점)
//   · 큰 업데이트(major)면 앱을 열 때 한 번만 묻는다 (같은 빌드는 다시 묻지 않음)
//   · 업데이트 → 앱 안에서 받기(진행률) → 안드로이드 설치 창 (ota_update). 처음 한 번 "알 수 없는 앱 설치 허용"
// 내 빌드 번호는 APK 를 만들 때 --dart-define=APP_BUILD 로 넣는다. 0 = 손으로 만든 개발 빌드 → 확인하지 않는다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';

import '../data/blob_store.dart';
import '../json_util.dart';

/// 이 APK 의 빌드 번호 (GitHub Actions 실행 번호)
const appBuild = int.fromEnvironment('APP_BUILD');

/// 릴리스 apk-latest 의 파일들
const updateBase = 'https://github.com/mdefitko777/hobby-atlas-v3/releases/download/apk-latest/';

/// 설정 › 버전 에 보이는 글자
String get appVersionLabel => appBuild > 0 ? '빌드 $appBuild' : '개발 빌드';

/// version.json 한 벌
class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.builtAt,
    required this.major,
    required this.apk,
    required this.sha256,
    required this.size,
    required this.notes,
  });

  final int build;
  final String builtAt;

  /// true = 앱을 열 때 한 번 묻는다, false(커밋에 [minor]) = ⬇ 아이콘만
  final bool major;
  final String apk;
  final String sha256;
  final int size;

  /// 바뀐 점 (커밋 제목, 8개까지)
  final List<String> notes;

  String get sizeLabel => size <= 0 ? '' : '${(size / 1048576).toStringAsFixed(0)} MB';

  static UpdateInfo? fromJson(Object? json) {
    final j = jMap(json);
    final build = jInt(j['build']);
    if (build <= 0) return null;
    return UpdateInfo(
      build: build,
      builtAt: jStr(j['built_at']),
      major: j['major'] != false,
      apk: jStr(j['apk']).isEmpty ? 'hobby-atlas.apk' : jStr(j['apk']),
      sha256: jStr(j['sha256']),
      size: jInt(j['size']),
      notes: jList(j['notes']).whereType<String>().toList(),
    );
  }
}

/// 앱 전체가 함께 보는 한 벌: ⬇ 아이콘 · 설정의 "업데이트 확인" · 업데이트 시트
class AppUpdate extends ChangeNotifier {
  AppUpdate._();
  static final instance = AppUpdate._();

  /// 이 기기에서 업데이트를 할 수 있나 (안드로이드 + CI 가 만든 APK)
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android && appBuild > 0;

  /// 받을 수 있는 새 빌드 (없으면 null)
  UpdateInfo? available;

  /// 받는 중 0–100 (null = 받지 않는 중)
  int? progress;

  /// 마지막 오류 (화면 토스트)
  String error = '';

  DateTime? _lastCheck;
  StreamSubscription<OtaEvent>? _download;

  /// version.json 확인. [force] 가 아니면 한 시간에 한 번. 새 빌드면 [available] 을 채우고 돌려준다.
  Future<UpdateInfo?> check({bool force = false, Future<String?> Function(Uri)? fetch}) async {
    if (!supported && fetch == null) return null;
    final now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < const Duration(hours: 1)) return available;
    _lastCheck = now;
    final uri = Uri.parse('${updateBase}version.json');
    final text = await (fetch ?? _get)(uri);
    if (text == null) return available;
    final info = UpdateInfo.fromJson(_decode(text));
    available = info != null && info.build > appBuild ? info : null;
    notifyListeners();
    return available;
  }

  static Future<String?> _get(Uri uri) async {
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      return res.statusCode == 200 ? utf8.decode(res.bodyBytes) : null;
    } on Object catch (e) {
      debugPrint('[update] $uri → $e');
      return null;
    }
  }

  static const _askedKey = 'update_asked';

  /// 이 빌드를 앱을 열 때 물어볼까 (큰 업데이트 · 아직 안 물어본 빌드)
  Future<bool> shouldAsk(UpdateInfo info) async =>
      info.major && (int.tryParse(await BlobStore.read(_askedKey) ?? '') ?? 0) < info.build;

  Future<void> markAsked(UpdateInfo info) => BlobStore.write(_askedKey, '${info.build}');

  /// 받기 → 설치 창. 진행률은 [progress], 끝나면(설치 창이 뜨면) null.
  void start(UpdateInfo info) {
    if (progress != null) return;
    progress = 0;
    error = '';
    notifyListeners();
    _download = OtaUpdate()
        .execute(
          '$updateBase${info.apk}',
          destinationFilename: 'hobby-atlas.apk',
          sha256checksum: info.sha256.isEmpty ? null : info.sha256,
        )
        .listen(
          (e) {
            switch (e.status) {
              case OtaStatus.DOWNLOADING:
                progress = int.tryParse(e.value ?? '') ?? progress;
              case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
                progress = null; // 안드로이드 설치 창으로
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _fail('"알 수 없는 앱 설치"를 허용해야 업데이트할 수 있어요');
              case OtaStatus.CHECKSUM_ERROR:
                _fail('받은 파일이 깨졌어요 · 다시 시도해 주세요');
              case OtaStatus.ALREADY_RUNNING_ERROR:
                break;
              default:
                _fail('업데이트를 받지 못했어요 (${e.status.name})');
            }
            notifyListeners();
          },
          onError: (Object e) {
            _fail('업데이트를 받지 못했어요');
            notifyListeners();
          },
        );
  }

  void _fail(String message) {
    progress = null;
    error = message;
    _download?.cancel();
  }

  @visibleForTesting
  void debugReset() {
    available = null;
    progress = null;
    error = '';
    _lastCheck = null;
  }
}

Object? _decode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
