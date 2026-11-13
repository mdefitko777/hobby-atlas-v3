// 패치 (Shorebird 코드 푸시) — 새 APK 를 깔지 않고 다트 코드만 받는 작은 업데이트.
//   · 받기 · 적용은 Shorebird 기본값 그대로: 앱을 열 때 뒤에서 받고, 다음에 앱을 새로 열 때(프로세스가 새로 뜰 때) 적용
//   · 여기서는 패치 번호를 읽고(설정 › 버전 `1.1.50 · 패치 3`), "업데이트 확인"을 누르면 그 자리에서 한 번 더 묻는다
// 네이티브 · 플러그인 · 앱에 묶인 파일은 패치로 못 바꾼다 → 그런 변경은 지금처럼 새 APK (app_update.dart).
// Shorebird 로 만든 APK 가 아니면(테스트 · 디버그 · 웹 · 손으로 만든 빌드) 전부 아무것도 하지 않는다.
import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../l10n/l10n.dart';
import 'app_update.dart';

/// 패치를 읽고 받는 곳 — 진짜는 Shorebird 엔진, 테스트는 가짜
abstract class PatchSource {
  /// Shorebird 엔진이 든 빌드인가
  bool get isAvailable;

  /// 지금 돌고 있는 패치 번호 (null = 릴리스 그대로)
  Future<int?> currentPatch();

  /// 다음에 앱을 새로 열 때 돌 패치 번호
  Future<int?> nextPatch();

  /// 서버에 새 패치가 있으면 받아 둔다 (새 패치가 있었으면 true). 받다가 실패하면 예외
  Future<bool> fetch();
}

/// shorebird_code_push 를 부르는 유일한 곳
class ShorebirdPatchSource implements PatchSource {
  final _updater = ShorebirdUpdater();

  @override
  bool get isAvailable => _updater.isAvailable;

  @override
  Future<int?> currentPatch() async => (await _updater.readCurrentPatch())?.number;

  @override
  Future<int?> nextPatch() async => (await _updater.readNextPatch())?.number;

  @override
  Future<bool> fetch() async {
    // 확인이 실패하면(오프라인) 예외 없이 "새 패치 없음"으로 답한다
    if (await _updater.checkForUpdate() != UpdateStatus.outdated) return false;
    // 앱을 켤 때의 자동 받기와 겹치면 update 는 기다리지 않고 그냥 끝난다 (2.0.6 부터) → [AppPatch.check] 가 잠깐 더 본다
    await _updater.update();
    return true;
  }
}

/// `1.1.50 · 패치 3` — 패치가 없으면 버전 그대로
String patchedLabel(String version, int? patch) =>
    patch == null ? version : trf('{version} · 패치 {n}', {'version': version, 'n': patch});

/// 앱 전체가 함께 보는 한 벌: 설정 › 버전 줄 · "업데이트 확인"
class AppPatch extends ChangeNotifier {
  AppPatch({PatchSource? source, this.settle = const Duration(milliseconds: 500)}) : _given = source;
  static final instance = AppPatch();

  final PatchSource? _given;

  /// 받는 중인 패치를 다시 읽어 보는 간격 — 10번까지 (테스트는 0)
  final Duration settle;

  // 처음 쓸 때 한 번 정한다. CI 가 만든 안드로이드 APK 가 아니면 엔진을 찾지도 않는다
  // (ShorebirdUpdater 는 엔진이 없으면 만들 때 콘솔에 긴 안내를 찍는다 → 테스트 로그가 지저분해진다)
  late final PatchSource? _source = _resolve();

  PatchSource? _resolve() {
    try {
      final source = _given ?? (AppUpdate.supported ? ShorebirdPatchSource() : null);
      return source != null && source.isAvailable ? source : null;
    } on Object catch (e) {
      debugPrint('[patch] $e'); // 패치를 못 읽어도 앱은 그대로 열려야 한다
      return null;
    }
  }

  /// 이 빌드가 패치를 받을 수 있나
  bool get available => _source != null;

  /// 지금 돌고 있는 패치 (null = 릴리스 그대로 · 아직 안 읽음)
  int? current;

  /// 다음에 앱을 새로 열 때 돌 패치
  int? next;

  /// 마지막 "업데이트 확인"에서 패치를 받다가 실패했다
  bool failed = false;

  /// 받아 둔 패치가 앱을 다시 열기를 기다린다 (되돌린 패치가 빠지기를 기다리는 때도 같다)
  bool get waiting => available && next != current;

  /// 설정 › 버전 글자 · 받아 둔 패치의 글자
  String get versionLabel => patchedLabel(appVersionLabel, current);
  String get nextLabel => patchedLabel(appVersionLabel, next);

  /// 기기에 적힌 패치 번호를 다시 읽는다 (인터넷을 쓰지 않는다)
  Future<void> refresh() async {
    final source = _source;
    if (source == null) return;
    try {
      final (now, later) = await (source.currentPatch(), source.nextPatch()).wait;
      if (now == current && later == next) return;
      current = now;
      next = later;
      notifyListeners();
    } on Object catch (e) {
      debugPrint('[patch] $e');
    }
  }

  /// "업데이트 확인" — 서버에 새 패치가 있으면 지금 받는다. 받았으면 [waiting]
  Future<void> check() async {
    final source = _source;
    if (source == null) return;
    failed = false;
    var found = false;
    try {
      found = await source.fetch();
    } on Object catch (e) {
      failed = true;
      debugPrint('[patch] $e');
    }
    await refresh();
    // 새 패치가 있다는데 아직 안 보인다 = 켤 때의 자동 받기가 받는 중 → 잠깐 기다려 본다.
    // 끝내 안 보이면 못 받은 것 — 받는 중 · 못 받은 것을 「최신」이라고 하지 않는다
    for (var i = 0; found && !waiting && i < 10; i++) {
      await Future<void>.delayed(settle);
      await refresh();
    }
    if (found && !waiting) failed = true;
  }
}
