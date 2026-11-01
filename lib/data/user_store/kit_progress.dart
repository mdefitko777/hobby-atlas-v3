// 조립 상태 · 예약 (기기 local_state, 수집 기록 items 와 따로) — UserStore 의 한 부분
//   build_status {kit_id: {stage: unbuilt|building|built, painted?: true, updated_at}}
//   preorders    {kit_id: {shop?, price?, deposit?, paid, arrival?: YYYY-MM|YYYY-MM-DD, arrived_at?, deleted?: true, updated_at}}
// 두 섹션 모두 항목마다 updated_at — 기기 사이 동기화는 항목별로 늦은 쪽이 이긴다. 예약을 지우면 deleted 로 남긴다.
// 수집 기록(items[kit_id])에 칸을 더하지 않는다: 옛 Gunpula 앱이 동기화하면서 모르는 칸을 버릴 수 있다.
// 계정 동기화: local_state 'build_status' · 'preorders' 는 lib/sync/device_state.dart 의 deviceSections 에 map 으로 등록돼 있다.
part of '../user_store.dart';

mixin _KitProgress on ChangeNotifier {
  void _changed();
  String _now();

  /// kit_id → 조립 기록 (없으면 미조립)
  final Map<String, BuildRecord> buildStatus = {};

  /// kit_id → 예약 (지운 것도 deleted 로 남아 있다 — 화면은 [preorderOf] · [activePreorders])
  final Map<String, Preorder> preorders = {};

  BuildRecord buildOf(String kitId) => buildStatus[kitId] ?? const BuildRecord();

  BuildStage stageOf(String kitId) => buildOf(kitId).stage;

  /// 단계 · 도색 바꾸기 (준 것만)
  void setBuild(String kitId, {BuildStage? stage, bool? painted}) {
    final old = buildOf(kitId);
    final next = old.copyWith(stage: stage, painted: painted, updatedAt: _now());
    if (next.stage == old.stage && next.painted == old.painted && buildStatus.containsKey(kitId)) return;
    buildStatus[kitId] = next;
    _changed();
  }

  /// 되돌리기: 앞의 기록 그대로 (시각만 새로 — 동기화 때 이 값이 이기게)
  void putBuild(String kitId, BuildRecord before) {
    buildStatus[kitId] = before.copyWith(updatedAt: _now());
    _changed();
  }

  /// 지우지 않은 예약 (도착한 것 포함)
  Preorder? preorderOf(String kitId) => switch (preorders[kitId]) {
    final p? when !p.deleted => p,
    _ => null,
  };

  /// 기다리는 예약만
  Map<String, Preorder> get activePreorders => {
    for (final e in preorders.entries)
      if (e.value.active) e.key: e.value,
  };

  /// 예약 적기 · 고치기 (null = 지우기 → deleted 로 남김)
  void putPreorder(String kitId, Preorder? p) {
    final now = _now();
    if (p == null) {
      final old = preorders[kitId];
      if (old == null || old.deleted) return;
      preorders[kitId] = old.copyWith(deleted: true, updatedAt: now);
    } else {
      preorders[kitId] = p.copyWith(deleted: false, updatedAt: now);
    }
    _changed();
  }

  void _loadKitProgress(Map<String, Object?> local) {
    buildStatus
      ..clear()
      ..addAll(buildRecordsFrom(local['build_status']));
    preorders
      ..clear()
      ..addAll(preordersFrom(local['preorders']));
  }

  /// 비어 있으면 키를 쓰지 않는다 (저장 파일 골든 · 옛 파일과 같은 모양)
  Map<String, Object?> _kitProgressJson() => {
    if (buildStatus.isNotEmpty) 'build_status': {for (final e in buildStatus.entries) e.key: e.value.toJson()},
    if (preorders.isNotEmpty) 'preorders': {for (final e in preorders.entries) e.key: e.value.toJson()},
  };
}
