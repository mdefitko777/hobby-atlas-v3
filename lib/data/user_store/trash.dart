// 컬렉션 휴지통 (기기에만) — UserStore 의 한 부분
part of '../user_store.dart';

/// 저장 파일의 trash → kit_id 별 (어느 탭에서 · 언제). 모양이 틀린 줄은 버린다
Map<String, ({String from, String at})> _trashFrom(Object? raw) => {
  for (final e in jMap(raw).entries)
    if (jMap(e.value) case final m when jStr(m['at']).isNotEmpty && (m['from'] == 'owned' || m['from'] == 'wanted'))
      e.key: (from: jStr(m['from']), at: jStr(m['at'])),
};

mixin _Trash on ChangeNotifier {
  void _changed();

  /// 컬렉션 휴지통: kit_id → (어느 탭에서 지웠나 owned · wanted, 지운 시각 UTC ISO). [UserStore.trashDays] 일 지나면 버린다. 기기에만
  final Map<String, ({String from, String at})> trash = {};

  /// 컬렉션에서 지운 상품을 휴지통에 ([owned] = 구매함 탭에서 지웠나)
  void trashAdd(Iterable<String> kitIds, {required bool owned, DateTime? now}) {
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();
    var any = false;
    for (final id in kitIds) {
      trash[id] = (from: owned ? 'owned' : 'wanted', at: at);
      any = true;
    }
    if (any) _changed();
  }

  void trashRemove(Iterable<String> kitIds) {
    var any = false;
    for (final id in kitIds) {
      if (trash.remove(id) != null) any = true;
    }
    if (any) _changed();
  }

  /// [UserStore.trashDays] 일 지난 것을 버린다 (읽을 때 · 휴지통을 열 때)
  void purgeTrash(DateTime now) {
    if (_purgeTrash(now)) _changed();
  }

  bool _purgeTrash(DateTime now) {
    final cutoff = now.toUtc().subtract(const Duration(days: UserStore.trashDays));
    final before = trash.length;
    trash.removeWhere((_, v) => DateTime.tryParse(v.at)?.isBefore(cutoff) ?? true);
    return trash.length != before;
  }

  Map<String, Object?> _trashJson() => {
    for (final e in trash.entries) e.key: {'from': e.value.from, 'at': e.value.at},
  };
}
