// NAS 元数据同步服务
//
// 歌手简介功能 V1.1
// 使用群晖 File Station API 将歌手元数据同步到 NAS，支持多设备共享。
//
// 元数据存储路径：/appdata/EmbTok/artist_metadata/<歌手名>.json
//
// File Station API 文档：
// - 上传：SYNO.FileStation.Upload (v2)
// - 下载：SYNO.FileStation.Download (v2)
// - 列出：SYNO.FileStation.List (v2)
// - 创建文件夹：SYNO.FileStation.CreateFolder (v2)

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/artist_metadata.dart';
import '../utils/logger.dart';
import 'synology_audio_api.dart';

/// NAS 元数据同步服务
class NasMetadataSyncService {
  NasMetadataSyncService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            )) {
    // 群晖 NAS 默认使用自签名证书，放行证书校验
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        validateCertificate: (cert, host, port) => true,
      );
    }
  }

  final Dio _dio;

  /// 元数据存储根目录
  static const String _metadataRootPath = '/appdata/EmbTok/artist_metadata';

  /// 会话级内存缓存：歌手名 → 元数据（避免重复下载）
  final Map<String, ArtistMetadata?> _downloadCache = {};

  /// 从 NAS 下载歌手元数据
  ///
  /// 返回 null 表示 NAS 上无此歌手的元数据或下载失败。
  Future<ArtistMetadata?> downloadMetadata(
    String artistName, {
    required SynologyAudioApi api,
  }) async {
    final key = artistName.trim();
    if (key.isEmpty) return null;
    if (_downloadCache.containsKey(key)) return _downloadCache[key];

    try {
      if (!api.isLoggedIn) {
        AppLogger.warn('NAS 元数据下载失败：未登录群晖',
            data: {'artist': key});
        return null;
      }

      final filePath = '$_metadataRootPath/${Uri.encodeComponent(key)}.json';
      final url = '${api.serverUrl}/webapi/entry.cgi';

      final response = await _dio.get(
        url,
        queryParameters: {
          'api': 'SYNO.FileStation.Download',
          'method': 'download',
          'version': '2',
          'path': filePath,
          '_sid': api.sid,
        },
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode != 200) {
        _downloadCache[key] = null;
        return null;
      }

      final bytes = response.data as List<int>;
      final jsonStr = utf8.decode(bytes);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final metadata = ArtistMetadata.fromJson(json);
      _downloadCache[key] = metadata;

      AppLogger.debug('NAS 元数据下载成功',
          data: {'artist': key, 'source': metadata.sourceDisplayName});
      return metadata;
    } catch (e) {
      AppLogger.warn('NAS 元数据下载失败',
          data: {'artist': key, 'error': e.toString()});
      _downloadCache[key] = null;
      return null;
    }
  }

  /// 上传歌手元数据到 NAS
  ///
  /// 返回 true 表示上传成功，false 表示失败。
  Future<bool> uploadMetadata(
    ArtistMetadata metadata, {
    required SynologyAudioApi api,
  }) async {
    try {
      if (!api.isLoggedIn) {
        AppLogger.warn('NAS 元数据上传失败：未登录群晖',
            data: {'artist': metadata.name});
        return false;
      }

      // 确保目录存在
      await _ensureDirectoryExists(api);

      final fileName = '${Uri.encodeComponent(metadata.name)}.json';
      final url = '${api.serverUrl}/webapi/entry.cgi';

      final jsonStr = jsonEncode(metadata.toJson());
      final jsonBytes = utf8.encode(jsonStr);

      final formData = FormData.fromMap({
        'api': 'SYNO.FileStation.Upload',
        'method': 'upload',
        'version': '2',
        'path': _metadataRootPath,
        'create_parents': 'true',
        'overwrite': 'true',
        '_sid': api.sid,
        'file': MultipartFile.fromBytes(
          jsonBytes,
          filename: fileName,
          contentType: DioMediaType('application', 'json'),
        ),
      });

      final response = await _dio.post(url, data: formData);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          AppLogger.debug('NAS 元数据上传成功',
              data: {'artist': metadata.name});
          return true;
        }
      }

      AppLogger.warn('NAS 元数据上传失败',
          data: {'artist': metadata.name, 'response': response.data});
      return false;
    } catch (e) {
      AppLogger.warn('NAS 元数据上传失败',
          data: {'artist': metadata.name, 'error': e.toString()});
      return false;
    }
  }

  /// 列出 NAS 上所有歌手元数据文件
  Future<List<String>> listMetadataFiles({
    required SynologyAudioApi api,
  }) async {
    try {
      if (!api.isLoggedIn) return [];

      final url = '${api.serverUrl}/webapi/entry.cgi';
      final response = await _dio.get(
        url,
        queryParameters: {
          'api': 'SYNO.FileStation.List',
          'method': 'list',
          'version': '2',
          'folder_path': _metadataRootPath,
          '_sid': api.sid,
        },
      );

      if (response.statusCode != 200) return [];

      final data = response.data;
      if (data is! Map || data['success'] != true) return [];

      final files = data['data']?['files'] as List<dynamic>?;
      if (files == null) return [];

      return files
          .where((f) =>
              f is Map &&
              f['name']?.toString().endsWith('.json') == true)
          .map((f) {
            final name = f['name'] as String;
            return Uri.decodeComponent(name.replaceAll('.json', ''));
          })
          .toList();
    } catch (e) {
      AppLogger.warn('NAS 元数据列表获取失败',
          data: {'error': e.toString()});
      return [];
    }
  }

  /// 确保元数据目录存在
  Future<void> _ensureDirectoryExists(SynologyAudioApi api) async {
    try {
      final url = '${api.serverUrl}/webapi/entry.cgi';

      // 先检查目录是否存在
      final checkResponse = await _dio.get(
        url,
        queryParameters: {
          'api': 'SYNO.FileStation.List',
          'method': 'list',
          'version': '2',
          'folder_path': _metadataRootPath,
          '_sid': api.sid,
        },
      );

      if (checkResponse.statusCode == 200) {
        final data = checkResponse.data;
        if (data is Map && data['success'] == true) {
          return; // 目录已存在
        }
      }

      // 创建目录（递归创建父目录）
      final parentPath = _metadataRootPath.substring(
          0, _metadataRootPath.lastIndexOf('/'));
      final dirName = _metadataRootPath.substring(
          _metadataRootPath.lastIndexOf('/') + 1);

      await _dio.get(
        url,
        queryParameters: {
          'api': 'SYNO.FileStation.CreateFolder',
          'method': 'create',
          'version': '2',
          'folder_path': parentPath,
          'name': dirName,
          '_sid': api.sid,
        },
      );

      AppLogger.debug('NAS 元数据目录创建成功',
          data: {'path': _metadataRootPath});
    } catch (e) {
      AppLogger.warn('NAS 元数据目录创建失败',
          data: {'path': _metadataRootPath, 'error': e.toString()});
    }
  }

  /// 清除下载缓存
  void clearCache() {
    _downloadCache.clear();
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
