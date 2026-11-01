// 알림 화면 모델 — 알림함 줄(lib/notifications) → AppNotice
part of '../derive.dart';

/// 알림 화면: 알림함(lib/notifications — 앱을 열 때 · 12시간마다 Gunpula 새 소식 파일을 걸러 넣은 줄), 새것부터.
/// 사진은 카탈로그에서 (아직 받는 중이면 빈 사진). 좋아요 · PB 예약 줄은 franchiseId 를 비워 채널과 상관없이 보이게.
Future<List<AppNotice>> deriveNotifications() async {
  final store = NotifyStore.instance;
  await store.load();
  return [for (final r in store.state.inbox) noticeOf(r, _cat.byId[r.kitId])];
}

/// 알림함 한 줄 → 화면 모델
AppNotice noticeOf(NoticeRecord r, Kit? kit) => r.isAnnStage
    ? AppNotice(
        id: r.id,
        type: NoticeType.announce,
        title: r.title,
        body: r.body,
        image: '',
        at: r.at.toLocal(),
        read: r.seen,
        franchiseId: r.franchise,
        annId: r.annId,
      )
    : AppNotice(
        id: r.id,
        type: r.isPbWindow || r.isRestock || r.isPreorder || (r.pb && r.kind == 'added')
            ? NoticeType.reserve
            : (r.reasons.contains('price') ? NoticeType.price : NoticeType.release),
        title: kit?.name ?? r.title,
        body: r.body,
        image: kit?.image ?? '',
        at: r.at.toLocal(),
        read: r.seen,
        franchiseId: r.wanted ? '' : r.franchise,
        kitId: r.kitId,
      );
