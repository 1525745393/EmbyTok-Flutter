// 群晖 Audio Station 数据模型
//
// 对应 SYNO.AudioStation.* API 的返回结构：
// - Song（歌曲）：SYNO.AudioStation.Song list
// - Album（专辑）：SYNO.AudioStation.Album list
// - Artist（歌手）：SYNO.AudioStation.Artist list
// - Playlist（歌单）：SYNO.AudioStation.Playlist list / getinfo
//
// 字段命名与 Audio Station 返回 JSON 保持一致（snake_case → camelCase），
// 便于后续扩展 additional 字段。

/// 歌曲音频信息（additional.song_audio）
class AudioSongAudio {

  const AudioSongAudio({
    this.bitrate,
    this.channel,
    this.codec,
    this.container,
    this.duration,
    this.filesize,
    this.frequency,
  });

  factory AudioSongAudio.fromJson(Map<String, dynamic> json) {
    return AudioSongAudio(
      bitrate: json['bitrate'] as int?,
      channel: json['channel'] as int?,
      codec: json['codec'] as String?,
      container: json['container'] as String?,
      duration: json['duration'] as int?,
      filesize: json['filesize'] as int?,
      frequency: json['frequency'] as int?,
    );
  }
  final int? bitrate;
  final int? channel;
  final String? codec;
  final String? container;
  final int? duration; // 秒
  final int? filesize;
  final int? frequency;

  Map<String, dynamic> toJson() => {
        if (bitrate != null) 'bitrate': bitrate,
        if (channel != null) 'channel': channel,
        if (codec != null) 'codec': codec,
        if (container != null) 'container': container,
        if (duration != null) 'duration': duration,
        if (filesize != null) 'filesize': filesize,
        if (frequency != null) 'frequency': frequency,
      };
}

/// 歌曲标签信息（additional.song_tag）
class AudioSongTag {

  const AudioSongTag({
    this.album,
    this.albumArtist,
    this.artist,
    this.comment,
    this.composer,
    this.disc,
    this.genre,
    this.track,
    this.year,
  });

  factory AudioSongTag.fromJson(Map<String, dynamic> json) {
    return AudioSongTag(
      album: json['album'] as String?,
      albumArtist: json['album_artist'] as String?,
      artist: json['artist'] as String?,
      comment: json['comment'] as String?,
      composer: json['composer'] as String?,
      disc: json['disc'] as int?,
      genre: json['genre'] as String?,
      track: json['track'] as int?,
      year: json['year'] as int?,
    );
  }
  final String? album;
  final String? albumArtist;
  final String? artist;
  final String? comment;
  final String? composer;
  final int? disc;
  final String? genre;
  final int? track;
  final int? year;

  Map<String, dynamic> toJson() => {
        if (album != null) 'album': album,
        if (albumArtist != null) 'album_artist': albumArtist,
        if (artist != null) 'artist': artist,
        if (comment != null) 'comment': comment,
        if (composer != null) 'composer': composer,
        if (disc != null) 'disc': disc,
        if (genre != null) 'genre': genre,
        if (track != null) 'track': track,
        if (year != null) 'year': year,
      };
}

/// 歌曲
class AudioSong {

  const AudioSong({
    required this.id,
    required this.title,
    this.path,
    this.type,
    this.audio,
    this.tag,
    this.rating,
  });

  factory AudioSong.fromJson(Map<String, dynamic> json) {
    final additional = json['additional'] as Map<String, dynamic>?;
    final audioJson = additional?['song_audio'] as Map<String, dynamic>?;
    final tagJson = additional?['song_tag'] as Map<String, dynamic>?;
    final ratingJson = additional?['song_rating'] as Map<String, dynamic>?;
    return AudioSong(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      path: json['path'] as String?,
      type: json['type'] as String?,
      audio: audioJson != null ? AudioSongAudio.fromJson(audioJson) : null,
      tag: tagJson != null ? AudioSongTag.fromJson(tagJson) : null,
      rating: ratingJson?['rating'] as int?,
    );
  }
  final String id; // music_xxx 或 music_v_xxx（整轨音轨）
  final String title;
  final String? path;
  final String? type; // file / folder
  final AudioSongAudio? audio;
  final AudioSongTag? tag;
  final int? rating;

  /// 是否为整轨文件的某个音轨（此类歌曲需强制转码播放）
  bool get isCueTrack => id.contains('_v_');

  /// 展示用时长文本（m:ss）
  String get durationText {
    final d = audio?.duration;
    if (d == null || d <= 0) return '';
    final m = d ~/ 60;
    final s = d % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 展示用歌手（优先 tag.artist，回退 albumArtist）
  String get artistDisplay => tag?.artist?.trim().isNotEmpty == true
      ? tag!.artist!
      : (tag?.albumArtist ?? '');

  /// 展示用专辑
  String get albumDisplay => tag?.album ?? '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (path != null) 'path': path,
        if (type != null) 'type': type,
        'additional': {
          if (audio != null) 'song_audio': audio!.toJson(),
          if (tag != null) 'song_tag': tag!.toJson(),
          if (rating != null) 'song_rating': {'rating': rating},
        },
      };
}

/// 专辑
class AudioAlbum {

  const AudioAlbum({
    required this.name,
    this.albumArtist,
    this.artist,
    this.displayArtist,
    this.year,
    this.rating,
    this.coverUrl,
  });

  factory AudioAlbum.fromJson(Map<String, dynamic> json) {
    final additional = json['additional'] as Map<String, dynamic>?;
    final ratingJson = additional?['avg_rating'] as Map<String, dynamic>?;
    return AudioAlbum(
      name: json['name'] as String? ?? '',
      albumArtist: json['album_artist'] as String?,
      artist: json['artist'] as String?,
      displayArtist: json['display_artist'] as String?,
      year: json['year'] as int?,
      rating: ratingJson?['rating'] as int?,
    );
  }
  final String name;
  final String? albumArtist;
  final String? artist;
  final String? displayArtist;
  final int? year;
  final int? rating;

  /// 预计算的封面 URL（由 API 层在获取数据后填充，避免 UI 层重复计算）
  final String? coverUrl;

  /// 展示用歌手
  String get artistDisplay =>
      displayArtist?.trim().isNotEmpty == true ? displayArtist! : (albumArtist ?? '');

  /// 返回带 coverUrl 的新实例（不可变模型的 copyWith 模式）
  AudioAlbum copyWith({String? coverUrl}) {
    return AudioAlbum(
      name: name,
      albumArtist: albumArtist,
      artist: artist,
      displayArtist: displayArtist,
      year: year,
      rating: rating,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}

/// 歌手
class AudioArtist {

  const AudioArtist({required this.name, this.rating, this.coverUrl});

  factory AudioArtist.fromJson(Map<String, dynamic> json) {
    final additional = json['additional'] as Map<String, dynamic>?;
    final ratingJson = additional?['avg_rating'] as Map<String, dynamic>?;
    return AudioArtist(
      name: json['name'] as String? ?? '',
      rating: ratingJson?['rating'] as int?,
    );
  }
  final String name;
  final int? rating;

  /// 预计算的封面 URL（由 API 层在获取数据后填充，避免 UI 层重复计算）
  final String? coverUrl;

  /// 返回带 coverUrl 的新实例（不可变模型的 copyWith 模式）
  AudioArtist copyWith({String? coverUrl}) {
    return AudioArtist(
      name: name,
      rating: rating,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}

/// 歌单
class AudioPlaylist {

  const AudioPlaylist({
    required this.id,
    required this.name,
    this.library,
    this.type,
    this.path,
  });

  factory AudioPlaylist.fromJson(Map<String, dynamic> json) {
    return AudioPlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      library: json['library'] as String?,
      type: json['type'] as String?,
      path: json['path'] as String?,
    );
  }
  final String id; // playlist_personal_normal/xxx
  final String name;
  final String? library; // all / personal
  final String? type; // normal / smart
  final String? path;
}

/// 音乐流派（NAS 自动聚合的音乐标签分类）
class AudioGenre {

  const AudioGenre({required this.name, this.songCount = 0});

  factory AudioGenre.fromJson(Map<String, dynamic> json) {
    return AudioGenre(
      name: json['name'] as String? ?? '',
      songCount: (json['song_count'] as num?)?.toInt() ?? 0,
    );
  }
  final String name;
  final int songCount;
}

/// 用户锁定的歌曲（My Pins / 收藏）
///
/// Pin 接口返回简化信息（id/title/artist/album），
/// 播放时需从全量歌曲列表按 ID 匹配完整 AudioSong
class AudioPin {

  const AudioPin({
    required this.id,
    required this.title,
    this.artist,
    this.album,
  });

  factory AudioPin.fromJson(Map<String, dynamic> json) {
    return AudioPin(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      album: json['album'] as String?,
    );
  }
  final String id;
  final String title;
  final String? artist;
  final String? album;
}

/// 文件夹浏览条目类型
enum AudioFolderItemType { folder, song }

/// 文件夹浏览条目（子文件夹或歌曲）
///
/// Folder API 返回 folders + songs 的混合列表，统一为此模型
class AudioFolderItem { // type=song 时的完整歌曲信息

  const AudioFolderItem({
    required this.type,
    required this.name,
    this.path = '',
    this.song,
  });
  final AudioFolderItemType type;
  final String name;
  final String path;
  final AudioSong? song;
}

/// 搜索结果（歌曲 + 专辑 + 歌手）
class AudioSearchResult {

  const AudioSearchResult({
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
  });
  final List<AudioSong> songs;
  final List<AudioAlbum> albums;
  final List<AudioArtist> artists;
}
