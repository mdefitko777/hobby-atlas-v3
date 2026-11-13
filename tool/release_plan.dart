// 이번 빌드가 릴리스(새 APK)인지 패치(Shorebird 코드 푸시, 다트 코드만)인지 정하고, 끝나면 version.json 을 만든다.
// .github/workflows/android-apk.yml 이 부른다 — 규칙을 워크플로 bash 에 두지 않은 까닭은
// 네트워크 없이 test/release_plan_test.dart 로 확인하려고.
//
//   dart tool/release_plan.dart plan --last prev.json --ref refs/heads/main [--release]
//     → 표준 출력에 key=value 줄 (GITHUB_OUTPUT 에 그대로 붙인다)
//   dart tool/release_plan.dart release-json --build 61 --version 1.1.61 --sha … --major true --apk hobby-atlas.apk
//       --notes notes.txt --notes-zh notes_zh.txt
//   dart tool/release_plan.dart patch-json --last prev.json --number 3 --sha … --notes notes.txt --notes-zh notes_zh.txt
//     → 표준 출력에 version.json
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// release = 새 APK + Shorebird 릴리스 등록, patch = 지난 릴리스에 코드만, none = 앱이 달라진 게 없다
enum BuildMode { release, patch, none }

/// 패치로 보낼 수 없는 것 — 네이티브 · 플러그인 · 앱에 묶이는 파일 · 빌드 방법.
/// config/ 는 pubspec 의 assets 에 든 supabase.json, 워크플로는 플래그(dart-define · Flutter 버전)가 바뀔 수 있어서.
const releasePaths = [
  'android/',
  'assets/',
  'config/',
  'pubspec.yaml',
  'pubspec.lock',
  'shorebird.yaml',
  '.github/workflows/android-apk.yml',
];

/// 패치로 보낼 수 있는 것 (다트 코드)
const patchPaths = ['lib/'];

bool _under(String path, List<String> roots) => roots.any((r) => r.endsWith('/') ? path.startsWith(r) : path == r);

bool needsRelease(String path) => _under(path, releasePaths);
bool canPatch(String path) => _under(path, patchPaths);

class BuildPlan {
  const BuildPlan({
    required this.mode,
    required this.reason,
    this.dryRun = false,
    this.releaseName = '',
    this.releaseBuild = 0,
    this.notesFrom = '',
  });

  final BuildMode mode;

  /// Actions 로그에 남기는 한 줄 (왜 이렇게 정했나)
  final String reason;

  /// true = main 이 아닌 가지: 만들어만 보고 Shorebird · 릴리스 apk-latest 에는 아무것도 올리지 않는다
  final bool dryRun;

  /// 패치가 얹힐 릴리스 (version.json 의 version · build) — 패치는 그 릴리스의 버전 · dart-define 그대로 만들어야 한다
  final String releaseName;
  final int releaseBuild;

  /// Shorebird 가 릴리스를 부르는 이름 (versionName+versionCode)
  String get releaseVersion => releaseBuild > 0 ? '$releaseName+$releaseBuild' : '';

  /// 바뀐 점을 모을 범위의 시작 = 지난 빌드(릴리스든 패치든)의 커밋. 비었으면 워크플로가 최근 커밋 몇 개로 대신한다
  final String notesFrom;

  /// GITHUB_OUTPUT 줄
  String toOutput() => [
    'mode=${mode.name}',
    'dry_run=$dryRun',
    'reason=$reason',
    'release_version=$releaseVersion',
    'release_name=$releaseName',
    'release_build=$releaseBuild',
    'notes_from=$notesFrom',
  ].join('\n');
}

/// [last] = 릴리스 apk-latest 의 version.json (없으면 빈 맵).
/// [sinceRelease] = 지난 릴리스 커밋 뒤로 바뀐 파일, [sinceBuild] = 지난 빌드(패치 포함) 뒤로 바뀐 파일.
/// null = 그 커밋을 이 저장소 기록에서 못 찾았다 (version.json 이 없거나 기록을 다시 쓴 경우).
/// [stale] = 이 커밋이 지난 빌드보다 옛것이다 ([headIsBehind]).
BuildPlan planBuild({
  required bool onMain,
  bool forceRelease = false,
  bool stale = false,
  Map<String, Object?> last = const {},
  List<String>? sinceRelease,
  List<String>? sinceBuild,
}) {
  final patch = last['patch'];
  final patchSha = patch is Map ? '${patch['sha'] ?? ''}' : '';
  final releaseSha = '${last['sha'] ?? ''}';
  // 지난 빌드 커밋을 못 찾으면 릴리스 커밋부터 — 그것도 없으면 빈 값 (최근 커밋 몇 개)
  final notesFrom = sinceBuild != null && patchSha.isNotEmpty ? patchSha : (sinceRelease != null ? releaseSha : '');

  BuildPlan release(String reason, {bool dryRun = false}) =>
      BuildPlan(mode: BuildMode.release, reason: reason, dryRun: dryRun, notesFrom: notesFrom);

  // 시험 가지는 늘 APK 를 만들어 본다 (artifact) — 패치는 얹힐 릴리스가 있어야 해서 시험할 것이 없다
  if (!onMain) return release('시험 빌드 (main 이 아님) — 올리지 않는다', dryRun: true);
  if (forceRelease) return release('수동 실행에서 release 를 골랐다');
  // Actions 에서 옛 실행을 "다시 실행"하면 그때의 커밋으로 돈다 → 그대로 만들면 옛 코드가 새 패치 번호로 폰에 가거나,
  // 옛 실행 번호의 APK 가 apk-latest 를 덮어 그 뒤 패치가 아무 폰에도 닿지 않는다. 그 변경은 이미 나간 빌드에 들어 있다.
  // (main 을 일부러 옛 커밋으로 되돌렸으면 수동 실행 release 로 낸다 — 위 줄)
  if (stale) return BuildPlan(mode: BuildMode.none, reason: '지난 빌드보다 옛 커밋이다 (옛 실행을 다시 실행?)', notesFrom: notesFrom);

  final name = '${last['version'] ?? ''}';
  final build = last['build'] is int ? last['build'] as int : 0;
  final registered = '${last['release_version'] ?? ''}';
  if (registered.isEmpty || name.isEmpty || build <= 0) return release('Shorebird 에 등록된 릴리스가 아직 없다');
  if (registered != '$name+$build') return release('version.json 의 release_version 이 version+build 와 다르다');
  if (sinceRelease == null) return release('지난 릴리스 커밋을 찾지 못했다');

  final native = sinceRelease.where(needsRelease).toList();
  if (native.isNotEmpty) {
    final more = native.length > 3 ? ' 외 ${native.length - 3}' : '';
    return release('패치로 못 보내는 파일이 바뀌었다: ${native.take(3).join(' · ')}$more');
  }

  if ((sinceBuild ?? sinceRelease).any(canPatch)) {
    return BuildPlan(
      mode: BuildMode.patch,
      reason: '다트 코드(lib/)만 바뀌었다',
      releaseName: name,
      releaseBuild: build,
      notesFrom: notesFrom,
    );
  }
  return BuildPlan(mode: BuildMode.none, reason: '지난 빌드 뒤로 앱이 달라진 게 없다', notesFrom: notesFrom);
}

/// 새 APK 를 올린 뒤의 version.json — 앱(lib/update/app_update.dart)이 build 를 보고 ⬇ · 묻기를 정한다.
/// release_version = Shorebird 에 등록된 이름 (이 칸이 있어야 다음 빌드가 패치가 될 수 있다), patch = 아직 없음.
Map<String, Object?> releaseJson({
  required int build,
  required String version,
  required String sha,
  required String builtAt,
  required bool major,
  required String sha256,
  required int size,
  List<String> notes = const [],
  List<String> notesZh = const [],
}) => {
  'build': build,
  'version': version,
  'sha': sha,
  'built_at': builtAt,
  'major': major,
  'apk': 'hobby-atlas.apk',
  'sha256': sha256,
  'size': size,
  'notes': notes,
  'notes_zh': notesZh,
  'release_version': '$version+$build',
  'patch': null,
};

/// 패치를 낸 뒤의 version.json — APK 쪽 칸([last])은 한 글자도 바꾸지 않고 patch 칸만 바꾼다.
/// build 가 그대로여야 이미 그 APK 를 쓰는 폰에 "새 APK" 알림이 뜨지 않는다.
Map<String, Object?> patchJson(
  Map<String, Object?> last, {
  required int number,
  required String sha,
  required String builtAt,
  List<String> notes = const [],
  List<String> notesZh = const [],
}) => {
  ...last,
  'patch': {
    'number': number,
    'build': last['build'],
    'sha': sha,
    'built_at': builtAt,
    'notes': notes,
    'notes_zh': notesZh,
  },
};

/// [sha] 뒤로 바뀐 파일 ([dir] = 저장소, 비우면 지금 폴더). 그 커밋이 기록에 없으면 null.
/// --no-renames: 옮긴 파일은 새 자리만 나와, assets/ 에서 꺼낸 파일(= 자산이 빠짐)을 놓친다.
/// core.quotepath=false: 한글 이름은 `"assets/\354…"` 처럼 따옴표로 싸여 나와 길 비교가 어긋난다.
List<String>? changedSince(String sha, {String? dir}) {
  ProcessResult git(List<String> args) =>
      Process.runSync('git', args, workingDirectory: dir, stdoutEncoding: utf8, stderrEncoding: utf8);
  if (sha.isEmpty || git(['cat-file', '-e', '$sha^{commit}']).exitCode != 0) return null;
  final diff = git(['-c', 'core.quotepath=false', 'diff', '--name-only', '--no-renames', sha, 'HEAD']);
  if (diff.exitCode != 0) return null;
  return const LineSplitter().convert('${diff.stdout}').where((l) => l.trim().isNotEmpty).toList();
}

/// HEAD 가 [sha] 보다 옛 커밋인가 ([sha] 의 조상이고 같은 커밋은 아님). [sha] 를 기록에서 못 찾으면 false.
bool headIsBehind(String sha, {String? dir}) {
  ProcessResult git(List<String> args) => Process.runSync('git', args, workingDirectory: dir);
  if (sha.isEmpty || git(['cat-file', '-e', '$sha^{commit}']).exitCode != 0) return false;
  String rev(String name) => '${git(['rev-parse', '$name^{commit}']).stdout}'.trim();
  return rev('HEAD') != rev(sha) && git(['merge-base', '--is-ancestor', 'HEAD', sha]).exitCode == 0;
}

/// 깨졌거나 없는 version.json = 빈 맵 (→ 릴리스)
Map<String, Object?> _readJson(String? path) {
  final file = File(path ?? '');
  if (!file.existsSync()) return const {};
  try {
    final json = jsonDecode(file.readAsStringSync());
    return json is Map<String, Object?> ? json : const {};
  } on FormatException {
    return const {};
  }
}

/// 바뀐 점 파일 (한 줄에 하나, 워크플로가 git log 로 만든다)
List<String> _readLines(String? path) {
  final file = File(path ?? '');
  if (!file.existsSync()) return const [];
  return file.readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}

void main(List<String> args) {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  String need(String name) {
    final value = option(name);
    if (value == null || value.isEmpty) {
      stderr.writeln('[release_plan] $name 이 없습니다');
      exit(64);
    }
    return value;
  }

  final last = _readJson(option('--last'));
  final now = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';
  const pretty = JsonEncoder.withIndent('  ');
  switch (args.isEmpty ? '' : args.first) {
    case 'plan':
      final patch = last['patch'];
      final patchSha = patch is Map ? '${patch['sha'] ?? ''}' : '';
      final plan = planBuild(
        onMain: option('--ref') == 'refs/heads/main',
        forceRelease: args.contains('--release'),
        stale: headIsBehind(patchSha.isNotEmpty ? patchSha : '${last['sha'] ?? ''}'),
        last: last,
        sinceRelease: changedSince('${last['sha'] ?? ''}'),
        sinceBuild: patch is Map ? changedSince(patchSha) : null,
      );
      stderr.writeln('[release_plan] ${plan.mode.name}${plan.dryRun ? ' (dry-run)' : ''} — ${plan.reason}');
      stdout.writeln(plan.toOutput());
    case 'release-json':
      final apk = File(need('--apk')).readAsBytesSync();
      stdout.writeln(
        pretty.convert(
          releaseJson(
            build: int.parse(need('--build')),
            version: need('--version'),
            sha: need('--sha'),
            builtAt: now,
            major: need('--major') == 'true',
            sha256: '${sha256.convert(apk)}',
            size: apk.length,
            notes: _readLines(option('--notes')),
            notesZh: _readLines(option('--notes-zh')),
          ),
        ),
      );
    case 'patch-json':
      if (last['build'] is! int) {
        stderr.writeln('[release_plan] 패치가 얹힐 version.json 을 읽지 못했습니다');
        exit(66);
      }
      stdout.writeln(
        pretty.convert(
          patchJson(
            last,
            number: int.parse(need('--number')),
            sha: need('--sha'),
            builtAt: now,
            notes: _readLines(option('--notes')),
            notesZh: _readLines(option('--notes-zh')),
          ),
        ),
      );
    default:
      stderr.writeln('usage: dart tool/release_plan.dart plan|release-json|patch-json …');
      exit(64);
  }
}
