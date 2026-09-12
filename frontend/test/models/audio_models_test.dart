/// 音频模型单元测试

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/models/audio_models.dart';

void main() {
  group('AudioSongAudio', () {
    test('fromJson 正确解析', () {
      final json = {
        'bitrate': 320,
        'channel': 2,
        'codec': 'mp3',
        'container': 'mp3',
        'duration': 240,
        'filesize': 9600000,
        'frequency': 44100,
      };
      final audio = AudioSongAudio.fromJson(json);
      expect(audio.bitrate, 320);
      expect(audio.channel, 2);
      expect(audio.codec, 'mp3');
      expect(audio.duration, 240);
      expect(audio.filesize, 9600000);
      expect(audio.frequency, 44100);
    });

    test('空 JSON 使用默认值', () {
      final audio = AudioSongAudio.fromJson(<String, dynamic>{});
      expect(audio.bitrate, isNull);
      expect(audio.channel, isNull);
      expect(audio.codec, isNull);
      expect(audio.duration, isNull);
    });

    test('toJson 正确序列化', () {
      const audio = AudioSongAudio(
        bitrate: 320,
        channel: 2,
        duration: 240,
      );
      final json = audio.toJson();
      expect(json['bitrate'], 320);
      expect(json['channel'], 2);
      expect(json['duration'], 240);
      expect(json['codec'], isNull);
    });
  });

  group('AudioSongTag', () {
    test('fromJson 正确解析', () {
      final json = {
        'album': '叶惠美',
        'album_artist': '周杰伦',
        'artist': '周杰伦',
        'genre': '流行',
        'track': 3,
        'year': 2003,
      };
      final tag = AudioSongTag.fromJson(json);
      expect(tag.album, '叶惠美');
      expect(tag.albumArtist, '周杰伦');
      expect(tag.artist, '周杰伦');
      expect(tag.genre, '流行');
      expect(tag.track, 3);
      expect(tag.year, 2003);
    });

    test('空 JSON 使用默认值', () {
      final tag = AudioSongTag.fromJson(<String, dynamic>{});
      expect(tag.album, isNull);
      expect(tag.artist, isNull);
      expect(tag.year, isNull);
    });
  });

  group('AudioSong', () {
    test('fromJson 正确解析完整歌曲', () {
      final json = {
        'id': 'song_123',
        'title': '晴天',
        'type': 'song',
        'additional': {
          'song_audio': {
            'bitrate': 320,
            'duration': 269,
          },
          'song_tag': {
            'artist': '周杰伦',
            'album': '叶惠美',
            'year': 2003,
          },
        },
      };
      final song = AudioSong.fromJson(json);
      expect(song.id, 'song_123');
      expect(song.title, '晴天');
      expect(song.artistDisplay, '周杰伦');
      expect(song.albumDisplay, '叶惠美');
      expect(song.audio?.duration, 269);
    });

    test('空 JSON 使用默认值', () {
      final song = AudioSong.fromJson(<String, dynamic>{});
      expect(song.id, '');
      expect(song.title, '');
      expect(song.artistDisplay, '');
      expect(song.albumDisplay, '');
    });

    test('durationText 格式化时长', () {
      final song = AudioSong(
        id: '1',
        title: 'test',
        audio: const AudioSongAudio(duration: 269), // 4分29秒
      );
      expect(song.durationText, '4:29');
    });

    test('durationText 零秒', () {
      const song = AudioSong(id: '1', title: 'test');
      expect(song.durationText, '');
    });
  });

  group('AudioAlbum', () {
    test('fromJson 正确解析完整专辑', () {
      final json = {
        'name': '叶惠美',
        'album_artist': '周杰伦',
        'year': 2003,
        'additional': {
          'avg_rating': {'rating': 5},
        },
      };
      final album = AudioAlbum.fromJson(json);
      expect(album.name, '叶惠美');
      expect(album.artistDisplay, '周杰伦');
      expect(album.year, 2003);
      expect(album.rating, 5);
    });

    test('空 JSON 使用默认值', () {
      final album = AudioAlbum.fromJson(<String, dynamic>{});
      expect(album.name, '');
      expect(album.artistDisplay, '');
      expect(album.year, isNull);
    });

    test('copyWith 正确复制封面 URL', () {
      const album = AudioAlbum(name: '叶惠美');
      final updated = album.copyWith(coverUrl: 'https://example.com/cover.jpg');
      expect(updated.name, '叶惠美');
      expect(updated.coverUrl, 'https://example.com/cover.jpg');
    });
  });

  group('AudioArtist', () {
    test('fromJson 正确解析完整歌手', () {
      final json = {
        'name': '周杰伦',
        'additional': {
          'avg_rating': {'rating': 5},
        },
      };
      final artist = AudioArtist.fromJson(json);
      expect(artist.name, '周杰伦');
      expect(artist.rating, 5);
    });

    test('空 JSON 使用默认值', () {
      final artist = AudioArtist.fromJson(<String, dynamic>{});
      expect(artist.name, '');
      expect(artist.rating, isNull);
    });

    test('copyWith 正确复制封面 URL', () {
      const artist = AudioArtist(name: '周杰伦');
      final updated = artist.copyWith(coverUrl: 'https://example.com/avatar.jpg');
      expect(updated.name, '周杰伦');
      expect(updated.coverUrl, 'https://example.com/avatar.jpg');
    });
  });

  group('AudioPlaylist', () {
    test('fromJson 正确解析完整歌单', () {
      final json = {
        'id': 'playlist_123',
        'name': '我的收藏',
        'library': 'personal',
        'type': 'normal',
      };
      final playlist = AudioPlaylist.fromJson(json);
      expect(playlist.id, 'playlist_123');
      expect(playlist.name, '我的收藏');
      expect(playlist.library, 'personal');
      expect(playlist.type, 'normal');
    });

    test('空 JSON 使用默认值', () {
      final playlist = AudioPlaylist.fromJson(<String, dynamic>{});
      expect(playlist.id, '');
      expect(playlist.name, '');
      expect(playlist.library, isNull);
      expect(playlist.type, isNull);
    });
  });

  group('AudioGenre', () {
    test('fromJson 正确解析流派', () {
      final json = {
        'name': '流行',
        'song_count': 100,
      };
      final genre = AudioGenre.fromJson(json);
      expect(genre.name, '流行');
      expect(genre.songCount, 100);
    });

    test('空 JSON 使用默认值', () {
      final genre = AudioGenre.fromJson(<String, dynamic>{});
      expect(genre.name, '');
      expect(genre.songCount, 0);
    });
  });

  group('AudioPin', () {
    test('fromJson 正确解析锁定歌曲', () {
      final json = {
        'id': 'song_123',
        'title': '晴天',
        'artist': '周杰伦',
        'album': '叶惠美',
      };
      final pin = AudioPin.fromJson(json);
      expect(pin.id, 'song_123');
      expect(pin.title, '晴天');
      expect(pin.artist, '周杰伦');
      expect(pin.album, '叶惠美');
    });

    test('空 JSON 使用默认值', () {
      final pin = AudioPin.fromJson(<String, dynamic>{});
      expect(pin.id, '');
      expect(pin.title, '');
      expect(pin.artist, isNull);
      expect(pin.album, isNull);
    });
  });
}
