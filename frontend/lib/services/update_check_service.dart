// 应用更新检查服务
//
// 通过 GitHub Releases API 检查最新版本，对比当前版本号判断是否需要更新。
// 版本号格式：x.y.z+buildNumber（如 1.133.0+11330）
// 对比逻辑：仅比较 x.y.z 三段主版本号，忽略 buildNumber

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<ReleaseInfo?> getLatestRelease() async {
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiBase/repos/$_owner/$_repo/releases/latest',
      );
      if (resp.statusCode == 200 && resp.data is Map<String, dynamic>) {
        return ReleaseInfo.fromJson(resp.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      // 404 表示还没有 Release
      if (e.response?.statusCode == 404) {
        AppLogger.info('GitHub: 暂无 Release');
        return null;
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
  bool _isNewer(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    // 补齐到相同长度
    final maxLen =
        partsA.length > partsB.length ? partsA.length : partsB.length;
    while (partsA.length < maxLen) {
      partsA.add(0);
    }
    while (partsB.length < maxLen) {
      partsB.add(0);
    }
    for (var i = 0; i < maxLen; i++) {
      if (partsA[i] > partsB[i]) return true;
      if (partsA[i] < partsB[i]) return false;
    }
    return false; // 相同版本
  }

  /// 获取 GitHub Release 页面 URL（用于浏览器打开）
  String get releasePageUrl => 'https://github.com/$_owner/$_repo/releases';
}

/// 更新检查 Provider
final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  return UpdateCheckService();
});
