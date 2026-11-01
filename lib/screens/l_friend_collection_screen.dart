// 화면 L: 친구의 컬렉션 — 친구 프로필 숫자에서 열림 (보기 전용)
//
// ┌──────── 디자인 가이드 대응표: L 친구 컬렉션 ───────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ L-1  │ 밑줄 탭 3개 + 개수                   │ 친구의 좋아요 · 구매함 · 도감            │ P06 · P04     │
// │ L-2  │ ThumbRow + TagPill                  │ 겹침 표시: "나도 있음" · "내 좋아요"      │ P01 · P09     │
// │ L-3  │ 작품 줄 + 친구/나 진행 막대 두 줄      │ 도감 비교 (친구 n · 나 n)               │ P01           │
// │ L-4  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 빈 목록             │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 친구 프로필 숫자 → 쌓기. 상품 줄 → D 상품 상세(쌓기).
// 쓰임: 선물 고르기(친구 좋아요) · 겹쳐 사지 않기(친구 구매함에 "내 좋아요" 표시) · 도감 비교.
// v3: 친구의 좋아요 · 구매함 id 는 Gunpula v3 get_friend_collection (I 화면이 받아서 넘겨 줌), 도감 칸은 그 구매함으로 센다.
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../api.dart';
import '../marks.dart';
import '../channels.dart';
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
}) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => FriendCollectionScreen(friend: friend, initial: tab, loaders: loaders),
    ),
  );
}

class _FriendData {
  const _FriendData(this.liked, this.owned, this.mine, this.works);
  final List<Kit> liked;
  final List<Kit> owned;

  /// 내 컬렉션 (겹침 표시용)
  final List<Kit> mine;
  final List<GuideWork> works;
}

class FriendCollectionScreen extends StatefulWidget {
  const FriendCollectionScreen({
    super.key,
    required this.friend,
    this.initial = CollectionJump.liked,
    this.loaders = const Loaders(),
  });
  final Member friend;
  final CollectionJump initial;
  final Loaders loaders;

  @override
  State<FriendCollectionScreen> createState() => _FriendCollectionScreenState();
}

class _FriendCollectionScreenState extends State<FriendCollectionScreen> {
  late CollectionJump _tab = widget.initial;
  late Future<_FriendData> _future = _load();

  Future<_FriendData> _load() async {
    // STATE: GET /kits?id= (친구 좋아요 · 구매함) · /kits?status_ne=none (나) · /guideWorks
    final f = widget.friend;
    final r = await Future.wait([
      widget.loaders.kitsByIds(f.likedIds),
      widget.loaders.kitsByIds(f.ownedIds),
      widget.loaders.collection(),
      widget.loaders.guideWorks(),
    ]);
    return _FriendData(r[0] as List<Kit>, r[1] as List<Kit>, r[2] as List<Kit>, r[3] as List<GuideWork>);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${f.name}의 컬렉션',
          style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
        ),
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
                    tab('좋아요', CollectionJump.liked, count: d.liked.length), // L-1
                    tab('구매함', CollectionJump.owned, count: d.owned.length),
                    tab('도감', CollectionJump.guide),
                  ],
                ),
              ),
              Expanded(
                child: switch (_tab) {
                  CollectionJump.liked => _kits(d.liked, d.mine, liked: true),
                  CollectionJump.owned => _kits(d.owned, d.mine, liked: false),
                  CollectionJump.guide => _guide(d.works),
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
      return EmptyView(message: liked ? '${f.name}의 좋아요가 비어 있어요' : '${f.name}의 구매함이 비어 있어요');
    }
    final m = Marks.of(context); // 앱 전체 한 벌 — 방금 누른 ♡ 도 반영
    String mark(Kit k) => m.owned(k) ? '나도 있음' : (m.liked(k) ? '내 좋아요' : '');

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            liked ? '선물 고를 때 참고하세요 · 겹치는 상품엔 표시가 있어요' : '이미 가진 상품이에요 · 내가 좋아요한 상품과 겹치면 표시돼요',
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
        ),
        for (final k in kits)
          ThumbRow(
            // L-2
            image: k.image,
            title: k.name,
            titleLines: 2,
            size: 64,
            subtitle: joinDot([channelOf(k.franchiseId).label, k.line, k.series]),
            tag: mark(k),
            tagStrong: mark(k) == '내 좋아요' && !liked, // 친구가 이미 샀는데 나도 원함 → 겹쳐 사기 주의
            trailing: Text(yen(k.priceJpy), style: const TextStyle(fontSize: Gp.t12)),
            onTap: () => openKitDetail(context, k, loaders: widget.loaders),
          ),
      ],
    );
  }

  Widget _guide(List<GuideWork> works) {
    final f = widget.friend;
    final shown = works.where((w) => (f.guide[w.id] ?? 0) > 0).toList()
      ..sort((a, b) => (f.guide[b.id] ?? 0).compareTo(f.guide[a.id] ?? 0));
    if (shown.isEmpty) return EmptyView(message: '${f.name}의 도감이 아직 비어 있어요');
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
                '  ${f.verified > 0 ? '인증 ${f.verified}개 · ' : ''}점등 ${f.lit}칸 (산 상품 기준)',
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
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
                  child: AppImage(w.image, fit: BoxFit.contain, placeholder: w.name),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      bar(f.name.characters.take(2).toString(), f.guide[w.id] ?? 0, w.total, accent: true),
                      const SizedBox(height: 4),
                      bar('나', w.owned, w.total),
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
