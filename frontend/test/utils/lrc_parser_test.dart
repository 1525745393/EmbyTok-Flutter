// LRC 歌词解析器单元测试

import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/utils/lrc_parser.dart';

void main() {
  group('parseLrc', () {
    test('解析标准时间戳 [mm:ss.xx]', () {
      final lines = parseLrc('[00:01.50]第一句\n[00:03.00]第二句\n');
      expect(lines.length, 2);
      expect(lines[0].time, const Duration(milliseconds: 1500));
      expect(lines[0].text, '第一句');
      expect(lines[1].time, const Duration(milliseconds: 3000));
      expect(lines[1].text, '第二句');
    });

    test('支持毫秒三位时间戳 [mm:ss.xxx]', () {
      final lines = parseLrc('[01:02.123]测试\n');
      expect(lines[0].time, const Duration(milliseconds: 62123));
    });

    test('支持 [mm:ss:xx] 百分之一秒格式', () {
      final lines = parseLrc('[00:10:50]百分位\n');
      expect(lines[0].time, const Duration(milliseconds: 10500));
    });

    test('一行多时间戳展开为多行', () {
      final lines = parseLrc('[00:10.00][00:20.00]副歌重复\n');
      expect(lines.length, 2);
      expect(lines[0].time, const Duration(milliseconds: 10000));
      expect(lines[1].time, const Duration(milliseconds: 20000));
      expect(lines[0].text, '副歌重复');
    });

    test('跳过元数据标签（ti/ar/al/by/offset）', () {
      final lines = parseLrc(
          '[ti:歌名]\n[ar:歌手]\n[al:专辑]\n[by:某人]\n[offset:+500]\n[00:01.00]歌词\n');
      expect(lines.length, 1);
      expect(lines[0].text, '歌词');
      // offset +500ms 作用到时间戳
      expect(lines[0].time, const Duration(milliseconds: 1500));
    });

    test('支持负 offset', () {
      final lines = parseLrc('[offset:-200]\n[00:01.00]歌词\n');
      expect(lines[0].time, const Duration(milliseconds: 800));
    });

    test('无时间戳行（纯文本/元数据）被跳过', () {
      final lines = parseLrc('纯文本行\n[ar:歌手]\n');
      expect(lines, isEmpty);
    });

    test('乱序时间戳自动排序', () {
      final lines = parseLrc('[00:05.00]后句\n[00:01.00]前句\n');
      expect(lines.first.text, '前句');
      expect(lines.last.text, '后句');
    });

    test('空文本返回空列表', () {
      expect(parseLrc(''), isEmpty);
      expect(parseLrc('\n\n'), isEmpty);
    });
  });

  group('activeLrcIndex', () {
    final lines = parseLrc('[00:01.00]第一句\n[00:03.00]第二句\n[00:05.00]第三句\n');

    test('播放开始前返回 -1', () {
      expect(activeLrcIndex(lines, Duration.zero), -1);
    });

    test('命中时间戳返回对应行', () {
      expect(activeLrcIndex(lines, const Duration(seconds: 1)), 0);
      expect(activeLrcIndex(lines, const Duration(seconds: 3)), 1);
    });

    test('两行之间返回前一行', () {
      expect(activeLrcIndex(lines, const Duration(milliseconds: 1999)), 0);
    });

    test('超过最后一句返回最后一行', () {
      expect(activeLrcIndex(lines, const Duration(seconds: 99)), 2);
    });

    test('空列表返回 -1', () {
      expect(activeLrcIndex(const [], const Duration(seconds: 5)), -1);
    });
  });

  group('formatDuration', () {
    test('标准 mm:ss', () {
      expect(formatDuration(const Duration(minutes: 1, seconds: 5)), '01:05');
      expect(formatDuration(const Duration(seconds: 0)), '00:00');
    });
  });
}
