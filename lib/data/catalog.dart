// Gunpula 상품 카탈로그 — 기기 캐시를 먼저 보여 주고, 뒤에서 GitHub Pages 의 새 데이터를 받는다.
//   1) split/manifest.json (176 B) 의 updated_at · total · content_hash 가 같으면 아무것도 받지 않는다 (manifestSignature)
//   2) 다르면 보조 파일(auxFiles) → split/kits-<채널>.json 5개를 받아 compute() 에서 가벼운 모양으로 바꿔 저장
// 처음 설치(캐시 없음)면 [firstDownload] — 앱은 셸 대신 받는 화면(lib/screens/w_first_run_screen.dart)을 보인다.
//   진행 = 받은 파일 [filesDone] / [filesTotal] · 받은 바이트 [bytesReceived]
import '../format.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../channels.dart' show channelCovers, lineCovers;
import '../json_util.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'blob_store.dart';
import 'gundam_atlas.dart' show atlasBoxartFile, atlasKitMsFile, atlasMsFile;
import 'gunpula.dart';
import 'user_store.dart';
import '../logic/lego_scope.dart';

enum CatalogPhase { empty, loading, ready, error }

class Catalog extends ChangeNotifier {
  Catalog._() {
    UserStore.instance.listPrice = listPriceKrw; // 구매가를 안 적은 상품 = 정가 × 환율
  }
  static final instance = Catalog._();

  static const _kitsKey = 'catalog_kits.json';
  static const _metaKey = 'catalog_meta.json';

  /// 상품 매핑 규칙(lib/data/gunpula.dart)을 바꾸면 +1 → 기기 캐시를 버리고 다시 받아 정리한다
  /// 4: 건담 박스 아트(data/atlas/gundam-boxart.json)를 대표 사진으로
  /// 5: 사진 없는 상품의 참고 그림(imageRef) · 魂 라인 이름(Hi-Resolution Model · 超合金 …)
  /// 6: 세부 시리즈(subline — HGUC · HGCE · ver. A.N.I.M.E. …)
  /// 7: 베이 상품 형태(subline — 스타터 · 부스터 · 랜덤 부스터 · 세트 · 런처 · 도구)
  /// 8: 이름으로 등급 코드 바로잡기(옵션 파츠 · HG · FM · Fate 미니 · 인형) · 이름 HTML 엔티티
  /// 9: 레고 이름 앞에 세트 번호 · 상품 번호를 찾기 낱말에
  /// 10: 레고 보기 범위용 세트 번호 · 등급 코드
  /// 11: 피규어 칸의 평면 굿즈(아크릴 스탠드 · 스티커 · 브로마이드 · 액자 아트)를 굿즈로
  /// 12: 베이 상세 사진 맨 앞에 공식 파츠 상세 그림
  /// 13: goodsmile.com 상세 사진을 다시 보이기 (점검이 끝남)
  /// 14: 공식 조립 설명서 번호 (manualId)
  /// 15: 찾기 글자(blob)의 전각 영숫자를 반각으로 (ＨＷＳ Ｖｅｒ．Ｋａ → hws ver.ka)
  /// 17: 찾기 낱말의 중국어(names.zh · labels.zh · search_zh)를 뒤로 모으고 그 자리(zhKeywordsFrom)
  static const mapVersion = 17;

  CatalogPhase phase = CatalogPhase.empty;
  String error = '';

  /// 첫 다운로드 중 진행 문구 ("건담 받는 중 …")
  String progress = '';

  /// 처음 설치라 캐시가 없어 받는 중 (실패해도 true — 받는 화면에서 다시 시도)
  bool firstDownload = false;

  /// 첫 다운로드: 받은 파일 수 / 받을 파일 수 (manifest + 보조 파일 + 채널별 상품)
  int filesDone = 0;
  int get filesTotal => 1 + auxFiles.length + franchiseIds.length;

  /// 첫 다운로드: 지금까지 받은 바이트
  int bytesReceived = 0;

  /// 테스트: 가짜 인터넷 (package:http/testing.dart MockClient)
  @visibleForTesting
  static http.Client? debugClient;

  /// 새 데이터를 받을 때마다 +1 (앱 셸이 화면을 다시 불러온다)
  int version = 0;

  /// 마지막 [version] 변화가 뒤에서 알아서 받은 것인가 (켤 때 · 돌아올 때 · 알림 상품 찾기).
  /// 앱 셸은 이때 지금 보고 있는 탭을 바로 다시 만들지 않는다 (검색어 · 스크롤을 지킨다).
  /// false = 사람이 고른 것 (당겨서 새로 고침 · 지금 새로 받기 · 레고 범위)
  bool lastChangeQuiet = false;

  List<Kit> kits = const [];
  Map<String, Kit> byId = const {};
  Map<String, Object?> manifest = const {};
  List<Map<String, Object?>> _slim = const [];
  final Map<String, Object?> _aux = {};

  /// 최근 추가 = 이 날짜 이후 처음 들어온 상품 (데이터의 가장 새 날짜 기준 3일)
  String recentSince = '';
  String recentUntil = '';

  /// 데이터 기준일 (manifest updated_at)
  String get updatedAt => jStr(manifest['updated_at']);

  Future<void>? _loading;

  /// 지금 받는 중인 refresh (없으면 null) — [checkForNewData] 가 끝날 때까지 기다린다
  Future<bool>? _inflight;

  /// manifest 를 마지막으로 받아 본 때 (같아서 아무것도 안 받았어도)
  DateTime? _checkedAt;

  /// 화면이 데이터를 쓰기 전에 기다린다. 캐시가 있으면 바로, 없으면 첫 다운로드가 끝날 때까지.
  Future<void> ensureLoaded() async {
    if (kits.isNotEmpty) return;
    await (_loading ??= _start());
    if (kits.isEmpty) {
      _loading = null; // 다시 시도할 수 있게
      throw CatalogException(error.isEmpty ? tr('상품 데이터를 받지 못했어요.') : error);
    }
  }

  Future<void> _start() async {
    await _loadCache();
    if (kits.isEmpty) {
      firstDownload = true;
      filesDone = 0;
      bytesReceived = 0;
      notifyListeners();
      await refresh();
    } else {
      // 캐시로 먼저 보여 주고 뒤에서 새로 받는다
      refresh(quiet: true).ignore();
    }
  }

  Future<void> _loadCache() async {
    final meta = await BlobStore.read(_metaKey);
    final slim = await BlobStore.read(_kitsKey);
    if (meta == null || slim == null) return;
    try {
      // 예전 규칙으로 정리한 캐시 (예: 굿즈가 전부 가샤폰이던 때) → 쓰지 않고 새로 받는다
      final m = jsonDecode(meta) as Map<String, Object?>;
      if (m['map_version'] != mapVersion) return;
      // 그때 받은 채널 목록이 지금과 다르면(새 채널 — 예: 마도카) 새로 받는다. 옛 앱은 manifest 에 있는 새 채널을
      // 건너뛰고도 manifest 를 그대로 적어 두어, 새 앱이 "같은 데이터" 로 보고 그 채널을 끝내 받지 않았다
      if (jList(m['franchises']).join(',') != franchiseIds.join(',')) return;
      manifest = m['manifest'] as Map<String, Object?>? ?? const {};
      _slim = await compute(_decodeSlim, slim);
      _rebuild();
    } on Object catch (e) {
      debugPrint('[catalog] 캐시를 못 읽음: $e');
    }
  }

  /// 목록을 만든 때의 레고 범위 — 다른 기기에서 바꿔 동기화되면 다시 거른다
  LegoScope? _builtScope;
  bool _watchingUser = false;

  void _watchLegoScope() {
    if (_watchingUser) return;
    _watchingUser = true;
    UserStore.instance.addListener(() {
      if (_builtScope != null && _builtScope != UserStore.instance.legoScope) refilter();
    });
  }

  /// 레고 범위를 바꾸면 보이는 목록(kits)만 다시 거른다 — Kit 은 다시 만들지 않는다
  void refilter() {
    if (_all.isEmpty) return;
    _applyScope();
    version++;
    lastChangeQuiet = false;
    notifyListeners();
  }

  /// 받은 상품 전부 (레고 범위와 상관없이) — byId 도 이것으로 만든다
  List<Kit> _all = const [];

  /// "최근 정식 세트" 범위 밖의 레고 (전부일 때도 계산해 둔다)
  Set<String> _legoOutOfScope = const {};

  /// 이 상품이 지금 레고 범위 때문에 목록에서 빠져 있는가 (좋아요 · 구매함 · 상세는 그대로 보인다)
  bool hiddenByScope(String id) => _builtScope != LegoScope.all && _legoOutOfScope.contains(id);

  void _applyScope() {
    _builtScope = UserStore.instance.legoScope;
    kits = _builtScope == LegoScope.all || _legoOutOfScope.isEmpty
        ? _all
        : [
            for (final k in _all)
              if (!_legoOutOfScope.contains(k.id)) k,
          ];
  }

  /// 테스트: 앱을 새로 켠 것처럼 메모리만 비운다 (기기 캐시는 그대로)
  @visibleForTesting
  void debugForget() {
    _slim = [];
    _loading = null;
    _checkedAt = null;
    _seenElsewhere = _seenElsewhereChecked = '';
    manifest = const {};
    _rebuild();
  }

  /// 테스트: 네트워크 없이 실제 모양의 데이터를 바로 넣는다
  @visibleForTesting
  void debugSet({required List<Map<String, Object?>> slim, required Map<String, Object?> aux}) {
    _slim = slim;
    _aux
      ..clear()
      ..addAll(aux);
    _rebuild();
  }

  /// 테스트: 새 데이터를 받은 것처럼 [version] 만 올린다
  @visibleForTesting
  void debugBumpVersion({bool quiet = true}) {
    version++;
    lastChangeQuiet = quiet;
    notifyListeners();
  }

  /// 받는 화면의 "다시 시도"
  Future<void> retry() => ensureLoaded().catchError((Object _) {});

  /// 테스트: 받는 화면 상태를 손으로
  @visibleForTesting
  void debugFirstRun({required bool on, int files = 0, int bytes = 0, String step = '', String error = ''}) {
    firstDownload = on;
    filesDone = files;
    bytesReceived = bytes;
    progress = step;
    this.error = error;
    phase = error.isEmpty ? CatalogPhase.loading : CatalogPhase.error;
    notifyListeners();
  }

  /// 보조 파일(JSON) — 필요한 화면이 처음 부를 때 푼다
  Future<Object?> aux(String file) async {
    if (_aux.containsKey(file)) return _aux[file];
    final text = await BlobStore.read(auxKey(file));
    Object? v;
    if (text != null) {
      try {
        v = jsonDecode(text);
      } on FormatException {
        v = null;
      }
    }
    if (v == null) {
      // 웹 미리보기처럼 캐시가 없으면 바로 받는다
      final t = await _get('data/$file');
      if (t != null) v = jsonDecode(t);
    }
    if (v != null) _aux[file] = v; // 못 받았으면 기억하지 않는다 (다음에 다시)
    return v;
  }

  /// 이미 푼 보조 파일 (아직이면 null) — 기다릴 수 없는 곳(설정 목록의 글자)에서
  Object? auxLoaded(String file) => _aux[file];

  /// 보조 파일의 기기 캐시 이름 — `atlas/…` 처럼 폴더가 붙은 이름도 한 파일로 (`/` → `__`)
  static String auxKey(String file) => 'aux_${file.replaceAll('/', '__')}';

  /// 알림 확인(runCatalogCheck — 뒤 작업 · 앱)이 마지막으로 다 본 manifest 의 서명 (notify_state.json last_manifest)
  String _seenElsewhere = '';

  /// 그 서명으로 이미 한 번 확인했다 (같은 서명으로 manifest 를 또 받지 않게)
  String _seenElsewhereChecked = '';

  /// 알림 확인이 본 manifest 를 알려 준다 (notify_store.dart). 이 목록보다 새것이면 true — 다음 [checkForNewData] 는
  /// 간격을 기다리지 않는다 (「새 상품」 알림은 그 manifest 로 만든 것이라, 이 기기 목록에는 아직 그 상품이 없다)
  bool noteManifestSeen(String signature) {
    if (signature.isEmpty) return false;
    _seenElsewhere = signature;
    return _behind;
  }

  bool get _behind =>
      kits.isNotEmpty &&
      _seenElsewhere.isNotEmpty &&
      _seenElsewhere != manifestSignature(manifest) &&
      _seenElsewhere != _seenElsewhereChecked;

  /// 새 데이터가 있는지 한 번 더 본다 — 이미 받는 중이면 그것이 끝날 때까지 기다리고, [maxAge] 안에 manifest 를
  /// 본 적이 있으면 받지 않는다 (알림 확인이 더 새 manifest 를 봤으면 바로). 바뀌었으면 true.
  ///   · 앱으로 돌아올 때 · 알림 확인이 새 manifest 를 봤을 때 (알림 확인과 같은 20분 간격, notify_store.dart)
  ///   · 알림 · 받은 링크의 상품이 이 기기 목록에 없을 때 (api.dart fetchKitsByIds)
  Future<bool> checkForNewData({required Duration maxAge}) async {
    if (_inflight case final f?) return f;
    if (kits.isEmpty) return false; // 처음 받기는 ensureLoaded 가 맡는다
    final behind = _behind;
    final at = _checkedAt;
    if (!behind && at != null && DateTime.now().difference(at) < maxAge) return false;
    _seenElsewhereChecked = _seenElsewhere;
    return refresh(quiet: true);
  }

  /// 새 데이터 확인. [force] = manifest 가 같아도 다시 받기 (설정 › 지금 새로 받기).
  /// [quiet] = 뒤에서 알아서 받는 것 ([lastChangeQuiet])
  ///
  /// 뒤에서 받는 중에 사람이 고르면(당겨서 새로 고침 · 지금 새로 받기) 그 받기를 기다려 결과를 돌려주고, 받은 것은
  /// 사람이 고른 것으로 친다 (지금 탭도 바로 다시). [force] 인데 그 받기가 같은 manifest 였으면 다시 받는다.
  Future<bool> refresh({bool force = false, bool quiet = false}) async {
    for (var f = _inflight; f != null; f = _inflight) {
      if (quiet) return false;
      _loud = true;
      final changed = await f; // whenComplete 뒤라 여기서는 _inflight 가 비어 있다 (그 사이 또 시작했으면 다시 기다림)
      if (changed || !force) return changed;
    }
    _loud = !quiet;
    return _inflight = _refresh(force: force).whenComplete(() => _inflight = null);
  }

  /// 지금 받기를 사람이 골랐다 (처음부터, 또는 뒤에서 받는 중에 [refresh]) → [lastChangeQuiet] = false
  bool _loud = false;

  Future<bool> _refresh({required bool force}) async {
    if (kits.isEmpty) {
      phase = CatalogPhase.loading;
      progress = tr('새 데이터 확인 중');
      notifyListeners();
    }
    try {
      final mText = await _get('data/split/manifest.json', count: true);
      if (mText == null) throw CatalogException(tr('인터넷에 연결하지 못했어요.'));
      _fileDone();
      final m = jsonDecode(mText) as Map<String, Object?>;
      _checkedAt = DateTime.now();
      // updated_at · total (+ content_hash — 같은 날 파일만 바뀐 갱신도 받는다)
      final same = manifestSignature(m) == manifestSignature(manifest);
      if (same && kits.isNotEmpty && !force) return false;

      final aux = <String, String>{};
      for (final f in auxFiles) {
        _step(trf('보조 데이터 {file}', {'file': f}));
        final t = await _get('data/$f', count: true);
        if (t != null) aux[f] = t;
        _fileDone();
      }
      final slim = <Map<String, Object?>>[];
      // manifest 에 없는 채널은 아직 Gunpula 에 파일이 없다 (새 채널을 앱이 먼저 알 때) — 건너뛴다
      final listed = jMap(m['franchises']);
      for (final f in franchiseIds) {
        if (listed.isNotEmpty && !listed.containsKey(f)) {
          _fileDone();
          continue;
        }
        _step(trf('{channel} 상품 받는 중', {'channel': tr(_label[f] ?? f)}));
        final raw = await _get('data/split/kits-$f.json', count: true);
        if (raw == null) throw CatalogException(trf('{channel} 상품을 받지 못했어요.', {'channel': tr(_label[f] ?? f)}));
        _fileDone();
        slim.addAll(
          await compute(mapKitsJob, {
            'raw': raw,
            'grades': aux['grades.json'] ?? '{}',
            'firstSeen': aux['kit-first-seen.json'] ?? '{}',
            if (f == 'gundam' && aux[atlasBoxartFile] != null) 'boxart': aux[atlasBoxartFile]!,
            if (f == 'gundam' && aux[atlasKitMsFile] != null) 'kitMs': aux[atlasKitMsFile]!, // 사진 없는 상품의 참고 그림
            if (f == 'gundam' && aux[atlasMsFile] != null) 'ms': aux[atlasMsFile]!,
          }),
        );
      }
      _step(tr('정리하는 중'));
      final slimText = await compute(jsonEncode, slim);
      // first-seen · 등급 · 박스 아트는 상품에 녹였으니 따로 두지 않는다
      for (final e in aux.entries) {
        if (mapOnlyAuxFiles.contains(e.key)) continue;
        await BlobStore.write(auxKey(e.key), e.value);
        _aux.remove(e.key);
      }
      for (final f in retiredAuxFiles) {
        await BlobStore.delete(auxKey(f));
      }
      await BlobStore.write(_kitsKey, slimText);
      await BlobStore.write(
        _metaKey,
        jsonEncode({
          'manifest': m,
          'map_version': mapVersion,
          'franchises': franchiseIds,
          'fetched_at': DateTime.now().toIso8601String(),
        }),
      );
      manifest = m;
      _slim = slim;
      _rebuild();
      version++;
      lastChangeQuiet = !_loud;
      return true;
    } on Object catch (e) {
      error = e is CatalogException ? e.message : trf('데이터를 정리하다 멈췄어요: {error}', {'error': e});
      debugPrint('[catalog] $error');
      _checkedAt = null; // 다 받지 못했다 — 다음 확인은 간격을 기다리지 않는다
      if (kits.isEmpty) phase = CatalogPhase.error;
      return false;
    } finally {
      progress = '';
      notifyListeners();
    }
  }

  void _fileDone() {
    if (!firstDownload || kits.isNotEmpty) return;
    filesDone++;
    notifyListeners();
  }

  final _bytesTick = Stopwatch();

  void _addBytes(int n) {
    if (!firstDownload || kits.isNotEmpty) return;
    bytesReceived += n;
    // 너무 자주 다시 그리지 않게 (0.1초에 한 번쯤)
    if (!_bytesTick.isRunning || _bytesTick.elapsedMilliseconds > 100) {
      _bytesTick
        ..reset()
        ..start();
      notifyListeners();
    }
  }

  void _step(String s) {
    if (kits.isNotEmpty) return; // 뒤에서 받는 중엔 문구를 바꾸지 않는다
    progress = s;
    notifyListeners();
  }

  /// slim → Kit (최근 추가 · 이번 달은 오늘 날짜로 다시 계산)
  void _rebuild() {
    _watchLegoScope();
    var latest = '';
    for (final s in _slim) {
      final f = s['firstSeen'];
      if (f is String && f.compareTo(latest) > 0) latest = f;
    }
    recentUntil = latest;
    recentSince = latest.isEmpty
        ? ''
        : DateTime.parse(latest).subtract(const Duration(days: 2)).toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final monthPrefix = monthKey(now);
    // 레고는 설정 › 레고 범위 (최근 정식 세트 · 전부) — 상품은 다 만들어 두고(byId: 좋아요 · 구매함 · 알림이
    // 범위 밖 상품도 찾는다) 둘러보는 목록(kits)만 거른다
    final outOfScope = <String>{};
    for (final s in _slim) {
      if (s['franchiseId'] == 'lego' && !legoRecentSet(s)) outOfScope.add('${s['id']}');
    }
    _legoOutOfScope = outOfScope;
    final list = [for (final s in _slim) Kit.fromSlim(s, recentSince: recentSince, monthPrefix: monthPrefix)]
      // 발매일 새것부터, 발매일 없는 것은 뒤로
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.firstSeen.compareTo(a.firstSeen);
      });
    _all = list;
    byId = {for (final k in list) k.id: k};
    _applyScope();
    phase = CatalogPhase.ready;
    if (list.isNotEmpty) firstDownload = false;
    error = '';
    // 기다리는 쪽(받은 링크 · 알림 → fetchKitsByIds)이 오류를 받지 않게 여기서 삼킨다 (네트워크로 받은 파일이 깨졌을 때 등)
    _aliasesLoad = _applyAliases().catchError((Object e) => debugPrint('[catalog] 옛 id 를 못 붙임: $e'));
    _loadRates().ignore();
    _loadChannelCovers().ignore();
  }

  /// 채널 대표 그림 (atlas-groups.json `channels.<id>.image`, 공식 그림) → channels.dart channelCovers
  /// + 종류별 도감 카드 그림 (`line_covers.<채널>.<등급 코드>`, 공식 로고 · 대표 그림) → lineCovers
  Future<void> _loadChannelCovers() async {
    final groups = jMap(await aux('atlas-groups.json'));
    final ch = jMap(groups['channels']);
    for (final e in ch.entries) {
      final img = resolveAsset(jMap(e.value)['image']);
      if (img.isNotEmpty) channelCovers[e.key] = img;
    }
    final lines = jMap(groups['line_covers']);
    for (final f in lines.entries) {
      final byLabel = lineCovers[f.key] = {};
      for (final e in jMap(f.value).entries) {
        final img = resolveAsset(jMap(e.value)['image']);
        // 베이 라인(BX · UX · CX)은 코드가 곧 이름, 건담 굿즈 묶음(GUNDAM_MERCH)의 그림은 가샤폰 로고라
        // 종류 도감의 "가샤폰" 카드로, 나머지는 등급 코드 → 앱의 라인 이름
        final label = f.key == 'beyblade' ? e.key : (e.key == 'GUNDAM_MERCH' ? '가샤폰' : lineLabel(e.key, '', ''));
        if (img.isNotEmpty) byLabel[label] = img;
      }
    }
    if (ch.isNotEmpty || lines.isNotEmpty) notifyListeners();
  }

  /// 1엔 = ? 원 (data/exchange-rates.json · Frankfurter, 매일). 못 받았으면 대략값
  double jpyToKrw = 9.0;

  Future<void> _loadRates() async {
    final r = jMap(jMap(await aux('exchange-rates.json'))['rates_to_krw'])['JPY'];
    if (r is num && r > 0) jpyToKrw = r.toDouble();
  }

  /// 정가를 원으로 (정가가 없으면 null)
  int? listPriceKrw(String id) => switch (byId[id]?.priceJpy) {
    final int p => (p * jpyToKrw).round(),
    _ => null,
  };

  /// 구매함 한 상품에 쓴 돈 — 적어 둔 구매가, 없으면 정가 × 환율 (estimate = true)
  ({int? krw, bool estimate}) paidOf(Kit k) => switch (UserStore.instance.entry(k.id)?['purchase_price']) {
    final num v => (krw: v.toInt(), estimate: false),
    _ => (krw: k.purchaseKrw ?? listPriceKrw(k.id), estimate: k.purchaseKrw == null),
  };

  /// 합쳐진 kit_id → 남은 kit_id (data/kit-aliases.json). 옛 id 로도 찾히게 하고, 내 기록을 옮긴다
  Map<String, String> aliases = const {};

  Future<void> _aliasesLoad = Future.value();

  /// 옛 id 가 byId 에 붙으면 끝난다 (오류를 내지 않는다). 캐시를 읽은 뒤 따로 붙어서, 앱을 막 켠 때
  /// 받은 링크 · 알림의 옛 id 는 이것을 기다린 뒤에 찾는다
  Future<void> get aliasesReady => _aliasesLoad;

  Future<void> _applyAliases() async {
    final raw = await aux('kit-aliases.json');
    final m = raw is Map<String, Object?> ? raw['aliases'] : null;
    if (m is! Map<String, Object?> || m.isEmpty) return;
    String resolve(String id) {
      var cur = id;
      for (var i = 0; i < 8 && m[cur] is String; i++) {
        cur = m[cur]! as String; // a → b → c 도 끝까지
      }
      return cur;
    }

    final map = {for (final k in m.keys) k: resolve(k)};
    aliases = map;
    byId = {
      ...byId,
      for (final e in map.entries)
        if (!byId.containsKey(e.key) && byId[e.value] != null) e.key: byId[e.value]!,
    };
    UserStore.instance.applyAliases(map);
  }

  static const _label = {
    'gundam': '건담',
    'beyblade': '베이블레이드',
    'pokemon': '포켓몬',
    'armored_core': '아머드 코어',
    'fate': 'Fate',
    'madoka': '마도카 마기카',
    'lego': '레고',
  };

  /// 받기 — Pages 가 안 되면 raw.githubusercontent. [count] = 첫 다운로드 바이트를 센다
  Future<String?> _get(String path, {bool count = false}) async {
    for (final base in [gunpulaBase, gunpulaRawBase]) {
      final client = debugClient ?? http.Client();
      try {
        final res = await client
            .send(http.Request('GET', Uri.parse('$base$path')))
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 200) {
          final bytes = BytesBuilder(copy: false);
          // 한 조각을 60초 넘게 못 받으면 멈춘 것으로 본다 (큰 파일도 천천히 오는 동안은 기다린다)
          await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
            bytes.add(chunk);
            if (count) _addBytes(chunk.length);
          }
          final text = utf8.decode(bytes.takeBytes());
          return base == gunpulaRawBase ? rawAssetPaths(text) : text;
        }
        await res.stream.drain<void>();
        debugPrint('[catalog] $base$path → HTTP ${res.statusCode}');
      } on Exception catch (e) {
        debugPrint('[catalog] $base$path → $e');
      } finally {
        if (debugClient == null) client.close();
      }
    }
    return null;
  }
}

List<Map<String, Object?>> _decodeSlim(String text) => [
  for (final e in jsonDecode(text) as List<Object?>)
    if (e is Map<String, Object?>) e,
];

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}
