// 화면 G: 도감 — 컬렉션의 다른 보기. 칸은 늘 컬러, 모은 것은 ♡ · 리본 표시로.
//
// ┌──────── 디자인 가이드 대응표: G 도감 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ G-1  │ CategoryGrid · CategoryTile          │ '전체'일 때: 도감을 볼 IP 고르기 (공식 그림 + 이름, 숫자 없음) │ P06 │
// │ G-2  │ ? 버튼(HelpButton) → 바텀 시트      │ 도감 읽는 법 (긴 범례 줄 대신) · 작품 도감은 아이콘 뜻도 │ P10 · P08 │
// │ G-3  │ 시대 SectionHeader + CategoryGrid    │ 건담 작품 도감 (Atlas 시대 → 작품 로고 + 이름, 폰 한 줄 4칸) │ P06 · P08 │
// │ G-4  │ 기체 칸 격자 (TierCell, 늘 컬러)      │ 아직 = 그림 그대로 · ♡ = 좋아요 · 리본 + 옅은 민트 테두리 = 구매함 · 내 사진 + 도는 고리 │ P01 · P04 │
// │ G-4a │ Lv 막대 (좋아요 1 · 구매 2 · 사진 3점) │ 하나 더할 때마다 오르는 작품 레벨        │ P01           │
// │ G-4b │ 칸 위 MarkOverlay (리본 · ♡)          │ 상품 하나면 그 상품 · 없으면 손으로 켜기 · 여럿이면 시트 │ P07 · P04 │
// │ G-4c │ ViewIconToggle + 장마다 SectionHeader · 칸 격자 │ 화수별 보기 (gundam-chapters 가 있을 때만, 장 머리에 숫자 없음) │ P01 · P07 │
// │ G-4d │ 머리 ToolIcon(공유) → V 공유 카드      │ 작품 진행 카드: 켜진 칸 / 전체 · 칸 격자 그림 │ P07 · P10   │
// │ G-5  │ 바텀 시트(끌어 올리기): 기체 → 상품    │ 이 기체의 상품 전부 → 상품 상세          │ P07           │
// │ G-5a │ ThumbRow + ♡ · 책갈피 아이콘          │ 상품 줄: 등급 · 축척 · 발매월 · 바로 좋아요 · 구매함 │ P07 · P04 │
// │ G-5b │ 시트의 TogglePill 2개                │ 손으로 켜기(기기 저장) · 내 사진          │ P03 · P07     │
// │ G-5c │ 바텀 시트(카메라 · 갤러리) (T-2)      │ 이 기체의 내 사진 → 사진 벽에도 (기기 저장) │ P05 · P07   │
// │ G-6  │ 베이 칸 + n/3 · 부품 시트            │ 베이블레이드 X 도감 (부품 3개, 늘 컬러 · 다 모으면 리본 · 좋아요 ♡) │ P01 │
// │ G-6a │ 🔧 ToolIcon (베이 머리줄)            │ 조합 만들기 (화면 T) — 블레이드 · 래칫 · 비트 · 덱 │ P07     │
// │ G-7  │ 세대 SectionHeader + CategoryGrid    │ 포켓몬 세대 · Fate 작품 · AC 세대 (그림 + 이름만) │ P06 │
// │ G-7b │ TagGameCards (포켓몬 '태그' 줄)       │ MEZASTAR · Frienda 태그 도감 입구 (R, CategoryTile) │ P06 │
// │ G-7a │ SectionListView (쌓기)              │ 묶음 카드 → 그 묶음 상품 (찾기 · 필터 · 격자/목록) │ P07 │
// │ G-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 정리 안 된 작품(정리 요청) │ P01 · P09 │
// │ G-5d │ 기체 시트 ⚑                          │ 빠진 상품 제보 (GitHub 이슈)             │ P07           │
// │ G-9  │ FindBar + GuideFilterSheet(GpPickSheet 60%) │ 도감에서 찾기(작품 · 기체 이름 · 형식번호) + 도감 필터 = 상품 필터와 같은 틀: 상태(전체 · ♡ · 리본 · 아직 없음 · 내 사진) · 라인 · 시대 · 기체 종류 · 상품 있는 것만 · 정렬 │ P04 · P07 · P01 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 🔧 → T 베이 조합 만들기(쌓기). 작품 칸 → 작품 도감(쌓기) → 기체 시트(덮기) → D 상품 상세(쌓기, 이 기체 상품끼리 좌우). 베이 → 부품 시트(덮기).
//       기체 시트 → 사진 고르기(덮기, T-2) → 토스트.
// 데이터: lib/data/derive.dart 건담 도감 ← lib/data/gundam_atlas.dart (data/atlas/gundam-ms · gundam-kit-ms · gundam-chapters).
//       작품 · 시대 카드 그림 = 공식 작품 로고 (주소 · 출처는 데이터 쪽 GundamAtlas 가 정한다).
// 코드: 이 파일 = G-1 · 고르기, lib/screens/guide/ = gundam_guide(G-3) · work_guide_screen(G-4 · G-5) · bbx_guide(G-6)
//       · world_guide(G-7) · guide_parts(찾기 · 칸 GuideCell = lib/widgets/tier_cell.dart TierCell). 분류 칸 = lib/widgets/tiles.dart CategoryTile.
import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../l10n/l10n.dart';
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
      return EmptyView(
        icon: Icons.auto_awesome_mosaic_outlined,
        message: tr('내 채널이 비어 있어요'),
        detail: tr('채널 관리에서 IP를 추가하면 도감을 볼 수 있어요'),
      );
    }
    return ListView(
      padding: EdgeInsets.only(top: 8, bottom: navClearance(context)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gp.gutter, 0, Gp.gutter, 12),
          child: Text(tr('어느 도감을 볼까요?'), style: const TextStyle(color: Gp.muted)),
        ),
        CategoryGrid(
          children: [
            for (final id in myChannels)
              CategoryTile(
                // G-1 P06 채널 공식 그림 + 이름만
                image: channelOf(id).image,
                name: tr(channelOf(id).label),
                onTap: () => onPick(id), // STATE: 채널 선택 → 그 IP 도감
              ),
          ],
        ),
      ],
    );
  }
}
