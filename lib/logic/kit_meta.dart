// 목록 줄 부제 「채널 · 라인 · 작품」 (순수 Dart) — 컬렉션 · 친구 컬렉션 · 캘린더 내 일정이 한 벌로 쓴다.
// 같은 말은 한 번만: 포켓몬은 작품도 「포켓몬」이라 「포켓몬 · 봉제인형 · 포켓몬」이 됐다 (2026-11-20 주인).
import '../channels.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'data_labels.dart';
import 'short_names.dart';

/// 줄 부제. [work] = 화면 언어의 작품 이름 ([kitWorkName]), [channel] = 여러 채널이 섞인 목록일 때만 채널 이름.
/// 채널 이름을 빼도(채널 바에 이미 있다) 같은 작품 이름은 다시 쓰지 않는다
String kitMetaLine(Kit k, {String? work, bool channel = true}) {
  String norm(String s) => s.replaceAll(' ', '').toLowerCase();
  final channelName = tr(channelOf(k.franchiseId).label);
  final seen = <String>{if (!channel) norm(channelName)};
  return joinDot([
    for (final s in [if (channel) channelName, dataLabel(k.line), work ?? shortWorkName(k.seriesLabel)])
      if (s.isNotEmpty && seen.add(norm(s))) s,
  ]);
}

/// 줄 부제의 작품 이름 — 건담은 도감의 공식 작품 이름 (Gunpula series 이름은 역샤아 · 철혈 · 초대 같은 줄임말이다).
/// 대표 기체를 모르면 · 다른 채널은 series 이름. 반복 머리는 뺀다 (칸 · 제목 · 알림 줄과 같게)
String kitWorkName(Kit k, GuideIndex index) {
  final unit = k.franchiseId == 'gundam' ? index.unitOf(k.id) : null;
  final official = unit == null ? '' : index.work(unit.workId)?.name ?? '';
  return shortWorkName(official.isNotEmpty ? official : k.seriesLabel);
}
