// 화면 G: 도감 — 컬렉션의 다른 보기. 검색 탭 종류 · 세대와 같은 틀: 왼쪽 묶음 목록 + 오른쪽 칸 격자 (펴면 3칸 · 접으면 4칸).
// 칸은 늘 컬러, 모은 것은 ♡ · 리본 표시로. 레벨 막대 · 수집 n / m 은 도감에 두지 않는다 (2026-11-20 주인).
//
// ┌──────── 디자인 가이드 대응표: G 도감 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ G-1  │ SideGrid · CategoryTile              │ '전체' · 내 채널 여럿일 때: 도감을 볼 채널 고르기 (검색 탭 칸과 같은 정사각 칸 · 공식 그림 칸 가득, 숫자 없음) · 하나면 바로 그 도감 │ P06 │
// │ G-2  │ 서랍 › 사용법 (도감 묶음)             │ 도감 읽는 법 (칸 표시 · 묶음 목록 · 아이콘 뜻) — 머리 줄 ? 는 서랍으로 │ P10 · P08 │
// │ G-3  │ SideDirectory (시대 머리 · 작품 줄)   │ 건담 도감: 왼쪽 시대별 작품 목록 → 오른쪽 그 작품 기체 칸 · 밀기 + ≡ 로 펴고 접기 (기억은 검색 탭과 따로) │ P06 · P08 │
// │ G-4  │ 기체 칸 격자 (GuideCell = TierCell, 늘 컬러) │ 아직 = 그림 그대로 · ♡ = 좋아요 · 리본 ✓ + 옅은 민트 테두리 = 구매함 · 내 사진 + 도는 고리 │ P01 · P04 │
// │ G-4b │ 칸 위 MarkOverlay (리본 · ♡)          │ 상품 하나면 그 상품 · 없으면 손으로 켜기 · 여럿이면 시트 │ P07 · P04 │
// │ G-4c │ 머리 줄 ToolIcon + 장마다 SectionHeader · 칸 격자 │ 모아 보기 ↔ 화수별로 보기 (gundam-chapters 가 있을 때만, 장 머리에 숫자 없음) │ P01 · P07 │
// │ G-4d │ 머리 줄 ToolIcon(공유) → V 공유 카드   │ 작품 진행 카드: 켜진 칸 / 전체 · 칸 격자 그림 │ P07 · P10   │
// │ G-4e │ WorkGuideScreen (쌓기)              │ 작품 도감 화면 = 같은 묶음 목록 + 기체 칸, 그 작품을 고른 채로 · 위 줄 찾기 + 도감 필터 │ P07 · P04 │
// │ G-5  │ 바텀 시트(끌어 올리기): 기체 → 상품    │ 이 기체의 상품 전부 → 상품 상세          │ P07           │
// │ G-5a │ ThumbRow + ♡ · 책갈피 아이콘          │ 상품 줄: 등급 · 축척 · 발매월 · 바로 좋아요 · 구매함 │ P07 · P04 │
// │ G-5b │ 시트의 TogglePill 2개                │ 손으로 켜기(기기 저장) · 내 사진          │ P03 · P07     │
// │ G-5c │ 바텀 시트(카메라 · 갤러리) (T-2)      │ 이 기체의 내 사진 → 사진 벽에도 (기기 저장) │ P05 · P07   │
// │ G-5d │ 기체 시트 ⚑                          │ 빠진 상품 제보 (GitHub 이슈)             │ P07           │
// │ G-6  │ SideDirectory (베이 · 블레이더) + 베이 칸 · 부품 시트 │ 베이블레이드 X 도감 (늘 컬러 · 부품 다 모으면 리본 · 좋아요 ♡, 부품 수는 시트에) │ P01 │
// │ G-6a │ 🔧 ToolIcon (머리 줄)                │ 조합 만들기 (화면 T) — 블레이드 · 래칫 · 비트 · 덱 │ P07     │
// │ G-7  │ SideDirectory (세대 묶음) + CategoryTile │ 포켓몬 세대 · Fate 작품 · AC 작품 (그림 + 이름만) │ P06 │
// │ G-7b │ 묶음 목록 '태그' → TagGameCards       │ MEZASTAR · Frienda 태그 도감 입구 (R, CategoryTile) │ P06 │
// │ G-7a │ SectionListView (쌓기)              │ 묶음 칸 → 그 묶음 상품 (찾기 · 필터 · 격자/목록) │ P07 │
// │ G-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 정리 안 된 작품(정리 요청) │ P01 · P09 │
// │ G-9  │ FindBar + GuideFilterSheet(GpPickSheet 60%) │ 도감에서 찾기(작품 · 기체 이름 · 형식번호) + 도감 필터 = 상품 필터와 같은 틀: 상태(전체 · ♡ · 리본 · 아직 없음 · 내 사진) · 라인 · 시대 · 기체 종류 · 상품 있는 것만 · 정렬 — 묶음 목록과 칸에 같이 │ P04 · P07 · P01 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 묶음 줄 → 오른쪽 칸 바꾸기(setState). 기체 칸 → 기체 시트(덮기) → D 상품 상세(쌓기, 이 기체 상품끼리 좌우).
//       🔧 → T 베이 조합 만들기(쌓기). 베이 → 부품 시트(덮기). 세대 칸 → G-7a(쌓기). 기체 시트 → 사진 고르기(덮기, T-2) → 토스트.
// 도감에는 레벨 막대 · 수집 n / m · 칸 위 숫자 꼬리표를 두지 않는다 (2026-11-20 주인: 필요 없음). 진행은 칸 표시(♡ · 리본 · 사진)로만.
// 데이터: lib/data/derive.dart 건담 도감 ← lib/data/gundam_atlas.dart (data/atlas/gundam-ms · gundam-kit-ms · gundam-chapters).
// 코드: 이 파일 = G-1 · 고르기, lib/screens/guide/ = gundam_guide(G-3) · work_guide_screen(G-4 · G-4e · G-5) · bbx_guide(G-6)
//       · world_guide(G-7) · guide_parts(찾기 · 묶음 목록 펴 둠 · 칸 GuideCell = lib/widgets/tier_cell.dart TierCell).
//       틀 = lib/widgets/side_directory.dart (검색 탭 b_category_browse 와 한 벌), 분류 칸 = lib/widgets/tiles.dart CategoryTile.
import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../l10n/l10n.dart';
import '../models.dart' show CoverStyle;
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'guide/bbx_guide.dart';
import 'guide/guide_parts.dart';
import 'guide/gundam_guide.dart';
import 'guide/world_guide.dart';

import 'guide/work_guide_screen.dart' show workGuideHelp;

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
    // G-1 고를 것이 하나뿐이면 고르는 단계 없이 그 도감
    final ch = channel == allChannelId && myChannels.length == 1 ? myChannels.first : channel;
    if (ch == allChannelId) return _ChannelPicker(myChannels: myChannels, onPick: onPickChannel);
    final ctrl = filter ?? GuideFilterController();
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final find = GuideFind(query, ctrl);
        return switch (ch) {
          'gundam' => GundamGuide(loaders: loaders, find: find),
          'beyblade' => BbxGuide(loaders: loaders, find: find),
          _ => WorldGuide(channel: ch, loaders: loaders, find: find),
        };
      },
    );
  }
}

/// G-1 '전체'일 때: 채널 고르기 — 검색 탭 종류 · 세대 칸과 같은 크기 (묶음 목록이 없어 접힌 때처럼 한 줄 4칸)
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
        detail: tr('채널 관리에서 채널을 추가하면 도감을 볼 수 있어요'),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final g = SideGrid.of(context, box.maxWidth, open: false);
        return CustomScrollView(
          key: const ValueKey('guide-channels'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(SideGrid.pad + 4, 12, SideGrid.pad, 8),
              sliver: SliverToBoxAdapter(
                child: Text(tr('어느 도감을 볼까요?'), style: const TextStyle(color: Gp.muted)),
              ),
            ),
            g.sliver(myChannels.length, (context, i) {
              final id = myChannels[i];
              final c = channelOf(id);
              return CategoryTile(
                // G-1 P06 채널 공식 그림(로고는 그 바탕색 위, 그림은 칸 가득) + 이름만. 앱 안 기본 그림은 상품 사진이라 칸 가득
                key: ValueKey('guide-ch-$id'),
                image: c.image,
                style: c.cover ?? const CoverStyle(logo: false),
                color: Gp.channelColor(id),
                icon: Icons.auto_awesome_mosaic_outlined,
                name: tr(c.label),
                onTap: () => onPick(id), // STATE: 채널 선택 → 그 채널 도감
              );
            }),
            SliverToBoxAdapter(child: SizedBox(height: navClearance(context))),
          ],
        );
      },
    );
  }
}

/// G-2 사용법의 도감 묶음들 (서랍 › 사용법 — s_app_shell.dart): (제목, 줄). 칸 머리의 ? 를 여기로 모았다
List<(String, List<HelpItem>)> guideHelpSections() => [
  (tr('작품 도감'), workGuideHelp()),
  (tr('베이'), bbxGuideHelp()),
  (tr('도감'), worldGuideHelp()),
];
