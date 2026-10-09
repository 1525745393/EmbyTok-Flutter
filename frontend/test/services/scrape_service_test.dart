import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/services/scrape_service.dart';

void main() {
  group('parseFilename 电影年份解析', () {
    test('括号包裹年份: The Dark Knight (2008)', () {
      final p = ScrapeService.parseFilename('The Dark Knight (2008).mp4');
      expect(p.type, 'movie');
      expect(p.year, 2008);
      expect(p.title, 'The Dark Knight');
    });

    test('中文括号年份: 霸王别姬 (1993).mp4', () {
      final p = ScrapeService.parseFilename('霸王别姬 (1993).mp4');
      expect(p.type, 'movie');
      expect(p.year, 1993);
      expect(p.title, '霸王别姬');
    });

    test('点分隔年份: The.Dark.Knight.(2008).mp4', () {
      final p = ScrapeService.parseFilename('The.Dark.Knight.(2008).mp4');
      expect(p.year, 2008);
      expect(p.title, contains('The Dark Knight'));
    });

    test('空格年份: Inception 2010.mp4', () {
      final p = ScrapeService.parseFilename('Inception 2010.mp4');
      expect(p.type, 'movie');
      expect(p.year, 2010);
      expect(p.title, 'Inception');
    });

    test('带分辨率噪声: Movie (1999) 1080p BluRay.mp4', () {
      final p = ScrapeService.parseFilename('Movie (1999) 1080p BluRay.mp4');
      expect(p.year, 1999);
      expect(p.title, 'Movie');
    });

    test('无年份: Some Movie.mp4', () {
      final p = ScrapeService.parseFilename('Some Movie.mp4');
      expect(p.type, 'movie');
      expect(p.year, isNull);
      expect(p.title, 'Some Movie');
    });
  });

  group('parseFilename 剧集解析', () {
    test('S01E01 标准格式', () {
      final p = ScrapeService.parseFilename('Breaking Bad (2008) S01E01.mp4');
      expect(p.type, 'tv');
      expect(p.season, 1);
      expect(p.episode, 1);
      expect(p.title, contains('Breaking Bad'));
    });

    test('1x01 格式', () {
      final p = ScrapeService.parseFilename('Show Name 1x05.mp4');
      expect(p.type, 'tv');
      expect(p.season, 1);
      expect(p.episode, 5);
    });

    test('中文季集: 剧 第1季第3集.mp4', () {
      final p = ScrapeService.parseFilename('剧 第1季第3集.mp4');
      expect(p.type, 'tv');
      expect(p.season, 1);
      expect(p.episode, 3);
    });

    test('纯数字文件: 01.mp4, 父目录为剧名', () {
      final p = ScrapeService.parseFilename('01.mp4', parentDir: 'My Show');
      expect(p.type, 'tv');
      expect(p.episode, 1);
      expect(p.season, 1);
      expect(p.title, 'My Show');
    });
  });
}
