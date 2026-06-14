// 应用全局常量

const int kDefaultPageLimit = 20;
const String kAppName = 'EmbyTok';
const String kStorageKeyConfig = 'embbytok_config';
const String kStorageKeyHistory = 'embbytok_history';
const String kStorageKeySearchHistory = 'embbytok_search_history';
const String kStorageKeySubtitle = 'embbytok_subtitle';
const String kStorageKeyPlaybackRate = 'embbytok_playback_rate';

// ============================
// 用户偏好持久化键（Task 1 新增）
// ============================
const String kStorageKeyForceDeviceMode = 'embbytok_force_device_mode';
const String kStorageKeyOrientationMode = 'embbytok_orientation_mode';
const String kStorageKeyFeedType = 'embbytok_feed_type';
const String kStorageKeyViewMode = 'embbytok_view_mode';
const String kStorageKeyIsMuted = 'embbytok_is_muted';
const String kStorageKeyIsAutoPlay = 'embbytok_is_auto_play';
const String kStorageKeyHiddenLibraryIds = 'embbytok_hidden_library_ids';

// 设备模式（standard / tv）
const String kDeviceModeStandard = 'standard';
const String kDeviceModeTv = 'tv';

// 浏览模式枚举（latest / random / favorites）
const String kFeedTypeLatest = 'latest';
const String kFeedTypeRandom = 'random';
const String kFeedTypeFavorites = 'favorites';

// 视图模式枚举（feed / grid）
const String kViewModeFeed = 'feed';
const String kViewModeGrid = 'grid';

// 视频方向过滤（vertical / horizontal / both）
const String kOrientationModeVertical = 'vertical';
const String kOrientationModeHorizontal = 'horizontal';
const String kOrientationModeBoth = 'both';

const int kMaxSearchHistory = 10;
const double kDefaultPlaybackRate = 1.0;
const double kLongPressPlaybackRate = 2.0;
const int kDebounceMs = 300;
const int kDoubleTapMs = 300;
const int kSeekPerPixelMs = 100;

const String kSubtitleColorWhite = 'white';
const String kSubtitleColorYellow = 'yellow';
const String kSubtitleSizeSmall = 'small';
const String kSubtitleSizeMedium = 'medium';
const String kSubtitleSizeLarge = 'large';
const String kSubtitlePosBottom = 'bottom';
const String kSubtitlePosLower = 'lower';
const String kSubtitlePosCenter = 'center';

// ============================
// Emby 媒体库类型定义
// ============================

// Emby CollectionType 常量：媒体库类型标识符
const String kLibraryTypeMovies = 'movies';
const String kLibraryTypeTvShows = 'tvshows';
const String kLibraryTypeHomeVideos = 'homevideos';
const String kLibraryTypePhotos = 'photos';
const String kLibraryTypeMusic = 'music';
const String kLibraryTypeMusicVideos = 'musicvideos';
const String kLibraryTypeMixed = 'mixed';
const String kLibraryTypeBooks = 'books';
const String kLibraryTypeBoxSets = 'boxsets';

// Emby ItemType 常量：媒体项类型标识符
const String kItemTypeMovie = 'Movie';
const String kItemTypeSeries = 'Series';
const String kItemTypeEpisode = 'Episode';
const String kItemTypeMusicVideo = 'MusicVideo';
const String kItemTypeHomeVideo = 'HomeVideo';
const String kItemTypeVideo = 'Video';
const String kItemTypePhoto = 'Photo';
const String kItemTypeAudio = 'Audio';

// CollectionType → IncludeItemTypes 映射表
// 用于向 Emby /Items 端点查询
const Map<String, String> kLibraryCollectionTypeToItemTypes = {
  kLibraryTypeMovies: 'Movie,Series,MusicVideo,Episode',
  kLibraryTypeTvShows: 'Series,Episode,Movie,MusicVideo',
  kLibraryTypeHomeVideos: 'Video,Movie,HomeVideo,Episode',
  kLibraryTypePhotos: 'Photo',
  kLibraryTypeMusic: 'Audio,MusicAlbum,MusicArtist,MusicGenre',
  kLibraryTypeMusicVideos: 'MusicVideo',
  kLibraryTypeMixed: 'Movie,Series,MusicVideo,Episode,Video,HomeVideo,Photo',
  kLibraryTypeBooks: 'Book',
  kLibraryTypeBoxSets: 'BoxSet',
};

// 默认的 IncludeItemTypes（向后兼容，相当于 movies/未指定类型时使用）
const String kDefaultIncludeItemTypes = 'Movie,Series,MusicVideo,Episode';

// CollectionType → 中文显示标签
const Map<String, String> kLibraryCollectionTypeDisplayLabel = {
  kLibraryTypeMovies: '电影',
  kLibraryTypeTvShows: '剧集',
  kLibraryTypeHomeVideos: '家庭视频',
  kLibraryTypePhotos: '照片',
  kLibraryTypeMusic: '音乐',
  kLibraryTypeMusicVideos: '音乐视频',
  kLibraryTypeMixed: '混合',
  kLibraryTypeBooks: '书籍',
  kLibraryTypeBoxSets: '合集',
};

// 视频类型集合（判断 MediaItem 是否为视频）
const Set<String> kVideoItemTypes = {
  kItemTypeMovie,
  kItemTypeSeries,
  kItemTypeEpisode,
  kItemTypeMusicVideo,
  kItemTypeHomeVideo,
  kItemTypeVideo,
};

// 图片类型集合
const Set<String> kPhotoItemTypes = {
  kItemTypePhoto,
};

// 根据 collectionType 获取 IncludeItemTypes；
// 找不到或为空时返回 kDefaultIncludeItemTypes
String includeItemTypesForLibraryType(String? libraryType) {
  if (libraryType == null || libraryType.isEmpty) {
    return kDefaultIncludeItemTypes;
  }
  final normalized = libraryType.trim().toLowerCase();
  return kLibraryCollectionTypeToItemTypes[normalized] ?? kDefaultIncludeItemTypes;
}

// 根据 collectionType 获取中文显示标签
String libraryDisplayLabel(String? libraryType, {String fallback = ''}) {
  if (libraryType == null || libraryType.isEmpty) {
    return fallback;
  }
  final normalized = libraryType.trim().toLowerCase();
  return kLibraryCollectionTypeDisplayLabel[normalized] ?? fallback;
}

// 判断某 libraryType 是否为图片库
bool isPhotoLibraryType(String? libraryType) {
  if (libraryType == null || libraryType.isEmpty) return false;
  final normalized = libraryType.trim().toLowerCase();
  return normalized == kLibraryTypePhotos;
}

// 判断某 libraryType 是否为视频库（可播放视频）
bool isVideoLibraryType(String? libraryType) {
  if (libraryType == null || libraryType.isEmpty) return false;
  final normalized = libraryType.trim().toLowerCase();
  return normalized == kLibraryTypeMovies ||
      normalized == kLibraryTypeTvShows ||
      normalized == kLibraryTypeHomeVideos ||
      normalized == kLibraryTypeMusicVideos ||
      normalized == kLibraryTypeMixed;
}
