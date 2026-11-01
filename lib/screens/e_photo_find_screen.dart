// 화면 E-8 사진 · 공유로 찾기 — 사진의 글자를 기기 안에서 읽어(ML Kit) 상품 후보를 고르고, 구매함 상품에 사진을 붙인다.
// 다른 앱에서 "공유 → Hobby Atlas" 로 보낸 스크린숏 · 글 · 주소도 여기로 (lib/share/share_intake.dart).
//
// ┌──────── 디자인 가이드 대응표: E-8 사진 · 공유로 찾기 ─────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                        │ 비즈니스 명칭(한글)                       │ 원칙(P번호)   │
// │ E-8  │ 사진 + "이름으로 찾기" + 결과 줄        │ 글자로 못 찾으면 이름 · 설명으로 찾기        │ P09 · P10     │
// │ E-9  │ 줄 오른쪽 📎 / 리본 / ♡                │ 구매함 상품에 사진 붙이기 · 바로 표시        │ P07 · P03     │
// │ E-11 │ MiniSpinner "글자 읽는 중…"            │ 기기 안 글자 읽기 (ML Kit 일본어 · 한국어)   │ P01           │
// │ E-12 │ _TokenChip Wrap (누르면 끄기 · 길게 = 검색창) │ 읽은 글자 조각 (JAN · 등급 · 축척 · 형식번호 · 낱말) │ P07 · P03 │
// │ E-13 │ ThumbRow + 일치도 알약 + 맞은 조각       │ 상품 후보 (JAN · 주소 = 100%)              │ P01 · P10     │
// │ E-14 │ 아이콘 + 한 줄                          │ 글자를 찾지 못했어요 · 이름으로 찾기         │ P09           │
// │ E-15 │ 공유로 받은 글 칸 (🔗)                  │ 공유로 받은 글 · 주소 → 주소 · 글자로 찾기   │ P01 · P07     │
// │ E-16 │ SentenceCandidates                     │ 후보가 없을 때 낱말 맞추기 (설명과 겹친 상품) │ P09           │
// │ E-10 │ LoadingView / ErrorView / EmptyView     │ 불러오기 3상태                            │ P01 · P09     │
// └────────────────────────────────────────────────────────────────────────────────────┘
// 전환: E-5 사진 · 앨범 / 공유로 받기 → 이 화면(쌓기) → D 상세(쌓기).
// 사진 속 물건 모양을 알아보는 AI 는 없다 — 상자 · 화면의 "글자"만 읽어 맞춘다. 일치도는 글자가 겹친 정도 그대로다.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../data/photo_files.dart';
import '../logic/ocr_lookup.dart';
import '../logic/url_lookup.dart';
import '../marks.dart';
import '../models.dart';
import '../ocr/ocr_catalog.dart';
import '../ocr/text_reader.dart';
import '../report.dart';
import '../sentence_search.dart';
import '../share/share_intake.dart';
import '../sync/account.dart';
import '../theme.dart';
import '../widgets.dart';
import 'b_search_screen.dart' show SentenceCandidates;
import 'd_kit_detail_screen.dart';

/// 공유로 받은 것 열기 (앱 셸이 부른다): 사진 → 글자 읽기, 글 · 주소 → 주소 · 글자로 찾기
Future<void> openShared(
  BuildContext context,
  SharedItem item, {
  required Loaders loaders,
  required VoidCallback onGoSearch,
}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  switch (item) {
    case SharedImage(:final path):
      final Uint8List bytes;
      try {
        bytes = await readSharedFile(path);
      } on Object {
        if (context.mounted) showToast(context, '공유한 사진을 열지 못했어요');
        return;
      }
      // 스크린숏 · 원본 크기 사진이라 내 사진으로 붙이지 않는다 (붙이기는 찍기 · 앨범에서)
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoFindScreen(photo: bytes, attachable: false, loaders: loaders, onGoSearch: onGoSearch),
        ),
      );
    case SharedText(:final text):
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoFindScreen(sharedText: text, loaders: loaders, onGoSearch: onGoSearch),
        ),
      );
  }
}

/// E-8 사진 · 공유로 찾기
class PhotoFindScreen extends StatefulWidget {
  const PhotoFindScreen({
    super.key,
    this.photo,
    this.sharedText = '',
    this.attachable = true,
    required this.loaders,
    required this.onGoSearch,
  });

  /// 찍은 · 고른 · 공유로 받은 사진 (글만 받았으면 null)
  final Uint8List? photo;

  /// 공유로 받은 글 · 주소
  final String sharedText;

  /// 구매함 상품에 이 사진을 붙일 수 있나 (찍기 · 앨범 = 줄인 JPEG)
  final bool attachable;
  final Loaders loaders;
  final VoidCallback onGoSearch;

  @override
  State<PhotoFindScreen> createState() => _PhotoFindScreenState();
}

enum _Read { reading, done, failed }

class _PhotoFindScreenState extends State<PhotoFindScreen> {
  late Future<List<Kit>> _future = _load();
  Future<List<Kit>> _load() => widget.loaders.kits([for (final c in allChannels) c.id]);

  /// 찾기 표 (상품 목록을 받은 뒤 한 번)
  OcrIndex? _index;
  UrlIndex? _urls;
  List<Kit>? _indexed;

  _Read _read = _Read.done;
  List<OcrToken> _tokens = const [];

  /// 끈 조각 (칩을 눌러 끔)
  final Set<OcrToken> _off = {};

  final _search = TextEditingController();
  String _query = '';

  /// 이 화면에서 사진을 붙인 상품 (✓)
  final Set<String> _attached = {};

  (String, List<SentenceHit>)? _memo;
  (String, List<SentenceHit>)? _fallbackMemo;
  (String, List<OcrCandidate>)? _ocrMemo;

  bool get _canAttach => widget.attachable && widget.photo != null;

  @override
  void initState() {
    super.initState();
    if (widget.photo case final p?) {
      _read = _Read.reading;
      unawaited(_readPhoto(p));
    } else {
      _tokens = extractOcrTokens(widget.sharedText);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// E-11 기기 안에서 글자 읽기
  Future<void> _readPhoto(Uint8List photo) async {
    try {
      final text = await textReader(photo);
      if (!mounted) return;
      setState(() {
        _tokens = extractOcrTokens(text);
        _read = _Read.done; // STATE: 읽음 → 조각 칩 · 후보
      });
    } on Object {
      if (mounted) setState(() => _read = _Read.failed); // STATE: 못 읽음 → 이름으로 찾기
    }
  }

  /// 상품 목록이 오면 찾기 표를 만든다 (다른 isolate, 같은 목록이면 지난번 것)
  void _ensureIndex(List<Kit> kits) {
    if (identical(_indexed, kits)) return;
    _indexed = kits;
    unawaited(
      loadOcrIndex(kits).then((i) {
        if (mounted) setState(() => _index = i); // STATE: 찾기 표 준비 → 후보
      }),
    );
  }

  List<OcrToken> get _active => [
    for (final t in _tokens)
      if (!_off.contains(t)) t,
  ];

  List<OcrCandidate> _candidates(OcrIndex index) {
    final active = _active;
    final key = active.join('|');
    if (_ocrMemo case (final k, final c) when k == key) return c;
    final c = index.lookUp(active);
    _ocrMemo = (key, c);
    return c;
  }

  List<SentenceHit> _hits(String q, List<Kit> kits) {
    if (_memo case (final k, final h) when k == q) return h;
    final h = sentenceSearch(q, kits);
    _memo = (q, h);
    return h;
  }

  /// E-16 켜 둔 조각을 문장으로 (낱말 하나여도)
  List<SentenceHit> _fallback(List<Kit> kits) {
    final q = _active.map((t) => t.label).join(' ');
    if (_fallbackMemo case (final k, final h) when k == q) return h;
    final h = sentenceSearch(q, kits, minWords: 1);
    _fallbackMemo = (q, h);
    return h;
  }

  void _toggle(OcrToken t) => setState(() => _off.contains(t) ? _off.remove(t) : _off.add(t)); // STATE: 조각 끄기 · 켜기 → 후보

  /// 조각을 길게 누르면 이름 찾기 칸에
  void _toQuery(OcrToken t) {
    _search.text = t.label;
    setState(() => _query = t.label); // STATE: 조각 → 이름으로 찾기
  }

  /// E-9 이 상품에 사진 붙이기 (내 사진 목록 · 사진 벽 · 상세 사진 줄에 보인다)
  Future<void> _attach(Kit k) async {
    final photo = widget.photo;
    if (photo == null) return;
    final store = Marks.read(context).store;
    final share = AccountScope.read(context).photos;
    final p = MyPhoto.create(kitId: k.id);
    await PhotoFiles.instance.write(p.file, photo);
    store.addPhoto(p);
    share.syncSoon();
    if (!mounted) return;
    setState(() => _attached.add(k.id)); // STATE: 붙임 → ✓
    showToast(
      context,
      '「${k.name}」에 사진을 붙였어요',
      onUndo: () {
        store.removePhoto(p.id);
        share.syncSoon();
        unawaited(PhotoFiles.instance.delete(p.file));
        if (mounted) setState(() => _attached.remove(k.id));
      },
    );
  }

  /// 줄 오른쪽: ♡ · 리본(구매함) · 📎(구매함이고 사진을 붙일 수 있을 때)
  Widget _marks(Kit k) {
    final marks = Marks.of(context);
    final liked = marks.liked(k);
    final owned = marks.owned(k);
    Widget btn(String tip, Widget icon, VoidCallback onTap) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: icon,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(
          '좋아요',
          LikedIcon(filled: liked, size: Gp.iM, color: liked ? Gp.accent : Gp.faint),
          () => Marks.read(context).toggleLike(context, k),
        ),
        btn(
          '구매함',
          OwnedIcon(filled: owned, size: Gp.iM, color: owned ? Gp.own : Gp.faint),
          () => Marks.read(context).toggleOwn(context, k),
        ),
        if (_canAttach && owned)
          _attached.contains(k.id)
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.check_circle, color: Gp.accent),
                )
              : btn('사진 붙이기', const Icon(Icons.add_photo_alternate_outlined, color: Gp.ink), () => _attach(k)),
      ],
    );
  }

  Widget _row(Kit k, List<Kit> list, {String tag = '', bool strong = false, String reason = ''}) => ThumbRow(
    image: k.image,
    title: k.name,
    tag: tag,
    tagStrong: strong,
    subtitle: reason.isNotEmpty ? reason : joinDot([channelOf(k.franchiseId).label, k.line]),
    onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: list),
    trailing: _marks(k),
  );

  /// E-11 · E-14 상태 한 줄 ([found] = 주소로 이미 찾음)
  Widget _status({bool found = false}) {
    final (icon, text) = switch (_read) {
      _Read.reading => (null, '글자 읽는 중…'),
      _Read.failed => (Icons.text_fields, '글자를 읽지 못했어요 · 이름으로 찾기'),
      _Read.done when _tokens.isEmpty && !found => (Icons.text_fields, '글자를 찾지 못했어요 · 이름으로 찾기'),
      _Read.done => (null, ''),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (icon == null)
            const MiniSpinner(size: Gp.iS, color: Gp.accent)
          else
            Icon(icon, size: Gp.iS, color: Gp.faint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shared = widget.photo == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          shared ? '공유로 찾기' : '사진으로 찾기',
          style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<List<Kit>>(
        future: _future,
        builder: (context, snap) {
          final kits = snap.data ?? const <Kit>[];
          if (kits.isNotEmpty) _ensureIndex(kits);
          final index = _index;
          final loading = snap.connectionState != ConnectionState.done;
          // 주소 → 상품 (E-15)
          final urlHits = widget.sharedText.isEmpty || kits.isEmpty
              ? const <UrlHit>[]
              : (_urls ??= UrlIndex(kits)).findInText(widget.sharedText);
          final urlIds = {for (final h in urlHits) h.kit.id};
          final cands = index == null || _read != _Read.done
              ? const <OcrCandidate>[]
              : [
                  for (final c in _candidates(index))
                    if (!urlIds.contains(c.kit.id)) c,
                ];
          final candKits = [for (final h in urlHits) h.kit, for (final c in cands) c.kit];
          // E-16 후보가 없으면 켜 둔 조각을 문장으로 (낱말 표 · 별명)
          final fallback = cands.isEmpty && urlHits.isEmpty && index != null && _active.isNotEmpty
              ? _fallback(kits)
              : const <SentenceHit>[];
          final marks = Marks.of(context);
          final owned = [
            for (final k in kits)
              if (marks.owned(k)) k,
          ];
          final hits = _query.isEmpty ? const <SentenceHit>[] : _hits(_query, kits);
          final byName = _query.isEmpty
              ? (_canAttach ? owned : const <Kit>[])
              : [
                  for (final k in kits)
                    if (kitMatches(k, _query)) k,
                ].take(40).toList();
          // 글자를 읽는 동안은 위 상태 줄이 돌고, 다 읽었는데 찾기 표가 아직이면 아래에서 돈다
          final preparing = _read == _Read.reading || (kits.isNotEmpty && index == null && _tokens.isNotEmpty);
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (widget.photo case final photo?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Gp.rLarge),
                    child: ColoredBox(
                      color: Gp.soft,
                      child: SizedBox(
                        height: 220,
                        child: Image.memory(photo, fit: BoxFit.contain, gaplessPlayback: true),
                      ),
                    ),
                  ),
                )
              else
                _SharedTextBox(text: widget.sharedText), // E-15
              _status(found: urlHits.isNotEmpty), // E-11 · E-14
              if (_tokens.isNotEmpty)
                Padding(
                  // E-12 읽은 글자 조각
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _tokens)
                        _TokenChip(
                          token: t,
                          on: !_off.contains(t),
                          onTap: () => _toggle(t),
                          onLongPress: () => _toQuery(t),
                        ),
                    ],
                  ),
                ),
              if (loading || preparing)
                _read == _Read.reading
                    ? const SizedBox(height: 120)
                    : const SizedBox(height: 120, child: LoadingView(label: '찾는 중…')) // E-10
              else if (snap.hasError)
                ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()))
              else ...[
                if (candKits.isNotEmpty) ...[
                  SectionHeader('후보', subtitle: '${candKits.length}개', padding: const EdgeInsets.fromLTRB(16, 14, 12, 4)),
                  for (final h in urlHits) _row(h.kit, candKits, tag: '100%', strong: true, reason: h.how), // E-13
                  for (final c in cands)
                    _row(c.kit, candKits, tag: '${c.score}%', strong: c.exact || c.score >= 85, reason: c.reason),
                ],
                if (fallback.isNotEmpty)
                  SentenceCandidates(
                    // E-16
                    hits: fallback,
                    onTap: (k) => openKitDetail(context, k, loaders: widget.loaders),
                  )
                else if (candKits.isEmpty && _tokens.isNotEmpty && _read == _Read.done)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.search_off, size: Gp.iS, color: Gp.faint),
                        SizedBox(width: 6),
                        Text('맞는 상품을 못 찾았어요 · 이름으로 찾기', style: TextStyle(fontSize: Gp.t12, color: Gp.muted)),
                      ],
                    ),
                  ),
                Padding(
                  // E-8 이름으로 찾기
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: '이름으로 찾기',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (q) => setState(() => _query = q.trim()), // STATE: 찾기 → 결과
                  ),
                ),
                if (hits.isNotEmpty)
                  SentenceCandidates(
                    hits: hits,
                    onTap: (k) => openKitDetail(context, k, loaders: widget.loaders),
                  ),
                if (_query.isEmpty && byName.isNotEmpty)
                  SectionHeader('구매함', subtitle: '${owned.length}개', padding: const EdgeInsets.fromLTRB(16, 18, 12, 4)),
                for (final k in byName) _row(k, byName),
                if (_query.isNotEmpty && byName.isEmpty && hits.isEmpty)
                  EmptyView(
                    icon: Icons.search_off,
                    message: '「$_query」와 일치하는 상품이 없어요',
                    action: OutlinedButton.icon(
                      onPressed: () => reportDataIssue(context, kind: ReportKind.missingKit, unitName: _query),
                      icon: const Icon(Icons.flag_outlined, size: Gp.iM),
                      label: const Text('없는 상품 제보'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// E-15 공유로 받은 글 (세 줄까지)
class _SharedTextBox extends StatelessWidget {
  const _SharedTextBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(color: Gp.soft, borderRadius: BorderRadius.circular(Gp.radius)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(urlsIn(text).isEmpty ? Icons.notes : Icons.link, size: Gp.iS, color: Gp.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
        ),
      ],
    ),
  );
}

/// E-12 읽은 글자 조각 하나 — 켜짐: 파랑 글자 + 옅은 파랑 바탕 / 꺼짐: 회색 + 가운데 줄
class _TokenChip extends StatelessWidget {
  const _TokenChip({required this.token, required this.on, required this.onTap, required this.onLongPress});
  final OcrToken token;
  final bool on;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static IconData? _icon(OcrKind k) => switch (k) {
    OcrKind.jan => Icons.qr_code_2,
    OcrKind.grade => Icons.workspace_premium_outlined,
    OcrKind.scale => Icons.straighten,
    OcrKind.model => Icons.tag,
    OcrKind.bbx => Icons.toys_outlined,
    OcrKind.word => null,
  };

  @override
  Widget build(BuildContext context) {
    final color = on ? Gp.accent : Gp.faint;
    final icon = _icon(token.kind);
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(Gp.rSmall),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32, maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Gp.accent.withValues(alpha: 0.08) : Gp.panel,
            borderRadius: BorderRadius.circular(Gp.rSmall),
            border: Border.all(color: on ? Gp.accent.withValues(alpha: 0.3) : Gp.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: Gp.iS, color: color), const SizedBox(width: 4)],
              Flexible(
                child: Text(
                  token.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Gp.t12,
                    fontWeight: FontWeight.w600,
                    color: on ? Gp.accent : Gp.faint,
                    decoration: on ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
