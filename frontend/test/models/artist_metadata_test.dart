/// ArtistMetadata 模型测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/models/artist_metadata.dart';

void main() {
  group('ArtistMetadata', () {
    group('fromJson', () {
      test('正确解析完整 JSON', () {
        final json = {
          'name': '周杰伦',
          'musicBrainzId': 'mbid-123',
          'imageUrl': 'https://example.com/avatar.jpg',
          'imageSmallUrl': 'https://example.com/avatar_small.jpg',
          'bioSummary': '周杰伦是台湾知名歌手',
          'bioContent': '<p>周杰伦是台湾知名歌手</p>',
          'bioLang': 'zh',
          'tags': ['流行', 'R&B'],
          'listeners': 1500000,
          'playcount': 50000000,
          'similarArtists': [
            {'name': '林俊杰', 'imageUrl': 'https://example.com/jj.jpg'},
          ],
          'source': 'lastFm',
          'cachedAt': '2026-09-01T00:00:00.000Z',
          'version': 1,
          'isManualOverride': false,
        };
        final metadata = ArtistMetadata.fromJson(json);
        expect(metadata.name, '周杰伦');
        expect(metadata.musicBrainzId, 'mbid-123');
        expect(metadata.imageUrl, 'https://example.com/avatar.jpg');
        expect(metadata.bioSummary, '周杰伦是台湾知名歌手');
        expect(metadata.bioLang, 'zh');
        expect(metadata.tags, ['流行', 'R&B']);
        expect(metadata.listeners, 1500000);
        expect(metadata.source, ArtistMetadataSource.lastFm);
        expect(metadata.similarArtists.length, 1);
        expect(metadata.similarArtists.first.name, '林俊杰');
        expect(metadata.isManualOverride, false);
      });

      test('空 JSON 使用默认值', () {
        final metadata = ArtistMetadata.fromJson(<String, dynamic>{
          'name': '未知歌手',
          'cachedAt': '2026-09-01T00:00:00.000Z',
        });
        expect(metadata.name, '未知歌手');
        expect(metadata.imageUrl, isNull);
        expect(metadata.bioSummary, isNull);
        expect(metadata.tags, isEmpty);
        expect(metadata.similarArtists, isEmpty);
        expect(metadata.source, ArtistMetadataSource.none);
        expect(metadata.version, 1);
        expect(metadata.isManualOverride, false);
      });

      test('无效 source 回退到 none', () {
        final json = {
          'name': '测试',
          'source': 'unknown_source',
          'cachedAt': '2026-09-01T00:00:00.000Z',
        };
        final metadata = ArtistMetadata.fromJson(json);
        expect(metadata.source, ArtistMetadataSource.none);
      });

      test('无效 cachedAt 回退到当前时间', () {
        final json = {
          'name': '测试',
          'cachedAt': 'invalid_date',
        };
        final metadata = ArtistMetadata.fromJson(json);
        expect(metadata.cachedAt, isA<DateTime>());
      });
    });

    group('toJson', () {
      test('正确序列化为 JSON', () {
        final metadata = ArtistMetadata(
          name: '周杰伦',
          imageUrl: 'https://example.com/avatar.jpg',
          bioSummary: '周杰伦是台湾知名歌手',
          bioLang: 'zh',
          tags: const ['流行'],
          listeners: 1500000,
          source: ArtistMetadataSource.lastFm,
          cachedAt: DateTime(2026, 9, 1),
          similarArtists: const [
            SimilarArtist(name: '林俊杰', imageUrl: 'https://example.com/jj.jpg'),
          ],
        );
        final json = metadata.toJson();
        expect(json['name'], '周杰伦');
        expect(json['imageUrl'], 'https://example.com/avatar.jpg');
        expect(json['bioSummary'], '周杰伦是台湾知名歌手');
        expect(json['source'], 'lastFm');
        expect(json['tags'], ['流行']);
        expect(json['similarArtists'], isA<List>());
        expect(json['isManualOverride'], false);
      });

      test('JSON 往返转换保持数据一致', () {
        final original = ArtistMetadata(
          name: '陈奕迅',
          imageUrl: 'https://example.com/chan.jpg',
          bioSummary: '香港歌手',
          bioLang: 'zh',
          tags: const ['粤语流行'],
          source: ArtistMetadataSource.deezer,
          cachedAt: DateTime(2026, 9, 1),
          isManualOverride: true,
        );
        final json = original.toJson();
        final restored = ArtistMetadata.fromJson(json);
        expect(restored.name, original.name);
        expect(restored.imageUrl, original.imageUrl);
        expect(restored.bioSummary, original.bioSummary);
        expect(restored.source, original.source);
        expect(restored.isManualOverride, original.isManualOverride);
      });
    });

    group('hasImage', () {
      test('有头像 URL 时返回 true', () {
        final metadata = ArtistMetadata(
          name: '测试',
          imageUrl: 'https://example.com/avatar.jpg',
          cachedAt: DateTime.now(),
        );
        expect(metadata.hasImage, true);
      });

      test('无头像 URL 时返回 false', () {
        final metadata = ArtistMetadata(
          name: '测试',
          cachedAt: DateTime.now(),
        );
        expect(metadata.hasImage, false);
      });

      test('空头像 URL 时返回 false', () {
        final metadata = ArtistMetadata(
          name: '测试',
          imageUrl: '',
          cachedAt: DateTime.now(),
        );
        expect(metadata.hasImage, false);
      });
    });

    group('hasBio', () {
      test('有简介时返回 true', () {
        final metadata = ArtistMetadata(
          name: '测试',
          bioSummary: '这是简介',
          cachedAt: DateTime.now(),
        );
        expect(metadata.hasBio, true);
      });

      test('无简介时返回 false', () {
        final metadata = ArtistMetadata(
          name: '测试',
          cachedAt: DateTime.now(),
        );
        expect(metadata.hasBio, false);
      });

      test('空简介时返回 false', () {
        final metadata = ArtistMetadata(
          name: '测试',
          bioSummary: '',
          cachedAt: DateTime.now(),
        );
        expect(metadata.hasBio, false);
      });
    });

    group('sourceDisplayName', () {
      test('正确显示各来源名称', () {
        expect(
          ArtistMetadata(
            name: '测试',
            source: ArtistMetadataSource.lastFm,
            cachedAt: DateTime.now(),
          ).sourceDisplayName,
          'Last.fm',
        );
        expect(
          ArtistMetadata(
            name: '测试',
            source: ArtistMetadataSource.deezer,
            cachedAt: DateTime.now(),
          ).sourceDisplayName,
          'Deezer',
        );
        expect(
          ArtistMetadata(
            name: '测试',
            source: ArtistMetadataSource.wikipedia,
            cachedAt: DateTime.now(),
          ).sourceDisplayName,
          'Wikipedia',
        );
        expect(
          ArtistMetadata(
            name: '测试',
            source: ArtistMetadataSource.manual,
            cachedAt: DateTime.now(),
          ).sourceDisplayName,
          '用户手动修正',
        );
        expect(
          ArtistMetadata(
            name: '测试',
            source: ArtistMetadataSource.none,
            cachedAt: DateTime.now(),
          ).sourceDisplayName,
          '无',
        );
      });
    });

    group('formattedListeners', () {
      test('格式化百万听众数', () {
        final metadata = ArtistMetadata(
          name: '测试',
          listeners: 1500000,
          cachedAt: DateTime.now(),
        );
        expect(metadata.formattedListeners, '1.5M');
      });

      test('格式化千听众数', () {
        final metadata = ArtistMetadata(
          name: '测试',
          listeners: 5000,
          cachedAt: DateTime.now(),
        );
        expect(metadata.formattedListeners, '5.0K');
      });

      test('无听众数返回空字符串', () {
        final metadata = ArtistMetadata(
          name: '测试',
          cachedAt: DateTime.now(),
        );
        expect(metadata.formattedListeners, '');
      });

      test('小于一千直接显示数字', () {
        final metadata = ArtistMetadata(
          name: '测试',
          listeners: 500,
          cachedAt: DateTime.now(),
        );
        expect(metadata.formattedListeners, '500');
      });
    });

    group('isExpired', () {
      test('新缓存未过期', () {
        final metadata = ArtistMetadata(
          name: '测试',
          cachedAt: DateTime.now(),
        );
        expect(metadata.isExpired(), false);
      });

      test('旧缓存已过期', () {
        final metadata = ArtistMetadata(
          name: '测试',
          cachedAt: DateTime.now().subtract(const Duration(days: 31)),
        );
        expect(metadata.isExpired(), true);
      });

      test('空数据 7 天过期', () {
        final metadata = ArtistMetadata(
          name: '测试',
          cachedAt: DateTime.now().subtract(const Duration(days: 8)),
        );
        expect(metadata.isEmpty, true);
        expect(metadata.isExpired(), true);
      });

      test('空数据 5 天未过期', () {
        final metadata = ArtistMetadata(
          name: '测试',
          cachedAt: DateTime.now().subtract(const Duration(days: 5)),
        );
        expect(metadata.isEmpty, true);
        expect(metadata.isExpired(), false);
      });
    });

    group('copyWith', () {
      test('正确复制并修改字段', () {
        final original = ArtistMetadata(
          name: '周杰伦',
          imageUrl: 'https://example.com/old.jpg',
          source: ArtistMetadataSource.lastFm,
          cachedAt: DateTime.now(),
        );
        final updated = original.copyWith(
          imageUrl: 'https://example.com/new.jpg',
          source: ArtistMetadataSource.manual,
        );
        expect(updated.name, '周杰伦');
        expect(updated.imageUrl, 'https://example.com/new.jpg');
        expect(updated.source, ArtistMetadataSource.manual);
      });
    });

    group('empty', () {
      test('创建空元数据', () {
        final metadata = ArtistMetadata.empty('未知歌手');
        expect(metadata.name, '未知歌手');
        expect(metadata.source, ArtistMetadataSource.none);
        expect(metadata.hasImage, false);
        expect(metadata.hasBio, false);
        expect(metadata.isEmpty, true);
      });
    });

    group('toJsonString / fromJsonString', () {
      test('JSON 字符串往返转换保持数据一致', () {
        final original = ArtistMetadata(
          name: '陈奕迅',
          imageUrl: 'https://example.com/chan.jpg',
          bioSummary: '香港歌手',
          source: ArtistMetadataSource.deezer,
          cachedAt: DateTime(2026, 9, 1),
        );
        final jsonString = original.toJsonString();
        final restored = ArtistMetadata.fromJsonString(jsonString);
        expect(restored.name, original.name);
        expect(restored.imageUrl, original.imageUrl);
        expect(restored.bioSummary, original.bioSummary);
        expect(restored.source, original.source);
      });
    });
  });

  group('SimilarArtist', () {
    test('fromJson / toJson 往返转换', () {
      const original = SimilarArtist(
        name: '林俊杰',
        imageUrl: 'https://example.com/jj.jpg',
      );
      final json = original.toJson();
      final restored = SimilarArtist.fromJson(json);
      expect(restored.name, original.name);
      expect(restored.imageUrl, original.imageUrl);
    });

    test('无头像时 imageUrl 为 null', () {
      const artist = SimilarArtist(name: '林俊杰');
      expect(artist.imageUrl, isNull);
    });
  });
}
