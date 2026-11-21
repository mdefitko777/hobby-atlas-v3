// 공용 화면 조각 한 벌 — 화면은 이 파일 하나만 가져온다 (P04 일관성). 실제 코드는 lib/widgets/ 에 주제별로:
//   states        LoadingView · ErrorView · EmptyView · MiniSpinner (불러오는 중 · 오류 · 빈 목록, P01 · P09)
//   images        AppImage(`local:파일` = 내 사진) · LocalPhotoImage · PhotoThumb · CircleThumb · BlurFitImage · ImagePager(사진 넘기기) · openImageViewer(크게 보기) · prefetchImages(미리 받기)
//   tiles         ProductTile 상품 카드(이름 두 줄 · 리본 + · ♡) · KeepWordsText · ThumbRow 목록 한 줄 · CategoryTile · CategoryGrid 분류 칸(그림 + 이름)
//   mark_overlay  MarkOverlay (리본 = 구매함 · ♡ = 좋아요, 도감 칸) · QuickMarks (상품 카드 ♡) · StatusMarks (보기만)
//   icons         LikedIcon · OwnedIcon · VerifiedBadge · ChannelGlyph
//   tags          TagPill · SoftTag · DateTag · stageColor · AnnTag(예고 꼬리표: 단계 · 라이브 때 · 예약 때 · 비공식) · liveColor · preorderColor · unofficialColor
//   buttons       RaisedCircleButton · TogglePill · GradientButton · ChipButton(상세의 빈 줄 대신 작은 버튼)
//   rings         AccentRing · RingAvatar
//   sections      SectionHeader · SectionPanel · UnderlineTab · PageDots · AccentBar · ListSummary(목록 맨 끝 합계)
//   toolbar       GpSearchBar · ToolRow · ToolIcon · FilterButton · ViewIconToggle · FindBar
//   header_collapse  HeaderCollapse · CollapsingHeader (한참 내려 읽으면 채널 바만 접기, 앱 셸 하나가 정한다)
//   sheets        showPickSheet · SquareSegments · CheckGrid · ExpandRow
//   side_directory  SideDirectory · SideGrid · SideDirItem · SideDirHead (왼쪽 묶음 목록 + 오른쪽 칸 격자 — 검색 종류 · 세대 · 도감 한 벌)
//   kit_filter_sheet · guide_filter_sheet  상품 · 도감 필터 시트 (같은 틀 · 같은 상태 줄 MineStateLabel, 규칙은 lib/logic/)
//   tier_cell     CellTier · tierFrame · cellImage · tierMarks · TierCell (도감 칸 한 벌, 늘 컬러)
//   feedback      showToast · errorText · navClearance
//   kit_progress  예약(PreorderRow · showPreorderSheet · 도착 → 구매함) · 바코드 겹침 경고 (조립 상태는 화면에 두지 않는다)
//   share_card    공유 카드 그림 (CollectionShareCard · GuideShareCard · captureCard)
//   help          HelpButton · HelpItem · HelpSheet · HelpPage (? = 이 화면 아이콘 뜻 · 서랍 › 사용법 = 모든 화면 한 쪽)
// 숫자 · 날짜 글자(lib/format.dart)도 같이 내보낸다.
export 'format.dart';
export 'widgets/buttons.dart';
export 'widgets/feedback.dart';
export 'widgets/guide_filter_sheet.dart';
export 'widgets/header_collapse.dart';
export 'widgets/help.dart';
export 'widgets/icons.dart';
export 'widgets/images.dart';
export 'widgets/kit_filter_sheet.dart';
export 'widgets/kit_progress.dart';
export 'widgets/mark_overlay.dart';
export 'widgets/rings.dart';
export 'widgets/sections.dart';
export 'widgets/stats.dart';
export 'widgets/share_card.dart';
export 'widgets/sheets.dart';
export 'widgets/side_directory.dart';
export 'widgets/states.dart';
export 'widgets/tags.dart';
export 'widgets/tier_cell.dart';
export 'widgets/tiles.dart';
export 'widgets/toolbar.dart';
