// 생김새로 찾기 — Gunpula release `imgsim` 의 안내 파일 읽기 · 받아 둔 모델과 비교 (순수 Dart).
// 새 안내 `imgsim-v2.json` (schema 2: 모델 여럿 · default · 모델마다 표)을 먼저 읽고, 아직 없으면 옛 `imgsim.json` (schema 1).
// 두 모델(B/32 · B/16)이 같은 768 차원이라 차원으로는 짝을 못 가린다 → 표 머리의 model 이 모델 id 와 같아야 쓴다.
library;

/// 받을 파일 하나 (모델 파일 · 표)
class VisualFile {
  const VisualFile(this.json);
  final Map<String, Object?> json;

  /// 기기에 둘 이름 — 안내 파일 값에서 마지막 조각만 (폴더 밖으로 못 나가게)
  String get file => '${json['file'] ?? ''}'.split(RegExp(r'[/\\]')).last;
  String get url => '${json['url'] ?? ''}';
  int get bytes => (json['bytes'] as num?)?.toInt() ?? 0;
  String get sha256 => '${json['sha256'] ?? ''}';
}

/// 모델 하나 + 그 모델로 만든 표 (안내 파일 schema 2 의 `models[]` 한 칸 모양)
class VisualModel {
  const VisualModel(this.json);
  final Map<String, Object?> json;

  String get id => '${json['id'] ?? ''}';
  VisualFile get model => VisualFile(json);
  VisualFile get vectors => VisualFile((json['vectors'] as Map?)?.cast<String, Object?>() ?? const {});
  int get bytes => model.bytes + vectors.bytes;

  /// 옛 안내(schema 1 `{model, vectors}`) → 한 칸. id 는 표의 model 이름 (없으면 모델 파일 이름에서 .tflite 를 뗀 것)
  factory VisualModel.fromV1(Map<String, Object?> m) {
    final model = (m['model'] as Map?)?.cast<String, Object?>() ?? const {};
    final vectors = (m['vectors'] as Map?)?.cast<String, Object?>() ?? const {};
    final named = '${vectors['model'] ?? ''}';
    final id = named.isNotEmpty ? named : '${model['file'] ?? ''}'.replaceFirst(RegExp(r'\.tflite$'), '');
    return VisualModel({...model, 'id': id, 'vectors': vectors});
  }
}

class VisualManifest {
  const VisualManifest({required this.defaultId, required this.models});

  /// 앱이 받을 모델 (B/16 표가 98 % 를 덮기 전까지는 B/32)
  final String defaultId;
  final List<VisualModel> models;

  VisualModel? byId(String id) => models.where((m) => m.id == id).firstOrNull;

  /// 받을 모델 — default 가 목록에 없으면 첫 칸
  VisualModel get preferred => byId(defaultId) ?? models.first;

  /// schema 2 또는 1. 모르는 schema 면 앱이 옛것 (FormatException 글 = 화면에 그대로)
  factory VisualManifest.parse(Map<String, Object?> m, {required String updateMessage}) {
    switch (m['schema']) {
      case 2:
        final models = [
          for (final e in (m['models'] as List?) ?? const [])
            if (e is Map) VisualModel(e.cast<String, Object?>()),
        ].where((e) => e.id.isNotEmpty && e.model.url.isNotEmpty && e.vectors.url.isNotEmpty).toList();
        if (models.isEmpty) throw FormatException(updateMessage);
        return VisualManifest(defaultId: '${m['default'] ?? models.first.id}', models: models);
      case 1:
        final one = VisualModel.fromV1(m);
        return VisualManifest(defaultId: one.id, models: [one]);
      default:
        throw FormatException(updateMessage);
    }
  }
}

/// 기기에 적어 둔 받은 모델 — 새 모양 `{schema: 2, installed: {...}}` 또는 옛 모양(받은 schema 1 안내 통째)
VisualModel? installedModel(Map<String, Object?> local) {
  if (local['installed'] case final Map<Object?, Object?> e) return VisualModel(e.cast<String, Object?>());
  if (local['model'] is Map && local['vectors'] is Map) return VisualModel.fromV1(local);
  return null;
}

/// 안내 파일과 받아 둔 모델 비교: [vectors] = 같은 모델의 새 표 (조용히 받는다),
/// [model] = 새 모델을 권할 때 그 모델 (받은 모델 파일이 바뀌었거나 · 목록에서 빠졌거나 · default 가 다른 모델로 옮김)
({VisualModel? vectors, VisualModel? model}) visualUpgrade(VisualModel installed, VisualManifest remote) {
  final same = remote.byId(installed.id);
  final modelChanged = same == null || same.model.sha256 != installed.model.sha256;
  final offer = modelChanged || remote.preferred.id != installed.id ? remote.preferred : null;
  final vectors = same != null && !modelChanged && same.vectors.sha256 != installed.vectors.sha256 ? same : null;
  return (vectors: vectors, model: offer);
}
