// 흑백 테마 — UI는 검정·회색·흰색, 브랜드 하늘색(Gp.accent)은 몇 군데에만 포인트로.
// 색의 뜻은 둘뿐: 파랑(accent) = 고름 · 누를 수 있음 · 좋아요 / 민트(own) = 가진 것(구매함 · 도감 인증).
// 모양의 뜻도 둘뿐: ♡ = 좋아요, 책갈피 리본(+ / ✓) = 구매함. (P04 일관성 · P08 미니멀)
import 'package:flutter/material.dart';

abstract final class Gp {
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF6B6B6B);

  /// 보조 글자 — 흰 바탕 대비 4.5:1 (WCAG AA) 을 넘기는 가장 옅은 회색
  static const faint = Color(0xFF767676);
  static const line = Color(0xFFE6E6E6);
  static const soft = Color(0xFFF0F0EE);

  /// 페이지 바탕: 아주 옅은 따뜻한 회백색 — 흰 버튼이 떠 보이게
  static const bg = Color(0xFFF7F7F5);

  /// 카드·시트 면
  static const panel = Color(0xFFFFFFFF);
  static const danger = Color(0xFFC0392B);

  /// 모서리 3단계 — 이 밖의 값은 쓰지 않는다 (캡슐 모양 없음)
  static const rSmall = 6.0; // 태그 · 작은 버튼 · 체크 칸 · 날짜 꼬리표
  static const radius = 12.0; // 카드 · 버튼 · 입력칸 · 사진
  static const rLarge = 18.0; // 큰 면: 시트 · 대화상자 · 달력 판 · 배너 카드

  /// 아이콘 3단계 — 글자 옆 16 · 버튼 20 · 머리줄 24 (큰 빈 화면 그림은 따로)
  static const iS = 16.0;
  static const iM = 20.0;
  static const iL = 24.0;

  /// 특별 관심 ★
  static const star = Color(0xFFBA7517);

  /// 레벨 색 — 10레벨마다: 회색 · 초록 · 파랑 · 보라 · 금색 · 빨강(50+)
  static const levelTiers = [
    Color(0xFF888780),
    Color(0xFF639922),
    accent,
    Color(0xFF7F77DD),
    Color(0xFFBA7517),
    Color(0xFFE24B4A),
  ];

  /// 사진 위 어두운 덮개 (구매함 리본 · 좋아요 동그라미)
  static const scrim = Color(0xA6222222);
  static const scrimLight = Color(0x8C222222);

  /// 반투명 흰 면 (사진 위 꼬리표 · 떠 있는 버튼 테두리)
  static const glass = Color(0xE6FFFFFF);

  /// 그림자 · 서랍 뒤 어둡게
  static const shadow = Color(0x33000000);

  /// 아래 탭 안 고른 아이콘 · 글자
  static const navIdle = Color(0xFF9A9A98);

  /// 빈 오른쪽 칸 그림 (넓은 화면)
  static const ghost = Color(0xFFDCDCDA);

  /// 글자 크기 6단계 (타이포 스케일) — 이 밖의 크기는 쓰지 않는다
  static const t11 = 11.0; // 아주 작은 보조: 배지 숫자 · 시간 · 알약
  static const t12 = 12.5; // 보조 글: 부제 · 설명 · 목록 둘째 줄
  static const t14 = 14.0; // 본문 · 버튼 · 목록 제목
  static const t16 = 16.0; // 시트 제목 · 강조 본문
  static const t19 = 19.0; // 화면 · 섹션 큰 제목 · 상품명
  static const t24 = 24.0; // 가격 · 큰 숫자 · 아바타 글자

  /// 브랜드 포인트 색: 라이징 프리덤 · 엑시아의 하늘색. 흑백 화면에 "가끔만" 쓴다
  /// (줄 제목 앞 막대 · 선택 채널 밑줄 · 배너 점 · 아바타 고리 · 기간 글자).
  static const accent = Color(0xFF1C86D9);

  /// 아바타 고리 그라데이션의 끝 색(민트 그린)
  static const accent2 = Color(0xFF2CC6A0);

  /// 가진 것(구매함 리본 ✓ · 구매함 테두리 · 인증 배지) — 민트를 흰 글자/아이콘이 보이게 조금 짙게
  static const own = Color(0xFF12A07F);

  /// 떠 있는 흰 버튼(아바타 · + · 채널 타일): 흰→옅은 회색 그라데이션 + 부드러운 그림자
  /// 브랜드 그라데이션 (Lv 알약 · 인증 배지)
  static const accentGradient = LinearGradient(colors: [accent, accent2]);

  static BoxDecoration raised({BoxShape shape = BoxShape.rectangle, double radius = Gp.radius}) => BoxDecoration(
    shape: shape,
    borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFEDEDEB)],
    ),
    border: Border.all(color: Gp.glass),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );
}

ThemeData buildGpTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Gp.ink,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    primary: Gp.ink,
    onPrimary: Colors.white,
    surface: Gp.bg,
    onSurface: Gp.ink,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Gp.bg,
    dividerColor: Gp.line,
    splashFactory: NoSplash.splashFactory,
    textTheme: base.textTheme.apply(bodyColor: Gp.ink, displayColor: Gp.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Gp.bg,
      foregroundColor: Gp.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Gp.ink, fontSize: Gp.t19, fontWeight: FontWeight.w800),
    ),
    dividerTheme: const DividerThemeData(color: Gp.line, thickness: 1, space: 1),
    // 큰 검정 바탕 + 흰 글자는 쓰지 않는다 → 옅은 회색 바탕 + 검정 글자
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFEDEDEB),
        foregroundColor: Gp.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gp.radius)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Gp.ink,
        side: const BorderSide(color: Gp.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gp.radius)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Gp.ink)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Gp.soft,
      isDense: true,
      hintStyle: const TextStyle(color: Gp.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Gp.radius), borderSide: BorderSide.none),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Gp.panel,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Gp.rLarge))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Gp.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gp.rLarge)),
    ),
    // 알림(토스트): 흰 반투명 바탕 · 검정 글자 · 되돌리기는 브랜드 색, 몇 초 뒤 사라짐
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF7FFFFFF),
      contentTextStyle: const TextStyle(color: Gp.ink, fontSize: Gp.t14, fontWeight: FontWeight.w500),
      actionTextColor: Gp.accent,
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gp.radius),
        side: const BorderSide(color: Gp.line),
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
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Gp.bg,
      indicatorColor: Gp.soft,
      selectedIconTheme: IconThemeData(color: Gp.ink),
      unselectedIconTheme: IconThemeData(color: Gp.faint),
      selectedLabelTextStyle: TextStyle(color: Gp.ink, fontWeight: FontWeight.w700, fontSize: Gp.t12),
      unselectedLabelTextStyle: TextStyle(color: Gp.faint, fontSize: Gp.t12),
    ),
  );
}
