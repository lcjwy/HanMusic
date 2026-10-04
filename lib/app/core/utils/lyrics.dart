import 'dart:convert';

/// 歌词行：[timestamp] 为 null 表示无时间戳（纯文本行，不可点击跳转）。
class LyricLine {
  const LyricLine(this.timestamp, this.text);

  final Duration? timestamp;
  final String text;
}

/// 解析后的歌词文档：LRC（带时间戳，可跟随滚动）或纯文本（仅静态滚动）。
class LyricsDocument {
  const LyricsDocument({required this.lines, required this.hasTimestamps});

  /// 单份歌词截断保护：异常超大的歌词文本不拖垮解析与内存。
  static const maxRawLength = 512 * 1024;

  static final _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:\.(\d{1,3}))?\]');

  /// 元数据标签（[ti:][ar:][offset:] 等）直接跳过。
  static final _metaTag = RegExp(r'^\[[a-zA-Z#]+[:.]');

  static const empty = LyricsDocument(lines: [], hasTimestamps: false);

  final List<LyricLine> lines;
  final bool hasTimestamps;

  /// 解析 LRC 或纯文本歌词；内容为空返回 null（调用方展示"暂无歌词"）。
  ///
  /// 支持一行多时间戳 `[00:12.00][01:45.30]文字`、无小数秒 `[01:12]`、
  /// 1-3 位小数秒；元数据标签与空行跳过。
  static LyricsDocument? parse(String raw) {
    if (raw.trim().isEmpty) return null;
    final text =
        raw.length > maxRawLength ? raw.substring(0, maxRawLength) : raw;
    final timed = <(Duration, String)>[];
    final plain = <String>[];
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty || _metaTag.hasMatch(line)) continue;
      final matches = _timeTag.allMatches(line).toList();
      final startsWithTime = matches.isNotEmpty && line.startsWith('[');
      if (!startsWithTime) {
        plain.add(line);
        continue;
      }
      final content = line.substring(matches.last.end).trim();
      for (final m in matches) {
        final fraction = (m.group(3) ?? '0').padRight(3, '0').substring(0, 3);
        timed.add((
          Duration(
            minutes: int.parse(m.group(1)!),
            seconds: int.parse(m.group(2)!),
            milliseconds: int.parse(fraction),
          ),
          content,
        ));
      }
    }
    if (timed.isNotEmpty) {
      timed.sort((a, b) => a.$1.compareTo(b.$1));
      return LyricsDocument(
        hasTimestamps: true,
        lines: [for (final (ts, text) in timed) LyricLine(ts, text)],
      );
    }
    if (plain.isEmpty) return null;
    return LyricsDocument(
      hasTimestamps: false,
      lines: [for (final text in plain) LyricLine(null, text)],
    );
  }

  /// 当前播放行索引（最后一条 timestamp ≤ position 的行）；无时间戳、
  /// 空文档或尚未唱到首行返回 -1。
  int currentIndexAt(Duration position) {
    if (!hasTimestamps || lines.isEmpty) return -1;
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timestamp! <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }
}
