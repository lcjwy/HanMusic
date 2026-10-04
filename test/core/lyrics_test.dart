import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/utils/lyrics.dart';

void main() {
  group('LyricsDocument.parse', () {
    test('LRC 基础解析：时间戳 + 文本，按时间排序', () {
      final doc = LyricsDocument.parse(
        '[00:03.50]第二行\n[00:01.00]第一行\n[01:02]分秒行',
      )!;
      expect(doc.hasTimestamps, isTrue);
      expect(doc.lines.length, 3);
      expect(doc.lines[0].text, '第一行');
      expect(doc.lines[0].timestamp, const Duration(seconds: 1));
      expect(doc.lines[1].timestamp, const Duration(milliseconds: 3500));
      expect(doc.lines[2].timestamp, const Duration(minutes: 1, seconds: 2));
    });

    test('一行多时间戳拆分为多条，空文本行保留为 ♪ 占位内容', () {
      final doc = LyricsDocument.parse('[00:01.00][00:05.00]副歌\n[00:09.00]')!;
      expect(doc.lines.length, 3);
      expect(doc.lines[0].text, '副歌');
      expect(doc.lines[1].text, '副歌');
      expect(doc.lines[1].timestamp, const Duration(seconds: 5));
      expect(doc.lines[2].text, '');
    });

    test('元数据标签与空行跳过', () {
      final doc = LyricsDocument.parse(
        '[ti:歌名]\n[ar:歌手]\n[offset:500]\n\n[00:01.00]正文',
      )!;
      expect(doc.lines.length, 1);
      expect(doc.lines[0].text, '正文');
    });

    test('纯文本歌词：无时间戳静态展示', () {
      final doc = LyricsDocument.parse('第一段\n第二段\n')!;
      expect(doc.hasTimestamps, isFalse);
      expect(doc.lines.map((l) => l.text), ['第一段', '第二段']);
      expect(doc.lines.every((l) => l.timestamp == null), isTrue);
      expect(doc.currentIndexAt(const Duration(minutes: 9)), -1);
    });

    test('空内容与元数据-only 返回 null', () {
      expect(LyricsDocument.parse(''), isNull);
      expect(LyricsDocument.parse('   \n\n'), isNull);
      expect(LyricsDocument.parse('[ti:only meta]'), isNull);
    });

    test('小数秒 1-3 位均可解析', () {
      final doc = LyricsDocument.parse('[00:01.5]a\n[00:02.25]b\n[00:03.123]c')!;
      expect(doc.lines[0].timestamp, const Duration(milliseconds: 1500));
      expect(doc.lines[1].timestamp, const Duration(milliseconds: 2250));
      expect(doc.lines[2].timestamp, const Duration(milliseconds: 3123));
    });
  });

  group('LyricsDocument.currentIndexAt', () {
    final doc = LyricsDocument.parse('[00:10.00]a\n[00:20.00]b\n[00:30.00]c')!;

    test('早于首行、行间、精确命中、越界', () {
      expect(doc.currentIndexAt(Duration.zero), -1);
      expect(doc.currentIndexAt(const Duration(seconds: 9)), -1);
      expect(doc.currentIndexAt(const Duration(seconds: 10)), 0);
      expect(doc.currentIndexAt(const Duration(seconds: 19)), 0);
      expect(doc.currentIndexAt(const Duration(seconds: 59)), 2);
    });
  });
}
