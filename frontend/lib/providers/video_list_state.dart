// 视频列表状态模型
//
// 独立拆分原因：
// - 状态模型是纯数据类，不包含业务逻辑
// - 便于在多个 Notifier/Provider 之间共享状态定义
// - 单独文件使状态结构一目了然

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../utils/app_preferences.dart' show FeedType;
import '../utils/constants.dart';

/// 视频列表状态：包含分页数据、加载状态和浏览模式
///
/// 核心字段：
/// - [items] 当前加载的媒体项列表（feed 模式使用）
/// - [gridItems] 网格视图专用列表（grid 模式使用，是 items 的子集）
/// - [gridStartIndex] 网格视图的全局起始偏移（用于 feed 模式跳转）
/// - [isLoading] 是否正在加载中
/// - [hasMore] 是否还有更多数据可加载
/// - [totalCount] 媒体库总视频数（用于分页显示)
/// - [feedType] 当前浏览模式（latest/random/favorites/resume）
/// - [sortBy] 排序字段（Emby SortBy 参数）
/// - [sortOrder] 排序顺序（Ascending/Descending）
/// - [searchTerm] 搜索关键词
class VideoListState {
  final List<MediaItem> items;
  final List<MediaItem> gridItems; // 网格视图专用列表（裁剪后）
  final int gridStartIndex; // 网格视图的全局起始偏移
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;
  final int totalCount; // 媒体库总视频数，用于分页显示
  final FeedType feedType; // 当前浏览模式
  final String sortBy;
  final String sortOrder;
  final String searchTerm;

  const VideoListState({
    this.items = const <MediaItem>[],
    this.gridItems = const <MediaItem>[],
    this.gridStartIndex = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = kDefaultPageLimit,
    this.totalCount = 0,
    this.feedType = FeedType.latest,
    this.sortBy = 'DateCreated,SortName',
    this.sortOrder = 'Descending',
    this.searchTerm = '',
  });

  VideoListState copyWith({
    List<MediaItem>? items,
    List<MediaItem>? gridItems,
    int? gridStartIndex,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
    int? totalCount,
    FeedType? feedType,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
  }) {
    return VideoListState(
      items: items ?? this.items,
      gridItems: gridItems ?? this.gridItems,
      gridStartIndex: gridStartIndex ?? this.gridStartIndex,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      totalCount: totalCount ?? this.totalCount,
      feedType: feedType ?? this.feedType,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }
}
