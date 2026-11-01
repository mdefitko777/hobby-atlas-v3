// 공식 예고 (announcements.json)
part of '../derive.dart';

Future<List<Announcement>> deriveAnnouncements(List<String> channelIds) async {
  await _cat.ensureLoaded();
  final set = channelIds.toSet();
  final list = [
    for (final a in jList(jMap(await _cat.aux('announcements.json'))['announcements']))
      if (jMap(a) case final m when set.contains(jStr(m['franchise'])) && jStr(m['id']).isNotEmpty) m,
  ]..sort((a, b) => jStr(b['announced_at']).compareTo(jStr(a['announced_at'])));
  var heroes = 0;
  return [
    for (final m in list)
      () {
        final image = resolveAsset(m['thumbnail_url']);
        return Announcement(
          id: jStr(m['id']),
          franchiseId: jStr(m['franchise']),
          title: pickName(m['names']),
          status: annStageLabels[jStr(m['status'])] ?? '공식 발표',
          date: jStr(m['announced_at']),
          source: jStr(m['source_name']),
          image: image,
          hero: image.isNotEmpty && heroes++ < 6,
          url: jStr(m['source_url']),
          video: jStr(m['video_id']),
        );
      }(),
  ];
}
