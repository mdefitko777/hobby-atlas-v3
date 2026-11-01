// 내 사진 — 사진 파일은 기기(앱 문서 폴더 photos/)에, 목록은 UserStore local_state.photos 에.
// 친구에게 보이기를 켠 사진만 lib/sync/photo_share.dart 가 Supabase Storage 에 올린다.
// 안드로이드: 파일 / 웹(미리보기) · 테스트: 메모리 (MemoryPhotoFiles)
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider, MemoryImage;

import '../json_util.dart';
import 'photo_files_io.dart' if (dart.library.js_interop) 'photo_files_web.dart' as impl;

/// 내 사진 한 장 (목록의 한 줄 — 사진 자체는 [file])
@immutable
class MyPhoto {
  const MyPhoto({
    required this.id,
    required this.file,
    required this.createdAt,
    this.kitId = '',
    this.unitId = '',
    this.shared = true,
    this.watermark = true,
    this.uploadedTo = '',
    this.deleted = false,
  });

  /// 새 사진 (id = 시각 + 무작위, 서버 경로 `<user_id>/<id>.jpg` 에도 그대로)
  factory MyPhoto.create({String kitId = '', String unitId = '', DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    final id = 'p${t.millisecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 30).toRadixString(36)}';
    return MyPhoto(id: id, file: '$id.jpg', createdAt: t.toIso8601String(), kitId: kitId, unitId: unitId);
  }

  final String id;

  /// 사진 파일 이름 (photos/ 폴더 안)
  final String file;
  final String createdAt;

  /// 이어 붙인 상품 (kit_id) · 도감 기체 (gget unit_id) — 없으면 ''
  final String kitId;
  final String unitId;

  /// 친구에게 보이기 (켜면 서버에 올림)
  final bool shared;

  /// 저장할 때 "HA · @아이디" 를 넣는지 (친구가 저장할 때도 이 값을 따른다)
  final bool watermark;

  /// 이 사진이 올라가 있는 계정 (Supabase user id) — '' = 서버에 없음
  final String uploadedTo;

  /// 지웠는데 서버에서 아직 못 내렸다 (내리면 목록에서 빠진다)
  final bool deleted;

  MyPhoto copyWith({String? kitId, String? unitId, bool? shared, bool? watermark, String? uploadedTo, bool? deleted}) =>
      MyPhoto(
        id: id,
        file: file,
        createdAt: createdAt,
        kitId: kitId ?? this.kitId,
        unitId: unitId ?? this.unitId,
        shared: shared ?? this.shared,
        watermark: watermark ?? this.watermark,
        uploadedTo: uploadedTo ?? this.uploadedTo,
        deleted: deleted ?? this.deleted,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'file': file,
    'created_at': createdAt,
    if (kitId.isNotEmpty) 'kit_id': kitId,
    if (unitId.isNotEmpty) 'unit_id': unitId,
    'shared': shared,
    'watermark': watermark,
    if (uploadedTo.isNotEmpty) 'uploaded_to': uploadedTo,
    if (deleted) 'deleted': true,
  };

  static MyPhoto? fromJson(Object? raw) {
    final m = jMap(raw);
    final id = jStr(m['id']);
    final file = jStr(m['file']);
    if (id.isEmpty || file.isEmpty || file.contains('/') || file.contains(r'\')) return null;
    return MyPhoto(
      id: id,
      file: file,
      createdAt: jStr(m['created_at']),
      kitId: jStr(m['kit_id']),
      unitId: jStr(m['unit_id']),
      shared: m['shared'] != false,
      watermark: m['watermark'] != false,
      uploadedTo: jStr(m['uploaded_to']),
      deleted: m['deleted'] == true,
    );
  }
}

/// 사진 파일 읽고 쓰기
abstract class PhotoFiles {
  /// 앱 전체 하나 — 테스트는 [MemoryPhotoFiles] 로 바꿔 끼운다
  static PhotoFiles instance = impl.createPhotoFiles();

  Future<void> write(String name, Uint8List bytes);
  Future<Uint8List?> read(String name);
  Future<void> delete(String name);

  /// 화면에 그릴 그림 (없으면 null)
  Future<ImageProvider?> provider(String name);
}

/// 메모리 (테스트 · 웹 미리보기)
class MemoryPhotoFiles extends PhotoFiles {
  final Map<String, Uint8List> files = {};

  @override
  Future<void> write(String name, Uint8List bytes) async => files[name] = bytes;

  @override
  Future<Uint8List?> read(String name) async => files[name];

  @override
  Future<void> delete(String name) async => files.remove(name);

  @override
  Future<ImageProvider?> provider(String name) async => switch (files[name]) {
    final b? => MemoryImage(b),
    _ => null,
  };
}
