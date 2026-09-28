import 'package:han_music/app/data/models/song.dart';

/// Web 平台：不支持本地文件扫描，一律走空实现。
List<String> scanAudioFiles(String dirPath) => const [];

Future<Song> songFromFile(String path) async => Song.fromLocalFile(path: path);
