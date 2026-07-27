/// SubtitleTrack 模型测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/models/subtitle_track.dart';

void main() {
  group('SubtitleTrack', () {
    test('fromJson 正确解析所有字段', () {
      final json = {
        'id': 'sub-1',
        'name': '中文简体',
        'language': 'chi',
        'format': 'srt',
        'url': 'http://example.com/sub.srt',
        'isDefault': true,
        'isForced': false,
      };
      final track = SubtitleTrack.fromJson(json);
      expect(track.id, 'sub-1');
      expect(track.name, '中文简体');
      expect(track.language, 'chi');
      expect(track.format, 'srt');
      expect(track.url, 'http://example.com/sub.srt');
      expect(track.isDefault, true);
      expect(track.isForced, false);
    });

    test('fromJson 缺失字段使用默认值', () {
      final json = {'id': 'sub-2'};
      final track = SubtitleTrack.fromJson(json);
      expect(track.id, 'sub-2');
      expect(track.name, '');
      expect(track.language, '');
      expect(track.format, '');
      expect(track.url, isNull);
      expect(track.isDefault, false);
      expect(track.isForced, false);
    });

    test('displayName 优先使用 name', () {
      const track = SubtitleTrack(
        id: '1',
        name: '中文简体',
        language: 'chi',
        format: 'srt',
      );
      expect(track.displayName, '中文简体');
    });

    test('displayName name 为空时 fallback 到 language', () {
      const track = SubtitleTrack(
        id: '2',
        name: '',
        language: 'eng',
        format: 'srt',
      );
      expect(track.displayName, 'eng');
    });

    test('displayName 全部为空时返回 Unknown', () {
      const track = SubtitleTrack(
        id: '3',
        name: '',
        language: '',
        format: 'srt',
      );
      expect(track.displayName, 'Unknown');
    });

    test('toJson 正确序列化', () {
      const track = SubtitleTrack(
        id: 'sub-3',
        name: 'English',
        language: 'eng',
        format: 'vtt',
        url: 'http://example.com/sub.vtt',
        isDefault: false,
        isForced: true,
      );
      final json = track.toJson();
      expect(json['id'], 'sub-3');
      expect(json['name'], 'English');
      expect(json['language'], 'eng');
      expect(json['format'], 'vtt');
      expect(json['url'], 'http://example.com/sub.vtt');
      expect(json['isDefault'], false);
      expect(json['isForced'], true);
    });
  });

  group('parseSrt', () {
    test('空字符串返回空列表', () {
      final result = parseSrt('');
      expect(result, isEmpty);
    });

    test('单个字幕 block 解析正确', () {
      const srt = '''1
00:00:01,000 --> 00:00:04,000
第一行字幕''';
      final result = parseSrt(srt);
      expect(result.length, 1);
      expect(result[0].start, const Duration(seconds: 1));
      expect(result[0].end, const Duration(seconds: 4));
      expect(result[0].text, '第一行字幕');
    });

    test('多个字幕 block 解析正确', () {
      const srt = '''1
00:00:01,000 --> 00:00:04,000
第一行字幕

2
00:00:05,000 --> 00:00:08,500
第二行字幕

3
00:00:10,000 --> 00:00:12,000
第三行字幕''';
      final result = parseSrt(srt);
      expect(result.length, 3);
      expect(result[0].text, '第一行字幕');
      expect(result[1].text, '第二行字幕');
      expect(result[2].text, '第三行字幕');
      expect(result[1].end, const Duration(seconds: 8, milliseconds: 500));
    });

    test('Windows 换行（\\r\\n）正确解析', () {
      final srt = '1\r\n00:00:01,000 --> 00:00:02,000\r\n字幕文本\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000\r\n第二句';
      final result = parseSrt(srt);
      expect(result.length, 2);
      expect(result[0].text, '字幕文本');
      expect(result[1].text, '第二句');
    });

    test('多个连续空行分隔正确', () {
      const srt = '''1
00:00:01,000 --> 00:00:02,000
字幕1


2
00:00:03,000 --> 00:00:04,000
字幕2



3
00:00:05,000 --> 00:00:06,000
字幕3''';
      final result = parseSrt(srt);
      expect(result.length, 3);
      expect(result[0].text, '字幕1');
      expect(result[1].text, '字幕2');
      expect(result[2].text, '字幕3');
    });

    test('序号缺失时仍能解析（通过时间行识别）', () {
      const srt = '''00:00:01,000 --> 00:00:02,000
没有序号的字幕

00:00:03,000 --> 00:00:04,000
第二个字幕''';
      final result = parseSrt(srt);
      expect(result.length, 2);
      expect(result[0].text, '没有序号的字幕');
      expect(result[1].text, '第二个字幕');
    });

    test('时间格式变体（HH:MM:SS,mmm）', () {
      const srt = '''1
01:02:03,456 --> 02:03:04,567
测试时间''';
      final result = parseSrt(srt);
      expect(result.length, 1);
      expect(result[0].start, const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 456));
      expect(result[0].end, const Duration(hours: 2, minutes: 3, seconds: 4, milliseconds: 567));
    });

    test('文本包含 HTML 标签（<b>、<i>、<font>）', () {
      const srt = '''1
00:00:01,000 --> 00:00:04,000
<b>加粗文本</b> <i>斜体</i> <font color="red">红色</font>''';
      final result = parseSrt(srt);
      expect(result.length, 1);
      expect(result[0].text, '加粗文本 斜体 红色');
    });

    test('文本包含 emoji 和特殊字符', () {
      const srt = '''1
00:00:01,000 --> 00:00:02,000
🎉 你好，世界！ 🌟

2
00:00:03,000 --> 00:00:04,000
特殊字符：@#¥%……&*（）''';
      final result = parseSrt(srt);
      expect(result.length, 2);
      expect(result[0].text, '🎉 你好，世界！ 🌟');
      expect(result[1].text, '特殊字符：@#¥%……&*（）');
    });

    test('超长文本（>500 字符）', () {
      final longText = 'A' * 600;
      final srt = '''1
00:00:01,000 --> 00:00:02,000
$longText''';
      final result = parseSrt(srt);
      expect(result.length, 1);
      expect(result[0].text.length, 600);
      expect(result[0].text, startsWith('AAAAA'));
    });

    test('多行文本（2 行以上）', () {
      const srt = '''1
00:00:01,000 --> 00:00:04,000
第一行字幕
第二行字幕
第三行字幕''';
      final result = parseSrt(srt);
      expect(result.length, 1);
      expect(result[0].text, '第一行字幕\n第二行字幕\n第三行字幕');
    });

    test('损坏格式（缺少时间行）不崩溃', () {
      const srt = '''1
这是一个没有时间行的损坏字幕

2
00:00:01,000 --> 00:00:02,000
正常字幕''';
      final result = parseSrt(srt);
      expect(result.length, 1);
      expect(result[0].text, '正常字幕');
    });

    test('中文字幕文本正确解析', () {
      const srt = '''1
00:00:01,000 --> 00:00:04,000
我爱北京天安门

2
00:00:05,000 --> 00:00:08,000
天安门上太阳升''';
      final result = parseSrt(srt);
      expect(result.length, 2);
      expect(result[0].text, '我爱北京天安门');
      expect(result[1].text, '天安门上太阳升');
    });

    test('中英混合字幕正确解析', () {
      const srt = '''1
00:00:01,000 --> 00:00:04,000
Hello 世界！Welcome to 北京

2
00:00:05,000 --> 00:00:08,000
学习 Flutter 开发 is fun''';
      final result = parseSrt(srt);
      expect(result.length, 2);
      expect(result[0].text, 'Hello 世界！Welcome to 北京');
      expect(result[1].text, '学习 Flutter 开发 is fun');
    });
  });

  group('parseVtt', () {
    test('空字符串返回空列表', () {
      final result = parseVtt('');
      expect(result, isEmpty);
    });

    test('基础 WEBVTT 格式解析', () {
      const vtt = '''WEBVTT

00:00:01.000 --> 00:00:04.000
第一行字幕

00:00:05.000 --> 00:00:08.500
第二行字幕''';
      final result = parseVtt(vtt);
      expect(result.length, 2);
      expect(result[0].start, const Duration(seconds: 1));
      expect(result[0].end, const Duration(seconds: 4));
      expect(result[0].text, '第一行字幕');
      expect(result[1].end, const Duration(seconds: 8, milliseconds: 500));
    });

    test('NOTE 行被忽略', () {
      const vtt = '''WEBVTT

NOTE This is a note
- with multiple lines

00:00:01.000 --> 00:00:02.000
正常字幕''';
      final result = parseVtt(vtt);
      expect(result.length, 1);
      expect(result[0].text, '正常字幕');
    });

    test('STYLE 行被忽略', () {
      const vtt = '''WEBVTT

STYLE
::cue {
  background: black;
}

00:00:01.000 --> 00:00:02.000
带样式的字幕''';
      final result = parseVtt(vtt);
      expect(result.length, 1);
      expect(result[0].text, '带样式的字幕');
    });

    test('时间格式 HH:MM:SS.mmm 正确解析', () {
      const vtt = '''WEBVTT

01:02:03.456 --> 02:03:04.567
测试时间''';
      final result = parseVtt(vtt);
      expect(result.length, 1);
      expect(result[0].start, const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 456));
      expect(result[0].end, const Duration(hours: 2, minutes: 3, seconds: 4, milliseconds: 567));
    });

    test('时间格式 MM:SS.mmm 正确解析', () {
      const vtt = '''WEBVTT

01:02.345 --> 03:04.567
短时间格式''';
      final result = parseVtt(vtt);
      expect(result.length, 1);
      expect(result[0].start, const Duration(minutes: 1, seconds: 2, milliseconds: 345));
      expect(result[0].end, const Duration(minutes: 3, seconds: 4, milliseconds: 567));
    });

    test('带 cue 标识符的字幕正确解析', () {
      const vtt = '''WEBVTT

cue-1
00:00:01.000 --> 00:00:02.000
带标识符的字幕''';
      final result = parseVtt(vtt);
      expect(result.length, 1);
      expect(result[0].text, '带标识符的字幕');
    });

    test('VTT 标签被正确移除', () {
      const vtt = '''WEBVTT

00:00:01.000 --> 00:00:02.000
<c.bg_black>黑色背景</c> <i>斜体</i> <b>粗体</b>''';
      final result = parseVtt(vtt);
      expect(result.length, 1);
      expect(result[0].text, '黑色背景 斜体 粗体');
    });

    test('时间行带设置（align:middle）正确解析', () {
      const vtt = '''WEBVTT

00:00:01.000 --> 00:00:02.000 align:middle
居中字幕''';
      final result = parseVtt(vtt);
      expect(result.length, 1);
      expect(result[0].text, '居中字幕');
      expect(result[0].start, const Duration(seconds: 1));
      expect(result[0].end, const Duration(seconds: 2));
    });
  });

  group('parseAss', () {
    test('空字符串返回空列表', () {
      final result = parseAss('');
      expect(result, isEmpty);
    });

    test('基础 ASS 格式解析（Dialogue 行）', () {
      const ass = '''[Script Info]
Title: Test Subtitle

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:04.00,Default,,0,0,0,,第一行字幕
Dialogue: 0,0:00:05.00,0:00:08.50,Default,,0,0,0,,第二行字幕''';
      final result = parseAss(ass);
      expect(result.length, 2);
      expect(result[0].start, const Duration(seconds: 1));
      expect(result[0].end, const Duration(seconds: 4));
      expect(result[0].text, '第一行字幕');
      expect(result[1].end, const Duration(seconds: 8, milliseconds: 500));
    });

    test('样式信息提取（粗体）', () {
      const ass = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,{\\b1}加粗文本''';
      final result = parseAss(ass);
      expect(result.length, 1);
      expect(result[0].text, '加粗文本');
      expect(result[0].isBold, true);
    });

    test('样式信息提取（斜体）', () {
      const ass = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,{\\i1}斜体文本''';
      final result = parseAss(ass);
      expect(result.length, 1);
      expect(result[0].text, '斜体文本');
      expect(result[0].isItalic, true);
    });

    test('样式信息提取（颜色）', () {
      const ass = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,{\\c&HFF0000&}红色文本''';
      final result = parseAss(ass);
      expect(result.length, 1);
      expect(result[0].text, '红色文本');
      expect(result[0].color, '#0000FF');
    });

    test('ASS 时间格式 H:MM:SS.cc 正确解析', () {
      const ass = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,1:02:03.45,2:03:04.56,Default,,0,0,0,,测试时间''';
      final result = parseAss(ass);
      expect(result.length, 1);
      expect(result[0].start, const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 450));
      expect(result[0].end, const Duration(hours: 2, minutes: 3, seconds: 4, milliseconds: 560));
    });

    test('\\N 换行符正确转换', () {
      const ass = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,第一行\\N第二行\\N第三行''';
      final result = parseAss(ass);
      expect(result.length, 1);
      expect(result[0].text, '第一行\n第二行\n第三行');
    });

    test('文本字段包含逗号正确解析', () {
      const ass = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,你好，世界！这是，带逗号的，文本''';
      final result = parseAss(ass);
      expect(result.length, 1);
      expect(result[0].text, '你好，世界！这是，带逗号的，文本');
    });

    test('混合样式标签正确解析', () {
      const ass = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,{\\b1\\i1\\c&H00FF00&}粗斜体绿色''';
      final result = parseAss(ass);
      expect(result.length, 1);
      expect(result[0].text, '粗斜体绿色');
      expect(result[0].isBold, true);
      expect(result[0].isItalic, true);
      expect(result[0].color, '#00FF00');
    });
  });

  group('parseSubtitle', () {
    test('srt 格式正确路由', () {
      const content = '''1
00:00:01,000 --> 00:00:02,000
测试字幕''';
      final result = parseSubtitle(content, 'srt');
      expect(result.length, 1);
      expect(result[0].text, '测试字幕');
    });

    test('vtt 格式正确路由', () {
      const content = '''WEBVTT

00:00:01.000 --> 00:00:02.000
测试字幕''';
      final result = parseSubtitle(content, 'vtt');
      expect(result.length, 1);
      expect(result[0].text, '测试字幕');
    });

    test('ass 格式正确路由', () {
      const content = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,测试字幕''';
      final result = parseSubtitle(content, 'ass');
      expect(result.length, 1);
      expect(result[0].text, '测试字幕');
    });

    test('ssa 格式正确路由到 ass 解析器', () {
      const content = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,测试字幕''';
      final result = parseSubtitle(content, 'ssa');
      expect(result.length, 1);
      expect(result[0].text, '测试字幕');
    });

    test('未知格式默认使用 srt 解析', () {
      const content = '''1
00:00:01,000 --> 00:00:02,000
测试字幕''';
      final result = parseSubtitle(content, 'unknown');
      expect(result.length, 1);
      expect(result[0].text, '测试字幕');
    });

    test('格式大小写不敏感', () {
      const content = '''1
00:00:01,000 --> 00:00:02,000
测试字幕''';
      final result1 = parseSubtitle(content, 'SRT');
      final result2 = parseSubtitle(content, 'Srt');
      expect(result1.length, 1);
      expect(result2.length, 1);
    });
  });

  group('findCueAtPosition', () {
    final cues = [
      const SubtitleCue(Duration(seconds: 1), Duration(seconds: 3), '第一句'),
      const SubtitleCue(Duration(seconds: 5), Duration(seconds: 7), '第二句'),
      const SubtitleCue(Duration(seconds: 9), Duration(seconds: 12), '第三句'),
    ];

    test('空列表返回 null', () {
      final result = findCueAtPosition([], const Duration(seconds: 1));
      expect(result, isNull);
    });

    test('在第一个字幕时间范围内找到正确字幕', () {
      final result = findCueAtPosition(cues, const Duration(seconds: 2));
      expect(result, isNotNull);
      expect(result!.text, '第一句');
    });

    test('在第二个字幕时间范围内找到正确字幕', () {
      final result = findCueAtPosition(cues, const Duration(seconds: 6));
      expect(result, isNotNull);
      expect(result!.text, '第二句');
    });

    test('在字幕间隙时间返回 null', () {
      final result = findCueAtPosition(cues, const Duration(seconds: 4));
      expect(result, isNull);
    });

    test('在所有字幕之前返回 null', () {
      final result = findCueAtPosition(cues, const Duration(seconds: 0));
      expect(result, isNull);
    });

    test('在所有字幕之后返回 null', () {
      final result = findCueAtPosition(cues, const Duration(seconds: 15));
      expect(result, isNull);
    });

    test('恰好等于开始时间返回字幕', () {
      final result = findCueAtPosition(cues, const Duration(seconds: 5));
      expect(result, isNotNull);
      expect(result!.text, '第二句');
    });

    test('恰好等于结束时间返回字幕', () {
      final result = findCueAtPosition(cues, const Duration(seconds: 7));
      expect(result, isNotNull);
      expect(result!.text, '第二句');
    });

    test('单个字幕正确查找', () {
      final singleCue = [
        const SubtitleCue(Duration(seconds: 1), Duration(seconds: 5), '唯一字幕'),
      ];
      final result = findCueAtPosition(singleCue, const Duration(seconds: 3));
      expect(result, isNotNull);
      expect(result!.text, '唯一字幕');
    });
  });
}
