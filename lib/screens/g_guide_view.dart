// 화면 G: 도감 — 컬렉션의 다른 보기. 모은 만큼 칸에 불이 켜진다.
//
// ┌──────── 디자인 가이드 대응표: G 도감 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ G-1  │ 채널 타일 격자                      │ '전체'일 때: 도감을 볼 IP 고르기         │ P06           │
// │ G-2  │ ? 버튼 → 바텀 시트                 │ 도감 읽는 법 (긴 범례 줄 대신)           │ P10 · P08     │
// │ G-3  │ 시대 섹션 + 작품 카드 + 진행 막대     │ 건담 작품 도감 (Atlas 시대 → 작품, 수집 n/전체) │ P01 · P06 │
// │ G-4  │ 기체 칸 격자 (4단계)                 │ 흑백 → ♡ 컬러 → 리본 컬러·초록 테두리 → 내 사진·도는 고리 │ P01 · P04 │
// │ G-4a │ Lv 막대 (좋아요 1 · 구매 2 · 사진 3점) │ 하나 더할 때마다 오르는 작품 레벨        │ P01           │
// │ G-4b │ 칸 위 MarkOverlay (리본 · ♡)          │ 상품 하나면 그 상품 · 없으면 손으로 켜기 · 여럿이면 시트 │ P07 · P04 │
// │ G-4c │ ViewIconToggle + 장마다 SectionHeader · 칸 격자 │ 화수별 보기 (gundam-chapters 가 있을 때만) │ P01 · P07 │
// │ G-5  │ 바텀 시트(끌어 올리기): 기체 → 상품    │ 이 기체의 상품 전부 → 상품 상세          │ P07           │
// │ G-5a │ ThumbRow + ♡ · 책갈피 아이콘          │ 상품 줄: 등급 · 축척 · 발매월 · 바로 좋아요 · 구매함 │ P07 · P04 │
// │ G-5b │ 시트의 TogglePill 2개                │ 손으로 켜기(기기 저장) · 내 사진          │ P03 · P07     │
// │ G-5c │ 바텀 시트(카메라 · 갤러리) (T-2)      │ 이 기체의 내 사진 → 사진 벽에도 (기기 저장) │ P05 · P07   │
// │ G-6  │ 베이 칸 + n/3 · 부품 시트            │ 베이블레이드 X 도감 (부품 3개)          │ P01           │
// │ G-6a │ 🔧 ToolIcon (베이 머리줄)            │ 조합 만들기 (화면 T) — 블레이드 · 래칫 · 비트 · 덱 │ P07     │
// │ G-7  │ 세대 · 작품 카드 + 진행 막대          │ 포켓몬 세대 · Fate 작품 · AC 세대       │ P01           │
// │ G-7b │ TagGameCards (포켓몬 세대 위)         │ MEZASTAR · Frienda 태그 도감 입구 (R)   │ P06           │
// │ G-7a │ SectionListView (쌓기)              │ 묶음 카드 → 그 묶음 상품 (찾기 · 필터 · 격자/목록) │ P07 │
// │ G-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 정리 안 된 작품(정리 요청) │ P01 · P09 │
// │ G-5d │ 기체 시트 ⚑                          │ 빠진 상품 제보 (GitHub 이슈)             │ P07           │
// │ G-9  │ FindBar + GuideFilterSheet(60% 시트) │ 도감에서 찾기(작품 · 기체 이름 · 형식번호) + 도감 필터: 단계(아직 · ♡ · 구매함 · 내 사진) · 상품 있는 것만 · 등급 · 종류 · 시대 · 정렬 │ P04 · P07 · P01 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 🔧 → T 베이 조합 만들기(쌓기). 작품 카드 → 작품 도감(쌓기) → 기체 시트(덮기) → D 상품 상세(쌓기, 이 기체 상품끼리 좌우). 베이 → 부품 시트(덮기).
//       기체 시트 → 사진 고르기(덮기, T-2) → 토스트.
// 데이터: lib/data/derive.dart 건담 도감 ← lib/data/gundam_atlas.dart (data/atlas/gundam-ms · gundam-kit-ms · gundam-chapters).
//       작품 · 시대 카드 그림 = 공식 작품 로고 (주소 · 출처는 데이터 쪽 GundamAtlas 가 정한다).
// 코드: 이 파일 = G-1 · 고르기, lib/screens/guide/ = gundam_guide(G-3) · work_guide_screen(G-4 · G-5) · bbx_guide(G-6)
//       · world_guide(G-7) · guide_parts(찾기 · 카드 · 칸 GuideCell = lib/widgets/tier_cell.dart TierCell).
import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'guide/bbx_guide.dart';
import 'guide/guide_parts.dart';
import 'guide/gundam_guide.dart';
import 'guide/world_guide.dart';

export 'guide/work_guide_screen.dart' show WorkGuideScreen;

class GuideView extends StatelessWidget {
  const GuideView({
    super.key,
    required this.channel,
    required this.myChannels,
    required this.onPickChannel,
    required this.loaders,
    this.query = '',
    this.filter,
  });

  final String channel;
  final List<String> myChannels;
  final ValueChanged<String> onPickChannel;
  final Loaders loaders;

  /// G-9 찾기 (컬렉션의 FindBar 글자)
  final String query;

  /// G-9 도감 필터 — 컬렉션의 필터 아이콘이 이 조건을 바꾸고, 도감은 지금 칸들을 [GuideFilterController.pool] 에 채운다
  final GuideFilterController? filter;

  @override
  Widget build(BuildContext context) {
    if (channel == allChannelId) return _ChannelPicker(myChannels: myChannels, onPick: onPickChannel);
    final ctrl = filter ?? GuideFilterController();
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final find = GuideFind(query, ctrl);
        return switch (channel) {
          'gundam' => GundamGuide(loaders: loaders, find: find),
          'beyblade' => BbxGuide(loaders: loaders, find: find),
          _ => WorldGuide(channel: channel, loaders: loaders, find: find),
        };
      },
    );
  }
}

/// G-1 '전체'일 때: IP 고르기
class _ChannelPicker extends StatelessWidget {
  const _ChannelPicker({required this.myChannels, required this.onPick});
  final List<String> myChannels;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (myChannels.isEmpty) {
      return const EmptyView(
        icon: Icons.auto_awesome_mosaic_outlined,
        message: '내 채널이 비어 있어요',
        detail: '채널 관리에서 IP를 추가하면 도감을 볼 수 있어요',
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, navClearance(context)),
      children: [
        const Text('어느 도감을 볼까요?', style: TextStyle(color: Gp.muted)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final id in myChannels)
              GestureDetector(
                onTap: () => onPick(id), // STATE: 채널 선택 → 그 IP 도감
                child: Container(
                  decoration: Gp.raised(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleThumb(image: channelOf(id).image, label: channelOf(id).label, size: 46),
                      const SizedBox(height: 8),
                      Text(
                        channelOf(id).label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: Gp.t12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
