/// 文件源模型（P0 第二批）
///
/// 参考 VidHub 文件源：本地 / SMB / WebDAV 多源管理。
class FileSource {
  final String id; // UUID
  final FileSourceType type;
  final String name; // 用户自定义名称
  final Map<String, String> config; // 类型相关配置
  final FileSourceStatus status;
  final int videoCount;
  final DateTime? lastScanAt;

  /// 是否启用（P0 增强）：禁用后媒体库隐藏该源影片，不删除数据
  final bool enabled;

  const FileSource({
    required this.id,
    required this.type,
    required this.name,
    this.config = const {},
    this.status = FileSourceStatus.idle,
    this.videoCount = 0,
    this.lastScanAt,
    this.enabled = true,
  });

  FileSource copyWith({
    String? name,
    Map<String, String>? config,
    FileSourceStatus? status,
    int? videoCount,
    DateTime? lastScanAt,
    bool? enabled,
  }) =>
      FileSource(
        id: id,
        type: type,
        name: name ?? this.name,
        config: config ?? this.config,
        status: status ?? this.status,
        videoCount: videoCount ?? this.videoCount,
        lastScanAt: lastScanAt ?? this.lastScanAt,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'config': config,
        'status': status.name,
        'videoCount': videoCount,
        'lastScanAt': lastScanAt?.toIso8601String(),
        'enabled': enabled,
      };

  factory FileSource.fromJson(Map<String, dynamic> json) => FileSource(
        id: json['id'] as String,
        type: FileSourceType.values.byName(json['type'] as String),
        name: json['name'] as String,
        config: Map<String, String>.from(json['config'] as Map),
        status: FileSourceStatus.values.byName(json['status'] as String),
        videoCount: json['videoCount'] as int? ?? 0,
        lastScanAt: json['lastScanAt'] == null
            ? null
            : DateTime.parse(json['lastScanAt'] as String),
        enabled: json['enabled'] as bool? ?? true,
      );
}

enum FileSourceType {
  local, // 手机媒体库（默认，不可删）
  smb, // 网络共享
  webdav, // WebDAV 网盘
}

enum FileSourceStatus {
  idle, // 空闲
  scanning, // 扫描中
  connected, // 已连接
  failed, // 失败
}
