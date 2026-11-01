// 화면 J: 공식 예고 상세 — 반다이 방송 · 공지가 지금 어느 단계인지
//
// ┌──────── 디자인 가이드 대응표: J 공식 예고 상세 ────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ J-1  │ 16:9 사진(화면 끝까지) + 뒤로        │ 공식 홍보 이미지                        │ P02 · P03     │
// │ J-2  │ SoftTag(단계 색) · IP · 날짜 · 출처     │ 예고 요약                              │ P01 · P02     │
// │ J-3  │ 4단계 진행 줄 (현재 = 브랜드 색)      │ 공식 발표 → 상품화 확정 → 예약 시작 → 발매 │ P01 · P06 │
// │ J-4  │ TogglePill(알림 받기) + 토스트       │ 다음 단계가 되면 알림 (가짜)            │ P03 · P07     │
// │ J-5  │ 공식으로 가기 ↗                        │ 출처 (반다이 공식)                      │ P10           │
// │ J-6  │ 가로 ProductTile (GET /kits)        │ 같은 IP의 상품                          │ P06           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 홈 배너 · 홈 공식 예고 줄 · 캘린더 예고 줄에서 쌓기(push, 오른쪽에서).
import 'package:flutter/material.dart';

import '../api.dart';
import '../detail_pane.dart';
import '../channels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';

/// 예고가 지나가는 단계 (db.json announcements.status 와 같은 글자)
const announcementStages = ['공식 발표', '상품화 확정', '예약 시작', '발매'];

void openAnnouncement(BuildContext context, Announcement a, {Loaders loaders = const Loaders()}) {
  openPage(
    context,
    AnnouncementScreen(item: a, loaders: loaders),
    id: a.id,
  );
}

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key, required this.item, this.loaders = const Loaders()});
  final Announcement item;
  final Loaders loaders;

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  bool _notify = false;
  late final Future<List<Kit>> _related = widget.loaders.kits([widget.item.franchiseId]);

  void _toggleNotify() {
    final before = _notify;
    setState(() => _notify = !before); // STATE: 알림 → 버튼 채움
    showToast(context, before ? '알림을 껐어요' : '다음 단계가 되면 알려 드릴게요', onUndo: () => setState(() => _notify = before));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.item;
    final stage = announcementStages.indexOf(a.status).clamp(0, announcementStages.length - 1);
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              ColoredBox(
                color: Gp.panel,
                child: SafeArea(
                  bottom: false,
                  child: AspectRatio(aspectRatio: 16 / 9, child: AppImage(a.image)), // J-1 P02
                ),
              ),
              SectionPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SoftTag(a.status, color: stageColor(a.status)), // J-2 P01
                        const SizedBox(width: 8),
                        Text(
                          channelOf(a.franchiseId).label,
                          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      a.title,
                      style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      joinDot([dateDot(a.date), a.source]),
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                    const SizedBox(height: 20),
                    _StageLine(current: stage), // J-3 P01
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TogglePill(
                            // J-4 P03
                            label: _notify ? '알림 받는 중' : '알림 받기',
                            icon: Icons.notifications_none,
                            activeIcon: Icons.notifications_active,
                            active: _notify,
                            onTap: _toggleNotify,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showToast(context, '반다이 공식 페이지를 브라우저에서 열어요'), // J-5 P10
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall)),
                              ),
                            ),
                            icon: const Icon(Icons.north_east, size: Gp.iS),
                            label: const Text('공식으로 가기'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SectionPanel(
                padding: const EdgeInsets.only(bottom: 24),
                child: FutureBuilder<List<Kit>>(
                  future: _related, // STATE: GET /kits?franchiseId= → 같은 IP 상품
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SizedBox(height: 120, child: LoadingView());
                    }
                    if (snap.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('관련 상품을 불러오지 못했어요', style: TextStyle(color: Gp.muted)),
                      );
                    }
                    final kits = snap.data!;
                    if (kits.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '아직 연결된 상품이 없어요 · 상품화되면 여기에 보여요', // P09
                          style: TextStyle(color: Gp.muted),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader('${channelOf(a.franchiseId).label}의 다른 상품'), // J-6 P06
                        SizedBox(
                          height: 148 + 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: kits.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, i) => ProductTile(
                              image: kits[i].image,
                              title: kits[i].name,
                              imageWidth: 148,
                              onTap: () => openKitDetail(context, kits[i], loaders: widget.loaders),
                              marks: QuickMarks(kit: kits[i]),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RaisedCircleButton(
                // J-1 P03
                tooltip: '뒤로',
                size: 40,
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(Icons.arrow_back_ios_new, size: Gp.iM, color: Gp.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// J-3 단계 진행 줄 — 지난 단계 · 지금(브랜드 색) · 남은 단계(회색)
class _StageLine extends StatelessWidget {
  const _StageLine({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, label) in announcementStages.indexed) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0 ? Colors.transparent : (i <= current ? Gp.accent : Gp.line),
                      ),
                    ),
                    Container(
                      width: i == current ? 14 : 10,
                      height: i == current ? 14 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? Gp.accent : Gp.panel,
                        border: Border.all(color: i <= current ? Gp.accent : Gp.line, width: 2),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == announcementStages.length - 1
                            ? Colors.transparent
                            : (i < current ? Gp.accent : Gp.line),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Gp.t11,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                    color: i == current ? Gp.accent : (i < current ? Gp.ink : Gp.faint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
