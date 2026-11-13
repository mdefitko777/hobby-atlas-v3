// 릴리스(새 APK)냐 패치(코드 푸시)냐 — tool/release_plan.dart 의 규칙 (.github/workflows/android-apk.yml 이 쓴다)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/release_plan.dart';

/// Shorebird 에 등록된 릴리스 1.1.60 이 나가 있는 version.json
Map<String, Object?> _released({Map<String, Object?>? patch}) => {
  'build': 60,
  'version': '1.1.60',
  'sha': 'r60',
  'release_version': '1.1.60+60',
  'patch': patch,
};

void main() {
  test('패치로 못 보내는 길 · 보낼 수 있는 길', () {
    for (final p in [
      'android/app/build.gradle.kts',
      'assets/gp/kits/a.webp',
      'config/supabase.json',
      'pubspec.yaml',
      'pubspec.lock',
      'shorebird.yaml',
      '.github/workflows/android-apk.yml',
    ]) {
      expect(needsRelease(p), isTrue, reason: p);
      expect(canPatch(p), isFalse, reason: p);
    }
    expect(canPatch('lib/update/app_patch.dart'), isTrue);
    expect(needsRelease('lib/update/app_patch.dart'), isFalse);
    // 앱에 안 들어가는 것 — 어느 쪽도 아니다. 이름이 비슷한 파일에 속지 않는다
    for (final p in ['docs/terms.md', 'test/a_test.dart', 'tool/release_plan.dart', 'README.md', 'pubspec.yaml.bak']) {
      expect(needsRelease(p) || canPatch(p), isFalse, reason: p);
    }
  });

  test('다트 코드만 바뀌면 패치 — 지난 릴리스의 버전 · 빌드 번호 그대로', () {
    final plan = planBuild(onMain: true, last: _released(), sinceRelease: ['lib/a.dart', 'test/a_test.dart']);
    expect(plan.mode, BuildMode.patch);
    expect(plan.dryRun, isFalse);
    expect(plan.releaseVersion, '1.1.60+60');
    expect(plan.releaseName, '1.1.60');
    expect(plan.releaseBuild, 60);
    expect(plan.notesFrom, 'r60');
    expect(plan.toOutput(), contains('mode=patch\n'));
    expect(plan.toOutput(), contains('release_version=1.1.60+60\n'));
  });

  test('네이티브 · 자산 · pubspec · 워크플로가 바뀌면 릴리스 (다트 코드가 같이 바뀌어도)', () {
    for (final p in ['android/app/src/main/AndroidManifest.xml', 'assets/app_icon.png', 'pubspec.lock']) {
      final plan = planBuild(onMain: true, last: _released(), sinceRelease: ['lib/a.dart', p]);
      expect(plan.mode, BuildMode.release, reason: p);
      expect(plan.reason, contains(p));
      expect(plan.releaseVersion, isEmpty, reason: '릴리스의 버전은 워크플로가 실행 번호로 새로 정한다');
    }
  });

  test('패치가 나간 뒤: 릴리스부터 본 변경으로 릴리스를 정하고, 바뀐 점은 지난 패치부터', () {
    final last = _released(patch: {'number': 2, 'build': 60, 'sha': 'p2'});
    // 지난 패치 뒤로 다트 코드가 또 바뀜 → 패치 3
    var plan = planBuild(
      onMain: true,
      last: last,
      sinceRelease: ['lib/a.dart', 'lib/b.dart'],
      sinceBuild: ['lib/b.dart'],
    );
    expect(plan.mode, BuildMode.patch);
    expect(plan.notesFrom, 'p2');
    // 앞서 실패한 릴리스 빌드의 네이티브 변경이 남아 있으면, 이번 푸시가 다트뿐이어도 릴리스
    plan = planBuild(
      onMain: true,
      last: last,
      sinceRelease: ['android/a.kt', 'lib/b.dart'],
      sinceBuild: ['lib/b.dart'],
    );
    expect(plan.mode, BuildMode.release);
    expect(plan.notesFrom, 'p2');
    // 지난 패치 뒤로 앱이 그대로 (문서만 · 다시 실행) → 아무것도 안 만든다
    plan = planBuild(onMain: true, last: last, sinceRelease: ['lib/a.dart'], sinceBuild: ['docs/terms.md']);
    expect(plan.mode, BuildMode.none);
    // 지난 패치 커밋을 못 찾으면 릴리스부터 본 변경으로
    plan = planBuild(onMain: true, last: last, sinceRelease: ['lib/a.dart']);
    expect(plan.mode, BuildMode.patch);
    expect(plan.notesFrom, 'r60');
  });

  test('Shorebird 릴리스가 아직 없으면 · 지난 릴리스 커밋을 못 찾으면 릴리스', () {
    // 옛 version.json (release_version 없음) = 처음 전환할 때
    var plan = planBuild(
      onMain: true,
      last: {'build': 50, 'version': '1.1.50', 'sha': 'r50'},
      sinceRelease: ['lib/a.dart'],
    );
    expect(plan.mode, BuildMode.release);
    expect(plan.notesFrom, 'r50');
    expect(planBuild(onMain: true, sinceRelease: ['lib/a.dart']).mode, BuildMode.release); // version.json 없음
    plan = planBuild(onMain: true, last: _released()); // 기록을 다시 써서 커밋이 없다
    expect(plan.mode, BuildMode.release);
    expect(plan.notesFrom, isEmpty);
    // 손으로 고쳐 어긋난 version.json 은 믿지 않는다
    plan = planBuild(
      onMain: true,
      last: {..._released(), 'release_version': '1.1.59+59'},
      sinceRelease: ['lib/a.dart'],
    );
    expect(plan.mode, BuildMode.release);
  });

  test('수동 실행 release = 다트 코드만 바뀌어도 릴리스', () {
    final plan = planBuild(onMain: true, forceRelease: true, last: _released(), sinceRelease: ['lib/a.dart']);
    expect(plan.mode, BuildMode.release);
    expect(plan.dryRun, isFalse);
  });

  test('옛 실행을 다시 실행 (지난 빌드보다 옛 커밋) = 아무것도 안 만든다 — 옛 코드가 새 패치로 나가지 않게', () {
    final last = _released(patch: {'number': 2, 'build': 60, 'sha': 'p2'});
    // 거꾸로 본 차이에는 다트 코드도 네이티브도 보인다 — 그래도 패치 · 릴리스가 아니다
    for (final changed in [
      ['lib/a.dart'],
      ['lib/a.dart', 'android/a.kt'],
    ]) {
      final plan = planBuild(onMain: true, stale: true, last: last, sinceRelease: changed, sinceBuild: changed);
      expect(plan.mode, BuildMode.none, reason: '$changed');
      expect(plan.releaseVersion, isEmpty);
    }
    // main 을 일부러 되돌렸을 때의 길: 수동 실행 release
    expect(planBuild(onMain: true, stale: true, forceRelease: true, last: last).mode, BuildMode.release);
    // 시험 가지는 main 의 빌드와 견주지 않는다
    final trial = planBuild(onMain: false, stale: true, last: last);
    expect(trial.mode, BuildMode.release);
    expect(trial.dryRun, isTrue);
  });

  test('main 이 아닌 가지 = 늘 올리지 않는 시험 빌드 (dry-run) — release 를 골라도', () {
    for (final force in [false, true]) {
      final plan = planBuild(onMain: false, forceRelease: force, last: _released(), sinceRelease: ['lib/a.dart']);
      expect(plan.mode, BuildMode.release);
      expect(plan.dryRun, isTrue);
      expect(plan.toOutput(), contains('dry_run=true\n'));
    }
  });

  test('version.json: 릴리스가 쓴 것을 다음 빌드가 읽어 패치로 정하고, 패치는 APK 쪽 칸을 건드리지 않는다', () {
    final apk = releaseJson(
      build: 61,
      version: '1.1.61',
      sha: 'r61',
      builtAt: '2026-11-13T00:00:00Z',
      major: false,
      sha256: 'ab',
      size: 9,
      notes: ['a'],
      notesZh: ['甲'],
    );
    expect(apk['release_version'], '1.1.61+61');
    expect(apk['patch'], isNull);
    expect(apk['apk'], 'hobby-atlas.apk');
    var plan = planBuild(onMain: true, last: apk, sinceRelease: ['lib/a.dart']);
    expect(plan.mode, BuildMode.patch);
    expect(plan.releaseVersion, '1.1.61+61');

    final patched = patchJson(apk, number: 1, sha: 'p1', builtAt: '2026-11-14T00:00:00Z', notes: ['b']);
    expect({...patched}..remove('patch'), {...apk}..remove('patch'));
    expect(patched['patch'], {
      'number': 1,
      'build': 61,
      'sha': 'p1',
      'built_at': '2026-11-14T00:00:00Z',
      'notes': ['b'],
      'notes_zh': <String>[],
    });
    // 다음 패치는 같은 릴리스에, 바뀐 점은 패치 1 뒤부터
    plan = planBuild(
      onMain: true,
      last: patched,
      sinceRelease: ['lib/a.dart', 'lib/b.dart'],
      sinceBuild: ['lib/b.dart'],
    );
    expect(plan.mode, BuildMode.patch);
    expect(plan.releaseVersion, '1.1.61+61');
    expect(plan.notesFrom, 'p1');
  });

  test('바뀐 파일 읽기: 자산을 다른 폴더로 옮겨도 · 한글 이름이어도 자산 변경으로 잡힌다', () {
    final repo = Directory.systemTemp.createTempSync('release_plan_');
    addTearDown(() => repo.deleteSync(recursive: true));
    String git(List<String> args) {
      final r = Process.runSync('git', [
        ...['-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'commit.gpgsign=false', '-c', 'core.autocrlf=false'],
        ...args,
      ], workingDirectory: repo.path);
      expect(r.exitCode, 0, reason: 'git ${args.join(' ')}: ${r.stderr}');
      return '${r.stdout}'.trim();
    }

    void write(String path, String text) => File('${repo.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    git(['init', '-q']);
    write('lib/a.dart', 'void a() {}\n');
    write('assets/moved.txt', '같은 내용이라 git 이 옮김으로 본다\n' * 20);
    write('assets/한글.txt', '1\n');
    git(['add', '-A']);
    git(['commit', '-q', '-m', 'release']);
    final release = git(['rev-parse', 'HEAD']);

    // 다트 코드만 → 패치
    write('lib/a.dart', 'void a() {}\nvoid b() {}\n');
    git(['commit', '-q', '-am', 'dart']);
    expect(changedSince(release, dir: repo.path), ['lib/a.dart']);

    // 자산을 앱 밖으로 옮김 (새 자리만 보이면 놓친다)
    git(['mv', 'assets/moved.txt', 'moved.txt']);
    git(['commit', '-q', '-m', 'move']);
    var changed = changedSince(release, dir: repo.path)!;
    expect(changed, contains('assets/moved.txt'));
    expect(
      planBuild(onMain: true, last: {..._released(), 'sha': release}, sinceRelease: changed).mode,
      BuildMode.release,
    );

    // 한글 이름의 자산
    final moved = git(['rev-parse', 'HEAD']);
    write('assets/한글.txt', '2\n');
    git(['commit', '-q', '-am', 'asset']);
    changed = changedSince(moved, dir: repo.path)!;
    expect(changed, ['assets/한글.txt']);
    expect(changed.any(needsRelease), isTrue);

    // 기록에 없는 커밋 · 빈 값 = 모른다 (→ 릴리스)
    expect(changedSince('0123456789abcdef0123456789abcdef01234567', dir: repo.path), isNull);
    expect(changedSince('', dir: repo.path), isNull);

    // 옛 커밋에서 다시 돌 때만 "뒤처졌다" — 같은 커밋 · 더 새 커밋 · 모르는 커밋은 아니다
    final head = git(['rev-parse', 'HEAD']);
    expect(headIsBehind(release, dir: repo.path), isFalse);
    expect(headIsBehind(head, dir: repo.path), isFalse);
    expect(headIsBehind('0123456789abcdef0123456789abcdef01234567', dir: repo.path), isFalse);
    expect(headIsBehind('', dir: repo.path), isFalse);
    git(['checkout', '-q', '--detach', moved]); // Actions "다시 실행" = 그때의 커밋
    expect(headIsBehind(head, dir: repo.path), isTrue);
    expect(headIsBehind(release, dir: repo.path), isFalse);
  });

  test('워크플로가 돌기 시작하는 길(on.push.paths)에 릴리스 · 패치 길이 모두 있다', () {
    final yaml = File('.github/workflows/android-apk.yml').readAsStringSync();
    final paths = RegExp(r"paths: \[(.*)\]").firstMatch(yaml)![1]!;
    for (final p in [...releasePaths, ...patchPaths]) {
      expect(paths, contains("'${p.endsWith('/') ? '$p**' : p}'"), reason: '$p 가 바뀌어도 빌드가 돌지 않는다');
    }
  });

  group('워크플로', () {
    // 단계 하나 = "      - " 로 시작하는 덩어리 (윈도우에서 CRLF 로 받은 파일도 같게 읽는다)
    final yaml = File('.github/workflows/android-apk.yml').readAsStringSync().replaceAll('\r\n', '\n');
    final steps = yaml.split(RegExp(r'\n      - '));
    String stepWith(String text) => steps.singleWhere((s) => s.contains(text), orElse: () => fail('단계 없음: $text'));

    // `shorebird <what> android …` 명령 한 줄 (줄 끝 \ 로 이은 것까지)
    String command(String what) {
      final step = stepWith('shorebird $what android');
      final from = step.indexOf('shorebird $what android');
      return RegExp(r'^(?:.*\\\n)*.*').firstMatch(step.substring(from))![0]!;
    }

    test('시험 가지는 Shorebird · apk-latest 어디에도 올리지 않는다', () {
      const mainOnly = "github.ref == 'refs/heads/main'";
      // 패치 · 릴리스 파일 올리기는 단계의 if 가 main 으로 막는다
      expect(stepWith('shorebird patch android'), contains("mode == 'patch' && $mainOnly"));
      final uploads = steps.where((s) => s.contains('gh release upload') || s.contains('gh release create')).toList();
      expect(uploads, hasLength(2));
      for (final step in uploads) {
        expect(RegExp(r'\n\s+if: (.*)').firstMatch(step)![1], contains(mainOnly), reason: step.split('\n').first);
      }
      // 릴리스 빌드는 가지 이름을 직접 보고 --dry-run (계획이 틀려도)
      final release = stepWith('shorebird release android');
      expect(
        release,
        contains('if [ "\$DRY_RUN" = "true" ] || [ "\$GITHUB_REF" != "refs/heads/main" ]; then dry="--dry-run"; fi'),
      );
      expect(command('release'), endsWith(r'$dry || {'));
    });

    test('패치는 릴리스와 같은 dart-define · 아이콘 글꼴 플래그로 만든다 (다르면 Shorebird 가 exit 64 로 멈춘다)', () {
      Set<String> defines(String cmd) => {for (final m in RegExp(r'--dart-define=(\w+)=').allMatches(cmd)) m[1]!};
      final release = command('release');
      final patch = command('patch');
      expect(defines(release), {'APP_BUILD', 'APP_VERSION'});
      expect(defines(patch), defines(release));
      for (final cmd in [release, patch]) {
        expect(cmd, contains('--no-tree-shake-icons'));
        expect(cmd, contains('--build-name='));
        expect(cmd, contains('--build-number='));
      }
      // 패치는 version.json 에 적힌 그 릴리스에만 얹는다 (latest 로 고르지 않는다)
      expect(patch, contains(r'--release-version="$REL"'));
      expect(patch, contains('--track=stable'));
    });
  });
}
