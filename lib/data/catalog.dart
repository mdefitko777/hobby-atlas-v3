// Gunpula 상품 카탈로그 — 기기 캐시를 먼저 보여 주고, 뒤에서 GitHub Pages 의 새 데이터를 받는다.
//   1) split/manifest.json 의 updated_at · total · content_hash 가 같으면 상품은 받지 않는다 (manifestSignature).
//      그래도 manifest `files`(보조 파일마다 지문)가 달라진 보조 파일은 그것만 받는다 ([auxHashes])
//   2) 다르면 보조 파일(auxFiles) → split/kits-<채널>.json 을 받아 compute() 에서 가벼운 모양으로 바꿔 저장
// 받는 것은 내 채널뿐 ([wantedChannels]) — 고르지 않은 채널은 상품 파일도 그 채널 보조 파일(건담 도감 · 베이 부품 · 태그 도감)도
// 받지 않는다. 채널을 더하면 그 채널 것만 받고([syncChannels]), 빼면 기기에서 지운다 (2026-11-14, 전에는 7채널 약 50 MB 를 다 받았다).
// 지우는 채널에서 내가 적어 둔 상품만은 따로 남긴다 ([_kept] — 컬렉션 · 알림이 그 상품을 계속 찾는다)
// 처음 설치(캐시 없음)면 [firstDownload] — 앱은 셸 대신 받는 화면(lib/screens/w_first_run_screen.dart)을 보인다.
//   진행 = 받은 파일 [filesDone] / [filesTotal] · 받은 바이트 [bytesReceived]
import '../format.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../channels.dart' show channelCovers, channelOf, channelsWithData, lineCovers;
import '../json_util.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'blob_store.dart';
import 'gundam_atlas.dart' show atlasBoxartFile, atlasKitMsFile, atlasMsFile;
import 'gunpula.dart';
import 'tag_atlas.dart' show friendaFile, mezastarIntlFile, mezastarJpFile;
import 'user_store.dart';
import '../logic/image_size.dart' show ThumbIndex, parseThumbIndex;
import '../logic/kit_rules.dart' show isJpTwin;
import '../logic/lego_scope.dart';

enum CatalogPhase { empty, loading, ready, error }

class Catalog extends ChangeNotifier {
  Catalog._() {
    UserStore.instance.listPrice = listPriceKrw; // 구매가를 안 적은 상품 = 한국 정가, 없으면 일본 정가 × 환율
  }
  static final instance = Catalog._();

  static const _kitsKey = 'catalog_kits.json';
  static const _metaKey = 'catalog_meta.json';
  static const _keptKey = 'catalog_kept.json';

  /// 뒤 사진 미리 받기(lib/background/image_prefetch.dart)가 카탈로그를 풀지 않고 표지 주소 · 판만 읽는다
  static const cacheKitsKey = _kitsKey;
  static const cacheMetaKey = _metaKey;

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
  /// 18: 파는 나라(한국 · 일본) · 같은 바코드 짝(twin) · 짝의 가격
  /// 19: 닌텐도 등급 · 한국 가게(BNKR · 아카데미) 브랜드, 두 나라 출처 상품(both)도 같은 바코드의 한국 상품과 한 카드로
  static const mapVersion = 19;

  CatalogPhase phase = CatalogPhase.empty;
  String error = '';

  /// 첫 다운로드 중 진행 문구 ("건담 받는 중 …")
  String progress = '';

  /// 처음 설치라 캐시가 없어 받는 중 (실패해도 true — 받는 화면에서 다시 시도)
  bool firstDownload = false;

  /// 첫 다운로드: 받은 파일 수 / 받을 파일 수 (manifest + 보조 파일 + 내 채널 상품)
  int filesDone = 0;
  int get filesTotal {
    final w = wantedChannels;
    return 1 + auxFilesFor(w).length + w.length;
  }

  /// 첫 다운로드: 지금까지 받은 바이트
  int bytesReceived = 0;

  /// 테스트: 가짜 인터넷 (package:http/testing.dart MockClient)
  @visibleForTesting
  static http.Client? debugClient;

  /// 새 데이터를 받을 때마다 +1 (앱 셸이 화면을 다시 불러온다)
  int version = 0;

  /// 마지막 [version] 변화가 뒤에서 알아서 받은 것인가 (켤 때 · 돌아올 때 · 알림 상품 찾기).
  /// 앱 셸은 이때 지금 보고 있는 탭을 바로 다시 만들지 않는다 (검색어 · 스크롤을 지킨다).
  /// false = 사람이 고른 것 (당겨서 새로 고침 · 지금 새로 받기)
  bool lastChangeQuiet = false;

  List<Kit> kits = const [];
  Map<String, Kit> byId = const {};
  Map<String, Object?> manifest = const {};
  List<Map<String, Object?>> _slim = const [];

  /// 기기 목록(_slim)에 없는 채널의 상품 중 내가 적어 둔 것 (UserStore.markedKitIds) — id → slim.
  /// 고르지 않은 채널은 받지 않아, 채널을 빼거나 옛 7채널 캐시에서 올라오면 좋아요 · 구매함 · 예약 · 알림이 기댄 상품이
  /// 사라졌다 (2026-11-14). 그 상품만 따로 두어 byId(컬렉션 · 알림 · 상세 · 친구 비교)에는 있고, 둘러보는 목록(kits)에는 없다
  Map<String, Map<String, Object?>> _kept = {};
  List<Kit> _keptKits = const [];
  bool _keptDirty = false;

  /// 기기 목록에 든 채널 (meta `franchises`) — 받기를 마친 채널만
  List<String> _have = const [];

  /// 받을 채널 = 내 채널 중 앱이 아는 것 · Gunpula 에 파일이 있는 것 (manifest `franchises`, 모르면 앱이 아는 것 전부).
  /// 순서는 franchiseIds
  List<String> get wantedChannels => _wantedFor(manifest);

  List<String> _wantedFor(Map<String, Object?> m) {
    final mine = UserStore.instance.myChannels;
    final listed = jMap(m['franchises']);
    return [
      for (final f in franchiseIds)
        if (mine.contains(f) && (listed.isEmpty || listed.containsKey(f))) f,
    ];
  }

  /// 기기 목록이 있다 (manifest 를 한 번은 받았다). 채널을 하나도 안 골랐거나 아직 상품이 없는 채널만 고르면
  /// kits 가 비어도 받기는 끝난 것 — kits.isEmpty 로 보면 받기 실패로 여겨 첫 받기 화면이 돌았다
  bool get _ready => manifest.isNotEmpty || kits.isNotEmpty;

  /// 채널을 더해 받는 중인 그 채널 이름 · 받은 바이트 (화면의 「불러오는 중」 자리, LoadingView)
  String channelStep = '';
  int channelBytes = 0;

  /// 더한 채널을 못 받았을 때 (채널 → 오류 문장) — 그 채널을 보는 화면이 오류 + 다시 시도
  final Map<String, String> _channelErrors = {};
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
    if (_ready) return;
    await (_loading ??= _start());
    if (!_ready) {
      _loading = null; // 다시 시도할 수 있게
      throw CatalogException(error.isEmpty ? tr('상품 데이터를 받지 못했어요.') : error);
    }
  }

  Future<void> _start() async {
    // 받을 채널은 내 채널로 정한다 — 저장 파일을 읽기 전이면 처음 값(건담 · 베이 · 포켓몬)으로 받아 버린다
    await UserStore.instance.load();
    await _loadCache();
    if (!_ready) {
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
    await _readKept();
    final meta = await BlobStore.read(_metaKey);
    final slim = await BlobStore.read(_kitsKey);
    if (meta == null || slim == null) return;
    try {
      final m = jsonDecode(meta) as Map<String, Object?>;
      // 버리거나 내 채널에 맞추기 전에, 고르지 않은 채널(옛 앱은 7채널을 다 받아 두었다)에서 내가 적어 둔 상품을 건진다
      await _keepFromCache(slim, m['franchises'] is List ? jList(m['franchises']).whereType<String>() : franchiseIds);
      // 예전 규칙으로 정리한 캐시 (예: 굿즈가 전부 가샤폰이던 때) → 쓰지 않고 새로 받는다
      if (m['map_version'] != mapVersion) return;
      // 채널 목록이 없는 옛 캐시는 새로 받는다. 있으면 그 채널들이 든 목록 — 내 채널과 다르면 뒤에서 그만큼만
      // 더 받거나 지운다 ([syncChannels])
      if (m['franchises'] is! List) return;
      _have = [
        for (final f in jList(m['franchises']))
          if (f is String && franchiseIds.contains(f)) f,
      ];
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
      _channelsMaybeChanged();
    });
  }

  bool _syncQueued = false;

  /// 받기가 끝났다. 그 사이 내 채널이 바뀌었으면(받는 중에 뺀 채널 · 더한 채널) 이어서 맞춘다 — 받기 전에 정한 채널로
  /// 끝나, 다음 확인(몇 시간 뒤)까지 뺀 채널이 기기에 남거나 더한 채널이 비어 있었다
  void _settled() {
    _inflight = null;
    _channelsMaybeChanged();
  }

  /// 내 채널이 바뀌었으면(채널 관리 · 다른 기기에서 맞춤) 더한 채널을 받고 뺀 채널을 지운다.
  /// 한 번에 여러 채널을 바꿔도 한 번만 (microtask 로 모은다)
  void _channelsMaybeChanged() {
    // 못 받은 채널은 빼고 본다 — 넣으면 받기가 끝날 때마다 다시 불러 멈추지 않는다 (다시 시도는 그 채널 화면에서)
    final pending = [
      for (final f in wantedChannels)
        if (_have.contains(f) || !_channelErrors.containsKey(f)) f,
    ];
    if (_syncQueued || manifest.isEmpty || listEquals(pending, _have)) return;
    _syncQueued = true;
    scheduleMicrotask(() {
      _syncQueued = false;
      syncChannels().ignore();
    });
  }

  /// 레고 범위를 바꾸면 보이는 목록(kits)만 다시 거른다 — Kit 은 다시 만들지 않는다.
  /// 조용히(quiet): 범위는 검색 탭 레고 채널에서 고르고 그 화면이 스스로 다시 부른다 — 앱 셸이 보고 있는 탭을
  /// 다시 만들면 고른 채널이 전체로 돌아간다 (2026-11-12). 다른 탭 · 다른 기기에서 맞춘 것은 떠날 때 다시 만든다
  void refilter() {
    if (_all.isEmpty) return;
    _applyScope();
    version++;
    lastChangeQuiet = true;
    notifyListeners();
  }

  /// 받은 상품 전부 (레고 범위와 상관없이) — byId 도 이것으로 만든다
  List<Kit> _all = const [];

  /// "최근 정식 세트" 범위 밖의 레고 (전부일 때도 계산해 둔다)
  Set<String> _legoOutOfScope = const {};

  /// 이 상품이 지금 레고 범위 때문에 목록에서 빠져 있는가 (좋아요 · 구매함 · 상세는 그대로 보인다)
  bool hiddenByScope(String id) => _builtScope != LegoScope.all && _legoOutOfScope.contains(id);

  /// 한국 · 일본 짝(같은 바코드)은 둘러보는 목록에 한국 쪽 하나만 — 주인이 한국에 있어서. 일본 쪽도 byId 에는
  /// 남아 좋아요 · 구매함 · 링크 · 알림이 그대로 찾는다 (lib/marks.dart 가 둘 중 어느 쪽 기록이든 한 카드에)
  void _applyScope() {
    _builtScope = UserStore.instance.legoScope;
    final lego = _builtScope != LegoScope.all && _legoOutOfScope.isNotEmpty;
    kits = [
      for (final k in _all)
        if (!isJpTwin(k) && !(lego && _legoOutOfScope.contains(k.id))) k,
    ];
  }

  /// 테스트: 앱을 새로 켠 것처럼 메모리만 비운다 (기기 캐시는 그대로)
  @visibleForTesting
  void debugForget() {
    _slim = [];
    _kept = {};
    _keptDirty = false;
    _have = const [];
    _channelErrors.clear();
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
    if (v == null && _auxWanted(file)) {
      // 웹 미리보기처럼 캐시가 없으면 바로 받는다 (고르지 않은 채널의 파일은 받지 않는다 — 그 화면은 빈 · 오류 상태)
      final t = await _get('data/$file');
      if (t != null) v = jsonDecode(t);
    }
    if (v != null) _aux[file] = v; // 못 받았으면 기억하지 않는다 (다음에 다시)
    return v;
  }

  bool _auxWanted(String file) => switch (auxChannel[file]) {
    final c? => UserStore.instance.myChannels.contains(c),
    null => true,
  };

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
      _ready &&
      _seenElsewhere.isNotEmpty &&
      _seenElsewhere != manifestSignature(manifest) &&
      _seenElsewhere != _seenElsewhereChecked;

  /// 새 데이터가 있는지 한 번 더 본다 — 이미 받는 중이면 그것이 끝날 때까지 기다리고, [maxAge] 안에 manifest 를
  /// 본 적이 있으면 받지 않는다 (알림 확인이 더 새 manifest 를 봤으면 바로). 바뀌었으면 true.
  ///   · 앱으로 돌아올 때 · 알림 확인이 새 manifest 를 봤을 때 (알림 확인과 같은 20분 간격, notify_store.dart)
  ///   · 알림 · 받은 링크의 상품이 이 기기 목록에 없을 때 (api.dart fetchKitsByIds)
  Future<bool> checkForNewData({required Duration maxAge}) async {
    if (_inflight case final f?) return f;
    if (!_ready) return false; // 처음 받기는 ensureLoaded 가 맡는다
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
    return _inflight = _refresh(force: force).whenComplete(_settled);
  }

  /// 지금 받기를 사람이 골랐다 (처음부터, 또는 뒤에서 받는 중에 [refresh]) → [lastChangeQuiet] = false
  bool _loud = false;

  Future<bool> _refresh({required bool force}) async {
    if (!_ready) {
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
      if (same && _ready && !force) {
        final auxChanged = await _refreshAux(m);
        // 판이 같아도 내 채널이 바뀌었으면 그만큼 (앱을 끈 사이 다른 기기에서 채널을 바꿨을 때)
        return await _syncChannels() || auxChanged;
      }
      final hashes = auxHashes(m);
      final want = _wantedFor(m);

      final aux = <String, String>{};
      for (final f in auxFilesFor(want)) {
        _step(trf('보조 데이터 {file}', {'file': f}));
        final t = await _get('data/$f', count: true);
        if (t != null) aux[f] = t;
        // 못 받았거나 받은 내용이 지문과 다른 파일은 지문을 적지 않는다 → 다음 확인에서 그 파일만 다시
        if (t == null || !auxMatches(t, hashes[f])) hashes.remove(f);
        _fileDone();
      }
      final slim = <Map<String, Object?>>[];
      // manifest 에 없는 채널은 아직 Gunpula 에 파일이 없다 (새 채널을 앱이 먼저 알 때) — want 에서 빠져 있다
      for (final f in want) {
        if (_reusable(f, m)) {
          // 이 채널 파일은 그대로다 — 기기 목록의 그 채널 상품을 다시 쓴다 (건담 12 MB 를 매일 받지 않게)
          slim.addAll(_slim.where((s) => s['franchiseId'] == f));
          _fileDone();
          continue;
        }
        _step(trf('{channel} 상품 받는 중', {'channel': _label(f)}));
        final raw = await _get('data/split/kits-$f.json', count: true);
        if (raw == null) throw CatalogException(trf('{channel} 상품을 받지 못했어요.', {'channel': _label(f)}));
        _fileDone();
        slim.addAll(await compute(mapKitsJob, _mapMsg(f, raw, aux)));
      }
      _step(tr('정리하는 중'));
      final slimText = await compute(jsonEncode, slim);
      // 등급 · first-seen 은 상품에 녹였어도 기기에 둔다 — 나중에 채널을 더할 때 다시 받지 않게 (메모리에는 두지 않는다)
      for (final e in aux.entries) {
        await BlobStore.write(auxKey(e.key), e.value);
        _aux.remove(e.key);
      }
      await _dropAux(want);
      for (final f in retiredAuxFiles) {
        await BlobStore.delete(auxKey(f));
      }
      // 빠지는 채널(받는 사이에 뺀 것)의 내 상품을 먼저 적어 둔다 — 목록을 쓴 뒤에 앱이 꺼져도 잃지 않게
      _keepLeaving(_slim.where((s) => !want.contains(s['franchiseId'])));
      await _saveKept(slim);
      await BlobStore.write(_kitsKey, slimText);
      _have = want;
      await _writeMeta(m.containsKey('files') ? {...m, 'files': hashes} : m);
      _slim = slim;
      _channelErrors.clear();
      _rebuild();
      version++;
      lastChangeQuiet = !_loud;
      return true;
    } on Object catch (e) {
      error = e is CatalogException ? e.message : trf('데이터를 정리하다 멈췄어요: {error}', {'error': e});
      debugPrint('[catalog] $error');
      _checkedAt = null; // 다 받지 못했다 — 다음 확인은 간격을 기다리지 않는다
      if (!_ready) phase = CatalogPhase.error;
      return false;
    } finally {
      progress = '';
      notifyListeners();
    }
  }

  /// 새 manifest [m] 에서도 채널 [f] 의 상품을 기기 것 그대로 써도 되는가: 기기에 있고, 채널 파일 지문
  /// (manifest `franchise_hashes`, Gunpula 2026-11-14 계약)과 매핑에 녹인 보조 파일 지문(등급 · 건담 박스 아트 ·
  /// 참고 그림)이 지난번과 같을 때. 지문이 없는 manifest(그전 Gunpula · raw)는 늘 다시 받는다
  bool _reusable(String f, Map<String, Object?> m) {
    if (!_have.contains(f)) return false;
    final now = jMap(m['franchise_hashes'])[f];
    if (now is! String || now.isEmpty || now != jMap(manifest['franchise_hashes'])[f]) return false;
    final files = auxHashes(m);
    final before = auxHashes(manifest);
    final deps = [
      'grades.json',
      if (f == 'gundam') ...[atlasBoxartFile, atlasKitMsFile, atlasMsFile],
    ];
    return deps.every((d) => files[d] != null && files[d] == before[d]);
  }

  /// mapKitsJob 에 넘길 것 — 건담만 박스 아트 · 참고 그림
  static Map<String, String> _mapMsg(String f, String raw, Map<String, String> aux) => {
    'raw': raw,
    'grades': aux['grades.json'] ?? '{}',
    'firstSeen': aux['kit-first-seen.json'] ?? '{}',
    if (f == 'gundam' && aux[atlasBoxartFile] != null) 'boxart': aux[atlasBoxartFile]!,
    if (f == 'gundam' && aux[atlasKitMsFile] != null) 'kitMs': aux[atlasKitMsFile]!, // 사진 없는 상품의 참고 그림
    if (f == 'gundam' && aux[atlasMsFile] != null) 'ms': aux[atlasMsFile]!,
  };

  /// 내 채널이 아닌 채널의 보조 파일을 기기 · 메모리에서 지운다. 메자스타 · 프렌다 태그를 적어 둔 사람은 태그 도감 파일만
  /// 기기에 남긴다 — 컬렉션 전체의 내 태그가 그 파일로 이름 · 그림을 찾는다 (다시 받지는 않는다, [_kept] 와 같은 까닭)
  Future<void> _dropAux(List<String> want) async {
    final me = UserStore.instance;
    final tags = me.tagOwned.isNotEmpty || me.tagLiked.isNotEmpty;
    for (final e in auxChannel.entries) {
      if (want.contains(e.value)) continue;
      _aux.remove(e.key);
      if (tags && const {mezastarIntlFile, mezastarJpFile, friendaFile}.contains(e.key)) continue;
      await BlobStore.delete(auxKey(e.key));
    }
  }

  Future<void> _readKept() async {
    final text = await BlobStore.read(_keptKey);
    if (text == null) return;
    try {
      _kept = {
        for (final s in _decodeSlim(text))
          if (s['id'] case final String id) id: s,
      };
    } on Object catch (e) {
      debugPrint('[catalog] 따로 둔 상품을 못 읽음: $e');
    }
  }

  /// 기기 캐시 글 [text](채널 [had] 가 든 목록)에서 내 채널이 아닌 채널의 내가 적어 둔 상품을 [_kept] 에.
  /// 큰 글(옛 7채널 약 50 MB)은 다른 isolate 에서 풀고 고른 몇 개만 받아 온다
  Future<void> _keepFromCache(String text, Iterable<String> had) async {
    final mine = UserStore.instance.myChannels;
    if (had.every(mine.contains)) return;
    final ids = UserStore.instance.markedKitIds.difference(_kept.keys.toSet());
    if (ids.isEmpty) return;
    try {
      _keepLeaving(await compute(_pickSlim, (text: text, ids: ids, mine: [...mine])));
      await _saveKept();
    } on Object catch (e) {
      debugPrint('[catalog] 옛 캐시에서 내 상품을 못 건짐: $e');
    }
  }

  /// 기기 목록에서 빠지는 상품 중 내가 적어 둔 것을 [_kept] 에 옮긴다 (채널을 뺄 때 · 받은 목록이 줄 때)
  void _keepLeaving(Iterable<Map<String, Object?>> leaving) {
    final marked = UserStore.instance.markedKitIds;
    for (final s in leaving) {
      if (s['id'] case final String id when marked.contains(id)) {
        _kept[id] = s;
        _keptDirty = true;
      }
    }
  }

  /// [_kept] 을 정리해 기기에 쓴다 — 새 기기 목록 [next] 에 든 상품(채널을 다시 골라 새 데이터가 이긴다) · 적어 둔 것을
  /// 다 뗀 상품은 뺀다
  Future<void> _saveKept([List<Map<String, Object?>> next = const []]) async {
    final marked = UserStore.instance.markedKitIds;
    final here = {for (final s in next) s['id']};
    final before = _kept.length;
    _kept.removeWhere((id, _) => here.contains(id) || !marked.contains(id));
    if (!_keptDirty && _kept.length == before) return;
    _keptDirty = false;
    await BlobStore.write(_keptKey, jsonEncode(_kept.values.toList()));
  }

  /// 내 채널에 맞춘다: 더한 채널은 그 채널 상품 · 보조 파일만 받고, 뺀 채널은 목록 · 기기에서 지운다 (인터넷 없이).
  /// 받는 중이면 끝난 뒤에. 바뀌었으면 true. 더한 채널을 못 받으면 그 채널만 빠진 채로 두고 오류를 남긴다
  Future<bool> syncChannels() async {
    for (var f = _inflight; f != null; f = _inflight) {
      await f;
    }
    if (!_ready || manifest.isEmpty) return false;
    return _inflight = _syncChannels().whenComplete(_settled);
  }

  /// [ids] 중 받을 채널이 아직 기기에 없으면 받을 때까지 기다린다 (홈 · 검색 · 캘린더 · 컬렉션의 fetchKits).
  /// 고른 채널을 다 못 받았으면 CatalogException — 몇 개라도 있으면 있는 것만 보여 준다
  Future<void> channelsReady(List<String> ids) async {
    bool missing(String f) => wantedChannels.contains(f) && !_have.contains(f);
    // manifest 가 없으면 받은 목록이 아니다 (테스트가 넣은 데이터) — 기다릴 것이 없다
    if (manifest.isEmpty || !ids.any(missing)) return;
    _channelErrors.removeWhere((f, _) => ids.contains(f)); // 다시 시도
    await syncChannels();
    final failed = [
      for (final f in ids)
        if (missing(f)) f,
    ];
    final wanted = [
      for (final f in ids)
        if (wantedChannels.contains(f)) f,
    ];
    if (failed.isNotEmpty && failed.length == wanted.length) {
      throw CatalogException(
        _channelErrors[failed.first] ?? trf('{channel} 상품을 받지 못했어요.', {'channel': _label(failed.first)}),
      );
    }
  }

  Future<bool> _syncChannels() async {
    final want = wantedChannels;
    final add = [
      for (final f in want)
        if (!_have.contains(f) && !_channelErrors.containsKey(f)) f,
    ];
    final drop = [
      for (final f in _have)
        if (!want.contains(f)) f,
    ];
    if (add.isEmpty && drop.isEmpty) return false;
    var slim = drop.isEmpty
        ? _slim
        : [
            for (final s in _slim)
              if (!drop.contains(s['franchiseId'])) s,
          ];
    final have = [
      for (final f in _have)
        if (!drop.contains(f)) f,
    ];
    final hashes = auxHashes(manifest);
    final shared = <String, String>{};
    Future<String> stored(String file) async =>
        shared[file] ??= await BlobStore.read(auxKey(file)) ?? await _get('data/$file') ?? '';
    try {
      for (final f in add) {
        channelStep = trf('{channel} 상품 받는 중', {'channel': _label(f)});
        channelBytes = 0;
        notifyListeners();
        final aux = <String, String>{
          for (final file in const ['grades.json', 'kit-first-seen.json'])
            if (await stored(file) case final t when t.isNotEmpty) file: t,
        };
        // 그 채널의 보조 파일 (건담 도감 · 베이 부품 · 태그 도감) — 그 채널을 뺄 때 지웠으니 새로 받는다
        for (final file in [
          for (final e in auxChannel.entries)
            if (e.value == f) e.key,
        ]) {
          final t = await _get('data/$file', channel: true);
          if (t == null || !auxMatches(t, hashes[file])) hashes.remove(file); // 다음 확인에서 다시 (_refreshAux)
          if (t == null) continue;
          aux[file] = t;
          await BlobStore.write(auxKey(file), t);
          _aux.remove(file);
        }
        final raw = await _get('data/split/kits-$f.json', channel: true);
        if (raw == null) {
          _channelErrors[f] = trf('{channel} 상품을 받지 못했어요.', {'channel': _label(f)});
          continue;
        }
        slim = [...slim, ...await compute(mapKitsJob, _mapMsg(f, raw, aux))];
        have.add(f);
      }
    } finally {
      channelStep = '';
      channelBytes = 0;
    }
    if (drop.isNotEmpty) await _dropAux(want);
    for (final e in auxChannel.entries) {
      if (drop.contains(e.value)) hashes.remove(e.key);
    }
    if (have.length == _have.length && drop.isEmpty) {
      notifyListeners(); // 다 못 받았다 — 받는 중 표시만 지운다
      return false;
    }
    // 고른 순서가 아니라 franchiseIds 순서로 (기기 기록 비교가 순서에 기대지 않게)
    _have = [
      for (final f in franchiseIds)
        if (have.contains(f)) f,
    ];
    // 빠지는 채널의 내 상품을 먼저 적어 둔다 — 목록을 쓴 뒤에 앱이 꺼져도 잃지 않게
    _keepLeaving(_slim.where((s) => drop.contains(s['franchiseId'])));
    await _saveKept(slim);
    await BlobStore.write(_kitsKey, await compute(jsonEncode, slim));
    await _writeMeta(manifest.containsKey('files') ? {...manifest, 'files': hashes} : manifest);
    _slim = slim;
    _rebuild();
    version++;
    // 지금 보는 탭은 그 채널을 기다려 이미 받았다 (fetchKits) — 검색어 · 스크롤을 지키려고 조용히
    lastChangeQuiet = true;
    notifyListeners();
    return true;
  }

  /// manifest `files` = 발행된 보조 파일마다 내용 지문 (data/ 아래 경로 → sha256 앞 16자리, Gunpula publish_site.mjs).
  /// content_hash 는 상품(split · 옛 id)만 덮어, 공식 예고처럼 보조 파일만 바뀐 날은 판이 같아 받지 않았다
  /// (2026-11-12 — 새 예고 2개가 당겨서 새로 고침에도 안 왔다). raw manifest · 그전 Gunpula 는 이 칸이 없다 → 예전처럼
  /// 받은 보조 파일이 manifest 지문(발행된 바이트의 sha256 앞 16자리)과 같은가. 지문이 없으면 비교하지 않는다
  static bool auxMatches(String text, String? hash) =>
      hash == null || sha256.convert(utf8.encode(text)).toString().substring(0, 16) == hash;

  static Map<String, String> auxHashes(Object? manifest) => {
    for (final e in jMap(jMap(manifest)['files']).entries)
      if (e.value case final String h when h.isNotEmpty) e.key: h,
  };

  /// 판은 같고 보조 파일만 바뀌었을 때 — 그 파일만 받는다 (상품 파일 수십 MB 는 그대로).
  /// 상품에만 녹이는 파일(mapOnlyAuxFiles)은 받지 않고, 도감 MS 파일도 화면용으로만 받는다 (상품은 그대로).
  /// 도감 · 박스 아트만 따로 발행되는 날이 잦아(2026-11 한 달 열 번 넘게) 그때마다 상품까지 받기엔 크고,
  /// 상품은 거의 매일 바뀌어 그때 같이 녹는다
  Future<bool> _refreshAux(Map<String, Object?> m) async {
    final hashes = auxHashes(m);
    final before = auxHashes(manifest);
    final changed = [
      for (final f in auxFilesFor(_wantedFor(m)))
        if (!mapOnlyAuxFiles.contains(f) && hashes[f] != null && hashes[f] != before[f]) f,
    ];
    // files 없는 manifest(raw · 그전 Gunpula)도 여기서 끝난다 — 적어 둔 지문은 그대로 두고 다음 Pages 판과 비교
    if (changed.isEmpty) return false;
    final got = <String>{};
    for (final f in changed) {
      final t = await _get('data/$f');
      if (t == null) {
        // 못 받은 파일은 옛 지문으로 두어 다음 확인에서 다시
        if (before[f] case final h?) {
          hashes[f] = h;
        } else {
          hashes.remove(f);
        }
        _checkedAt = null;
        continue;
      }
      await BlobStore.write(auxKey(f), t);
      _aux.remove(f); // 다음 aux() 가 새 파일을 푼다
      got.add(f);
      if (!auxMatches(t, hashes[f])) {
        // 발행 직후 CDN 이 옛 파일을 주거나 raw 로 받았다 — 받은 것은 쓰되 옛 지문으로 두어 다음 확인에서 다시
        if (before[f] case final h?) {
          hashes[f] = h;
        } else {
          hashes.remove(f);
        }
        _checkedAt = null;
      }
    }
    await _writeMeta({...m, 'files': hashes});
    if (got.isEmpty) return false;
    if (got.contains('kit-aliases.json')) byId = _index(); // 빠진 옛 id 는 떼고 다시 붙인다
    _loadAuxDerived(aliases: got.contains('kit-aliases.json'));
    version++; // 앱 셸이 탭 화면을 다시 불러온다 (홈 · 예고 화면의 공식 예고 …)
    lastChangeQuiet = !_loud;
    return true;
  }

  Future<void> _writeMeta(Map<String, Object?> m) async {
    await BlobStore.write(
      _metaKey,
      jsonEncode({
        'manifest': m,
        'map_version': mapVersion,
        'franchises': _have,
        'fetched_at': DateTime.now().toIso8601String(),
      }),
    );
    manifest = m;
  }

  void _fileDone() {
    if (!firstDownload || _ready) return;
    filesDone++;
    notifyListeners();
  }

  final _bytesTick = Stopwatch();

  void _addBytes(int n, {bool channel = false}) {
    if (channel) {
      channelBytes += n;
    } else if (!firstDownload || _ready) {
      return;
    } else {
      bytesReceived += n;
    }
    // 너무 자주 다시 그리지 않게 (0.1초에 한 번쯤)
    if (!_bytesTick.isRunning || _bytesTick.elapsedMilliseconds > 100) {
      _bytesTick
        ..reset()
        ..start();
      notifyListeners();
    }
  }

  void _step(String s) {
    if (_ready) return; // 뒤에서 받는 중엔 문구를 바꾸지 않는다
    progress = s;
    notifyListeners();
  }

  /// slim → Kit (최근 추가 · 이번 달은 오늘 날짜로 다시 계산)
  void _rebuild() {
    _watchLegoScope();
    // 채널 관리의 회색 칸 — Gunpula 에 파일이 생기면(새 채널) 저절로 진해진다
    channelsWithData
      ..clear()
      ..addAll(jMap(manifest['franchises']).keys);
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
    // 레고는 레고 범위 (검색 탭 › 레고, 최근 정식 세트 · 전부) — 상품은 다 만들어 두고(byId: 좋아요 · 구매함 · 알림이
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
    _keptKits = [for (final s in _kept.values) Kit.fromSlim(s, recentSince: recentSince, monthPrefix: monthPrefix)];
    byId = _index();
    _applyScope();
    phase = CatalogPhase.ready;
    if (_ready) firstDownload = false;
    error = '';
    _loadAuxDerived();
  }

  /// id → 상품: 받은 상품 전부 + 따로 둔 내 상품 (같은 id 면 받은 것)
  Map<String, Kit> _index() => {for (final k in _keptKits) k.id: k, for (final k in _all) k.id: k};

  /// 보조 파일에서 오는 값 — 옛 id 연결 · 환율 · 채널 그림
  void _loadAuxDerived({bool aliases = true}) {
    // 기다리는 쪽(받은 링크 · 알림 → fetchKitsByIds)이 오류를 받지 않게 여기서 삼킨다 (네트워크로 받은 파일이 깨졌을 때 등)
    if (aliases) _aliasesLoad = _applyAliases().catchError((Object e) => debugPrint('[catalog] 옛 id 를 못 붙임: $e'));
    _loadRates().ignore();
    _loadChannelCovers().ignore();
    _loadThumbs().ignore();
  }

  /// 작은 그림 목록 → [ThumbIndex.current]. 2 MB 가 넘는 글이라 aux() 대신 다른 isolate 에서 풀고 Map 으로만 둔다.
  /// 기기에 없으면(옛 데이터 · 아직 발행 전 · 웹 미리보기) 그대로 원본
  Future<void> _loadThumbs() async {
    final text = await BlobStore.read(auxKey(thumbsFile));
    if (text == null || text.isEmpty) return;
    ThumbIndex.current = await compute(parseThumbIndex, text);
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

  /// 정가를 원으로 (정가가 없으면 null) — 한국 정가가 있으면 그대로, 없으면 일본 정가 × 환율.
  /// 지출 합계 · 구매가 시트의 「정가로 ≈」 에만 쓴다 (목록 · 상세에는 환산값을 보이지 않는다)
  int? listPriceKrw(String id) => switch (byId[id]) {
    Kit(priceKrw: final int w) => w,
    Kit(priceJpy: final int p) => (p * jpyToKrw).round(),
    _ => null,
  };

  /// 구매함 한 상품에 쓴 돈 — 적어 둔 구매가, 없으면 [listPriceKrw] (estimate = true)
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

  static String _label(String f) => tr(channelOf(f).label);

  /// 받기 — Pages 가 안 되면 raw.githubusercontent. [count] = 첫 다운로드 바이트를 센다 · [channel] = 더한 채널 바이트
  Future<String?> _get(String path, {bool count = false, bool channel = false}) async {
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
            if (count || channel) _addBytes(chunk.length, channel: channel);
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

/// compute(): 기기 목록 글에서 [ids] 중 내 채널([mine]) 밖의 상품만
List<Map<String, Object?>> _pickSlim(({String text, Set<String> ids, List<String> mine}) a) => [
  for (final s in _decodeSlim(a.text))
    if (a.ids.contains(s['id']) && !a.mine.contains(s['franchiseId'])) s,
];

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}
