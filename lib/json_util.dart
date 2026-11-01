// JSON 값 꺼내기 — 모양이 다르면 빈 값 (서버 · Gunpula 파일 · 기기 파일 공통)
String jStr(Object? v) => v is String ? v : '';

/// 숫자 · 불리언도 글자로 (phstudy 같이 섞여 오는 곳)
String jText(Object? v) => v is String ? v : (v == null ? '' : '$v');

/// 키가 글자가 아닌 Map 도 받아 들인다
Map<String, Object?> jMap(Object? v) =>
    v is Map<String, Object?> ? v : (v is Map ? {for (final e in v.entries) '${e.key}': e.value} : const {});

List<Object?> jList(Object? v) => v is List ? v : const [];

int jInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
