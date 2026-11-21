// 흑백 테마 — UI는 검정·회색·흰색, 브랜드 하늘색(Gp.accent)은 몇 군데에만 포인트로.
// 색의 뜻은 둘뿐: 파랑(accent) = 고름 · 누를 수 있음 · 좋아요 / 민트(own) = 구매함 · 도감 인증.
// 모양의 뜻도 둘뿐: ♡ = 좋아요, 책갈피 리본(+ / ✓) = 구매함. (P04 일관성 · P08 미니멀)
//
// 밤 모드 (2026-11-22) — 낮과 밤 두 벌 [GpPalette] 이 있고, [Gp] 의 색은 지금 켠 벌을 읽는
// getter 다. 그래서 `const Icon(..., color: Gp.ink)` 처럼 색이 든 const 식은 쓸 수 없다
// (크기 · 모서리 · 글자 크기는 그대로 const 라 const 로 써도 된다).
// 상품 사진은 건드리지 않는다 — 흰 바탕 상품 사진이 이 앱의 내용이라서 덮개 · 반전을 걸면 상품이 상한다.
// 짙은 검정이 아니라 깊은 회색(#121212)이다 (주인이 고름). 분류 칸 · 채널 색은 흰 아이콘을 얹는
// 짙은 브랜드 색이라 두 벌이 같이 쓴다.
import 'dart:convert';

import 'package:flutter/material.dart';

import 'data/blob_store.dart';

/// 한 벌의 색 — 낮([GpPalette.light])과 밤([GpPalette.night]).
/// 색이 아닌 값(크기 · 모서리 · 글자 크기)은 두 벌이 같으므로 [Gp] 에 const 로 남아 있다.
class GpPalette {
  const GpPalette({
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.soft,
    required this.bg,
    required this.panel,
    required this.danger,
    required this.star,
    required this.reserve,
    required this.resale,
    required this.scrim,
    required this.scrimLight,
    required this.glass,
    required this.shadow,
    required this.navIdle,
    required this.ghost,
    required this.accent,
    required this.accent2,
    required this.own,
    required this.fill,
    required this.toast,
    required this.raisedTop,
    required this.raisedBottom,
    required this.levelGrey,
    required this.coverA,
    required this.coverB,
    required this.dark,
  });

  final Color ink, muted, faint, line, soft, bg, panel, danger;
  final Color star, reserve, resale, scrim, scrimLight, glass, shadow, navIdle, ghost;
  final Color accent, accent2, own;

  /// 옅은 회색 버튼 바탕 (FilledButton · raised 아래쪽)
  final Color fill;

  /// 토스트 바탕 (반투명)
  final Color toast;
  final Color raisedTop, raisedBottom;

  /// 레벨 1단(10레벨 아래)의 회색 — 나머지 단계 색은 두 벌이 같다
  final Color levelGrey;

  /// 사진을 안 올린 배경 자리의 옅은 그라데이션 (서랍 머리 · 내 정보) — 파랑기 → 민트기
  final Color coverA, coverB;

  final bool dark;

  static const light = GpPalette(
    ink: Color(0xFF111111),
    muted: Color(0xFF6B6B6B),
    faint: Color(0xFF767676), // 흰 바탕 대비 4.5:1 (WCAG AA) 을 넘기는 가장 옅은 회색
    line: Color(0xFFE6E6E6),
    soft: Color(0xFFF0F0EE),
    bg: Color(0xFFFFFFFF),
    panel: Color(0xFFFFFFFF),
    danger: Color(0xFFC0392B),
    star: Color(0xFFBA7517),
    reserve: Color(0xFF7F77DD),
    resale: Color(0xFFD9822B),
    scrim: Color(0xA6222222),
    scrimLight: Color(0x8C222222),
    glass: Color(0xE6FFFFFF),
    shadow: Color(0x33000000),
    navIdle: Color(0xFF9A9A98),
    ghost: Color(0xFFDCDCDA),
    accent: Color(0xFF1C86D9),
    accent2: Color(0xFF2CC6A0),
    own: Color(0xFF12A07F),
    fill: Color(0xFFEDEDEB),
    toast: Color(0xF7FFFFFF),
    raisedTop: Color(0xFFFFFFFF),
    raisedBottom: Color(0xFFEDEDEB),
    levelGrey: Color(0xFF888780),
    coverA: Color(0xFFE9F3FB),
    coverB: Color(0xFFE8F8F3),
    dark: false,
  );

  /// 깊은 회색 한 벌. 글자색은 #121212 바탕에서 모두 4.5:1 을 넘는다
  /// (faint 5.8 · muted 7.7 · ink 15.9 · accent 7.2).
  static const night = GpPalette(
    ink: Color(0xFFECECEC),
    muted: Color(0xFFA6A6A6),
    faint: Color(0xFF8E8E92),
    line: Color(0xFF323236),
    soft: Color(0xFF26262A), // 어두운 면 안의 작은 상자 — panel 보다 한 단 밝게
    bg: Color(0xFF121212),
    panel: Color(0xFF1C1C1E),
    danger: Color(0xFFFF7064),
    star: Color(0xFFE3A93E),
    reserve: Color(0xFF9A93EA),
    resale: Color(0xFFEC9E4E),
    scrim: Color(0xA6000000), // 사진 위 덮개는 밤에도 어두운 쪽이 맞다
    scrimLight: Color(0x8C000000),
    glass: Color(0xCC2A2A2E), // 사진 위 꼬리표 — 밤에는 반투명 "검은 유리"
    shadow: Color(0x66000000),
    navIdle: Color(0xFF76767C),
    ghost: Color(0xFF2A2A2E),
    accent: Color(0xFF4FA8E8),
    accent2: Color(0xFF3AD6AE),
    own: Color(0xFF1BC79A),
    fill: Color(0xFF2A2A2E),
    toast: Color(0xF71E1E22),
    raisedTop: Color(0xFF2E2E33),
    raisedBottom: Color(0xFF232327),
    levelGrey: Color(0xFF9A9A94),
    coverA: Color(0xFF16242E), // 같은 파랑기 · 민트기를 어둡게 (밤에 흰 띠가 되지 않게)
    coverB: Color(0xFF152824),
    dark: true,
  );
}

/// 밤 모드 켜기 · 끄기 — 손으로만 (기기 설정을 따라가지 않는다: 주인이 그렇게 골랐다).
/// 언어와 같은 방식이다 ([L10n]): 기기 파일 하나에 적어 두고, 바뀌면 앱 전체를 다시 만든다.
abstract final class GpMode {
  static const storeKey = 'app-theme.json';
  static final ValueNotifier<bool> notifier = ValueNotifier(false);

  static bool get isDark => notifier.value;
  static GpPalette get palette => notifier.value ? GpPalette.night : GpPalette.light;

  static Future<void> load() async {
    try {
      final raw = await BlobStore.read(storeKey);
      notifier.value = raw != null && (jsonDecode(raw) as Map)['dark'] == true;
    } catch (_) {
      notifier.value = false;
    }
  }

  static Future<void> set(bool dark) async {
    if (notifier.value == dark) return;
    notifier.value = dark; // 화면은 먼저 바꾼다 — 적어 두기가 실패해도 지금 켠 것은 켠 것이다
    try {
      await BlobStore.write(storeKey, jsonEncode({'dark': dark}));
    } catch (_) {
      // 기기에 적지 못하면 다음에 앱을 열 때 낮으로 돌아온다 (고를 수 없게 막지는 않는다)
    }
  }

  /// 테스트 · 미리보기용 (저장하지 않음)
  @visibleForTesting
  static void debugSet(bool dark) => notifier.value = dark;
}

abstract final class Gp {
  /// 지금 켠 한 벌 — 두 벌에서만 다른 것(그림자 · 테두리 유무)을 가를 때 `Gp.p.dark` 로 본다
  static GpPalette get p => GpMode.palette;

  static Color get ink => p.ink;
  static Color get muted => p.muted;

  /// 보조 글자 — 흰 바탕 대비 4.5:1 (WCAG AA) 을 넘기는 가장 옅은 회색
  static Color get faint => p.faint;
  static Color get line => p.line;
  static Color get soft => p.soft;

  /// 페이지 바탕: 흰색 (2026-11-20 주인이 회백색과 견주어 고름). 층은 회색 틈 대신 [bandLine] 머리카락 줄로 나눈다.
  /// 흰 면 안의 작은 상자(공식 정보 표 · 아이디 칸 · 합계 칸)는 bg 가 아니라 [soft] 로 칠한다 — bg 면 흰 면에 녹는다
  static Color get bg => p.bg;

  /// 흰 띠 섹션 위 머리카락 줄 (흰 바탕에서 층을 나눈다)
  static BorderSide get bandLine => BorderSide(color: line, width: 0.5);

  /// 상품 사진 테두리 — 0.5 머리카락 줄 (흰 바탕 상품 사진이 흰 페이지에 녹지 않게)
  static BorderSide get photoEdge => BorderSide(color: line, width: 0.5);

  /// 분류 칸 그림자 — 낮고 옅게. 흰 바탕에서 흰 로고 칸(PG · EG · MGEX)도 칸 끝이 보일 만큼 (테두리는 쓰지 않는다)
  static List<BoxShadow> get tileShadow => p.dark
      // 밤에는 그림자로 층을 나눌 수 없다 (검정 위 검정) → 한 겹만 깊게
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 2))]
      : const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x14000000), blurRadius: 1.5, offset: Offset(0, 0.5)),
        ];

  /// 카드·시트 면
  static Color get panel => p.panel;
  static Color get danger => p.danger;

  /// 모서리 3단계 — 이 밖의 값은 쓰지 않는다 (캡슐 모양 없음)
  static const rSmall = 6.0; // 태그 · 작은 버튼 · 체크 칸 · 날짜 꼬리표
  static const radius = 12.0; // 카드 · 버튼 · 입력칸 · 사진
  static const rLarge = 18.0; // 큰 면: 시트 · 대화상자 · 달력 판 · 배너 카드

  /// 아이콘 단계 — 작은 글자(t11 · t12) 옆 · 사진 위 작은 점 12 · 글자 옆 16 · 버튼 20 · 머리줄 24 · 빈 화면 · 오류 그림 40
  static const iXS = 12.0;
  static const iS = 16.0;
  static const iM = 20.0;
  static const iL = 24.0;
  static const iXL = 40.0;

  /// 화면 옆 여백 (목록 · 격자 · 섹션 안쪽)
  static const gutter = 16.0;

  /// 특별 관심 ★
  static Color get star => p.star;

  /// 예약(좋아요와 구매함 사이) — 예약 꼬리표 · 달력 도착 점
  static Color get reserve => p.reserve;

  /// 재판매(再販) — 상세 꼬리표 · 달력 점
  static Color get resale => p.resale;

  /// 레벨 색 — 10레벨마다: 회색 · 초록 · 파랑 · 보라 · 금색 · 빨강(50+)
  static List<Color> get levelTiers => [
    p.levelGrey,
    const Color(0xFF639922),
    accent,
    reserve,
    star,
    const Color(0xFFE24B4A),
  ];

  /// 사진 위 어두운 덮개 (구매함 리본 · 좋아요 동그라미)
  static Color get scrim => p.scrim;
  static Color get scrimLight => p.scrimLight;

  /// 반투명 흰 면 (사진 위 꼬리표 · 떠 있는 버튼 테두리)
  static Color get glass => p.glass;

  /// 그림자 · 서랍 뒤 어둡게
  static Color get shadow => p.shadow;

  /// 아래 탭 안 고른 아이콘 · 글자
  static Color get navIdle => p.navIdle;

  /// 빈 오른쪽 칸 그림 (넓은 화면)
  static Color get ghost => p.ghost;

  /// 글자 크기 6단계 (타이포 스케일) — 이 밖의 크기는 쓰지 않는다
  static const t11 = 11.0; // 아주 작은 보조: 배지 숫자 · 시간 · 알약
  static const t12 = 12.5; // 보조 글: 부제 · 설명 · 목록 둘째 줄
  static const t14 = 14.0; // 본문 · 버튼 · 목록 제목
  static const t16 = 16.0; // 시트 제목 · 강조 본문
  static const t19 = 19.0; // 화면 · 섹션 큰 제목 · 상품명
  static const t24 = 24.0; // 가격 · 큰 숫자 · 아바타 글자

  /// 브랜드 포인트 색: 라이징 프리덤 · 엑시아의 하늘색. 흑백 화면에 "가끔만" 쓴다
  /// (줄 제목 앞 막대 · 선택 채널 밑줄 · 배너 점 · 아바타 고리 · 기간 글자).
  static Color get accent => p.accent;

  /// 아바타 고리 그라데이션의 끝 색(민트 그린)
  static Color get accent2 => p.accent2;

  /// 구매함(리본 ✓ · 구매함 테두리 · 인증 배지) — 민트를 흰 글자/아이콘이 보이게 조금 짙게
  static Color get own => p.own;

  /// 떠 있는 흰 버튼(아바타 · + · 채널 타일): 흰→옅은 회색 그라데이션 + 부드러운 그림자
  /// 브랜드 그라데이션 (Lv 알약 · 인증 배지)
  static LinearGradient get accentGradient => LinearGradient(colors: [accent, accent2]);

  /// 로고도 사진도 없는 분류 칸의 바탕 — 채널마다 한 색 (회색은 쓰지 않는다). 모르는 채널은 [tilePalette] 에서 고른다
  static Color channelColor(String channel) =>
      _channelColors[channel] ?? tilePalette[channel.codeUnits.fold<int>(0, (a, c) => a + c) % tilePalette.length];

  static const _channelColors = {
    'gundam': Color(0xFF2B4C7E),
    'beyblade': Color(0xFF6C3CC4),
    'pokemon': Color(0xFFE3350D),
    'armored_core': Color(0xFF3D5A4C),
    'fate': Color(0xFF7A1F2B),
    'madoka': Color(0xFFC2477D),
    'lego': Color(0xFFD01012),
    'nintendo': Color(0xFFE60012),
    'effects': Color(0xFF0F7C8C),
  };

  /// 흰 아이콘이 보이는 짙은 색들 (분류 칸 바탕)
  static const tilePalette = [
    Color(0xFF2B4C7E),
    Color(0xFF6C3CC4),
    Color(0xFF0F7C8C),
    Color(0xFFC2477D),
    Color(0xFF3D5A4C),
    Color(0xFFD7263D),
  ];

  static BoxDecoration raised({BoxShape shape = BoxShape.rectangle, double radius = Gp.radius}) => BoxDecoration(
    shape: shape,
    borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Gp.p.raisedTop, Gp.p.raisedBottom],
    ),
    // 밤에는 흰 테두리(glass)가 띠처럼 번쩍여 머리카락 줄로 바꾼다
    border: Border.all(color: Gp.p.dark ? Gp.line : Gp.glass),
    boxShadow: Gp.p.dark
        ? const [BoxShadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 6))]
        : const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 6)),
            BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
  );
}

/// 한 벌의 Material 테마. 색은 지금 켠 [GpPalette] 에서 가져오므로, 밤 모드를 켜고 끌 때마다
/// 새로 만들어야 한다 (앱 뿌리의 ValueListenableBuilder 가 [GpMode.notifier] 를 듣는다).
ThemeData buildGpTheme() {
  final p = Gp.p;
  final scheme = ColorScheme.fromSeed(
    seedColor: Gp.ink,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: Gp.ink,
    // 밤에는 primary 가 밝은 글자색이라 그 위 글자는 바탕색이어야 보인다
    onPrimary: p.dark ? p.bg : Colors.white,
    surface: Gp.bg,
    onSurface: Gp.ink,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Gp.bg,
    dividerColor: Gp.line,
    splashFactory: NoSplash.splashFactory,
    textTheme: base.textTheme.apply(bodyColor: Gp.ink, displayColor: Gp.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Gp.bg,
      foregroundColor: Gp.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Gp.ink,
        fontSize: Gp.t19,
        fontWeight: FontWeight.w600,
      ), // 모든 화면 제목 한 벌 (화면에서 덮어쓰지 않는다)
    ),
    dividerTheme: DividerThemeData(color: Gp.line, thickness: 1, space: 1),
    // 큰 검정 바탕 + 흰 글자는 쓰지 않는다 → 옅은 회색 바탕 + 검정 글자 (밤에는 한 단 밝은 회색 + 흰 글자)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.fill,
        foregroundColor: Gp.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gp.radius)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Gp.ink,
        side: BorderSide(color: Gp.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gp.radius)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Gp.ink)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Gp.soft,
      isDense: true,
      hintStyle: TextStyle(color: Gp.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Gp.radius), borderSide: BorderSide.none),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Gp.panel,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Gp.rLarge))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Gp.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gp.rLarge)),
    ),
    // 알림(토스트): 반투명 바탕 · 바탕과 반대되는 글자 · 되돌리기는 브랜드 색, 몇 초 뒤 사라짐
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.toast,
      contentTextStyle: TextStyle(color: Gp.ink, fontSize: Gp.t14, fontWeight: FontWeight.w500),
      actionTextColor: Gp.accent,
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gp.radius),
        side: BorderSide(color: Gp.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Gp.bg,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: Gp.t11,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Gp.ink : Gp.faint,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Gp.ink : Gp.faint),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Gp.bg,
      indicatorColor: Gp.soft,
      selectedIconTheme: IconThemeData(color: Gp.ink),
      unselectedIconTheme: IconThemeData(color: Gp.faint),
      selectedLabelTextStyle: TextStyle(color: Gp.ink, fontWeight: FontWeight.w700, fontSize: Gp.t12),
      unselectedLabelTextStyle: TextStyle(color: Gp.faint, fontSize: Gp.t12),
    ),
  );
}
