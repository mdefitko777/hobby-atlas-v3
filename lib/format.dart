// 숫자 · 날짜 · 시간 글자 — 화면(widgets.dart 가 다시 내보냄)과 동기화 · 알림이 같이 쓴다
/// "a · b · c" — 빈 칸은 빼고 가운뎃점으로 잇는다
String joinDot(Iterable<String> parts) => parts.where((s) => s.isNotEmpty).join(' · ');

String _comma(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// 일본 정가: ¥3,850 (없으면 '가격 미정')
String yen(int? v) => v == null ? '가격 미정' : '¥${_comma(v)}';

/// 날짜 한 가지 모양: "2026-10-05" → "2026.10.05", "2027-07" → "2027.07" (상세 · 목록 · 공고 공통)
String dateDot(String d) => d.replaceAll('-', '.');

/// 전각 영숫자 · 기호 → 반각 (ＨＧＵＣ → HGUC, Ｖｅｒ．Ｋａ → Ver.Ka, 전각 빈칸 → 빈칸). 【】「」 같은 CJK 괄호는 그대로
/// 상품 이름 정리(lib/data/gunpula.dart) · 검색 글자(blob)와 검색어(lib/logic/kit_rules.dart)가 같이 쓴다
String halfWidth(String s) =>
    String.fromCharCodes(s.runes.map((c) => c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : (c == 0x3000 ? 0x20 : c)));

String _two(int n) => n.toString().padLeft(2, '0');

/// 달 열쇠 "2026-10" (그 DateTime 의 시간대 그대로 — 발매월 · 이번 달 지출 비교)
String monthKey(DateTime d) => '${d.year}-${_two(d.month)}';

/// 날 열쇠 "2026-10-05"
String dayKey(DateTime d) => '${monthKey(d)}-${_two(d.day)}';

/// 짧은 때: "11.01 13:20" (마지막 확인 시각)
String shortDateTime(DateTime d) => '${d.month}.${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

/// 원화: 41,000원
String won(int v) => '${_comma(v)}원';

/// 원화 짧게 (My Page 숫자 칸): 9,800원 · 18.4만 · 243만
String wonShort(int v) {
  if (v < 10000) return won(v);
  final man = v / 10000;
  return man < 100 ? '${man.toStringAsFixed(1).replaceAll('.0', '')}만' : '${man.round()}만';
}

/// 지난 시간: 방금 · 3분 전 · 2시간 전 · 어제 · 4일 전 · 10.16 (알림 · 친구 소식 · 동기화 공통)
String timeAgo(DateTime at, {required DateTime now}) {
  final d = now.difference(at);
  if (d.inSeconds < 60) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24 && at.day == now.day) return '${d.inHours}시간 전';
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days == 1) return '어제';
  if (days < 7) return '$days일 전';
  return '${at.month}.${at.day.toString().padLeft(2, '0')}';
}
