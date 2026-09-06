// 群晖 Audio Station API 客户端
//
// 对接 Synology DSM 的 Audio Station Web API（无官方文档，以下基于社区抓包整理）：
//
// 认证（DSM 7）：
//   POST /webapi/entry.cgi?api=SYNO.API.Auth&method=login&version=6
//   &session=audiostation&account=<user>&passwd=<pwd>&format=sid
//   → data.sid（会话 ID），后续请求均需带 _sid=<sid>
//
// 数据（路径经 query.cgi 发现，DSM 6/7 均可用固定路径兜底）：
//   SYNO.AudioStation.Song     list (v3)   → AudioStation/song.cgi
//   SYNO.AudioStation.Album    list (v3)   → AudioStation/album.cgi
//   SYNO.AudioStation.Artist   list (v3)   → AudioStation/artist.cgi
//   SYNO.AudioStation.Playlist list (v2)   → AudioStation/playlist.cgi
//   SYNO.AudioStation.Search   list (v1)   → AudioStation/search.cgi
//   SYNO.AudioStation.Cover    (v1)        → AudioStation/cover.cgi（返回图片）
//   SYNO.AudioStation.Stream   stream (v2) → AudioStation/stream.cgi（返回音频流）
//
// 说明：
// - 部分节点返回 JSON 字符串而非 JSON 对象，需二次解析（_decodeBody 处理）
// - 整轨音轨（id 含 _v_）无法直接 stream，需强制 transcode 播放
// - 统一使用 GET（query 参数）请求数据接口

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/audio_models.dart';
import '../utils/logger.dart';

/// 群晖 API 返回的数据包裹层
class SynologyResponse<T> {
  final bool success;
  final T? data;
  final int? errorCode;
  final String? errorMsg;

  const SynologyResponse({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMsg,
  });

  bool get hasError => !success;

  factory SynologyResponse.failure(int? code, String? msg) =>
      SynologyResponse(success: false, errorCode: code, errorMsg: msg);
}

/// 群晖登录失败（用于携带 DSM 错误码，便于 UI 提示 OTP/密码错误）
class SynologyAuthException implements Exception {
  final int? errorCode;
  final String message;
  SynologyAuthException(this.message, {this.errorCode});

  @override
  String toString() => message;
}

/// 两步验证（OTP）已开启：登录返回 403 + token，需要带 otp_code 重试
class SynologyOtpRequiredException extends SynologyAuthException {
  /// DSM 下发的临时 token（随 OTP 一起提交）
  final String? token;

  SynologyOtpRequiredException(this.token)
      : super('需要两步验证（OTP）', errorCode: 403);
}

class SynologyAudioApi {
  final Dio _dio;

  /// 当前服务器地址（如 http://192.168.1.100:5000）
  String? _serverUrl;

  /// 当前会话 ID（登录后有效）
  String? _sid;

  /// 会话所属账号（登录后有效）
  String? _account;

  /// 设备 ID（OTP 两步验证时使用）
  String? _deviceId;

  SynologyAudioApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            )) {
    // 群晖 NAS 默认使用自签名证书（HTTPS 5001），
    // 放行证书校验以支持自签名部署（用户显式连接自己的 NAS）。
    // 注意：仅作用于本客户端，不影响项目其他 API 的证书策略。
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        validateCertificate: (cert, host, port) => true,
      );
    }
  }

  // ============================
  // 会话状态
  // ============================

  String? get serverUrl => _serverUrl;
  String? get sid => _sid;
  String? get account => _account;
  bool get isLoggedIn => _sid != null && _sid!.isNotEmpty;

  /// 已登录时可离线构造（从持久化恢复会话）
  void restoreSession({required String serverUrl, required String sid, String? account}) {
    _serverUrl = _serverUrl ?? serverUrl;
    _sid = sid;
    _account = account;
  }

  void clearSession() {
    _serverUrl = null;
    _sid = null;
    _account = null;
  }

  // ============================
  // 认证
  // ============================

  /// 登录 Audio Station，返回会话 ID（sid）
  ///
  /// [otpCode]：DSM 开启两步验证时，第一次登录返回 403 + token，需带 OTP 重试。
  Future<String> login({
    required String serverUrl,
    required String account,
    required String password,
    String? otpCode,
    String? deviceId,
  }) async {
    _serverUrl = _normalizeServerUrl(serverUrl);
    _account = account;

    // DSM 7 使用 entry.cgi，DSM 6 使用 auth.cgi；先尝试 entry.cgi，失败回退
    final params = <String, dynamic>{
      'api': 'SYNO.API.Auth',
      'version': 6,
      'method': 'login',
      'session': 'audiostation',
      'account': account,
      'passwd': password,
      'format': 'sid',
      'enable_device_token': 'yes',
      if (otpCode != null && otpCode.isNotEmpty) 'otp_code': otpCode,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };

    dynamic raw;
    try {
      raw = await _requestLogin('/webapi/entry.cgi', params);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // DSM 6：auth.cgi
        raw = await _requestLogin('/webapi/auth.cgi', params);
      } else {
        rethrow;
      }
    }

    final body = _decodeBody(raw);
    if (body is! Map<String, dynamic>) {
      throw SynologyAuthException('服务器返回异常格式');
    }

    final success = body['success'] == true;
    if (!success) {
      final error = body['error'] as Map<String, dynamic>?;
      final code = error?['code'] as int?;
      // 两步验证开启：DSM 返回 403，token 位于 error.errors.token
      if (code == 403) {
        final errors = error?['errors'] as Map<String, dynamic>?;
        final token = errors?['token'] as String?;
        if (otpCode == null || otpCode.isEmpty) {
          throw SynologyOtpRequiredException(token);
        }
      }
      throw SynologyAuthException(_authErrorMessage(code), errorCode: code);
    }

    final data = body['data'] as Map<String, dynamic>?;
    final newSid = data?['sid'] as String?;
    if (newSid == null || newSid.isEmpty) {
      throw SynologyAuthException('登录响应缺少 sid');
    }
    _sid = newSid;
    // 记录设备 ID：OTP 两步验证时需携带 device_id 完成登录
    final did = data?['did'] as String?;
    if (did != null && did.isNotEmpty) {
      _deviceId = did;
    }
    AppLogger.info('群晖 Audio Station 登录成功', data: {'account': account});
    return newSid;
  }

  /// 退出登录（使当前 sid 失效）
  Future<void> logout() async {
    final serverUrl = _serverUrl;
    final sid = _sid;
    _sid = null;
    _account = null;
    if (serverUrl == null || sid == null) return;
    try {
      await _requestRaw('/webapi/entry.cgi', {
        'api': 'SYNO.API.Auth',
        'version': 6,
        'method': 'logout',
        'session': 'audiostation',
        '_sid': sid,
      });
    } catch (e) {
      AppLogger.warn('群晖登出失败（忽略）', data: {'error': e.toString()});
    } finally {
      _serverUrl = null;
    }
  }

  // ============================
  // 歌曲 / 专辑 / 歌手 / 歌单
  // ============================

  /// 获取歌曲列表（支持按专辑/歌手过滤）
  Future<List<AudioSong>> getSongs({
    String? album,
    String? artist,
    int offset = 0,
    int limit = 200,
  }) async {
    final data = await _callList('SYNO.AudioStation.Song', 'AudioStation/song.cgi', {
      'method': 'list',
      'version': 3,
      'library': 'all',
      'offset': offset,
      'limit': limit,
      'additional': jsonify(['song_tag', 'song_audio', 'song_rating']),
      if (album != null && album.isNotEmpty) 'album': album,
      if (artist != null && artist.isNotEmpty) 'artist': artist,
    });
    final songs = _asList(data?['songs']);
    return songs
        .map((e) => AudioSong.fromJson(_asMap(e)))
        .toList(growable: false);
  }

  /// 获取专辑列表
  Future<List<AudioAlbum>> getAlbums({
    int offset = 0,
    int limit = 200,
  }) async {
    final data = await _callList('SYNO.AudioStation.Album', 'AudioStation/album.cgi', {
      'method': 'list',
      'version': 3,
      'library': 'all',
      'offset': offset,
      'limit': limit,
      'additional': jsonify(['avg_rating']),
    });
    final albums = _asList(data?['albums']);
    return albums
        .map((e) => AudioAlbum.fromJson(_asMap(e)))
        .toList(growable: false);
  }

  /// 获取歌手列表
  Future<List<AudioArtist>> getArtists({
    int offset = 0,
    int limit = 200,
  }) async {
    final data = await _callList('SYNO.AudioStation.Artist', 'AudioStation/artist.cgi', {
      'method': 'list',
      'version': 3,
      'library': 'all',
      'offset': offset,
      'limit': limit,
      'additional': jsonify(['avg_rating']),
    });
    final artists = _asList(data?['artists']);
    return artists
        .map((e) => AudioArtist.fromJson(_asMap(e)))
        .toList(growable: false);
  }

  /// 获取歌单列表
  Future<List<AudioPlaylist>> getPlaylists({
    int offset = 0,
    int limit = 200,
  }) async {
    final data = await _callList('SYNO.AudioStation.Playlist', 'AudioStation/playlist.cgi', {
      'method': 'list',
      'version': 2,
      'library': 'all',
      'offset': offset,
      'limit': limit,
    });
    final playlists = _asList(data?['playlists']);
    return playlists
        .map((e) => AudioPlaylist.fromJson(_asMap(e)))
        .toList(growable: false);
  }

  /// 获取歌单内歌曲
  Future<List<AudioSong>> getPlaylistSongs(String playlistId) async {
    final data = await _callList('SYNO.AudioStation.Playlist', 'AudioStation/playlist.cgi', {
      'method': 'getinfo',
      'version': 2,
      'library': 'all',
      'id': playlistId,
      'limit': 0,
      'additional': jsonify(['songs_song_tag', 'songs_song_audio', 'songs_song_rating']),
    });
    final songs = _asList(data?['songs']);
    return songs
        .map((e) => AudioSong.fromJson(_asMap(e)))
        .toList(growable: false);
  }

  /// 搜索歌曲 / 专辑 / 歌手
  Future<AudioSearchResult> search(String keyword) async {
    final data = await _callList('SYNO.AudioStation.Search', 'AudioStation/search.cgi', {
      'method': 'list',
      'version': 1,
      'library': 'all',
      'keyword': keyword,
      'limit': 100,
      'additional': jsonify(['song_tag', 'song_audio', 'song_rating']),
    });
    return AudioSearchResult(
      songs: _asList(data?['songs'])
          .map((e) => AudioSong.fromJson(_asMap(e)))
          .toList(growable: false),
      albums: _asList(data?['albums'])
          .map((e) => AudioAlbum.fromJson(_asMap(e)))
          .toList(growable: false),
      artists: _asList(data?['artists'])
          .map((e) => AudioArtist.fromJson(_asMap(e)))
          .toList(growable: false),
    );
  }

  // ============================
  // 封面 / 播放流
  // ============================

  /// 歌曲封面 URL（直接可加载，无需二次请求）
  String? getSongCoverUrl(String songId) {
    final url = _serverUrl;
    final sid = _sid;
    if (url == null || sid == null) return null;
    return _buildUrl('/webapi/AudioStation/cover.cgi', {
      'api': 'SYNO.AudioStation.Cover',
      'version': 1,
      'method': 'getsongcover',
      'library': 'all',
      'id': songId,
      '_sid': sid,
    });
  }

  /// 专辑封面 URL（按专辑名 + 专辑艺术家）
  String? getAlbumCoverUrl({
    required String albumName,
    String? albumArtistName,
  }) {
    final url = _serverUrl;
    final sid = _sid;
    if (url == null || sid == null) return null;
    return _buildUrl('/webapi/AudioStation/cover.cgi', {
      'api': 'SYNO.AudioStation.Cover',
      'version': 1,
      'method': 'getcover',
      'library': 'all',
      'album_name': albumName,
      if (albumArtistName != null && albumArtistName.isNotEmpty)
        'album_artist_name': albumArtistName,
      '_sid': sid,
    });
  }

  /// 歌曲播放流 URL
  ///
  /// 整轨音轨（id 含 _v_）无法直接 stream，强制使用 transcode（mp3）。
  String? getStreamUrl(String songId) {
    final url = _serverUrl;
    final sid = _sid;
    if (url == null || sid == null) return null;
    final isCue = songId.contains('_v_');
    final suffix = isCue ? '/0.mp3' : '';
    return _buildUrl('/webapi/AudioStation/stream.cgi$suffix', {
      'api': 'SYNO.AudioStation.Stream',
      'version': 2,
      'method': isCue ? 'transcode' : 'stream',
      'id': songId,
      if (isCue) 'format': 'mp3',
      '_sid': sid,
    });
  }

  // ============================
  // 内部工具
  // ============================

  /// 发起列表类请求并解析 data 字段（兼容 JSON 字符串响应）
  Future<Map<String, dynamic>?> _callList(
    String api,
    String path,
    Map<String, dynamic> params,
  ) async {
    final serverUrl = _serverUrl;
    final sid = _sid;
    if (serverUrl == null || sid == null) {
      throw SynologyAuthException('未登录群晖 Audio Station');
    }
    final raw = await _requestRaw('/webapi/$path', {
      ...params,
      'api': api,
      '_sid': sid,
    });
    final body = _decodeBody(raw);
    if (body is! Map<String, dynamic>) {
      throw SynologyAuthException('服务器返回异常格式');
    }
    if (body['success'] != true) {
      final error = body['error'] as Map<String, dynamic>?;
      throw SynologyAuthException(
        '群晖 API 请求失败（${error?['code'] ?? '未知错误'}）',
        errorCode: error?['code'] as int?,
      );
    }
    return _asMap(body['data']);
  }

  /// 发送 GET 请求并返回原始 body（可能是 Map / List / String）
  Future<dynamic> _requestRaw(String path, Map<String, dynamic> params) async {
    final base = _serverUrl;
    if (base == null) {
      throw SynologyAuthException('未配置群晖服务器地址');
    }
    final response = await _dio.get<dynamic>(
      '$base$path',
      queryParameters: params,
      options: Options(responseType: ResponseType.json),
    );
    return response.data;
  }

  /// 登录专用：POST + application/x-www-form-urlencoded
  ///
  /// DSM 的登录接口要求 POST 传参（GET 在部分 DSM 版本/配置下不可用），
  /// 采用 form 编码以兼容 DSM 6（auth.cgi）与 DSM 7（entry.cgi）。
  Future<dynamic> _requestLogin(String path, Map<String, dynamic> params) async {
    final base = _serverUrl;
    if (base == null) {
      throw SynologyAuthException('未配置群晖服务器地址');
    }
    final response = await _dio.post<dynamic>(
      '$base$path',
      data: params,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
      ),
    );
    return response.data;
  }

  /// 兼容部分接口返回 JSON 字符串（需二次解析）
  dynamic _decodeBody(dynamic raw) {
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  List<dynamic> _asList(dynamic v) {
    if (v is List) return v;
    if (v is String) {
      // 部分接口 songs 字段也可能是 JSON 字符串
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const [];
  }

  String _buildUrl(String path, Map<String, dynamic> params) {
    final uri = Uri.parse('$_serverUrl$path')
        .replace(queryParameters: params.map((k, v) => MapEntry(k, '$v')));
    return uri.toString();
  }

  String _normalizeServerUrl(String url) {
    var u = url.trim();
    final hasScheme = u.startsWith('http://') || u.startsWith('https://');
    if (!hasScheme) {
      // 无协议前缀：补 http://
      // 同时若输入中不含冒号（即纯 IP/主机名，无端口），
      // 补群晖默认 HTTP 端口 5000（DSM 默认配置）
      if (!u.contains(':')) {
        u = 'http://$u:5000';
      } else {
        u = 'http://$u';
      }
    }
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  /// 将 List<String> 序列化为 JSON 字符串参数（DSM 接受逗号分隔也可）
  String jsonify(List<String> values) => values.join(',');

  String _authErrorMessage(int? code) {
    switch (code) {
      case 400:
        return '请求参数错误';
      case 401:
        return '用户名或密码错误';
      case 403:
        return '需要两步验证（OTP）或账号被禁用';
      case 406:
        return '账号已禁用';
      case 408:
        return '请求超时';
      case 409:
        return '两次登录间隔太短';
      case 100:
        return '未知错误';
      default:
        return '登录失败（错误码 $code）';
    }
  }
}
