/// SubtitleTrack 模型测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/subtitle_track.dart';

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
}
