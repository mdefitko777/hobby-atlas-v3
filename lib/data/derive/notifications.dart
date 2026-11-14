// 알림 화면 모델 — 알림함 줄(lib/notifications) → AppNotice
part of '../derive.dart';

/// 알림 화면: 알림함(lib/notifications — 앱을 열 때 · 3시간마다 Gunpula 새 소식 파일을 걸러 넣은 줄), 새것부터.
/// 사진은 카탈로그에서, 카탈로그를 아직 받는 중이거나 아직 없는 새 상품이면 피드의 작은 표지(옛 줄 · 옛 피드는 빈 사진).
/// 좋아요 · PB 예약 줄은 franchiseId 를 비워 채널과 상관없이 보이게.
Future<List<AppNotice>> deriveNotifications() async {
  final store = NotifyStore.instance;
  await store.load();
  return [for (final r in store.state.inbox) noticeOf(r, _cat.byId[r.kitId])];
}

/// 알림함 한 줄 → 화면 모델 (예고 단계 · 처음 보인 라이브 = 누르면 그 예고)
AppNotice noticeOf(NoticeRecord r, Kit? kit) => r.isAnnStage || r.isLive
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
        // 피드의 작은 표지는 카탈로그가 온 뒤 칸이 thumbs.json 으로 고르는 주소와 같다 → 그림 캐시를 같이 쓴다
        image: kit?.image ?? r.thumb,
        at: r.at.toLocal(),
        read: r.seen,
        franchiseId: r.wanted ? '' : r.franchise,
        kitId: r.kitId,
      );
