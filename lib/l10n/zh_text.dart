// 중국어(간체) 화면 글 — 한국어 원본 → 중국어. 화면 묶음마다 파일 하나 (여러 사람이 나눠 번역해도 부딪히지 않게).
// 말과 말투는 docs/terms.md 를 따른다. 같은 한국어가 두 파일에 있으면 뒤의 것이 이긴다 — 같은 번역이어야 한다
// (test/l10n_coverage_test.dart 가 서로 다른 번역을 찾는다).
import 'zh/bbx.dart';
import 'zh/browse.dart';
import 'zh/catalog.dart';
import 'zh/collection.dart';
import 'zh/common.dart';
import 'zh/detail.dart';
import 'zh/notify.dart';
import 'zh/query.dart';
import 'zh/search.dart';
import 'zh/widgets.dart';

/// 묶음 이름 → 표 (테스트가 묶음끼리 번역이 어긋난 것을 찾는다). common 이 맨 앞 — 묶음 파일이 같은 말을 다시 쓰면 그쪽이 이긴다
final Map<String, Map<String, String>> zhGroups = {
  'common': zhCommon,
  'detail': zhDetail,
  'collection': zhCollection,
  'search': zhSearch,
  'browse': zhBrowse,
  'catalog': zhCatalog,
  'notify': zhNotify,
  'bbx': zhBbx,
  'widgets': zhWidgets,
  'query': zhQuery,
};

final Map<String, String> zhText = {for (final g in zhGroups.values) ...g};
