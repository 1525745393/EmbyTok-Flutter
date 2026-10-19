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

  group('applyEpisodeInfo 单集条目复用系列元数据', () {
    ScrapedMedia base() => const ScrapedMedia(
          tmdbId: 123,
          type: 'tv',
          title: '测试剧',
          year: 2020,
          posterPath: '/p.jpg',
          backdropPath: '/b.jpg',
          overview: '整剧简介',
          rating: 8.5,
          genres: ['剧情'],
          cast: [
            {'name': '张三', 'role': '主角', 'id': '1', 'profilePath': '/a.jpg'},
          ],
          tvId: 456,
          scrapedAt: 1,
        );

    test('保留整剧元数据并替换季集号', () {
      final ep = ScrapeService.applyEpisodeInfo(base(), 2, 5);
      expect(ep.type, 'tv');
      expect(ep.season, 2);
      expect(ep.episode, 5);
      expect(ep.title, '测试剧');
      expect(ep.year, 2020);
      expect(ep.overview, '整剧简介');
      expect(ep.posterPath, '/p.jpg');
      expect(ep.backdropPath, '/b.jpg');
      expect(ep.cast.length, 1);
      expect(ep.cast.first['name'], '张三');
      expect(ep.tvId, 456);
      expect(ep.tmdbId, 123);
    });

    test('单集条目不携带上一集的剧照/集名（防止串集）', () {
      final src = ScrapedMedia(
        tmdbId: 1,
        type: 'tv',
        title: '剧',
        stillPath: '/s1.jpg',
        episodeTitle: '第一集',
        season: 1,
        episode: 1,
        scrapedAt: 1,
      );
      final ep = ScrapeService.applyEpisodeInfo(src, 1, 2);
      expect(ep.episode, 2);
      expect(ep.season, 1);
      expect(ep.stillPath, isNull);
      expect(ep.episodeTitle, isNull);
    });
  });
}
