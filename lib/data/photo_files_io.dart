// 내 사진 파일 — 안드로이드: 앱 문서 폴더/photos (앱을 지우면 같이 지워진다)
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show FileImage, ImageProvider;
import 'package:path_provider/path_provider.dart';

import 'photo_files.dart';

PhotoFiles createPhotoFiles() => _IoPhotoFiles();

class _IoPhotoFiles extends PhotoFiles {
  Directory? _dir;

  Future<Directory> _root() async {
    final d = _dir ??= Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<File> _file(String name) async => File('${(await _root()).path}/$name');

  @override
  Future<void> write(String name, Uint8List bytes) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<Uint8List?> read(String name) async {
    try {
      final f = await _file(name);
      return f.existsSync() ? await f.readAsBytes() : null;
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> delete(String name) async {
    try {
      final f = await _file(name);
      if (f.existsSync()) await f.delete();
    } on Exception {
      // 없으면 그만
    }
  }

  @override
  Future<ImageProvider?> provider(String name) async {
    try {
      final f = await _file(name);
      return f.existsSync() ? FileImage(f) : null;
    } on Exception {
      return null;
    }
  }
}
