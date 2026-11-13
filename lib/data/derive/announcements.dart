// 예고 (announcements.json) — 공식 + 비공식(unofficial: true)
part of '../derive.dart';

/// 내 채널의 예고 — 곧 할 · 하는 중인 라이브가 맨 앞, 나머지는 발표일 새것부터 (lib/logic/live_stream.dart liveFirst)
Future<List<Announcement>> deriveAnnouncements(List<String> channelIds) async {
  await _cat.ensureLoaded();
  final set = channelIds.toSet();
  final list = [
    for (final a in jList(jMap(await _cat.aux('announcements.json'))['announcements']))
      if (jMap(a) case final m when set.contains(jStr(m['franchise'])) && jStr(m['id']).isNotEmpty) m,
  ]..sort((a, b) => jStr(b['announced_at']).compareTo(jStr(a['announced_at'])));
  final all = liveFirst(list.map(announcementOf).toList(), appNow());
  final heroes = annHeroIds(all); // 사진 있는 공식 6개, 모자라면 비공식으로 채움
  return [for (final a in all) heroes.contains(a.id) ? a.asHero() : a];
}

/// 공식 쪽이 이어받아 빠진 예고: 옛 id → 새 id (announcements.json `replaced`, 없으면 빈 지도)
Future<Map<String, String>> deriveAnnReplaced() async {
  await _cat.ensureLoaded();
  return annReplacedOf(await _cat.aux('announcements.json'));
}

/// announcements.json 한 줄 → 화면 모델. live_state · live_at 이 있으면 라이브(방송) 예고
/// (유튜브 = source_type youtube + video_id, 프리미엄 반다이 라이브 쇼핑 = news + source_url — 여는 길은 다른 예고와 같다)
Announcement announcementOf(Map<String, Object?> m) {
  final liveAt = parseLiveAt(m['live_at']);
  final liveState = jStr(m['live_state']);
  return Announcement(
    id: jStr(m['id']),
    franchiseId: jStr(m['franchise']),
    title: _shown(m['names']),
    status: annStageLabels[jStr(m['status'])] ?? '공식 발표',
    date: jStr(m['announced_at']),
    source: jStr(m['source_name']),
    image: resolveAsset(m['thumbnail_url']),
    hero: false,
    url: jStr(m['source_url']),
    video: jStr(m['video_id']),
    liveAt: liveAt,
    // 시각만 있고 상태가 빠진 줄도 라이브로 본다 (단계는 기기 시계가 정한다)
    liveState: liveState.isEmpty && liveAt != null ? 'upcoming' : liveState,
    unofficial: m['unofficial'] == true,
  );
}
