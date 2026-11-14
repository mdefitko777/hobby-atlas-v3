// 홈 › My Page — "내 것"만 모아 보는 탭 (글자 대신 아이콘: ♡ 좋아요 · 리본 구매함 · ★ 특별 관심)
//
// ┌──────── 디자인 가이드 대응표: A 홈 › My Page ──────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ A-21 │ _Stats (아이콘 5칸 + 공유)           │ 좋아요 · 구매함 · 미조립(쌓인 것) · 이번 달 지출 · 총 지출 │ P01 · P07 │
// │ A-21b│ 숫자 줄 끝 공유 아이콘 → V 공유 카드  │ 내 컬렉션 카드 (그림으로 공유 · 저장)      │ P07 · P10     │
// │ A-22 │ _LikedSoon                         │ 좋아요 중 날짜가 다가오는 것 (PB 마감 · 발매) │ P01     │
// │ A-23 │ _OwnedRow                          │ 최근 산 것 (가로 줄)                     │ P08           │
// │ A-24 │ _SpecialFeed                       │ 특별 관심 친구가 최근 담은 것            │ P01           │
// │ A-25 │ FindBar (홈 검색창 자리)             │ 내 것에서 찾기 + 필터 → 숫자 · 목록이 같이 좁혀짐 │ P04 · P07 │
// └──────────────────────────────────────────────────────────────────────────────────┘
import 'package:flutter/material.dart';

import '../api.dart';
import '../clock.dart';
import '../data/catalog.dart';
import '../data/user_store.dart';
import '../l10n/l10n.dart';
import '../logic/build_status.dart';
import '../logic/kit_rules.dart';
import '../marks.dart';
import '../models.dart';
import '../sync/account.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';
import 'f_collection_screen.dart' show CollectionJump;
import 'v_share_sheet.dart' show openCollectionShare;

class MyPageView extends StatefulWidget {
  const MyPageView({super.key, required this.loaders, this.onJump, this.query = '', this.filter});
  final Loaders loaders;

  /// A-25 찾기 · 필터 (홈 검색창 자리의 FindBar)
  final String query;
  final KitFilter? filter;

  /// 숫자 · 머리 아이콘 → 컬렉션 탭 (앱 셸)
  final ValueChanged<CollectionJump>? onJump;

  @override
  State<MyPageView> createState() => _MyPageViewState();
}

class _MyPageViewState extends State<MyPageView> {
  @override
  Widget build(BuildContext context) {
    final marks = Marks.of(context); // 좋아요 · 구매함이 바뀌면 다시 그린다
    final me = UserStore.instance;
    final cat = Catalog.instance;
    final f = widget.filter?..statusOf = marks.statusOf;
    bool hit(Kit k) => kitMatches(k, widget.query) && (f == null || f.matches(k)); // A-25
    final liked = [
      for (final id in me.idsWith(const {CollectStatus.wanted}))
        if (cat.byId[id] case final k? when hit(k)) k,
    ];
    final owned = [
      for (final id in me.idsWith(const {CollectStatus.owned}))
        if (cat.byId[id] case final k? when hit(k)) k,
    ];
    // 이 기기 어디에도 없는 상품(다른 기기에서 적었고 이 기기는 그 채널을 받은 적이 없다)도 수에는 센다 — 기록은 그대로라
    // 그 채널을 고르면 목록에도 보인다. 찾기 · 필터 중에는 거를 수 없어 세지 않는다
    final plain = widget.query.trim().isEmpty && (f == null || f.count == 0);
    int unseen(CollectStatus s) => plain ? me.idsWith({s}).where((id) => cat.byId[id] == null).length : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 레벨은 왼쪽 위 아바타 옆 Lv (lib/level.dart) — 여기는 숫자 4칸만
        Padding(
          // 페이지 바탕 위 평평한 한 줄 (수집 | 돈) — 튀어나오지 않게
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: CollectionStats(
            // A-21 · A-21b 끝에 공유 카드
            liked: liked.length + unseen(CollectStatus.wanted),
            owned: owned.length + unseen(CollectStatus.owned),
            backlog: backlogCount(owned.where(needsAssembly).map((k) => k.id), me.stageOf),
            month: me.spendInMonth(appNow()),
            total: me.spendKrw,
            onLiked: () => widget.onJump?.call(CollectionJump.liked),
            onOwned: () => widget.onJump?.call(CollectionJump.owned),
            onBacklog: () => widget.onJump?.call(CollectionJump.backlog),
            onShare: () => openCollectionShare(context, loaders: widget.loaders),
          ),
        ),
        _Section(
          icon: const LikedIcon(size: Gp.iM),
          onMore: () => widget.onJump?.call(CollectionJump.liked),
          child: _LikedSoon(kits: liked, loaders: widget.loaders),
        ),
        _Section(
          icon: const OwnedIcon(size: Gp.iS),
          onMore: () => widget.onJump?.call(CollectionJump.owned),
          child: _OwnedRow(kits: owned.take(12).toList(), loaders: widget.loaders),
        ),
        _Section(
          icon: const Icon(Icons.star_rounded, size: Gp.iM, color: Gp.star),
          child: const _SpecialFeed(),
        ),
      ],
    );
  }
}

/// 섹션 = 흰 띠 + 머리 아이콘 하나 (글자 제목 없음) + ›
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.child, this.onMore});
  final Widget icon;
  final Widget child;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              icon,
              const Spacer(),
              if (onMore != null)
                InkWell(
                  onTap: onMore,
                  borderRadius: BorderRadius.circular(Gp.radius),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.chevron_right, color: Gp.faint),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// A-22 좋아요 — 날짜가 다가오는 것부터 4개 (날짜 없는 것은 최근 담은 순으로 채움)
class _LikedSoon extends StatelessWidget {
  const _LikedSoon({required this.kits, required this.loaders});
  final List<Kit> kits;
  final Loaders loaders;

  @override
  Widget build(BuildContext context) {
    if (kits.isEmpty) return const _Empty(icon: Icons.favorite_border);
    final dated = [
      for (final k in kits)
        if (upcomingOf(k) case final u?) (k, u),
    ]..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));
    final rest = [
      for (final k in kits)
        if (!dated.any((d) => d.$1 == k)) k,
    ];
    final rows = [...dated.map((d) => (d.$1, d.$2)), ...rest.map((k) => (k, null))].take(4);
    return Column(
      children: [
        for (final (k, u) in rows)
          InkWell(
            onTap: () => openKitDetail(context, k, loaders: loaders, list: kits),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Gp.rSmall),
                    child: SizedBox(width: 38, height: 38, child: AppImage(k.image, placeholder: tr(k.line))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      k.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t14),
                    ),
                  ),
                  if (u != null) ...[const SizedBox(width: 8), DateTag(u.label, urgent: u.urgent)],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A-23 최근 산 것 (가로 줄, 카드에 ♡ · 리본 그대로)
class _OwnedRow extends StatelessWidget {
  const _OwnedRow({required this.kits, required this.loaders});
  final List<Kit> kits;
  final Loaders loaders;

  @override
  Widget build(BuildContext context) {
    if (kits.isEmpty) return const _Empty(icon: Icons.bookmark_border);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final k = kits[i];
          return ProductTile(
            image: k.image,
            title: k.name,
            imageWidth: 86,
            imageAspect: 1,
            id: k.id,
            onTap: () => openKitDetail(context, k, loaders: loaders, list: kits),
          );
        },
      ),
    );
  }
}

/// A-24 특별 관심 — 친구 서랍에서 ★ 한 친구들이 최근 담은 것
class _SpecialFeed extends StatefulWidget {
  const _SpecialFeed();

  @override
  State<_SpecialFeed> createState() => _SpecialFeedState();
}

class _SpecialFeedState extends State<_SpecialFeed> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final special = UserStore.instance.specialFriends;
    if (!account.signedIn || special.isEmpty) return const _Empty(icon: Icons.star_border_rounded);
    final friends = account.friends;
    if (!_asked) {
      _asked = true;
      for (final h in special) {
        friends.collection(h).then((_) {}, onError: (Object _) {});
      }
    }
    final cat = Catalog.instance;
    final events = <(String name, String status, Kit kit, DateTime at)>[];
    for (final h in special) {
      final c = friends.collections[h];
      if (c == null) continue;
      for (final e in c.items.entries) {
        final kit = cat.byId[e.key];
        final at = DateTime.tryParse('${e.value['updated_at'] ?? ''}');
        final st = '${e.value['status'] ?? ''}';
        if (kit == null || at == null || (st != 'owned' && st != 'wanted')) continue;
        events.add((c.profile.name, st, kit, at.toLocal()));
      }
    }
    events.sort((a, b) => b.$4.compareTo(a.$4));
    if (events.isEmpty) return const _Empty(icon: Icons.star_border_rounded);
    return Column(
      children: [
        for (final (name, st, kit, at) in events.take(4))
          InkWell(
            onTap: () => openKitDetail(context, kit),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Gp.soft,
                    child: Text(
                      name.isEmpty ? '?' : name.substring(0, 1),
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  st == 'owned' ? const OwnedIcon(size: Gp.iS) : const LikedIcon(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      kit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t14),
                    ),
                  ),
                  Text(
                    _ago(at),
                    style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _ago(DateTime at) => timeAgo(at, now: appNow());
}

/// 비어 있을 때 — 흐린 아이콘 하나
class _Empty extends StatelessWidget {
  const _Empty({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Icon(icon, size: Gp.iL, color: Gp.line),
  );
}
