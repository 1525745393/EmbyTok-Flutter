// 应用更新检查服务
//
// 通过 GitHub Releases API 检查最新版本，对比当前版本号判断是否需要更新。
// 版本号格式：x.y.z+buildNumber（如 1.133.0+11330）
// 对比逻辑：仅比较 x.y.z 三段主版本号，忽略 buildNumber
//
// 中国网络适配：
// - 检查更新 API：直连 api.github.com 失败/超时后，依次尝试通用代理
//   镜像（见 [_apiMirrors]）；全部失败时回退到本地缓存的上次检查结果
// - APK 下载：原始链接优先，失败后依次尝试国内加速镜像；下载请求
//   单独使用长 receiveTimeout（避免大文件中间停顿被 10s 超时误杀）
// - 完整性：若 Release 正文包含 SHA256 摘要（见 [ReleaseInfo.sha256Digest]），
//   下载后强制校验，防止镜像源篡改安装包

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../utils/logger.dart';

/// GitHub Release 信息
class ReleaseInfo {
  // 附件（APK 等）

  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

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
  final String tagName; // 如 "v1.133.0"
  final String name; // release 标题
  final String body; // release notes（Markdown）
  final String htmlUrl; // release 页面链接
  final DateTime publishedAt;
  final List<ReleaseAsset> assets;

  /// 解析版本号：去掉 "v" 前缀，取 "x.y.z" 部分（忽略 +buildNumber）
  String get version {
    var v = tagName;
    if (v.startsWith('v')) v = v.substring(1);
    // 去掉 +buildNumber
    final plusIndex = v.indexOf('+');
    if (plusIndex > 0) v = v.substring(0, plusIndex);
    return v.trim();
  }

  /// 从 Release 正文解析 APK 的 SHA256 摘要（小写 hex）
  ///
  /// 支持格式：`SHA256: <hash>`、`SHA-256 <hash>` 或正文中独立一行的
  /// 64 位十六进制字符串。发布时在 release notes 里附带摘要即可启用
  /// 下载完整性校验；未提供时返回 null（下载不校验）。
  String? get sha256Digest {
    final match = RegExp(
      r'SHA[- ]?256[:：]?\s*([0-9a-fA-F]{64})',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1)?.toLowerCase();
  }

  /// 序列化（用于本地缓存，网络失败时回退显示）
  Map<String, dynamic> toJson() => {
        'tag_name': tagName,
        'name': name,
        'body': body,
        'html_url': htmlUrl,
        'published_at': publishedAt.toIso8601String(),
        'assets': assets.map((a) => a.toJson()).toList(),
      };
}

/// Release 附件（APK 等）
class ReleaseAsset {
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
  final String name;
  final String downloadUrl;
  final int size;
  final String contentType;

  /// 是否为 APK 文件
  bool get isApk => name.toLowerCase().endsWith('.apk');

  /// 是否为 SHA256 摘要附件
  bool get isSha256 => name.toLowerCase().endsWith('.sha256');

  /// 序列化（用于本地缓存）
  Map<String, dynamic> toJson() => {
        'name': name,
        'browser_download_url': downloadUrl,
        'size': size,
        'content_type': contentType,
      };
}

/// 版本对比结果
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    this.latestRelease,
    this.fromCache = false,
  });
  final bool hasUpdate;
  final String currentVersion;
  final ReleaseInfo? latestRelease;

  /// 本次结果是否来自本地缓存（网络全部失败时回退）
  final bool fromCache;
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
  UpdateCheckService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Accept': 'application/vnd.github+json',
              },
            ));
  static const String _owner = '1525745393';
  static const String _repo = 'EmbyTok-Flutter';
  static const String _apiBase = 'https://api.github.com';

  /// GitHub API 通用代理镜像（前缀 + 完整 URL 即可代理任意请求）
  /// 顺序即优先级：直连失败后依次尝试
  static const List<String> _apiMirrors = [
    'https://gh-proxy.com/',
    'https://ghfast.top/',
    'https://ghproxy.net/',
  ];

  /// APK 下载镜像（原始链接失败后依次尝试，已移除停止服务的旧镜像）
  static const List<String> _downloadMirrors = [
    'https://ghfast.top/',
    'https://gh-proxy.com/',
    'https://ghproxy.net/',
    'https://gh.ddlc.top/',
  ];

  final Dio _dio;

  /// 获取最新 Release
  ///
  /// 使用 /releases 而非 /releases/latest，以便获取预发布版本；
  /// 按 published_at 降序排列，取第一个。
  /// 直连失败后自动尝试国内镜像；全部失败返回 null。
  Future<ReleaseInfo?> getLatestRelease() async {
    final release = await _fetchLatestRelease();
    if (release != null) {
      // 网络成功时刷新本地缓存（弱网/被墙时回退用）
      await _writeCachedRelease(release);
    }
    return release;
  }

  /// 依次尝试直连与镜像源，返回最新 Release
  Future<ReleaseInfo?> _fetchLatestRelease() async {
    final paths = <String>[
      // 直连 GitHub API
      '$_apiBase/repos/$_owner/$_repo/releases?per_page=5',
      // 镜像：前缀 + 完整 URL
      for (final m in _apiMirrors)
        '$m$_apiBase/repos/$_owner/$_repo/releases?per_page=5',
    ];

    Object? lastError;
    for (int i = 0; i < paths.length; i++) {
      final url = paths[i];
      final isMirror = i > 0;
      try {
        final resp = await _dio.get<dynamic>(
          url,
          options: Options(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final code = resp.statusCode;
        if (code == 200 && resp.data is List<dynamic>) {
          final releases = (resp.data as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(ReleaseInfo.fromJson)
              .toList();
          if (releases.isEmpty) return null;
          releases.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          AppLogger.info('更新检查成功', data: {
            'source': isMirror ? '镜像 #$i' : '直连',
            'version': releases.first.version,
          });
          return releases.first;
        }
        if (code == 404) {
          AppLogger.info('GitHub: 暂无 Release');
          return null;
        }
        // 429：记录并尝试下一源（镜像服务器 IP 不同，可能未被限流）
        if (code == 429) {
          AppLogger.warn('更新检查源被限流，尝试下一源', data: {
            'source': isMirror ? '镜像 #$i' : '直连',
          });
          lastError = UpdateRateLimitException();
          continue;
        }
        lastError = Exception('HTTP $code');
        AppLogger.warn('更新检查源返回异常，尝试下一源', data: {
          'source': isMirror ? '镜像 #$i' : '直连',
          'status': code,
        });
      } on DioException catch (e) {
        // 404 为确定性结论（仓库无 Release），不继续尝试镜像
        if (e.response?.statusCode == 404) {
          AppLogger.info('GitHub: 暂无 Release');
          return null;
        }
        // 429：记录并继续尝试下一源，全部源都被限流才抛异常
        if (e.response?.statusCode == 429) {
          AppLogger.warn('更新检查源被限流，尝试下一源', data: {
            'source': isMirror ? '镜像 #$i' : '直连',
          });
          lastError = UpdateRateLimitException();
          continue;
        }
        lastError = e;
        AppLogger.warn('更新检查源网络失败，尝试下一源', data: {
          'source': isMirror ? '镜像 #$i' : '直连',
          'error': e.message,
        });
      } catch (e) {
        lastError = e;
        AppLogger.warn('更新检查源异常，尝试下一源', data: {
          'source': isMirror ? '镜像 #$i' : '直连',
        });
      }
    }
    // 全部源都被限流时抛出限流异常（区别于普通网络失败）
    if (lastError is UpdateRateLimitException) {
      throw UpdateRateLimitException();
    }
    AppLogger.error('所有更新检查源都失败', error: lastError);
    return null;
  }

  /// 检查是否有更新
  ///
  /// [currentVersion] 当前版本号（如 "1.133.0"）
  /// 抛出 [UpdateRateLimitException] 当 API 限流时。
  /// 网络全部失败时回退到本地缓存的上次检查结果（[UpdateCheckResult.fromCache]）。
  Future<UpdateCheckResult> checkForUpdate(String currentVersion) async {
    ReleaseInfo? release;
    var fromCache = false;
    try {
      release = await getLatestRelease();
    } on UpdateRateLimitException {
      rethrow;
    }
    if (release == null) {
      // 网络失败：回退本地缓存，避免"检查失败"的坏体验
      final cached = await _readCachedRelease();
      if (cached != null) {
        release = cached;
        fromCache = true;
      } else {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
        );
      }
    }

    final latestVersion = release.version;
    final hasUpdate = _isNewer(latestVersion, currentVersion);

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      currentVersion: currentVersion,
      latestRelease: release,
      fromCache: fromCache,
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
    final maxLen =
        aParts.length > bParts.length ? aParts.length : bParts.length;
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
    final mainVersion =
        dashIndex > 0 ? version.substring(0, dashIndex) : version;

    return mainVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  /// 获取 GitHub Release 页面 URL（用于浏览器打开）
  String get releasePageUrl => 'https://github.com/$_owner/$_repo/releases';

  /// 下载 APK 到本地缓存目录
  ///
  /// - [asset] 要下载的 APK 附件
  /// - [version] 版本号（用于文件名，避免不同版本缓存冲突）
  /// - [onProgress] 下载进度回调（0.0 ~ 1.0）
  /// - [expectedSha256] 期望的 SHA256 摘要（小写 hex）；提供时下载完成后
  ///   强制校验，不匹配则删除文件并抛错——防止镜像源篡改安装包
  /// - 返回下载后的本地文件路径
  Future<String> downloadApk(
    ReleaseAsset asset, {
    required String version,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
    String? expectedSha256,
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

    // 已下载过同名文件且大小匹配则复用（仍需通过完整性校验）
    final existingFile = File(savePath);
    if (await existingFile.exists() &&
        await existingFile.length() == asset.size) {
      onProgress(1.0);
      await _verifyOrDelete(savePath, expectedSha256);
      return savePath;
    }

    // GitHub 国内加速镜像列表（按优先级排序）
    // 原始链接优先，失败后依次尝试镜像
    final downloadUrls = <String>[
      asset.downloadUrl, // 原始 GitHub 链接
      for (final m in _downloadMirrors) '$m${asset.downloadUrl}',
    ];

    Object? lastError;
    for (int i = 0; i < downloadUrls.length; i++) {
      final url = downloadUrls[i];
      final isMirror = i > 0;
      try {
        AppLogger.info('开始下载 APK', data: {
          'url': isMirror ? '镜像 #$i' : '原始链接',
          'fileName': asset.name,
        });
        await _dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
          // 下载覆盖长 receiveTimeout：APK 较大、镜像可能较慢，
          // 避免两次数据包间隔超过默认 10s 被误判超时中断
          options: Options(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 120),
          ),
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            onProgress(received / total);
          },
        );
        AppLogger.info('APK 下载完成', data: {
          'source': isMirror ? '镜像 #$i' : '原始链接',
          'path': savePath,
        });
        // 完整性校验：失败会删除文件并抛错终止下载。
        // 安全起见不继续尝试其他镜像（内容与官方不一致即视为可疑）。
        await _verifyOrDelete(savePath, expectedSha256);
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

  /// 计算本地文件 SHA256 摘要（小写 hex）
  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  // ---------------- 本地缓存（网络失败时回退显示上次检查结果） ----------------

  Future<ReleaseInfo?> _readCachedRelease() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kStorageKeyUpdateCheckCache);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final releaseJson = json['release'];
      if (releaseJson is! Map<String, dynamic>) return null;
      return ReleaseInfo.fromJson(releaseJson);
    } catch (e) {
      AppLogger.error('读取更新检查缓存失败', error: e);
      return null;
    }
  }

  Future<void> _writeCachedRelease(ReleaseInfo release) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kStorageKeyUpdateCheckCache,
        jsonEncode({
          'checkedAt': DateTime.now().toIso8601String(),
          'release': release.toJson(),
        }),
      );
    } catch (e) {
      AppLogger.error('写入更新检查缓存失败', error: e);
    }
  }

  /// 校验下载文件完整性；失败时删除文件并抛错（调用方继续尝试下一源）
  Future<void> _verifyOrDelete(String savePath, String? expectedSha256) async {
    if (expectedSha256 == null) return;
    final file = File(savePath);
    final actual = await _sha256Of(file);
    if (actual == expectedSha256) {
      AppLogger.info('APK 完整性校验通过');
      return;
    }
    // 校验失败：丢弃不安全的安装包
    if (await file.exists()) {
      await file.delete();
    }
    AppLogger.error('APK 完整性校验失败，已丢弃文件', data: {
      'expected': expectedSha256,
      'actual': actual,
    });
    throw Exception('下载文件校验失败（内容与官方不一致），已丢弃不安全的安装包');
  }
}

/// 更新检查 Provider
final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  return UpdateCheckService();
});
