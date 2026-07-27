import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/models/media_item.dart';
import 'package:embytok_flutter/models/user_data.dart';

void main() {
  group('MediaItem', () {
    group('fromJson', () {
      // ===================== snake_case 格式 =====================
      group('snake_case 格式', () {
        test('正确解析完整 JSON', () {
          final json = {
            'id': 'item-1',
            'title': '测试电影',
            'type': 'Movie',
            'duration_seconds': 7200.0,
            'thumbnail_url': 'http://example.com/thumb.jpg',
            'overview': '这是一部测试电影',
            'year': 2023,
            'rating': 8.5,
            'genres': ['动作', '科幻'],
            'playback_url': 'http://example.com/video.mp4',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-1');
          expect(item.title, '测试电影');
          expect(item.type, 'Movie');
          expect(item.durationSeconds, 7200.0);
          expect(item.thumbnailUrl, 'http://example.com/thumb.jpg');
          expect(item.overview, '这是一部测试电影');
          expect(item.year, 2023);
          expect(item.rating, 8.5);
          expect(item.genres, ['动作', '科幻']);
          expect(item.playbackUrl, 'http://example.com/video.mp4');
        });

        test('处理可选字段为 null', () {
          final json = {
            'id': 'item-2',
            'title': '简单视频',
            'type': 'Episode',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-2');
          expect(item.title, '简单视频');
          expect(item.type, 'Episode');
          expect(item.durationSeconds, isNull);
          expect(item.thumbnailUrl, isNull);
          expect(item.overview, isNull);
          expect(item.year, isNull);
          expect(item.rating, isNull);
          expect(item.genres, isNull);
          expect(item.playbackUrl, isNull);
        });

        test('正确解析 genres 列表', () {
          final json = {
            'id': 'item-3',
            'title': '测试',
            'type': 'Movie',
            'genres': ['喜剧', '爱情', '动画'],
          };
          final item = MediaItem.fromJson(json);
          expect(item.genres, hasLength(3));
          expect(item.genres, containsAll(['喜剧', '爱情', '动画']));
        });

        test('正确解析剧集相关字段', () {
          final json = {
            'id': 'ep-1',
            'title': '第一集',
            'type': 'Episode',
            'series_name': '测试剧集',
            'series_id': 'series-1',
            'index_number': 5,
            'parent_index_number': 2,
          };
          final item = MediaItem.fromJson(json);
          expect(item.seriesName, '测试剧集');
          expect(item.seriesId, 'series-1');
          expect(item.indexNumber, 5);
          expect(item.parentIndexNumber, 2);
        });

        test('正确解析 user_data 嵌套对象', () {
          final json = {
            'id': 'item-ud',
            'title': '用户数据测试',
            'type': 'Movie',
            'user_data': {
              'playback_position_ticks': 36000000000,
              'play_count': 2,
              'is_favorite': true,
              'played': true,
              'last_played_date': '2024-01-15T10:30:00.0000000Z',
              'rating': 9.0,
            },
          };
          final item = MediaItem.fromJson(json);
          expect(item.userData, isNotNull);
          expect(item.userData!.playbackPositionTicks, 36000000000);
          expect(item.userData!.playCount, 2);
          expect(item.userData!.isFavorite, true);
          expect(item.userData!.played, true);
          expect(item.userData!.lastPlayedDate, '2024-01-15T10:30:00.0000000Z');
          expect(item.userData!.rating, 9.0);
          expect(item.isFavorite, true);
        });

        test('正确解析 image_tags 和 backdrop_image_tags', () {
          final json = {
            'id': 'item-img',
            'title': '图片测试',
            'type': 'Movie',
            'image_tags': {
              'Primary': 'primary_tag',
              'Thumb': 'thumb_tag',
              'Backdrop': 'backdrop_tag',
            },
            'backdrop_image_tags': ['backdrop1', 'backdrop2'],
          };
          final item = MediaItem.fromJson(json);
          expect(item.imageTags, isNotNull);
          expect(item.imageTags!['Primary'], 'primary_tag');
          expect(item.imageTags!['Thumb'], 'thumb_tag');
          expect(item.imageTags!['Backdrop'], 'backdrop_tag');
          expect(item.backdropImageTags, hasLength(2));
          expect(item.backdropImageTags, containsAll(['backdrop1', 'backdrop2']));
        });
      });

      // ===================== PascalCase 格式（Emby 原生格式） =====================
      group('PascalCase 格式（Emby 原生格式）', () {
        test('完整字段解析正确', () {
          final json = {
            'Id': 'item-pascal-1',
            'Name': '测试电影',
            'Type': 'Movie',
            'RunTimeTicks': 72000000000,
            'Overview': '这是一部测试电影',
            'ProductionYear': 2023,
            'CommunityRating': 8.5,
            'Genres': ['动作', '科幻'],
            'SeriesName': '测试剧集',
            'SeriesId': 'series-pascal-1',
            'SeasonName': '第一季',
            'ParentIndexNumber': 1,
            'IndexNumber': 5,
            'UserData': {
              'PlaybackPositionTicks': 36000000000,
              'PlayCount': 2,
              'IsFavorite': true,
              'Played': true,
              'LastPlayedDate': '2024-01-15T10:30:00.0000000Z',
              'UnplayedItemCount': 3,
              'Rating': 9.5,
            },
            'ImageTags': {
              'Primary': 'primary_tag',
              'Thumb': 'thumb_tag',
              'Backdrop': 'backdrop_tag',
            },
            'BackdropImageTags': ['backdrop1', 'backdrop2'],
            'Studios': [
              {'Name': '工作室A'},
              {'Name': '工作室B'},
            ],
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-pascal-1');
          expect(item.title, '测试电影');
          expect(item.type, 'Movie');
          expect(item.runtimeTicks, 72000000000);
          expect(item.durationSeconds, 7200.0);
          expect(item.overview, '这是一部测试电影');
          expect(item.productionYear, 2023);
          expect(item.year, 2023);
          expect(item.communityRating, 8.5);
          expect(item.rating, 8.5);
          expect(item.genres, ['动作', '科幻']);
          expect(item.genreNames, ['动作', '科幻']);
          expect(item.seriesName, '测试剧集');
          expect(item.seriesId, 'series-pascal-1');
          expect(item.parentIndexNumber, 1);
          expect(item.indexNumber, 5);
          expect(item.imageTags, isNotNull);
          expect(item.imageTags!['Primary'], 'primary_tag');
          expect(item.backdropImageTags, hasLength(2));
          expect(item.studioNames, hasLength(2));
          expect(item.studioNames, containsAll(['工作室A', '工作室B']));
          expect(item.userData, isNotNull);
          expect(item.userData!.playbackPositionTicks, 36000000000);
          expect(item.userData!.playCount, 2);
          expect(item.userData!.isFavorite, true);
          expect(item.userData!.played, true);
          expect(item.userData!.lastPlayedDate, '2024-01-15T10:30:00.0000000Z');
          expect(item.userData!.unplayedItemCount, 3);
          expect(item.userData!.rating, 9.5);
          expect(item.isFavorite, true);
        });

        test('剧集类型 Episode 解析正确', () {
          final json = {
            'Id': 'ep-pascal-1',
            'Name': '第五集',
            'Type': 'Episode',
            'SeriesName': '精彩剧集',
            'SeriesId': 'series-100',
            'ParentIndexNumber': 2,
            'IndexNumber': 5,
            'ProductionYear': 2024,
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'ep-pascal-1');
          expect(item.title, '第五集');
          expect(item.type, 'Episode');
          expect(item.seriesName, '精彩剧集');
          expect(item.seriesId, 'series-100');
          expect(item.parentIndexNumber, 2);
          expect(item.indexNumber, 5);
          expect(item.isEpisode, true);
          expect(item.isMovie, false);
        });

        test('UserData 嵌套对象解析正确', () {
          final json = {
            'Id': 'item-ud-pascal',
            'Name': '用户数据测试',
            'Type': 'Movie',
            'UserData': {
              'PlaybackPositionTicks': 18000000000,
              'PlayCount': 5,
              'IsFavorite': true,
              'Played': false,
              'LastPlayedDate': '2024-02-20T15:00:00.0000000Z',
              'UnplayedItemCount': 0,
              'Rating': 7.5,
            },
          };
          final item = MediaItem.fromJson(json);
          expect(item.userData, isNotNull);
          expect(item.userData!.playbackPositionTicks, 18000000000);
          expect(item.userData!.playCount, 5);
          expect(item.userData!.isFavorite, true);
          expect(item.userData!.played, false);
          expect(item.userData!.lastPlayedDate, '2024-02-20T15:00:00.0000000Z');
          expect(item.userData!.unplayedItemCount, 0);
          expect(item.userData!.rating, 7.5);
        });

        test('空 UserData 解析正确', () {
          final json = {
            'Id': 'item-no-ud',
            'Name': '无用户数据',
            'Type': 'Movie',
          };
          final item = MediaItem.fromJson(json);
          expect(item.userData, isNull);
          expect(item.isFavorite, false);
          expect(item.playCount, 0);
          expect(item.isWatched, false);
          expect(item.hasProgress, false);
        });
      });

      // ===================== 混合格式 =====================
      group('混合格式', () {
        test('PascalCase + snake_case 混合解析正确', () {
          final json = {
            'Id': 'item-mix-1',
            'title': '混合格式',
            'Type': 'Episode',
            'runtime_ticks': 36000000000,
            'overview': '混合格式测试',
            'SeriesName': '测试剧集',
            'index_number': 3,
            'CommunityRating': 8.0,
            'genres': ['剧情', '悬疑'],
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-mix-1');
          expect(item.title, '混合格式');
          expect(item.type, 'Episode');
          expect(item.runtimeTicks, 36000000000);
          expect(item.durationSeconds, 3600.0);
          expect(item.overview, '混合格式测试');
          expect(item.seriesName, '测试剧集');
          expect(item.indexNumber, 3);
          expect(item.communityRating, 8.0);
          expect(item.genres, containsAll(['剧情', '悬疑']));
        });

        test('PascalCase 优先级高于 snake_case', () {
          final json = {
            'Id': 'item-priority',
            'id': 'snake-id',
            'Name': 'Pascal标题',
            'title': 'snake标题',
            'Type': 'Movie',
            'type': 'Episode',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-priority');
          expect(item.title, 'Pascal标题');
          expect(item.type, 'Movie');
        });
      });

      // ===================== 类型不匹配降级 =====================
      group('类型不匹配降级', () {
        test('字符串类型的数字能优雅降级', () {
          final json = {
            'Id': 'item-type-1',
            'Name': '类型测试',
            'Type': 'Movie',
            'RunTimeTicks': '72000000000',
            'CommunityRating': '8.5',
            'ProductionYear': '2023',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-type-1');
          expect(item.title, '类型测试');
          expect(item.type, 'Movie');
        });

        test('genres 非列表时不崩溃', () {
          final json = {
            'Id': 'item-genres-type',
            'Name': '类型测试',
            'Type': 'Movie',
            'Genres': '不是列表',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-genres-type');
          expect(item.title, '类型测试');
        });

        test('UserData 非对象时不崩溃', () {
          final json = {
            'Id': 'item-ud-type',
            'Name': '类型测试',
            'Type': 'Movie',
            'UserData': '不是对象',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-ud-type');
          expect(item.userData, isNull);
        });

        test('ImageTags 非对象时不崩溃', () {
          final json = {
            'Id': 'item-img-type',
            'Name': '类型测试',
            'Type': 'Movie',
            'ImageTags': '不是对象',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, 'item-img-type');
          expect(item.imageTags, isNull);
        });
      });

      // ===================== 边界情况 =====================
      group('边界情况', () {
        test('处理空 JSON', () {
          final json = <String, dynamic>{};
          final item = MediaItem.fromJson(json);
          expect(item.id, '');
          expect(item.title, '');
          expect(item.type, 'Movie');
        });

        test('空字符串字段处理', () {
          final json = {
            'Id': '',
            'Name': '',
            'Type': '',
            'Overview': '',
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, '');
          expect(item.title, '');
          expect(item.type, '');
          expect(item.overview, '');
        });

        test('null JSON 值处理', () {
          final json = {
            'Id': null,
            'Name': null,
            'Type': null,
          };
          final item = MediaItem.fromJson(json);
          expect(item.id, '');
          expect(item.title, '');
          expect(item.type, 'Movie');
        });

        test('空列表 genres 处理', () {
          final json = {
            'Id': 'item-empty-genres',
            'Name': '空列表测试',
            'Type': 'Movie',
            'Genres': <dynamic>[],
          };
          final item = MediaItem.fromJson(json);
          expect(item.genres, isEmpty);
        });

        test('runtimeTicks 为 0 时 durationSec 为 0', () {
          final json = {
            'Id': 'item-zero-ticks',
            'Name': '零时长',
            'Type': 'Movie',
            'RunTimeTicks': 0,
          };
          final item = MediaItem.fromJson(json);
          expect(item.durationSec, 0.0);
          expect(item.formattedDuration, '');
        });
      });

      // ===================== 图片 URL 生成方法 =====================
      group('图片 URL 生成方法', () {
        test('imageUrl 正确构造 Emby 图片 URL', () {
          final json = {
            'Id': 'item-img-url',
            'Name': '图片测试',
            'Type': 'Movie',
            'ImageTags': {
              'Primary': 'abc123',
              'Backdrop': 'def456',
            },
          };
          final item = MediaItem.fromJson(json);
          final url = item.imageUrl(
            'Primary',
            embyServerUrl: 'http://emby.example.com',
            apiKey: 'test-key',
            maxWidth: 500,
          );
          expect(url, isNotNull);
          expect(url, contains('http://emby.example.com'));
          expect(url, contains('/Items/item-img-url/Images/Primary'));
          expect(url, contains('MaxWidth=500'));
          expect(url, contains('Tag=abc123'));
          expect(url, contains('api_key=test-key'));
        });

        test('primaryUrl 返回 Primary 类型图片 URL', () {
          final json = {
            'Id': 'item-primary',
            'Name': '海报测试',
            'Type': 'Movie',
            'ImageTags': {'Primary': 'poster-tag'},
          };
          final item = MediaItem.fromJson(json);
          final url = item.primaryUrl(
            embyServerUrl: 'http://emby.example.com',
            apiKey: 'key123',
          );
          expect(url, isNotNull);
          expect(url, contains('/Images/Primary'));
          expect(url, contains('MaxWidth=500'));
        });

        test('backdropUrl 返回 Backdrop 类型图片 URL', () {
          final json = {
            'Id': 'item-backdrop',
            'Name': '背景图测试',
            'Type': 'Movie',
            'ImageTags': {'Backdrop': 'bd-tag'},
          };
          final item = MediaItem.fromJson(json);
          final url = item.backdropUrl(
            embyServerUrl: 'http://emby.example.com',
          );
          expect(url, isNotNull);
          expect(url, contains('/Images/Backdrop'));
          expect(url, contains('MaxWidth=1280'));
        });

        test('没有对应 imageTag 时返回 null', () {
          final json = {
            'Id': 'item-no-tag',
            'Name': '无图片测试',
            'Type': 'Movie',
            'ImageTags': {'Thumb': 'thumb-tag'},
          };
          final item = MediaItem.fromJson(json);
          final url = item.primaryUrl(
            embyServerUrl: 'http://emby.example.com',
          );
          expect(url, isNull);
        });

        test('没有 embyServerUrl 时 fallback 到 thumbnailUrl', () {
          final json = {
            'Id': 'item-thumb',
            'Name': '缩略图测试',
            'Type': 'Movie',
            'thumbnail_url': 'http://cdn.example.com/thumb.jpg',
          };
          final item = MediaItem.fromJson(json);
          final url = item.imageUrl('Primary');
          expect(url, 'http://cdn.example.com/thumb.jpg');
        });

        test('thumbnailUrlWithAuth 优先使用 Emby URL', () {
          final json = {
            'Id': 'item-auth-img',
            'Name': '认证图片测试',
            'Type': 'Movie',
            'ImageTags': {'Primary': 'auth-tag'},
            'thumbnail_url': 'http://cdn.example.com/fallback.jpg',
          };
          final item = MediaItem.fromJson(json);
          final url = item.thumbnailUrlWithAuth(
            'http://emby.example.com',
            'api-key-123',
          );
          expect(url, isNotNull);
          expect(url, contains('emby.example.com'));
          expect(url, contains('api_key=api-key-123'));
        });

        test('没有 Emby URL 时 thumbnailUrlWithAuth fallback 到 thumbnailUrl', () {
          final json = {
            'Id': 'item-fallback',
            'Name': 'Fallback测试',
            'Type': 'Movie',
            'thumbnail_url': 'http://cdn.example.com/fallback.jpg',
          };
          final item = MediaItem.fromJson(json);
          final url = item.thumbnailUrlWithAuth(null, null);
          expect(url, 'http://cdn.example.com/fallback.jpg');
        });
      });
    });

    group('toJson', () {
      test('正确序列化为 JSON', () {
        final item = MediaItem(
          id: 'item-1',
          title: '测试',
          type: 'Movie',
          durationSeconds: 3600.0,
          year: 2024,
        );
        final json = item.toJson();
        expect(json['id'], 'item-1');
        expect(json['title'], '测试');
        expect(json['type'], 'Movie');
        expect(json['duration_seconds'], 3600.0);
        expect(json['year'], 2024);
        expect(json['thumbnail_url'], isNull);
      });
    });
  });
}
