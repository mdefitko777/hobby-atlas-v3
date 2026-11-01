// 도감 칸 한 벌 — 건담 기체 · 베이 · 메자스타 · 프렌다 태그 · 설정의 견본이 같은 틀 · 같은 그림 · 같은 톡 튀기를 쓴다.
//   단계: 흑백(아직) → 컬러(좋아요) → 민트 테두리(구매함) → 도는 고리 + 내 사진(인증)
import 'package:flutter/material.dart';

import '../theme.dart';
import 'images.dart';
import 'rings.dart';

/// 도감 칸 단계 — 흑백 · 컬러(좋아요) · 초록 테두리(구매) · 도는 고리(사진 인증)
enum CellTier { none, liked, owned, photo }

/// 단계별 칸 틀 (도감 칸 · ? 견본 공통)
Widget tierFrame(CellTier tier, Widget child, {double radius = Gp.radius}) {
  final photo = tier == CellTier.photo;
  final inner = Container(
    decoration: BoxDecoration(
      color: Gp.panel,
      borderRadius: BorderRadius.circular(photo ? radius - 2 : radius),
      border: switch (tier) {
        CellTier.photo => null,
        CellTier.owned => Border.all(color: Gp.own, width: 2.2), // 가진 것 = 민트
        _ => Border.all(color: Gp.line),
      },
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  return photo ? AccentRing(radius: radius, spin: true, child: inner) : inner;
}

/// 칸 안 그림: 내 사진이면 꽉 채우고, 아니면 공식 그림 (없음 = 흑백)
Widget cellImage(CellTier tier, String image, String? photo) => tier == CellTier.photo && photo != null
    ? AppImage(photo)
    : Padding(
        padding: const EdgeInsets.all(6),
        child: AppImage(image, fit: BoxFit.contain, grayscale: tier == CellTier.none),
      );

/// 도감 칸 하나: 틀 + 그림 + 위에 얹는 것([overlays]) + 아래 글자([caption]). 단계가 오르면 톡 튀어 오른다
class TierCell extends StatefulWidget {
  const TierCell({
    super.key,
    required this.image,
    required this.tier,
    required this.caption,
    required this.onTap,
    this.photo,
    this.overlays = const [],
    this.onLongPress,
    this.square = true,
    this.gap = 5,
  });

  final String image;
  final CellTier tier;

  /// 칸 아래 이름 줄
  final Widget caption;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 내가 올린 사진 (있으면 칸 그림 대신 보여 준다)
  final String? photo;

  /// 그림 위 꼬리표 · 배지 · 리본 (Positioned)
  final List<Widget> overlays;

  /// true = 칸 그림을 정사각형으로 가운데에, false = 남는 높이를 다 쓴다
  final bool square;

  /// 그림과 이름 사이
  final double gap;

  @override
  State<TierCell> createState() => _TierCellState();
}

class _TierCellState extends State<TierCell> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );
  late final Animation<double> _scale = _pop.drive(
    Tween(begin: 0.86, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
  );

  @override
  void didUpdateWidget(TierCell old) {
    super.didUpdateWidget(old);
    if (widget.tier.index > old.tier.index) _pop.forward(from: 0); // 한 단계 올라감
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;
    final frame = ScaleTransition(
      scale: _scale,
      child: tierFrame(
        t,
        Stack(fit: StackFit.expand, children: [cellImage(t, widget.image, widget.photo), ...widget.overlays]),
      ),
    );
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: widget.square ? Center(child: AspectRatio(aspectRatio: 1, child: frame)) : frame,
          ),
          SizedBox(height: widget.gap),
          widget.caption,
        ],
      ),
    );
  }
}
