// 화면 V: 공유 카드 — 내 컬렉션 요약 · 도감 작품 진행을 그림(PNG)으로 공유 · 저장
//
// ┌──────── 디자인 가이드 대응표: V 공유 카드 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ V-1  │ 바텀 시트 + RepaintBoundary 미리보기 │ 공유할 카드 그대로 보기                  │ P02 · P01     │
// │ V-2  │ CollectionShareCard                 │ 내 컬렉션: 아바타 · Lv · ♡ · 리본 · 예약 · 미조립 · 박스 아트 │ P07 · P08 │
// │ V-3  │ GuideShareCard                      │ 도감 작품: 켜진 칸 / 전체 · 칸 격자        │ P01 · P07     │
// │ V-4  │ 워터마크 "HA · @아이디"              │ 어디서 만든 카드인지 (내 아이디)          │ P10           │
// │ V-5  │ 아이콘 버튼 두 개: 공유 · 저장        │ 안드로이드 공유 창(share_plus) · 파일로 저장 │ P07 · P03   │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 입구: 내 정보(I) 머리 공유 · My Page(A-21) 숫자 줄 공유 · 작품 도감(G-4) 머리 공유. 전환: 덮기(바텀 시트).
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../data/catalog.dart';
import '../level.dart';
import '../logic/build_status.dart';
import '../logic/level_math.dart';
import '../marks.dart';
import '../models.dart';
import '../sync/account.dart';
import '../theme.dart';
import '../widgets.dart';
import 'u_social.dart' show MyAvatar;

/// V-1 · V-5 카드 미리보기 + 공유 · 저장 — [fileName] 은 확장자 없이
Future<void> showShareCard(BuildContext context, {required Widget card, required String fileName}) {
  final key = GlobalKey();
  return showGpSheet<void>(
    context,
    tall: true,
    builder: (sheet) => _ShareSheet(boundary: key, card: card, fileName: '$fileName.png'),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.boundary, required this.card, required this.fileName});
  final GlobalKey boundary;
  final Widget card;
  final String fileName;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(Uint8List png) f) async {
    if (_busy) return;
    setState(() => _busy = true); // STATE: 찍는 중 → 버튼 잠금
    try {
      final png = await captureCard(widget.boundary);
      if (png == null) throw StateError('카드를 그리지 못했어요');
      await f(png);
    } on Object catch (e) {
      if (mounted) showToast(context, '만들지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run(
    (png) => SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: widget.fileName)],
        fileNameOverrides: [widget.fileName],
      ),
    ),
  );

  Future<void> _save() => _run((png) async {
    final uri = await FilePicker.saveFile(fileName: widget.fileName, bytes: png, mimeType: 'image/png');
    if (mounted && uri != null) showToast(context, '저장했어요');
  });

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String tip, VoidCallback onTap, {Key? key}) => RaisedCircleButton(
      key: key,
      tooltip: tip,
      size: 52,
      onTap: () => _busy ? null : onTap(),
      child: Icon(icon, size: Gp.iL, color: _busy ? Gp.faint : Gp.ink),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gp.gutter, 0, Gp.gutter, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // V-1 찍히는 그대로 (폭이 좁은 폰은 줄여서 보인다)
            FittedBox(
              child: RepaintBoundary(key: widget.boundary, child: widget.card),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                action(Icons.ios_share, '공유', _share, key: const ValueKey('share-card-share')), // V-5
                const SizedBox(width: 24),
                action(Icons.download_outlined, '저장', _save, key: const ValueKey('share-card-save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// V-2 내 컬렉션 카드 — 내 정보 · My Page 에서. [level] 을 모르면 도감에서 센다
Future<void> openCollectionShare(BuildContext context, {Loaders loaders = const Loaders(), int? level}) async {
  final marks = Marks.read(context);
  final me = marks.store;
  final account = AccountScope.read(context);
  var lv = level;
  if (lv == null) {
    try {
      lv = guideLevel((await loadLevel(loaders)).lit, 0, owned: me.ownedCount);
    } on Object {
      lv = guideLevel(0, 0, owned: me.ownedCount);
    }
  }
  if (!context.mounted) return;
  final owned = me.idsWith(const {CollectStatus.owned});
  final byId = Catalog.instance.byId;
  final name = account.signedIn ? account.displayName : '나';
  final handle = account.signedIn ? account.handle : '';
  await showShareCard(
    context,
    fileName: 'hobby-atlas-collection',
    card: CollectionShareCard(
      avatar: MyAvatar(fallback: name.characters.isEmpty ? '나' : name.characters.first, size: 56, ringWidth: 2.5),
      name: name.isEmpty ? '나' : name,
      handle: handle,
      level: LevelChip(level: lv),
      liked: me.wantedCount,
      owned: owned.length,
      preorders: me.activePreorders.keys.where((id) => me.statusOf(id) != CollectStatus.owned).length,
      backlog: backlogCount(owned.where((id) => byId[id] != null && needsAssembly(byId[id]!)), me.stageOf),
      thumbs: [
        for (final id in owned)
          if (byId[id]?.image case final img? when img.isNotEmpty) img,
      ].take(CollectionShareCard.maxThumbs).toList(),
    ),
  );
}

/// V-3 도감 작품 카드 — 작품 도감(G-4) 머리에서. [tiers] = 기체 칸마다 지금 단계
Future<void> openGuideShare(BuildContext context, {required GuideWork work, required List<CellTier> tiers}) {
  final account = AccountScope.read(context);
  return showShareCard(
    context,
    fileName: 'hobby-atlas-${work.id}',
    card: GuideShareCard(
      image: work.image,
      name: work.name,
      handle: account.signedIn ? account.handle : '',
      tiers: tiers,
    ),
  );
}
