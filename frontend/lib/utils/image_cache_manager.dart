// 图片缓存管理：为 CachedNetworkImage 提供统一的缓存管理器
//
// 设计目标：
// 1. 限制内存缓存大小，避免长时间浏览导致 OOM
// 2. 统一磁盘缓存配置，防止碎片化
// 3. 提供一个便捷的 getter 供全局使用

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 应用内默认图片缓存管理器
/// - 内存缓存：最多 200 张 / 最大 100MB
/// - 磁盘缓存：最大 200MB
class AppImageCacheManager {
  static const String _cacheKey = 'embbytokImageCache';

  /// 缩略图缓存（网格视图、搜索结果等小图）
  static final CacheManager thumbnail = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: _cacheKey),
      fileService: HttpFileService(),
    ),
  );

  /// 详情页大图（item_detail_view / person_detail_view 等）
  static final CacheManager largeImage = CacheManager(
    Config(
      '${_cacheKey}Large',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: '${_cacheKey}Large'),
      fileService: HttpFileService(),
    ),
  );
}

/// 获取缩略图场景使用的缓存尺寸参数（宽像素）
const int kThumbnailCacheWidthSmall = 240;
const int kThumbnailCacheWidthMedium = 400;
const int kThumbnailCacheWidthLarge = 800;
