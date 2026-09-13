/// Deezer 服务测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/services/deezer_service.dart';

void main() {
  group('DeezerArtistInfo', () {
    group('fromJson', () {
      test('正确解析完整 JSON', () {
        final json = {
          'id': '12345',
          'name': 'Taylor Swift',
          'picture_small': 'https://api.deezer.com/artist/123/56.jpg',
          'picture_medium': 'https://api.deezer.com/artist/123/250.jpg',
          'picture_big': 'https://api.deezer.com/artist/123/500.jpg',
          'picture_xl': 'https://api.deezer.com/artist/123/1000.jpg',
          'nb_album': 20,
          'nb_fan': 50000000,
          'description': 'Taylor Swift is an American singer-songwriter.',
        };
        final info = DeezerArtistInfo.fromJson(json);
        expect(info.name, 'Taylor Swift');
        expect(info.pictureSmall, 'https://api.deezer.com/artist/123/56.jpg');
        expect(info.pictureMedium, 'https://api.deezer.com/artist/123/250.jpg');
        expect(info.pictureBig, 'https://api.deezer.com/artist/123/500.jpg');
        expect(info.pictureXl, 'https://api.deezer.com/artist/123/1000.jpg');
        expect(info.nbAlbum, 20);
        expect(info.nbFan, 50000000);
        expect(info.description, 'Taylor Swift is an American singer-songwriter.');
      });

      test('空 JSON 使用默认值', () {
        final info = DeezerArtistInfo.fromJson(<String, dynamic>{});
        expect(info.name, '');
        expect(info.pictureSmall, isNull);
        expect(info.pictureMedium, isNull);
        expect(info.pictureBig, isNull);
        expect(info.pictureXl, isNull);
        expect(info.nbAlbum, isNull);
        expect(info.nbFan, isNull);
        expect(info.description, isNull);
      });

      test('缺失 name 字段时使用空字符串', () {
        final info = DeezerArtistInfo.fromJson(<String, dynamic>{
          'nb_fan': 1000,
        });
        expect(info.name, '');
        expect(info.nbFan, 1000);
      });
    });

    group('bestImageUrl', () {
      test('优先使用 XL 尺寸头像', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          pictureSmall: 'small.jpg',
          pictureMedium: 'medium.jpg',
          pictureBig: 'big.jpg',
          pictureXl: 'xl.jpg',
        );
        expect(info.bestImageUrl, 'xl.jpg');
      });

      test('无 XL 时使用 Big 尺寸', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          pictureSmall: 'small.jpg',
          pictureMedium: 'medium.jpg',
          pictureBig: 'big.jpg',
        );
        expect(info.bestImageUrl, 'big.jpg');
      });

      test('无 XL/Big 时使用 Medium 尺寸', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          pictureSmall: 'small.jpg',
          pictureMedium: 'medium.jpg',
        );
        expect(info.bestImageUrl, 'medium.jpg');
      });

      test('仅 Small 尺寸时使用 Small', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          pictureSmall: 'small.jpg',
        );
        expect(info.bestImageUrl, 'small.jpg');
      });

      test('无头像时返回 null', () {
        const info = DeezerArtistInfo(name: 'Test');
        expect(info.bestImageUrl, isNull);
      });
    });

    group('hasImage', () {
      test('有头像时返回 true', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          pictureXl: 'xl.jpg',
        );
        expect(info.hasImage, true);
      });

      test('无头像时返回 false', () {
        const info = DeezerArtistInfo(name: 'Test');
        expect(info.hasImage, false);
      });

      test('空头像 URL 时返回 false', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          pictureXl: '',
        );
        expect(info.hasImage, false);
      });
    });

    group('hasBio', () {
      test('有简介时返回 true', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          description: 'This is a description.',
        );
        expect(info.hasBio, true);
      });

      test('无简介时返回 false', () {
        const info = DeezerArtistInfo(name: 'Test');
        expect(info.hasBio, false);
      });

      test('空简介时返回 false', () {
        const info = DeezerArtistInfo(
          name: 'Test',
          description: '',
        );
        expect(info.hasBio, false);
      });
    });
  });
}
