// 홈 › My Page — "내 것"만 모아 보는 탭 (글자 대신 아이콘: ♡ 좋아요 · 리본 구매함 · ★ 특별 관심)
//
// ┌──────── 디자인 가이드 대응표: A 홈 › My Page ──────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ A-21 │ _Stats (아이콘 4칸)                 │ 좋아요 수 · 구매함 수 · 이번 달 지출 · 총 지출 │ P01 · P07 │
// │ A-22 │ _LikedSoon                         │ 좋아요 중 날짜가 다가오는 것 (PB 마감 · 발매) │ P01     │
// │ A-23 │ _OwnedRow                          │ 최근 산 것 (가로 줄)                     │ P08           │
// │ A-24 │ _SpecialFeed                       │ 특별 관심 친구가 최근 담은 것            │ P01           │
// └──────────────────────────────────────────────────────────────────────────────────┘
import 'package:flutter/material.dart';

import '../api.dart';
import '../clock.dart';
import '../data/catalog.dart';
import '../data/user_store.dart';
import '../marks.dart';
import '../models.dart';
import '../sync/account.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';
import 'f_collection_screen.dart' show CollectionJump;

class MyPageView extends StatefulWidget {
  const MyPageView({super.key, required this.loaders, this.onJump});
  final Loaders loaders;

  /// 숫자 · 머리 아이콘 → 컬렉션 탭 (앱 셸)
  final ValueChanged<CollectionJump>? onJump;

  @override
  State<MyPageView> createState() => _MyPageViewState();
}

class _MyPageViewState extends State<MyPageView> {
  @override
  Widget build(BuildContext context) {
    Marks.of(context); // 좋아요 · 구매함이 바뀌면 다시 그린다
    final me = UserStore.instance;
    final cat = Catalog.instance;
    final liked = [for (final id in me.idsWith(const {CollectStatus.wanted})) ?cat.byId[id]];
    final owned = [for (final id in me.idsWith(const {CollectStatus.owned})) ?cat.byId[id]];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 레벨은 왼쪽 위 아바타 옆 Lv (lib/level.dart) — 여기는 숫자 4칸만
        SectionPanel(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _Stats(
            liked: liked.length,
            owned: owned.length,
            month: me.spendInMonth(appNow()),
            total: me.spendKrw,
            onJump: widget.onJump,
          ),
        ),
        _Section(
          icon: const Icon(Icons.favorite, size: 18, color: Gp.accent),
          onMore: () => widget.onJump?.call(CollectionJump.liked),
          child: _LikedSoon(kits: liked, loaders: widget.loaders),
        ),
        _Section(
          icon: const RibbonIcon(size: 17),
          onMore: () => widget.onJump?.call(CollectionJump.owned),
          child: _OwnedRow(kits: owned.take(12).toList(), loaders: widget.loaders),
        ),
        _Section(
          icon: const Icon(Icons.star_rounded, size: 20, color: Color(0xFFBA7517)),
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
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.chevron_right, color: Gp.faint)),
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

/// A-21 숫자 4칸 — 아이콘 + 숫자 (좋아요 · 구매함은 누르면 그 목록)
class _Stats extends StatelessWidget {
  const _Stats({required this.liked, required this.owned, required this.month, required this.total, this.onJump});
  final int liked, owned, month, total;
  final ValueChanged<CollectionJump>? onJump;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget icon, String value, {VoidCallback? onTap, String tip = ''}) => Expanded(
      child: Tooltip(
        message: tip,
        child: Material(
          color: Gp.soft,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  SizedBox(height: 18, child: Center(child: icon)),
                  const SizedBox(height: 3),
                  Text(value, style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        cell(const Icon(Icons.favorite, size: 17, color: Gp.accent), '$liked', onTap: () => onJump?.call(CollectionJump.liked), tip: '좋아요'),
        const SizedBox(width: 6),
        cell(const RibbonIcon(size: 16), '$owned', onTap: () => onJump?.call(CollectionJump.owned), tip: '구매함'),
        const SizedBox(width: 6),
        cell(const Icon(Icons.calendar_month_outlined, size: 17, color: Gp.muted), wonShort(month), tip: '이번 달 지출'),
        const SizedBox(width: 6),
        cell(const Icon(Icons.account_balance_wallet_outlined, size: 17, color: Gp.muted), wonShort(total), tip: '총 지출'),
      ],
    );
  }
}

/// 날짜 꼬리표 하나 (빨강 = PB 예약 마감, 파랑 = 발매)
class DateTag extends StatelessWidget {
  const DateTag(this.text, {super.key, this.urgent = false});
  final String text;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final c = urgent ? Gp.danger : Gp.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: Gp.t11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

/// 상품의 다가오는 날짜 (PB 예약 마감 > 발매일) — 없으면 null. My Page · 캘린더 공통
({String sortKey, String label, bool urgent})? upcomingOf(Kit k, {bool wanted = true}) {
  final now = appNow();
  final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  if (wanted && k.pbCloses.length >= 10 && k.pbCloses.compareTo(today) >= 0) {
    final d = DateTime.parse(k.pbCloses).difference(DateTime(now.year, now.month, now.day)).inDays;
    return (sortKey: k.pbCloses, label: d == 0 ? 'PB 오늘' : 'PB D-$d', urgent: true);
  }
  if (k.date.length == 10 && k.date.compareTo(today) >= 0) {
    return (sortKey: k.date, label: dateDot(k.date.substring(5)), urgent: false);
  }
  if (k.date.length == 7 && k.date.compareTo(today.substring(0, 7)) >= 0) {
    return (sortKey: '${k.date}-99', label: '${int.parse(k.date.substring(5))}월', urgent: false);
  }
  return null;
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
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(width: 38, height: 38, child: AppImage(k.image, placeholder: k.line)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: Gp.t14)),
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
                    child: Text(name.isEmpty ? '?' : name.substring(0, 1), style: const TextStyle(fontSize: Gp.t12, color: Gp.ink)),
                  ),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  st == 'owned' ? const RibbonIcon(size: 14) : const Icon(Icons.favorite, size: 14, color: Gp.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(kit.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: Gp.t14)),
                  ),
                  Text(_ago(at), style: const TextStyle(fontSize: Gp.t11, color: Gp.faint)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _ago(DateTime at) {
    final d = appNow().difference(at);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}분';
    if (d.inHours < 24) return '${d.inHours}시간';
    if (d.inDays < 7) return '${d.inDays}일';
    return dateDot('${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}');
  }
}

/// 비어 있을 때 — 흐린 아이콘 하나
class _Empty extends StatelessWidget {
  const _Empty({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Icon(icon, size: 26, color: Gp.line),
  );
}
