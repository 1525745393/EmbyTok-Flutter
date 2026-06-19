/// UserData 模型测试
///
/// 重点验证：
/// - Emby PascalCase / 简化字段解析
/// - toJson 序列化

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/user_data.dart';

void main() {
  group('UserData', () {
    group('fromJson', () {
      test('正确解析 Emby PascalCase 字段', () {
        final json = {
          'PlaybackPositionTicks': 36000000000,
          'IsFavorite': true,
          'Played': true,
          'UnplayedItemCount': 0,
          'LastPlayedDate': '2024-01-15T10:30:00Z',
        };
        final data = UserData.fromJson(json);
        expect(data.playbackPositionTicks, 36000000000.0);
        expect(data.isFavorite, true);
        expect(data.played, true);
        expect(data.unplayedItemCount, 0);
        expect(data.lastPlayedDate, '2024-01-15T10:30:00Z');
      });

      test('正确解析简化 snake_case 字段', () {
        final json = {
          'playback_position_ticks': 72000000000,
          'is_favorite': false,
          'played': false,
          'unplayed_item_count': 5,
          'last_played_date': '2024-06-20',
        };
        final data = UserData.fromJson(json);
        expect(data.playbackPositionTicks, 72000000000.0);
        expect(data.isFavorite, false);
        expect(data.played, false);
        expect(data.unplayedItemCount, 5);
        expect(data.lastPlayedDate, '2024-06-20');
      });

      test('空 JSON 使用默认值', () {
        final data = UserData.fromJson(<String, dynamic>{});
        expect(data.playbackPositionTicks, 0.0);
        expect(data.isFavorite, false);
        expect(data.played, false);
        expect(data.unplayedItemCount, 0);
        expect(data.lastPlayedDate, isNull);
      });
    });

    group('toJson', () {
      test('toJson 正确序列化为简化字段', () {
        const data = UserData(
          playbackPositionTicks: 18000000000,
          isFavorite: true,
          played: true,
          unplayedItemCount: 3,
          lastPlayedDate: '2024-01-10',
        );
        final json = data.toJson();
        expect(json['playback_position_ticks'], 18000000000.0);
        expect(json['is_favorite'], true);
        expect(json['played'], true);
        expect(json['unplayed_item_count'], 3);
        expect(json['last_played_date'], '2024-01-10');
      });
    });
  });
}
