// 화면 C: 채널 바(홈 · 검색 · 캘린더 · 컬렉션 공용) + 채널 관리
//
// ┌──────── 디자인 가이드 대응표: C 채널 ──────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                    │ 비즈니스 명칭(한글)              │ 원칙(P번호)   │
// │ C-0  │ ChannelHeader                     │ 아바타 줄 + 채널 바 (네 탭 공용)  │ P04           │
// │ C-1  │ ChannelBar (가로 스크롤 텍스트 탭) │ 내 채널 바 (전체 + 내 IP) · 홈 내용을 좌우로 밀어도 바뀜 │ P06 · P04 │
// │ C-2  │ IconButton(ChannelGlyph 세 줄)     │ 채널 관리 열기                   │ P07 · P03     │
// │ C-3  │ CupertinoPageRoute                │ 오른쪽에서 밀려 들어오는 관리 화면 │ P03           │
// │ C-4  │ LongPressDraggable + DragTarget   │ 내 채널 (길게 눌러 순서 변경)     │ P03 · P07     │
// │ C-5  │ 타일 오른쪽 위 − / + 표시          │ 채널 빼기 · 더하기               │ P06 · P01     │
// │ C-6  │ Text(설명)                        │ "아직 수록 상품 없음" 안내        │ P10 · P01     │
// └──────────────────────────────────────────────────────────────────────────────┘
// 전환: C-2 → C-3 쌓기(push, 오른쪽에서). 바꾼 내용은 바로 앱 셸로 올라가 네 화면이 같이 바뀐다.
// 현행 앱 문제: 상단에 5개 IP가 모두에게 고정 → v2는 사람마다 자기 채널만 보이게.
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../channels.dart';
import '../theme.dart';
import '../widgets.dart';

/// '전체' 칩의 id
const allChannelId = 'all';

/// 채널 바가 있는 화면의 공통 상태 (홈 · 검색 · 캘린더 · 컬렉션):
/// 선택한 채널 · 지금 불러온 범위 · 내 채널이 바뀌면 다시 불러오기.
mixin ChannelScope<T extends StatefulWidget> on State<T> {
  /// 선택한 채널 (allChannelId = 전체)
  String channel = allChannelId;
  List<String> _loadedFor = const [];

  /// 앱 셸이 내려 준 내 채널 (화면이 widget.myChannels 로 구현)
  List<String> get myChannels;

  /// '전체'면 내 채널 전부, 아니면 그 채널 하나
  List<String> get scopeIds => channel == allChannelId ? myChannels : [channel];

  /// 범위가 정해졌을 때 데이터를 부르는 곳 (화면이 구현, GET은 api.dart)
  void loadScope(List<String> ids);

  void reloadScope() {
    _loadedFor = [...scopeIds];
    loadScope(_loadedFor);
  }

  void selectChannel(String id) => setState(() {
    channel = id; // STATE: 선택 채널 → 그 범위로 다시 GET
    reloadScope();
  });

  /// 내용 위에서 좌우로 밀면 옆 채널 (전체 → 내 채널 순서, 채널 바와 같은 순서).
  /// 가로로 넘기는 줄 · 배너 위에서 시작하면 그 줄이 먼저 받는다
  Widget channelSwipe(Widget child) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragEnd: (d) {
      final v = d.primaryVelocity ?? 0;
      if (v.abs() < 300) return;
      final ids = [allChannelId, ...myChannels];
      final i = ids.indexOf(channel) + (v < 0 ? 1 : -1);
      if (i >= 0 && i < ids.length) selectChannel(ids[i]); // STATE: 밀기 → 옆 채널
    },
    child: child,
  );

  /// didUpdateWidget 에서 부른다: 내 채널에서 빠진 채널을 보고 있었다면 '전체'로
  void syncScope() {
    if (channel != allChannelId && !myChannels.contains(channel)) channel = allChannelId;
    if (scopeIds.join(',') != _loadedFor.join(',')) setState(reloadScope);
  }
}

/// C-0 아바타 줄 + 채널 바 — 네 탭이 같은 머리를 쓴다
class ChannelHeader extends StatelessWidget {
  const ChannelHeader({
    super.key,
    required this.leading,
    required this.myChannels,
    required this.selected,
    required this.onSelect,
    required this.onMyChannelsChanged,
  });

  /// 좁은 화면: 아바타 · 알림 · 설정 줄 (넓은 화면은 측면 탭에 있으므로 null)
  final Widget? leading;
  final List<String> myChannels;
  final String selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<List<String>> onMyChannelsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 2), child: leading),
        ChannelBar(
          myChannels: myChannels,
          selected: selected,
          onSelect: onSelect,
          onMyChannelsChanged: onMyChannelsChanged,
        ),
      ],
    );
  }
}

/// C-1 내 채널 바
class ChannelBar extends StatelessWidget {
  const ChannelBar({
    super.key,
    required this.myChannels,
    required this.selected,
    required this.onSelect,
    required this.onMyChannelsChanged,
  });

  final List<String> myChannels;

  /// allChannelId 또는 채널 id
  final String selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<List<String>> onMyChannelsChanged;

  @override
  Widget build(BuildContext context) {
    final ids = [allChannelId, ...myChannels];
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              // 오른쪽 끝을 흐리게 — 더 있다는 신호
              shaderCallback: (r) => const LinearGradient(
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.88, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final id in ids)
                    UnderlineTab(
                      label: id == allChannelId ? '전체' : channelOf(id).label,
                      selected: id == selected,
                      onTap: () => onSelect(id), // STATE: 선택 채널 → 아래 목록 다시 거름
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '채널 관리',
            icon: const ChannelGlyph(), // C-2 P07
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                // C-3 P03
                builder: (_) => ChannelManagerScreen(initial: myChannels, onChanged: onMyChannelsChanged),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// C-3 채널 관리
class ChannelManagerScreen extends StatefulWidget {
  const ChannelManagerScreen({super.key, required this.initial, required this.onChanged});

  final List<String> initial;
  final ValueChanged<List<String>> onChanged;

  @override
  State<ChannelManagerScreen> createState() => _ChannelManagerScreenState();
}

class _ChannelManagerScreenState extends State<ChannelManagerScreen> {
  late final List<String> _mine = [...widget.initial];

  void _update(void Function() change) {
    setState(change); // STATE: 내 채널 목록 → 이 화면 두 격자 + 앱 셸의 채널 바
    widget.onChanged([..._mine]);
  }

  void _moveTo(String id, int index) => _update(() {
    _mine.remove(id);
    _mine.insert(index.clamp(0, _mine.length), id);
  });

  @override
  Widget build(BuildContext context) {
    final more = allChannels.where((c) => !_mine.contains(c.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('채널')),
      body: LayoutBuilder(
        builder: (context, box) {
          // 창 너비에 맞춰 3~6열
          final cols = (box.maxWidth / 120).floor().clamp(3, 6);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const _GroupTitle(title: '내 채널', hint: '길게 눌러 순서 변경'),
              if (_mine.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '아래에서 + 를 눌러 채널을 추가하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Gp.muted),
                  ),
                )
              else
                _Grid(
                  cols: cols,
                  children: [
                    for (final (i, id) in _mine.indexed)
                      DragTarget<String>(
                        // C-4 P03
                        onWillAcceptWithDetails: (d) => d.data != id,
                        onAcceptWithDetails: (d) => _moveTo(d.data, i),
                        builder: (context, cand, _) => LongPressDraggable<String>(
                          data: id,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: box.maxWidth / cols - 12,
                              height: 96,
                              child: _ChannelTile(channel: channelOf(id), badge: _Badge.none, lifted: true),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _ChannelTile(channel: channelOf(id), badge: _Badge.none),
                          ),
                          child: _ChannelTile(
                            channel: channelOf(id),
                            badge: _Badge.remove, // C-5 P06
                            highlighted: cand.isNotEmpty,
                            onTap: () => _update(() => _mine.remove(id)),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              const _GroupTitle(title: '더 많은 채널'),
              _Grid(
                cols: cols,
                children: [
                  for (final c in more)
                    _ChannelTile(
                      channel: c,
                      badge: _Badge.add, // C-5 P06
                      onTap: () => _update(() => _mine.add(c.id)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '회색 = 아직 상품 없음 · 추가해 두면 새 상품이 홈에 먼저 떠요', // C-6 P10
                style: TextStyle(color: Gp.muted, fontSize: Gp.t12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title, this.hint = ''});
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text(
            hint,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cols, required this.children});
  final int cols;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: children,
    );
  }
}

enum _Badge { add, remove, none }

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.badge,
    this.onTap,
    this.highlighted = false,
    this.lifted = false,
  });

  final Channel channel;
  final _Badge badge;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: Gp.raised().copyWith(
              border: Border.all(color: highlighted ? Gp.ink : Gp.glass, width: highlighted ? 1.5 : 1),
              boxShadow: lifted ? const [BoxShadow(color: Gp.shadow, blurRadius: 24, offset: Offset(0, 10))] : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleThumb(image: channel.image, label: channel.label),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      channel.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: Gp.t12, color: channel.hasData ? Gp.ink : Gp.faint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge != _Badge.none)
          Positioned(
            top: 7,
            right: 7,
            child: IgnorePointer(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge == _Badge.add ? Colors.transparent : Gp.ink,
                  border: Border.all(color: badge == _Badge.add ? Gp.faint : Gp.ink),
                ),
                child: Icon(
                  badge == _Badge.add ? Icons.add : Icons.remove,
                  size: 12,
                  color: badge == _Badge.add ? Gp.muted : Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
