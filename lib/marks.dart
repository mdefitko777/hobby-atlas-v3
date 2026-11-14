// 좋아요 · 구매함 — 앱 전체가 함께 보는 한 벌. v3: 기기에 저장된다 (lib/data/user_store.dart).
// 홈에서 ♡ 를 누르면 컬렉션 · 상세 · 내 정보 숫자 · 친구 컬렉션의 "나도 있음"까지 같이 바뀐다.
// 한 상품에 상태는 하나 (옛 Gunpula 와 같음): 좋아요 = wanted, 구매함 = owned. 구매함에 넣으면 좋아요에서 빠진다.
// 한국 · 일본 짝(같은 바코드, Kit.twinId)은 한 상품으로 본다 — 어느 id 에 적힌 기록이든 한 카드에 보이고, 바꾸면
// 기록이 있는 쪽 id 에 적는다 (두 id 모두 그대로 쓸 수 있어 옛 기록 · 다른 기기 기록이 깨지지 않는다).
import 'package:flutter/material.dart';

import 'data/user_store.dart';
import 'l10n/l10n.dart';
import 'models.dart';
import 'widgets.dart' show showToast;

class MarksHost extends StatefulWidget {
  const MarksHost({super.key, required this.child, this.store});
  final Widget child;

  /// 테스트용으로 바꿔 끼울 수 있다 (기본: 앱 전체 하나)
  final UserStore? store;

  @override
  State<MarksHost> createState() => _MarksHostState();
}

class _MarksHostState extends State<MarksHost> {
  UserStore get store => widget.store ?? UserStore.instance;

  @override
  void initState() {
    super.initState();
    store.addListener(_onChange);
  }

  @override
  void dispose() {
    store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) => Marks._(store: store, version: store.revision, child: widget.child);
}

class Marks extends InheritedWidget {
  const Marks._({required this.store, required this.version, required super.child});

  final UserStore store;
  final int version;

  /// 그리는 중(build)에 — 바뀌면 다시 그려진다
  static Marks of(BuildContext context) {
    final m = context.dependOnInheritedWidgetOfExactType<Marks>();
    assert(m != null, 'MarksHost 가 위에 없어요 (main.dart 의 MaterialApp.builder)');
    return m!;
  }

  /// 누를 때(콜백)에
  static Marks read(BuildContext context) => context.getInheritedWidgetOfExactType<Marks>()!;

  /// 위에 MarksHost 가 없을 수도 있는 곳 (상세 열기 — 테스트는 MarksHost 없이 연다)
  static Marks? maybeRead(BuildContext context) => context.getInheritedWidgetOfExactType<Marks>();

  bool _live(String id) => switch (store.statusOf(id)) {
    CollectStatus.owned || CollectStatus.wanted => true,
    _ => false,
  };

  /// 기록(좋아요 · 구매함)을 가진 id 들 — 짝 중 기록이 있는 쪽, 아무 쪽에도 없으면 이 상품
  List<String> _holders(Kit k) {
    final ids = [k.id, if (k.twinId.isNotEmpty) k.twinId].where(_live).toList();
    return ids.isEmpty ? [k.id] : ids;
  }

  /// 상세 · 수량 · 구매가가 붙을 id — 짝의 다른 쪽에만 기록이 있으면 그쪽
  String holderId(Kit k) => _holders(k).first;

  /// 내 기록이 없으면 상품에 적힌 status (테스트용 가짜 데이터). 짝은 둘 중 센 쪽 (구매함 > 좋아요)
  CollectStatus statusOf(Kit k) {
    final own = store.statusOf(k.id);
    final twin = k.twinId.isEmpty ? null : store.statusOf(k.twinId);
    if (own == CollectStatus.owned || twin == CollectStatus.owned) return CollectStatus.owned;
    if (own == CollectStatus.wanted || twin == CollectStatus.wanted) return CollectStatus.wanted;
    return own ?? k.status;
  }

  /// 기록이 있는 쪽 id(둘 다면 둘 다)에 적는다 — 짝의 두 기록이 서로 다른 상태로 남지 않게
  void _write(Kit k, CollectStatus next) {
    for (final id in _holders(k)) {
      if (store.statusOf(id) != next) store.setStatus(id, next);
    }
  }

  bool liked(Kit k) => statusOf(k) == CollectStatus.wanted;
  bool owned(Kit k) => statusOf(k) == CollectStatus.owned;

  /// owned 가 liked 보다 우선. 끄는 쪽은 그 상태일 때만 지운다.
  void set(Kit k, {bool? liked, bool? owned}) {
    final now = statusOf(k);
    var next = now;
    if (liked == true) next = CollectStatus.wanted;
    if (liked == false && now == CollectStatus.wanted) next = CollectStatus.none;
    if (owned == true) next = CollectStatus.owned;
    if (owned == false && now == CollectStatus.owned) next = CollectStatus.none;
    if (next != now) _write(k, next);
  }

  void _restore(Kit k, CollectStatus s) {
    if (statusOf(k) != s) _write(k, s);
  }

  /// ♡ 누르기 + 토스트(되돌리기) — 상품 사진 · 상세 · 카메라 결과 공통
  void toggleLike(BuildContext context, Kit k) {
    final before = statusOf(k);
    set(k, liked: before != CollectStatus.wanted);
    showToast(
      context,
      before == CollectStatus.wanted
          ? tr('좋아요를 취소했어요')
          : before == CollectStatus.owned
          ? trf('「{name}」 구매함 → 좋아요로 옮겼어요', {'name': k.name})
          : trf('「{name}」 좋아요', {'name': k.name}),
      onUndo: () => _restore(k, before),
    );
  }

  /// 리본 누르기 + 토스트(되돌리기)
  void toggleOwn(BuildContext context, Kit k) {
    final before = statusOf(k);
    set(k, owned: before != CollectStatus.owned);
    showToast(
      context,
      before == CollectStatus.owned ? tr('구매함에서 뺐어요') : trf('「{name}」 구매함에 넣었어요', {'name': k.name}),
      onUndo: () => _restore(k, before),
    );
  }

  @override
  bool updateShouldNotify(Marks old) => version != old.version;
}
