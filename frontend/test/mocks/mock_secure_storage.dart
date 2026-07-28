import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mockito/mockito.dart';

/// FlutterSecureStorage 的 Mock 实现
/// 用于测试时模拟安全存储的读写行为
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {
  final Map<String, String> _storage = {};
  bool _shouldThrowOnRead = false;
  bool _shouldThrowOnWrite = false;
  bool _shouldThrowOnDelete = false;

  void setShouldThrowOnRead(bool value) {
    _shouldThrowOnRead = value;
  }

  void setShouldThrowOnWrite(bool value) {
    _shouldThrowOnWrite = value;
  }

  void setShouldThrowOnDelete(bool value) {
    _shouldThrowOnDelete = value;
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    if (_shouldThrowOnRead) {
      throw Exception('Simulated read failure');
    }
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    if (_shouldThrowOnWrite) {
      throw Exception('Simulated write failure');
    }
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    if (_shouldThrowOnDelete) {
      throw Exception('Simulated delete failure');
    }
    _storage.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    return Map.unmodifiable(_storage);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    if (_shouldThrowOnDelete) {
      throw Exception('Simulated deleteAll failure');
    }
    _storage.clear();
  }

  void reset() {
    _storage.clear();
    _shouldThrowOnRead = false;
    _shouldThrowOnWrite = false;
    _shouldThrowOnDelete = false;
  }

  String? getValue(String key) {
    return _storage[key];
  }

  void setValue(String key, String value) {
    _storage[key] = value;
  }
}
