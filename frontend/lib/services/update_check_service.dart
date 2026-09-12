// 应用更新检查服务
//
// 通过 GitHub Releases API 检查最新版本，对比当前版本号判断是否需要更新。
// 版本号格式：x.y.z+buildNumber（如 1.133.0+11330）
// 对比逻辑：仅比较 x.y.z 三段主版本号，忽略 buildNumber

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// GitHub Release 信息
class ReleaseInfo {
  final String tagName; // 如 "v1.133.0"
  final String name; // release 标题
  final String body; // release notes（Markdown）
  final String htmlUrl; // release 页面链接
  final DateTime publishedAt;
  final List<ReleaseAsset> assets; // 附件（APK 等）

  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  /// 解析版本号：去掉 "v" 前缀，取 "x.y.z" 部分（忽略 +buildNumber）
  String get version {
    var v = tagName;
    if (v.startsWith('v')) v = v.substring(1);
    // 去掉 +buildNumber
    final plusIndex = v.indexOf('+');
    if (plusIndex > 0) v = v.substring(0, plusIndex);
    return v.trim();
  }

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assetsRaw = json['assets'] as List<dynamic>? ?? [];
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
      assets: assetsRaw
          .whereType<Map<String, dynamic>>()
          .map(ReleaseAsset.fromJson)
          .toList(),
    );
  }
}

/// Release 附件（APK 等）
class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final String contentType;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }

  /// 是否为 APK 文件
  bool get isApk => name.toLowerCase().endsWith('.apk');
}

/// 版本对比结果
class UpdateCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final ReleaseInfo? latestRelease;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    this.latestRelease,
  });
}

/// API 限流异常（429）
class UpdateRateLimitException implements Exception {
  @override
  String toString() => 'GitHub API 请求过于频繁，请稍后再试';
}

/// 更新检查服务
///
/// 通过 GitHub API 检查仓库最新 Release，与当前版本对比。
/// GitHub 仓库：1525745393/EmbyTok-Flutter
class UpdateCheckService {
  static const String _owner = '1525745393';
  static const String _repo = 'EmbyTok-Flutter';
  static const String _apiBase = 'https://api.github.com';

  final Dio _dio;

  UpdateCheckService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Accept': 'application/vnd.github+json',
              },
            ));

  /// 获取最新 Release
  ///
  /// 使用 /releases 而非 /releases/latest，以便获取预发布版本
  /// 按 published_at 降序排列，取第一个
  Future<ReleaseInfo?> getLatestRelease() async {
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiBase/repos/$_owner/$_repo/releases',
        queryParameters: {'per_page': 5},
      );
      if (resp.statusCode == 200 && resp.data is List<dynamic>) {
        final releases = (resp.data as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ReleaseInfo.fromJson)
            .toList();
        if (releases.isEmpty) return null;
        // 按发布时间降序，取最新的
        releases.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        return releases.first;
      }
      return null;
    } on DioException catch (e) {
      // 404 表示还没有 Release
      if (e.response?.statusCode == 404) {
        AppLogger.info('GitHub: 暂无 Release');
        return null;
      }
      // 429 表示 API 限流
      if (e.response?.statusCode == 429) {
        AppLogger.warn('GitHub API 限流，请稍后再试');
        throw UpdateRateLimitException();
      }
      AppLogger.error('检查更新失败（网络）', error: e);
      return null;
    } catch (e) {
      AppLogger.error('检查更新失败', error: e);
      return null;
    }
  }

  /// 检查是否有更新
  ///
  /// [currentVersion] 当前版本号（如 "1.133.0"）
  /// 抛出 [UpdateRateLimitException] 当 API 限流时
  Future<UpdateCheckResult> checkForUpdate(String currentVersion) async {
    final release = await getLatestRelease();
    if (release == null) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
      );
    }

    final latestVersion = release.version;
    final hasUpdate = _isNewer(latestVersion, currentVersion);

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      currentVersion: currentVersion,
      latestRelease: release,
    );
  }

  /// 判断 [a] 是否比 [b] 更新
  /// 版本格式：x.y.z，逐段比较数字大小
  /// 预发布版本（如 1.0.0-beta）视为正式版本的更低优先级
  bool _isNewer(String a, String b) {
    // 分离主版本号和预发布标签
    final aParts = _parseVersion(a);
    final bParts = _parseVersion(b);

    // 补齐到相同长度
    final maxLen =
        aParts.length > bParts.length ? aParts.length : bParts.length;
    while (aParts.length < maxLen) {
      aParts.add(0);
    }
    while (bParts.length < maxLen) {
      bParts.add(0);
    }
    for (var i = 0; i < maxLen; i++) {
      if (aParts[i] > bParts[i]) return true;
      if (aParts[i] < bParts[i]) return false;
    }

    // 主版本号相同，比较预发布标签
    // 有预发布标签的版本 < 无预发布标签的正式版本
    final aHasPreRelease = a.contains('-');
    final bHasPreRelease = b.contains('-');
    if (aHasPreRelease && !bHasPreRelease) return false;
    if (!aHasPreRelease && bHasPreRelease) return true;

    // 两者都是预发布版本，比较预发布标签
    if (aHasPreRelease && bHasPreRelease) {
      final aPre = a.substring(a.indexOf('-') + 1);
      final bPre = b.substring(b.indexOf('-') + 1);
      return _comparePreRelease(aPre, bPre) > 0;
    }

    return false; // 相同版本
  }

  /// 比较预发布版本标签
  /// 如 beta.2 > beta.1 > beta
  int _comparePreRelease(String a, String b) {
    final aParts = a.split('.');
    final bParts = b.split('.');
    final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < maxLen; i++) {
      final aNum = int.tryParse(i < aParts.length ? aParts[i] : '0') ?? 0;
      final bNum = int.tryParse(i < bParts.length ? bParts[i] : '0') ?? 0;
      if (aNum > bNum) return 1;
      if (aNum < bNum) return -1;
    }
    return 0;
  }

  /// 解析版本号，提取数字段
  /// 如 "1.0.0-beta" → [1, 0, 0]
  List<int> _parseVersion(String version) {
    // 去掉预发布标签（-beta, -rc.1 等）
    final dashIndex = version.indexOf('-');
    final mainVersion = dashIndex > 0 ? version.substring(0, dashIndex) : version;

    return mainVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  /// 获取 GitHub Release 页面 URL（用于浏览器打开）
  String get releasePageUrl => 'https://github.com/$_owner/$_repo/releases';

  /// 下载 APK 到本地缓存目录
  ///
  /// - [asset] 要下载的 APK 附件
  /// - [version] 版本号（用于文件名，避免不同版本缓存冲突）
  /// - [onProgress] 下载进度回调（0.0 ~ 1.0）
  /// - 返回下载后的本地文件路径
  Future<String> downloadApk(
    ReleaseAsset asset, {
    required String version,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    // 使用应用支持目录，避免被系统自动清理
    final dir = await getApplicationSupportDirectory();
    final downloadsDir = Directory('${dir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    // 文件名加入版本号，避免不同版本同名缓存
    final fileName = '${version}_${asset.name}';
    final savePath = '${downloadsDir.path}/$fileName';

    // 已下载过同名文件且大小匹配则直接返回
    final existingFile = File(savePath);
    if (await existingFile.exists() &&
        await existingFile.length() == asset.size) {
      onProgress(1.0);
      return savePath;
    }

    // GitHub 国内加速镜像列表（按优先级排序）
    // 原始链接优先，失败后依次尝试镜像
    final downloadUrls = <String>[
      asset.downloadUrl, // 原始 GitHub 链接
      'https://ghproxy.com/${asset.downloadUrl}',
      'https://mirror.ghproxy.com/${asset.downloadUrl}',
      'https://gh-proxy.com/${asset.downloadUrl}',
      'https://github.moeyy.xyz/${asset.downloadUrl}',
    ];

    Object? lastError;
    for (int i = 0; i < downloadUrls.length; i++) {
      final url = downloadUrls[i];
      final isMirror = i > 0;
      try {
        AppLogger.info('开始下载 APK', data: {
          'url': isMirror ? '镜像 #${i}' : '原始链接',
          'fileName': asset.name,
        });
        await _dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            onProgress(received / total);
          },
        );
        AppLogger.info('APK 下载完成', data: {
          'source': isMirror ? '镜像 #$i' : '原始链接',
          'path': savePath,
        });
        return savePath;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          AppLogger.info('APK 下载已取消');
          rethrow;
        }
        lastError = e;
        AppLogger.warn('下载失败，尝试下一个源', data: {
          'source': isMirror ? '镜像 #$i' : '原始链接',
          'error': e.message,
        });
        // 删除未完成的文件
        if (await existingFile.exists()) {
          await existingFile.delete();
        }
        continue;
      }
    }
    AppLogger.error('所有下载源都失败了', error: lastError);
    throw Exception('下载失败，请检查网络连接后重试');
  }
}

/// 更新检查 Provider
final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  return UpdateCheckService();
});
