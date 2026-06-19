/// MediaSource / MediaStream 模型测试
///
/// 重点验证：
/// - JSON 解析（Emby 原生 PascalCase + 简化 snake_case）
/// - isLandscape / isPortrait 方向判断
/// - audioStreams / subtitleStreams 过滤
/// - defaultAudioStream 默认音轨选择

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/media_source.dart';

void main() {
  group('MediaStream', () {
    test('fromJson 正确解析 Emby PascalCase 字段', () {
      const json = {
        'Index': 0,
        'Type': 'Video',
        'Language': 'eng',
        'DisplayTitle': 'H.264 1080p',
        'IsDefault': true,
        'IsForced': false,
        'IsExternal': false,
        'Codec': 'h264',
        'Width': 1920,
        'Height': 1080,
      };
      final stream = MediaStream.fromJson(json);
      expect(stream.index, 0);
      expect(stream.type, 'Video');
      expect(stream.language, 'eng');
      expect(stream.displayTitle, 'H.264 1080p');
      expect(stream.isDefault, true);
      expect(stream.isForced, false);
      expect(stream.isExternal, false);
      expect(stream.codec, 'h264');
      expect(stream.width, 1920);
      expect(stream.height, 1080);
    });

    test('fromJson 正确解析简化 snake_case 字段', () {
      const json = {
        'index': 1,
        'type': 'Audio',
        'language': 'chi',
        'codec': 'aac',
      };
      final stream = MediaStream.fromJson(json);
      expect(stream.index, 1);
      expect(stream.type, 'Audio');
      expect(stream.language, 'chi');
      expect(stream.codec, 'aac');
    });

    test('空 JSON 使用默认值', () {
      final stream = MediaStream.fromJson(<String, dynamic>{});
      expect(stream.index, 0);
      expect(stream.type, 'Video');
      expect(stream.language, isNull);
      expect(stream.isDefault, false);
      expect(stream.isForced, false);
    });
  });

  group('MediaSource', () {
    test('fromJson 正确解析包含媒体流的完整 JSON', () {
      final json = {
        'Id': 'source-1',
        'Name': 'Main',
        'Container': 'mkv',
        'RunTimeTicks': 72000000000,
        'MediaStreams': [
          {'Index': 0, 'Type': 'Video', 'Width': 1080, 'Height': 1920},
          {'Index': 1, 'Type': 'Audio', 'Language': 'eng', 'IsDefault': true},
          {'Index': 2, 'Type': 'Subtitle', 'Language': 'chi'},
        ],
      };
      final source = MediaSource.fromJson(json);
      expect(source.id, 'source-1');
      expect(source.name, 'Main');
      expect(source.container, 'mkv');
      expect(source.runTimeTicks, 72000000000);
      expect(source.mediaStreams, hasLength(3));
      // 从第一个视频流提取宽高
      expect(source.width, 1080);
      expect(source.height, 1920);
    });

    test('从简化 snake_case JSON 解析', () {
      final json = {
        'id': 'source-2',
        'name': 'Stream',
        'media_streams': <Map<String, dynamic>>[],
      };
      final source = MediaSource.fromJson(json);
      expect(source.id, 'source-2');
      expect(source.name, 'Stream');
      expect(source.mediaStreams, isEmpty);
    });

    test('isLandscape: 宽 > 高 为 true', () {
      const source = MediaSource(
        id: '1',
        name: 'landscape',
        width: 1920,
        height: 1080,
      );
      expect(source.isLandscape, true);
      expect(source.isPortrait, false);
    });

    test('isPortrait: 高 > 宽 为 true（竖屏视频）', () {
      const source = MediaSource(
        id: '2',
        name: 'portrait',
        width: 1080,
        height: 1920,
      );
      expect(source.isPortrait, true);
      expect(source.isLandscape, false);
    });

    test('宽或高为 null 时，isLandscape 和 isPortrait 都为 false', () {
      const source = MediaSource(id: '3', name: 'unknown');
      expect(source.isLandscape, false);
      expect(source.isPortrait, false);
    });

    test('audioStreams 过滤出所有 Audio 类型的流', () {
      final source = MediaSource(
        id: '4',
        name: 'multi',
        mediaStreams: const [
          MediaStream(index: 0, type: 'Video'),
          MediaStream(index: 1, type: 'Audio', language: 'eng'),
          MediaStream(index: 2, type: 'Audio', language: 'chi'),
          MediaStream(index: 3, type: 'Subtitle'),
        ],
      );
      expect(source.audioStreams, hasLength(2));
      expect(source.audioStreams.map((s) => s.language), containsAll(['eng', 'chi']));
    });

    test('subtitleStreams 过滤出所有 Subtitle 类型的流', () {
      final source = MediaSource(
        id: '5',
        name: 'multi',
        mediaStreams: const [
          MediaStream(index: 0, type: 'Video'),
          MediaStream(index: 1, type: 'Subtitle', language: 'eng'),
          MediaStream(index: 2, type: 'Subtitle', language: 'chi', isForced: true),
        ],
      );
      expect(source.subtitleStreams, hasLength(2));
    });

    test('defaultAudioStream 返回 isDefault=true 的音轨', () {
      final source = MediaSource(
        id: '6',
        name: 'multi',
        mediaStreams: const [
          MediaStream(index: 0, type: 'Audio', language: 'eng'),
          MediaStream(index: 1, type: 'Audio', language: 'chi', isDefault: true),
        ],
      );
      final defaultStream = source.defaultAudioStream;
      expect(defaultStream, isNotNull);
      expect(defaultStream!.language, 'chi');
      expect(defaultStream.isDefault, true);
    });

    test('defaultAudioStream 无默认音轨时返回第一个', () {
      final source = MediaSource(
        id: '7',
        name: 'no-default',
        mediaStreams: const [
          MediaStream(index: 0, type: 'Audio', language: 'eng'),
        ],
      );
      final defaultStream = source.defaultAudioStream;
      expect(defaultStream, isNotNull);
      expect(defaultStream!.index, 0);
    });

    test('defaultAudioStream 无音轨时返回 null', () {
      const source = MediaSource(id: '8', name: 'no-audio');
      expect(source.defaultAudioStream, isNull);
    });
  });
}
