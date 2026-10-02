// 本地视频项：表示手机本地视频（系统媒体库资产或 App 专属目录文件）
// 对应 PRD《本地模式》§5.3 数据模型
class LocalVideoItem {
  /// photo_manager assetId 或路径哈希（唯一标识）
  final String id;

  /// 文件名（去扩展名）
  final String name;

  /// 绝对路径或 content:// URI
  final String path;

  /// 文件夹分组（MediaStore RELATIVE_PATH）
  final String? relativePath;

  /// 文件大小（字节）
  final int sizeBytes;

  /// 时长
  final Duration duration;

  /// 分辨率宽
  final int width;

  /// 分辨率高
  final int height;

  /// MIME 类型（video/mp4、video/x-matroska 等）
  final String mimeType;

  /// 修改时间
  final DateTime modifiedAt;

  /// 是否 App 专属目录文件（true=可重命名/直接 File.delete；false=系统媒体库资产，删除走 photo_manager）
  final bool isAppDirFile;

  /// photo_manager assetId（系统媒体库资产删除用；App 目录文件为 null）
  final String? assetId;

  /// 同目录下同名字幕文件绝对路径列表（.srt/.ass/.vtt）
  final List<String> subtitlePaths;

  /// 所属文件源 ID（P1）：'local_default' 为手机本地，其余为 WebDAV/SMB 源
  final String sourceId;

  /// 网络播放 URL（P1）：WebDAV/SMB 源的可直接播放地址；本地为 null
  final String? networkUrl;

  /// 网络请求头（P2）：WebDAV Basic Auth 等，播放器加载 networkUrl 时使用
  final Map<String, String> networkHeaders;

  /// 媒体类型（来自文件源配置）：movie/tv/short，null=自动
  final String? mediaType;

  const LocalVideoItem({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.duration,
    required this.width,
    required this.height,
    required this.mimeType,
    required this.modifiedAt,
    required this.isAppDirFile,
    this.relativePath,
    this.assetId,
    this.subtitlePaths = const [],
    this.sourceId = 'local_default',
    this.networkUrl,
    this.networkHeaders = const {},
    this.mediaType,
  });

  /// 复制并覆盖字段（用于扫描时回填 sourceId / mediaType）
  LocalVideoItem copyWith({String? sourceId, String? mediaType}) => LocalVideoItem(
        id: id,
        name: name,
        path: path,
        sizeBytes: sizeBytes,
        duration: duration,
        width: width,
        height: height,
        mimeType: mimeType,
        modifiedAt: modifiedAt,
        isAppDirFile: isAppDirFile,
        relativePath: relativePath,
        assetId: assetId,
        subtitlePaths: subtitlePaths,
        sourceId: sourceId ?? this.sourceId,
        networkUrl: networkUrl,
        networkHeaders: networkHeaders,
        mediaType: mediaType ?? this.mediaType,
      );

  /// 路径哈希 key（用于续播 SharedPreferences key）
  String get pathHash => id;

  /// 分辨率角标文本，如 "1920×1080"
  String get resolutionLabel => '${width}×$height';

  /// 时长角标文本，如 "12:34"
  String get durationLabel {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 文件大小人类可读
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'relativePath': relativePath,
        'sizeBytes': sizeBytes,
        'durationMs': duration.inMilliseconds,
        'width': width,
        'height': height,
        'mimeType': mimeType,
        'modifiedAt': modifiedAt.millisecondsSinceEpoch,
        'isAppDirFile': isAppDirFile,
        'assetId': assetId,
        'subtitlePaths': subtitlePaths,
        'sourceId': sourceId,
        'networkUrl': networkUrl,
        'networkHeaders': networkHeaders,
      };

  factory LocalVideoItem.fromJson(Map<String, dynamic> json) => LocalVideoItem(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        relativePath: json['relativePath'] as String?,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        width: json['width'] as int? ?? 0,
        height: json['height'] as int? ?? 0,
        mimeType: json['mimeType'] as String? ?? 'video/*',
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
            json['modifiedAt'] as int? ?? 0),
        isAppDirFile: json['isAppDirFile'] as bool? ?? false,
        assetId: json['assetId'] as String?,
        subtitlePaths: (json['subtitlePaths'] as List?)?.cast<String>() ?? const [],
        sourceId: json['sourceId'] as String? ?? 'local_default',
        networkUrl: json['networkUrl'] as String?,
        networkHeaders: (json['networkHeaders'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)) ?? const {},
      );
}
