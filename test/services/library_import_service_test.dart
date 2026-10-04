import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/library_import_service.dart';
import 'package:han_music/app/services/library_service.dart';

void main() {
  late LibraryService library;

  setUp(() {
    library = LibraryService(MemoryStore());
  });

  Song fakeSong(String path) => Song.fromLocalFile(path: path);

  LibraryImportService buildService(
    Future<Song> Function(String path) readSong,
  ) =>
      LibraryImportService(library, readSong: readSong);

  test('批内重复与已入库路径去重，added 为真实新增数', () async {
    final service = buildService((path) async => fakeSong(path));

    expect(
      await service.importFiles(['/a/x.mp3', '/a/x.mp3', '/b/y.mp3']),
      isTrue,
    );
    expect(service.added.value, 2);
    // 输入先去重再扫描，重复路径不重复计数
    expect(service.scanned.value, 2);
    expect(library.songs.length, 2);

    expect(await service.importFiles(['/b/y.mp3', '/c/z.mp3']), isTrue);
    expect(service.added.value, 1);
    expect(library.songs.length, 3);
  });

  test('已有任务进行中时再次导入返回 false 且不执行', () async {
    final gate = Completer<void>();
    final service = buildService((path) async {
      await gate.future;
      return fakeSong(path);
    });

    final first = service.importFiles(['/a.mp3']);
    // 第一个任务已进入读取（importing 置位发生在首个 await 之前）
    expect(service.importing.value, isTrue);

    expect(await service.importFiles(['/b.mp3']), isFalse);
    gate.complete();
    await first;

    expect(service.added.value, 1);
    expect(library.songs.length, 1);
    expect(service.importing.value, isFalse);
  });

  test('取消后处理完当前文件即停止并标记 cancelled', () async {
    final gate = Completer<void>();
    final service = buildService((path) async {
      if (path == '/b.mp3') await gate.future;
      return fakeSong(path);
    });

    final run = service.importFiles(['/a.mp3', '/b.mp3', '/c.mp3']);
    // a 已完成、b 挂起在读取中
    await Future<void>.delayed(Duration.zero);
    expect(service.scanned.value, 1);

    service.cancel();
    gate.complete();
    await run;

    expect(service.cancelled, isTrue);
    expect(service.added.value, 2);
    expect(service.scanned.value, 2);
    expect(library.songs.length, 2);
  });

  test('单文件读取失败不阻断整批导入', () async {
    final service = buildService((path) async {
      if (path == '/bad.mp3') throw Exception('corrupt metadata');
      return fakeSong(path);
    });

    expect(await service.importFiles(['/a.mp3', '/bad.mp3', '/b.mp3']), isTrue);
    expect(service.added.value, 2);
    expect(service.scanned.value, 3);
    expect(library.songs.length, 2);
    expect(service.importing.value, isFalse);
  });
}
