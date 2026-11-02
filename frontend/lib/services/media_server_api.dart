import 'emby_auth_api.dart';
import 'emby_library_api.dart';
import 'emby_discovery_api.dart';
import 'emby_series_api.dart';
import 'emby_people_api.dart';
import 'emby_genres_api.dart';
import 'emby_favorites_api.dart';
import 'emby_playback_api.dart';
import 'emby_search_api.dart';
import 'emby_misc_api.dart';

/// Emby 媒体服务器 API 接口聚合（结构性拆分 #6）。
///
/// 方法按域拆分为独立子接口（认证/媒体库/发现/剧集/人员/分类/收藏/
/// 播放/搜索/观看历史与云同步），本类聚合全部子接口，
/// 供调用方以 `MediaServerApi` 统一引用，接口语义不变。
abstract class MediaServerApi
    implements
        EmbyAuthApi,
        EmbyLibraryApi,
        EmbyDiscoveryApi,
        EmbySeriesApi,
        EmbyPeopleApi,
        EmbyGenresApi,
        EmbyFavoritesApi,
        EmbyPlaybackApi,
        EmbySearchApi,
        EmbyMiscApi {}
