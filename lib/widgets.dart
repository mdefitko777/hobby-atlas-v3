// 공용 화면 조각 한 벌 — 화면은 이 파일 하나만 가져온다 (P04 일관성). 실제 코드는 lib/widgets/ 에 주제별로:
//   states        LoadingView · ErrorView · EmptyView · MiniSpinner (불러오는 중 · 오류 · 빈 목록, P01 · P09)
//   images        AppImage(`local:파일` = 내 사진) · LocalPhotoImage · PhotoThumb · CircleThumb · BlurFitImage · ImagePager(사진 넘기기) · openImageViewer(크게 보기)
//   tiles         ProductTile 상품 카드 · ThumbRow 목록 한 줄 · CategoryTile · CategoryGrid 분류 칸(그림 + 이름)
//   mark_overlay  MarkOverlay · QuickMarks (리본 = 구매함 · ♡ = 좋아요) · StatusMarks (보기만)
//   icons         LikedIcon · OwnedIcon · VerifiedBadge · ChannelGlyph
//   tags          TagPill · SoftTag · DateTag · stageColor · AnnTag(예고 꼬리표: 단계 · 라이브 때 · 예약 때 · 비공식) · liveColor · preorderColor · unofficialColor
//   buttons       RaisedCircleButton · TogglePill · GradientButton
//   rings         AccentRing · RingAvatar
//   sections      SectionHeader · SectionPanel · UnderlineTab · PageDots · AccentBar
//   toolbar       GpSearchBar · ToolRow · ToolIcon · FilterButton · ViewIconToggle · FindBar
//   sheets        showPickSheet · SquareSegments · CheckGrid · ExpandRow
//   kit_filter_sheet · guide_filter_sheet  상품 · 도감 필터 시트 (같은 틀 · 같은 상태 줄 MineStateLabel, 규칙은 lib/logic/)
//   tier_cell     CellTier · tierFrame · cellImage · tierMarks · TierCell (도감 칸 한 벌, 늘 컬러)
//   feedback      showToast · navClearance
//   kit_progress  조립 상태(BuildStatusButton · BuildStatusRow) · 예약(PreorderRow · showPreorderSheet) · 바코드 겹침 경고
//   share_card    공유 카드 그림 (CollectionShareCard · GuideShareCard · captureCard)
//   stats         StatGroups · CollectionStats (My Page · 내 정보 숫자 줄)
//   help          HelpButton · HelpItem · HelpSheet (? = 이 화면 아이콘 뜻, 머리 줄 오른쪽 끝)
// 숫자 · 날짜 글자(lib/format.dart)도 같이 내보낸다.
export 'format.dart';
export 'widgets/buttons.dart';
export 'widgets/feedback.dart';
export 'widgets/guide_filter_sheet.dart';
export 'widgets/help.dart';
export 'widgets/icons.dart';
export 'widgets/images.dart';
export 'widgets/kit_filter_sheet.dart';
export 'widgets/kit_progress.dart';
export 'widgets/mark_overlay.dart';
export 'widgets/rings.dart';
export 'widgets/sections.dart';
export 'widgets/share_card.dart';
export 'widgets/sheets.dart';
export 'widgets/states.dart';
export 'widgets/stats.dart';
export 'widgets/tags.dart';
export 'widgets/tier_cell.dart';
export 'widgets/tiles.dart';
export 'widgets/toolbar.dart';
