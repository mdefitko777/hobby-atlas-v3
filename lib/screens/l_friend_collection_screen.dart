// 화면 L: 친구의 컬렉션 — 친구 프로필 숫자에서 열림 (보기 전용)
//
// ┌──────── 디자인 가이드 대응표: L 친구 컬렉션 ───────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ L-1  │ 밑줄 탭 3개 + 개수                   │ 친구의 좋아요 · 구매함 · 도감            │ P06 · P04     │
// │ L-2  │ ThumbRow + TagPill                  │ 겹침 표시: "나도 있음" · "내 좋아요"      │ P01 · P09     │
// │ L-3  │ 작품 줄 + 친구/나 진행 막대 두 줄 · 📷 n │ 도감 비교 (친구 n · 나 n · 친구 사진 n)   │ P01           │
// │ L-6  │ AppBar 오른쪽 ? (HelpButton)       │ 겹침 꼬리표 뜻 (긴 안내 줄 대신)          │ P10           │
// │ L-4  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 빈 목록             │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 친구 프로필 숫자 → 쌓기. 상품 줄 → D 상품 상세(쌓기).
// 쓰임: 선물 고르기(친구 좋아요) · 겹쳐 사지 않기(친구 구매함에 "내 좋아요" 표시) · 도감 비교.
// v3: 친구의 좋아요 · 구매함 id 는 Gunpula v3 get_friend_collection (I 화면이 받아서 넘겨 줌), 도감 칸은 그 구매함으로 센다.
//     친구 사진 수 = 친구가 보이기로 둔 사진(get_friend_wall)의 상품을 같은 도감 셈(friendGuide)에 넣은 것.
//     "손으로 켜기"(guide_manual_lit)는 서버에 없어 친구 쪽 비교에는 들어가지 않는다 (산 상품 기준).
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../api.dart';
import '../marks.dart';
import '../channels.dart';
import '../l10n/l10n.dart';
import '../logic/short_names.dart' show shortWorkName;
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';
import 'f_collection_screen.dart' show CollectionJump;

void openFriendCollection(
  BuildContext context,
  Member friend,
  CollectionJump tab, {
  Loaders loaders = const Loaders(),
  List<String> photoKitIds = const [],
}) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => FriendCollectionScreen(friend: friend, initial: tab, loaders: loaders, photoKitIds: photoKitIds),
    ),
  );
}

class _FriendData {
  const _FriendData(this.liked, this.owned, this.mine, this.works, this.photosByWork);
  final List<Kit> liked;
  final List<Kit> owned;

  /// 내 컬렉션 (겹침 표시용)
  final List<Kit> mine;
  final List<GuideWork> works;

  /// 작품 id → 친구 사진 수 (사진에 이은 상품 기준)
  final Map<String, int> photosByWork;
}

class FriendCollectionScreen extends StatefulWidget {
  const FriendCollectionScreen({
    super.key,
    required this.friend,
    this.initial = CollectionJump.liked,
    this.loaders = const Loaders(),
    this.photoKitIds = const [],
  });
  final Member friend;
  final CollectionJump initial;
  final Loaders loaders;

  /// 친구가 보이기로 둔 사진 (한 장에 하나, 상품을 안 이었으면 '')
  final List<String> photoKitIds;

  @override
  State<FriendCollectionScreen> createState() => _FriendCollectionScreenState();
}

class _FriendCollectionScreenState extends State<FriendCollectionScreen> {
  late CollectionJump _tab = widget.initial;
  late Future<_FriendData> _future = _load();

  Future<_FriendData> _load() async {
    // STATE: 친구 좋아요 · 구매함 상품 · 내 상품 · 건담 작품
    final f = widget.friend;
    final r = await Future.wait([
      widget.loaders.kitsByIds(f.likedIds),
      widget.loaders.kitsByIds(f.ownedIds),
      widget.loaders.collection(),
      widget.loaders.guideWorks(),
    ]);
    var byWork = const <String, int>{};
    final linked = [
      for (final id in widget.photoKitIds)
        if (id.isNotEmpty) id,
    ];
    if (linked.isNotEmpty) {
      try {
        byWork = await widget.loaders.friendGuide(linked).timeout(const Duration(seconds: 8));
      } on Object {
        // 도감 데이터가 없으면 작품별 사진 수 없이
      }
    }
    return _FriendData(r[0] as List<Kit>, r[1] as List<Kit>, r[2] as List<Kit>, r[3] as List<GuideWork>, byWork);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    return Scaffold(
      appBar: AppBar(
        title: Text(trf('{name}의 컬렉션', {'name': f.name})),
        actions: [
          HelpButton(title: tr('친구 컬렉션'), items: friendCollectionHelp()), // L-6
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<_FriendData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(); // L-4
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()));
          }
          final d = snap.data!;
          Widget tab(String label, CollectionJump j, {int? count}) => UnderlineTab(
            label: label,
            count: count,
            selected: _tab == j,
            onTap: () => setState(() => _tab = j), // STATE: 탭 → 목록
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Row(
                  children: [
                    tab(tr('좋아요'), CollectionJump.liked, count: d.liked.length), // L-1
                    tab(tr('구매함'), CollectionJump.owned, count: d.owned.length),
                    tab(tr('도감'), CollectionJump.guide),
                  ],
                ),
              ),
              Expanded(
                child: switch (_tab) {
                  CollectionJump.liked => _kits(d.liked, d.mine, liked: true),
                  CollectionJump.owned || CollectionJump.backlog => _kits(d.owned, d.mine, liked: false),
                  CollectionJump.guide => _guide(d.works, d.photosByWork),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kits(List<Kit> kits, List<Kit> mine, {required bool liked}) {
    final f = widget.friend;
    if (kits.isEmpty) {
      return EmptyView(
        message: liked ? trf('{name}의 좋아요가 비어 있어요', {'name': f.name}) : trf('{name}의 구매함이 비어 있어요', {'name': f.name}),
      );
    }
    final m = Marks.of(context); // 앱 전체 한 벌 — 방금 누른 ♡ 도 반영
    String mark(Kit k) => m.owned(k) ? '나도 있음' : (m.liked(k) ? '내 좋아요' : '');

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 4), // 꼬리표 뜻은 ? 에 (긴 안내 줄 대신)
        for (final k in kits)
          ThumbRow(
            // L-2
            image: k.image,
            title: k.name,
            titleLines: 2,
            size: 64,
            subtitle: joinDot([tr(channelOf(k.franchiseId).label), tr(k.line), k.seriesLabel]),
            tag: tr(mark(k)),
            tagStrong: mark(k) == '내 좋아요' && !liked, // 친구가 이미 샀는데 나도 원함 → 겹쳐 사기 주의
            trailing: KitPriceLines(k),
            onTap: () => openKitDetail(context, k, loaders: widget.loaders),
          ),
      ],
    );
  }

  Widget _guide(List<GuideWork> works, Map<String, int> photos) {
    final f = widget.friend;
    final shown = works.where((w) => (f.guide[w.id] ?? 0) > 0 || (photos[w.id] ?? 0) > 0).toList()
      ..sort((a, b) => (f.guide[b.id] ?? 0).compareTo(f.guide[a.id] ?? 0));
    if (shown.isEmpty) return EmptyView(message: trf('{name}의 도감이 아직 비어 있어요', {'name': f.name}));
    Widget bar(String who, int n, int total, {bool accent = false}) => Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            who,
            style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
          ),
        ),
        Expanded(
          child: AccentBar(value: total == 0 ? 0 : n / total, height: 5, color: accent ? Gp.accent : Gp.faint),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$n/$total',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
          ),
        ),
      ],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            const VerifiedBadge(size: 18),
            Expanded(
              child: Text(
                '  ${joinDot([
                  if (f.verified > 0) trf('인증 {n}개', {'n': f.verified}),
                  trf('점등 {n}칸 (산 상품 기준)', {'n': f.lit}),
                ])}',
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ),
            if (widget.photoKitIds.isNotEmpty)
              Tooltip(
                // 친구가 보이기로 둔 사진
                key: const ValueKey('friend-photo-count'),
                message: tr('사진'),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined, size: Gp.iS, color: Gp.muted),
                    Text(
                      ' ${widget.photoKitIds.length}',
                      style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final w in shown)
          Container(
            // L-3
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Gp.panel,
              borderRadius: BorderRadius.circular(Gp.radius),
              border: Border.all(color: Gp.line),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 52,
                  child: AppImage(w.image, fit: BoxFit.contain, placeholder: shortWorkName(w.name)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(shortWorkName(w.name), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          if ((photos[w.id] ?? 0) > 0) ...[
                            const Icon(Icons.photo_camera_outlined, size: Gp.iXS, color: Gp.muted),
                            Text(
                              ' ${photos[w.id]}',
                              key: ValueKey('work-photos-${w.id}'),
                              style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      bar(f.name.characters.take(2).toString(), f.guide[w.id] ?? 0, w.total, accent: true),
                      const SizedBox(height: 4),
                      bar(tr('나'), w.owned, w.total),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// L-6 ? 도움말 — 줄 앞 꼬리표 (겹침 표시)
List<HelpItem> friendCollectionHelp() => [
  HelpItem.widget(TagPill(tr('나도 있음')), tr('나도 가진 상품')),
  HelpItem.widget(TagPill(tr('내 좋아요')), tr('내가 좋아요한 상품 (선물 참고)')),
  HelpItem.widget(TagPill(tr('내 좋아요'), strong: true), tr('친구가 이미 산 내 좋아요 — 겹쳐 사기 주의')),
];
