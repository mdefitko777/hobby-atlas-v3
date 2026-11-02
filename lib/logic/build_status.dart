// 조립 상태 (구매함 상품) — 미조립 · 조립 중 · 완성 (+ 도색). 순수 Dart.
// 기기 local_state 'build_status' 에 kit_id 별로 둔다 (lib/data/user_store/kit_progress.dart).
// 수집 기록(items[kit_id])에는 넣지 않는다 — 옛 Gunpula 앱이 동기화 때 모르는 칸을 버릴 수 있다.
// 조립하는 상품만 단계가 있다 ([needsAssembly]) — 피규어 · 인형 · 굿즈는 사면 끝.
import '../json_util.dart';
import '../models.dart';

/// 프라모델이 아니어도 직접 조립하는 라인 (lib/data/gunpula.dart lineLabel 의 이름)
const _assemblyLines = {'건담 아티팩트', 'G FRAME FA', 'MOBILITY JOINT', 'MS 앙상블'};

/// 조립 상태를 둘 상품인가 — 프라모델(HG · MG · RG · PG · EG · SD · RE/100 · 옵션 파츠 · 30MM · V.I. · 포켓프라 …)
/// + 조립식 식완 · 가샤폰 라인. 아머드 코어 식완(어셈블 컬렉션)도 조립식
bool needsAssembly(Kit k) =>
    k.type == '프라모델' || _assemblyLines.contains(k.line) || (k.franchiseId == 'armored_core' && k.line == '식완');

/// 조립 단계 — 기록이 없으면 미조립
enum BuildStage {
  unbuilt('미조립'),
  building('조립 중'),
  built('완성');

  const BuildStage(this.label);
  final String label;

  String get key => name;

  /// 한 번 누를 때마다 다음 단계 (완성 → 미조립)
  BuildStage get next => BuildStage.values[(index + 1) % BuildStage.values.length];

  static BuildStage parse(Object? v) => BuildStage.values.where((s) => s.name == v).firstOrNull ?? BuildStage.unbuilt;
}

/// 한 상품의 조립 기록 — [updatedAt] 이 늦은 쪽이 이긴다 (기기 사이 동기화)
class BuildRecord {
  const BuildRecord({this.stage = BuildStage.unbuilt, this.painted = false, this.updatedAt = ''});

  final BuildStage stage;

  /// 도색함 (완성이 아니어도 켤 수 있다 — 부분 도색)
  final bool painted;

  /// UTC ISO
  final String updatedAt;

  /// 처음 상태(미조립 · 도색 없음)인가 — 화면에 따로 표시하지 않는다
  bool get isDefault => stage == BuildStage.unbuilt && !painted;

  BuildRecord copyWith({BuildStage? stage, bool? painted, String? updatedAt}) =>
      BuildRecord(stage: stage ?? this.stage, painted: painted ?? this.painted, updatedAt: updatedAt ?? this.updatedAt);

  Map<String, Object?> toJson() => {'stage': stage.key, if (painted) 'painted': true, 'updated_at': updatedAt};

  static BuildRecord? fromJson(Object? raw) {
    final m = jMap(raw);
    if (m.isEmpty) return null;
    return BuildRecord(
      stage: BuildStage.parse(m['stage']),
      painted: m['painted'] == true,
      updatedAt: jStr(m['updated_at']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BuildRecord && other.stage == stage && other.painted == painted && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(stage, painted, updatedAt);
}

/// 저장 모양 → kit_id 별 기록 (모양이 틀린 줄은 버린다)
Map<String, BuildRecord> buildRecordsFrom(Object? raw) => {
  for (final e in jMap(raw).entries) e.key: ?BuildRecord.fromJson(e.value),
};

/// 컬렉션 구매함 거르기 — 전체 · 단계 하나
BuildStage? buildFilterAt(int i) => i <= 0 || i > BuildStage.values.length ? null : BuildStage.values[i - 1];

/// [ownedIds] 의 단계별 수 (기록 없음 = 미조립)
Map<BuildStage, int> stageCounts(Iterable<String> ownedIds, BuildStage Function(String id) stageOf) {
  final out = {for (final s in BuildStage.values) s: 0};
  for (final id in ownedIds) {
    out[stageOf(id)] = out[stageOf(id)]! + 1;
  }
  return out;
}

/// 쌓인 것 (미조립 수) — My Page · 컬렉션 · 공유 카드
int backlogCount(Iterable<String> ownedIds, BuildStage Function(String id) stageOf) =>
    ownedIds.where((id) => stageOf(id) == BuildStage.unbuilt).length;
