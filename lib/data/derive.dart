// 카탈로그 + 내 기록 → 화면 모델 (도감 · 세계관 · 베이블레이드 · 예고 · 알림 · 내 정보).
// 숫자(모은 칸 · 진행도)는 미리 적힌 값이 아니라 매번 내 기록에서 센다.
// 기능별 part 파일: derive/guide · bbx · worlds · announcements · notifications · profile
library;

import '../clock.dart';
import '../l10n/l10n.dart';
import '../logic/announcement_match.dart' show annHeroIds, annReplacedOf;
import '../logic/live_stream.dart';
import '../models.dart';
import '../notifications/feed_rules.dart' show annStageLabels;
import '../notifications/notify_models.dart';
import '../notifications/notify_store.dart';
import 'catalog.dart';
import 'gundam_atlas.dart';
import 'gunpula.dart';
import 'user_store.dart';
import '../sync/account.dart';
import '../json_util.dart';
import '../logic/collection_rules.dart' show bestStatus;
import '../logic/friends.dart' show friendMemberOf;
import '../sync/friends_service.dart' show PublicProfile;

part 'derive/announcements.dart';
part 'derive/bbx.dart';
part 'derive/guide.dart';
part 'derive/notifications.dart';
part 'derive/profile.dart';
part 'derive/worlds.dart';

Catalog get _cat => Catalog.instance;
UserStore get _me => UserStore.instance;

/// 데이터의 `names` · `labels` 에서 화면 언어 이름 (중국어 화면 = zh 먼저, 건담 Atlas 와 같은 순서)
String _shown(Object? names) => atlasName(names, zh: L10n.isZh);

CollectStatus _kitStatus(String id) => _me.statusOf(id) ?? CollectStatus.none;

/// 여러 상품 중 가장 높은 상태 (구매함 > 좋아요 > 없음)
CollectStatus _best(Iterable<String> kitIds) => bestStatus(kitIds.map(_kitStatus));
