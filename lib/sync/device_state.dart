// 기기 기록 동기화의 규칙 (순수 Dart — 서버 · 위젯 없음). 서비스는 device_state_sync.dart.
//
// 무엇을 맞추나 = [deviceSections] 목록 (UserStore local_state 의 키 + 모양 하나씩).
// 새 local_state 키를 계정에 맞추려면 이 목록에 한 줄만 더한다 — 저장 · 읽기는 UserStore 의 toJson / _fromJson 그대로 쓴다:
//   DeviceSection.set('build_status')       // ['a', 'b'] 같은 모음 (순서 없음)
//   DeviceSection.map('pre_orders')          // {id: 값} — 키마다 따로 늦은 쪽
//   DeviceSection.records('x', newFirst: true) // [{id, …}] — id 마다 따로 늦은 쪽
//   DeviceSection.value('x', empty: [...])   // 통째로 늦은 쪽 (순서가 중요한 목록 · 설정 한 개)
//   DeviceSection.recent('x', cap: 20)       // 최근 순서 목록 (두 기기 것을 섞어 새것부터)
// (실행 중에 더하려면 [registerDeviceSection].)
//
// 장부 (기기 = UserStore.deviceSync.sections, 서버 = device state data.sections — 모양이 같다):
//   {키: {항목: {t: 밀리초, v: 값}}}      — 살아 있는 항목 (모음은 v 없음, 값 = 항목 이름)
//   {키: {항목: {t: 밀리초, d: 1}}}       — 지운 항목 (다른 기기가 되살리지 않게, [tombstoneDays] 일 뒤 버림)
// 합치기: 항목마다 t 가 큰 쪽, 같으면 서버 쪽. t = 0 은 "언제 바꿨는지 모름"(이 기능 전에 모은 기록 — 처음 맞출 때 붙임):
//   서버에 없는 것은 더해지고(합집합), 서버에서 시각이 붙은 변경이 있으면 그것이 이긴다.
library;

import 'dart:convert';

import '../channels.dart' show defaultMyChannels;
import '../json_util.dart';

enum DeviceSectionKind { set, map, records, value, recent }

class DeviceSection {
  /// 모음 — [intItems] = 원소가 숫자 (guide_manual_lit 의 unit_id)
  const DeviceSection.set(this.key, {this.intItems = false})
    : kind = DeviceSectionKind.set,
      idField = '',
      newFirst = false,
      empty = null,
      cap = 0;

  const DeviceSection.map(this.key)
    : kind = DeviceSectionKind.map,
      intItems = false,
      idField = '',
      newFirst = false,
      empty = null,
      cap = 0;

  /// id 를 가진 기록 목록 — [newFirst] = 다른 기기에서 온 새 기록을 앞에 (아니면 끝에)
  const DeviceSection.records(this.key, {this.idField = 'id', this.newFirst = false})
    : kind = DeviceSectionKind.records,
      intItems = false,
      empty = null,
      cap = 0;

  /// 통째로 하나 — [empty] = 처음 설치 기본값 (처음 맞출 때 이 값이면 "아직 없음"으로 보고 서버 것을 받는다)
  const DeviceSection.value(this.key, {this.empty})
    : kind = DeviceSectionKind.value,
      intItems = false,
      idField = '',
      newFirst = false,
      cap = 0;

  /// 최근 순서 글자 목록 (최근 검색어) — 새것부터 [cap] 개
  const DeviceSection.recent(this.key, {this.cap = 20})
    : kind = DeviceSectionKind.recent,
      intItems = false,
      idField = '',
      newFirst = false,
      empty = null;

  /// UserStore local_state 의 키
  final String key;
  final DeviceSectionKind kind;
  final bool intItems;
  final String idField;
  final bool newFirst;
  final Object? empty;
  final int cap;
}

/// 계정에 맞추는 local_state 키. 안 맞추는 것(기기에만): recent_viewed · photos(사진은 photo_restore 가 따로) ·
/// profile_images · photo_privacy(서버 표가 따로) · friends_seen_at · friend_avatars(캐시) · 알림 상태(NotifyStore)
const List<DeviceSection> builtInDeviceSections = [
  DeviceSection.set('bbx_owned_parts'),
  DeviceSection.map('bbx_manual_map'),
  DeviceSection.records('bbx_combos', newFirst: true),
  DeviceSection.records('bbx_decks'),
  DeviceSection.set('guide_manual_lit', intItems: true),
  DeviceSection.set('tag_owned'),
  DeviceSection.set('tag_liked'),
  DeviceSection.set('special_friends'),
  DeviceSection.value('my_channels', empty: defaultMyChannels),
  DeviceSection.set('dismissed_suggestions'),
  DeviceSection.value('profile_tags', empty: <String>[]),
  // 조립 상태 · 예약 (lib/data/user_store/kit_progress.dart) — kit_id 마다 따로 늦은 쪽 (예약을 지우면 deleted: true 로 남는다)
  DeviceSection.map('build_status'),
  DeviceSection.map('preorders'),
  DeviceSection.recent('recent_searches'),
  DeviceSection.map('search_counts'),
  DeviceSection.map('trash'),
];

final List<DeviceSection> _extra = [];

/// 실행 중에 맞출 키 더하기 (같은 키는 한 번만)
void registerDeviceSection(DeviceSection s) {
  if (deviceSections.any((x) => x.key == s.key)) return;
  _extra.add(s);
}

List<DeviceSection> get deviceSections => [...builtInDeviceSections, ..._extra];

/// 지운 표시를 남겨 두는 날 수 (이보다 오래 꺼져 있던 기기는 지운 것을 되살릴 수 있다)
const tombstoneDays = 180;

typedef Ledger = Map<String, Map<String, Object?>>;

int _t(Object? e) => jInt(jMap(e)['t']);
bool _dead(Object? e) => jMap(e)['d'] != null;

/// 지금 기록 → 항목: 값 (모음은 true)
Map<String, Object?> entriesOf(DeviceSection s, Object? json) => switch (s.kind) {
  DeviceSectionKind.set => {for (final x in jList(json)) '$x': true},
  DeviceSectionKind.map => {...jMap(json)},
  DeviceSectionKind.records => {
    for (final r in jList(json))
      if (jStr(jMap(r)[s.idField]) case final id when id.isNotEmpty) id: r,
  },
  DeviceSectionKind.value => json == null ? {} : {'_': json},
  DeviceSectionKind.recent => {for (final (i, x) in jList(json).indexed) '$x': i},
};

/// 장부에 지금 기록을 적는다 — 새로 생긴 · 바뀐 항목은 [now], 없어진 항목은 지움 표시.
/// [section] 이 null 이면 이 키를 처음 맞춤 → 시각 0 (언제 바꿨는지 모름). 바뀐 게 없으면 같은 객체를 돌려준다.
Map<String, Object?> stampSection(DeviceSection s, Map<String, Object?>? section, Object? json, int now) {
  final first = section == null;
  final cur = entriesOf(s, json);
  // 통째로 하나: 아직 처음 기본값 그대로면 "없음" — 다른 기기에서 고른 값을 받는다
  if ((first || section.isEmpty) && s.kind == DeviceSectionKind.value && sameJson(cur['_'], s.empty)) {
    return section ?? {};
  }
  final out = <String, Object?>{...?section};
  var changed = first;
  for (final e in cur.entries) {
    final old = out[e.key];
    final v = s.kind == DeviceSectionKind.set ? null : e.value;
    if (old != null && !_dead(old) && sameJson(jMap(old)['v'], v)) continue;
    out[e.key] = {'t': first ? 0 : now, 'v': ?v};
    changed = true;
  }
  for (final k in [...out.keys]) {
    if (!cur.containsKey(k) && !_dead(out[k])) {
      out[k] = {'t': now, 'd': 1};
      changed = true;
    }
  }
  return changed || section == null ? out : section;
}

/// 한 키의 두 장부 합치기 — 항목마다 t 가 큰 쪽, 같으면 [remote]. 오래된 지움 표시는 버린다
Map<String, Object?> mergeSection(Map<String, Object?>? local, Map<String, Object?>? remote, int now) {
  final cutoff = now - tombstoneDays * Duration.millisecondsPerDay;
  final out = <String, Object?>{};
  for (final k in {...?local?.keys, ...?remote?.keys}) {
    final a = local?[k], b = remote?[k];
    final win = a == null ? b : (b == null ? a : (_t(a) > _t(b) ? a : b));
    if (win == null || (_dead(win) && _t(win) < cutoff)) continue;
    out[k] = win;
  }
  return out;
}

/// 장부 전체 합치기 (등록된 키만 — 모르는 키는 부르는 쪽이 서버 것 그대로 둔다)
Ledger mergeLedger(Ledger local, Ledger remote, int now) => {
  for (final s in deviceSections)
    if (local[s.key] != null || remote[s.key] != null) s.key: mergeSection(local[s.key], remote[s.key], now),
};

/// 장부 → 그 키의 기록 (local_state 모양). 지금 기록 [current] 와 같으면 null (바꿔 끼울 것 없음)
Object? rebuildSection(DeviceSection s, Map<String, Object?> section, Object? current) {
  final live = {
    for (final e in section.entries)
      if (!_dead(e.value)) e.key: jMap(e.value),
  };
  Object? item(String k) => s.intItems ? int.tryParse(k) ?? k : k;
  switch (s.kind) {
    case DeviceSectionKind.set:
      final now = {for (final x in jList(current)) '$x'};
      if (now.length == live.length && live.keys.every(now.contains)) return null;
      return [
        for (final x in jList(current))
          if (live.containsKey('$x')) x,
        for (final k in live.keys.toList()..sort())
          if (!now.contains(k)) item(k),
      ];
    case DeviceSectionKind.map:
      final next = {for (final e in live.entries) e.key: e.value['v']};
      return sameJson(next, jMap(current)) ? null : next;
    case DeviceSectionKind.records:
      final cur = entriesOf(s, current);
      final kept = [
        for (final r in jList(current))
          ?live[jStr(jMap(r)[s.idField])]?['v'],
      ];
      final fresh = [
        for (final e in live.entries)
          if (!cur.containsKey(e.key)) e,
      ]..sort((a, b) => _t(b.value).compareTo(_t(a.value)));
      final next = s.newFirst
          ? [for (final e in fresh) e.value['v'], ...kept]
          : [...kept, for (final e in fresh) e.value['v']];
      return sameJson(next, current) ? null : next;
    case DeviceSectionKind.value:
      final v = live['_'];
      if (v == null || sameJson(v['v'], current)) return null;
      return v['v'];
    case DeviceSectionKind.recent:
      final order = live.entries.toList()
        ..sort((a, b) {
          final c = _t(b.value).compareTo(_t(a.value));
          return c != 0 ? c : jInt(a.value['v']).compareTo(jInt(b.value['v']));
        });
      final next = [for (final e in order.take(s.cap)) e.key];
      return sameJson(next, current) ? null : next;
  }
}

/// JSON 값이 같은지 (Map 키 순서는 보지 않는다)
bool sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !sameJson(e.value, b[e.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

/// 장부 모양으로 읽기 (모르는 모양은 버림)
Ledger ledgerFrom(Object? raw) => {
  for (final e in jMap(raw).entries)
    e.key: {
      for (final x in jMap(e.value).entries)
        if (x.value is Map) x.key: jMap(x.value),
    },
};

/// 서버에 보낼 크기 (바이트, 대략) — 1 MB 를 넘으면 서버가 54000
int jsonBytes(Object? v) => utf8.encode(jsonEncode(v)).length;
