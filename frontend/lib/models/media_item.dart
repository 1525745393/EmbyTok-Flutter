// 媒体项模型：对应后端 MediaItem，用于电影、剧集、音乐视频等

class MediaItem {
  final String id;
  final String title;
  final String type;
  final double? durationSeconds;
  final String? thumbnailUrl;
  final String? overview;
  final int? year;
  final double? rating;
  final List<String>? genres;
  final String? playbackUrl;

  MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.durationSeconds,
    this.thumbnailUrl,
    this.overview,
    this.year,
    this.rating,
    this.genres,
    this.playbackUrl,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final genresDynamic = json['genres'] as List<dynamic>?;
    return MediaItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      thumbnailUrl: json['thumbnail_url'] as String?,
      overview: json['overview'] as String?,
      year: json['year'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      genres: genresDynamic?.map((e) => e.toString()).toList(),
      playbackUrl: json['playback_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'duration_seconds': durationSeconds,
        'thumbnail_url': thumbnailUrl,
        'overview': overview,
        'year': year,
        'rating': rating,
        'genres': genres,
        'playback_url': playbackUrl,
      };
}
