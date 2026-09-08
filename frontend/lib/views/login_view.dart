// 登录页面：深色 TikTok 风格，粉紫色主题
// 优化：服务器历史（友好名称 + 类型图标 + 删除确认）、连接测试、键盘交互、内联错误提示
// 安全：密码通过 flutter_secure_storage 加密存储，防重复提交锁

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/providers.dart';
import '../providers/server_registry_provider.dart';
import '../services/api_client.dart';
import '../services/services.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// 安全存储键名（仅用于凭据，服务器历史仍用 SharedPreferences）
const _kSecureKeyServer = 'embytok_secure_server';
const _kSecureKeyUsername = 'embytok_secure_username';
const _kSecureKeyPassword = 'embytok_secure_password';

/// 服务器历史最大保留条数
const _kMaxServerHistory = 5;

/// 服务器类型
enum ServerType {
  emby,
  plex,
  synology,
}

/// 服务器历史记录条目
class _ServerHistoryEntry {
  final String url;
  final ServerType serverType;
  final String displayName;
  final DateTime lastUsed;

  _ServerHistoryEntry({
    required this.url,
    this.serverType = ServerType.emby,
    String? displayName,
    DateTime? lastUsed,
  })  : displayName = displayName ?? _extractHostPort(url),
        lastUsed = lastUsed ?? DateTime.now();

  /// 从 URL 提取 host:port 作为显示名称
  static String _extractHostPort(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '$host$port';
    } catch (_) {
      return url;
    }
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        't': serverType.name,
        'n': displayName,
        'd': lastUsed.toIso8601String(),
      };

  factory _ServerHistoryEntry.fromJson(Map<String, dynamic> json) {
    return _ServerHistoryEntry(
      url: json['url'] as String? ?? '',
      serverType: ServerType.values.firstWhere(
        (e) => e.name == (json['t'] as String?),
        orElse: () => ServerType.emby,
      ),
      displayName: json['n'] as String?,
      lastUsed:
          json['d'] != null ? DateTime.tryParse(json['d'] as String) : null,
    );
  }
}

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _embyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _serverFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _secureStorage = const FlutterSecureStorage();

  bool _passwordVisible = false;
  bool _rememberMe = false;
  List<_ServerHistoryEntry> _serverHistory = [];

  // 当前选择的服务器类型（Emby / 群晖 Audio Station）
  ServerType _serverType = ServerType.emby;

  // 群晖两步验证：是否显示 OTP 输入框
  bool _otpRequired = false;

  // 连接测试状态：null=未测试, true=成功, false=失败
  bool? _connectionStatus;
  bool _isTestingConnection = false;
  // 连接测试请求序号：防止快速切换服务器类型时在途请求乱序覆盖结果
  int _testConnSeq = 0;

  // 防重复提交锁 & 内联错误提示
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    // 服务器地址失焦时自动测试连接
    _serverFocusNode.addListener(_onServerFocusChanged);
  }

  /// 服务器输入框焦点变化回调：失焦且地址非空时自动测试连接
  void _onServerFocusChanged() {
    if (!_serverFocusNode.hasFocus && _embyController.text.trim().isNotEmpty) {
      _testConnection();
    }
  }

  @override
  void dispose() {
    _serverFocusNode.removeListener(_onServerFocusChanged);
    _embyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _serverFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// 加载服务器历史（SharedPreferences）和凭据（安全存储）
  /// 兼容旧格式（纯 URL 字符串）和新格式（JSON 字符串）
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载服务器历史 — 尝试新格式，回退到旧格式并迁移
      final rawHistory = prefs.getStringList(kStorageKeyServerHistory) ?? [];
      final entries = <_ServerHistoryEntry>[];
      bool needsMigration = false;

      for (final raw in rawHistory) {
        if (raw.startsWith('{')) {
          // 新格式：JSON 字符串
          try {
            final json = jsonDecode(raw) as Map<String, dynamic>;
            entries.add(_ServerHistoryEntry.fromJson(json));
          } catch (_) {
            // 损坏的 JSON，跳过
          }
        } else {
          // 旧格式：纯 URL 字符串，自动迁移
          entries.add(_ServerHistoryEntry(url: raw));
          needsMigration = true;
        }
      }

      // 从安全存储加载凭据
      final server = await _secureStorage.read(key: _kSecureKeyServer);
      final username = await _secureStorage.read(key: _kSecureKeyUsername);
      final password = await _secureStorage.read(key: _kSecureKeyPassword);

      if (mounted) {
        setState(() {
          _serverHistory = entries;
          if (server != null && server.isNotEmpty) {
            _embyController.text = server;
            _usernameController.text = username ?? '';
            _passwordController.text = password ?? '';
            _rememberMe = true;
          }
        });
      }

      // 旧格式迁移：保存为新格式
      if (needsMigration) {
        await _persistHistory();
      }
    } catch (e) {
      AppLogger.error('加载登录数据失败', error: e);
    }
  }

  /// 持久化服务器历史到 SharedPreferences
  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _serverHistory.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(kStorageKeyServerHistory, raw);
    } catch (e) {
      AppLogger.error('保存服务器历史失败', error: e);
    }
  }

  /// 保存服务器地址到历史列表（去重，最多 5 个）
  Future<void> _saveServerHistory(String url) async {
    try {
      // 移除同 URL 的旧条目
      _serverHistory.removeWhere((e) => e.url == url);
      // 插入到最前面
      _serverHistory.insert(
          0, _ServerHistoryEntry(url: url, lastUsed: DateTime.now()));
      // 最多保留 _kMaxServerHistory 条
      if (_serverHistory.length > _kMaxServerHistory) {
        _serverHistory = _serverHistory.sublist(0, _kMaxServerHistory);
      }
      await _persistHistory();
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.error('保存服务器历史失败', error: e);
    }
  }

  /// 删除指定服务器历史条目
  Future<void> _deleteHistoryEntry(int index) async {
    setState(() => _serverHistory.removeAt(index));
    await _persistHistory();
  }

  /// 保存或清除凭据（使用 flutter_secure_storage 加密存储）
  Future<void> _saveCredentials(
      String server, String username, String password) async {
    try {
      if (_rememberMe) {
        await _secureStorage.write(key: _kSecureKeyServer, value: server);
        await _secureStorage.write(key: _kSecureKeyUsername, value: username);
        await _secureStorage.write(key: _kSecureKeyPassword, value: password);
      } else {
        await Future.wait([
          _secureStorage.delete(key: _kSecureKeyServer),
          _secureStorage.delete(key: _kSecureKeyUsername),
          _secureStorage.delete(key: _kSecureKeyPassword),
        ]);
      }
    } catch (e) {
      AppLogger.error('保存凭据失败', error: e);
    }
  }

  /// 测试服务器连接：按服务器类型走不同探测端点
  /// 请求序号机制：快速切换服务器类型或反复失焦时，后发先至的过期结果被丢弃
  Future<void> _testConnection() async {
    final url = _embyController.text.trim();
    if (url.isEmpty) return;

    final seq = ++_testConnSeq;
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final apiClient = ApiClient(baseUrl: url);
      final ok = switch (_serverType) {
        ServerType.emby ||
        ServerType.plex =>
          (await apiClient.get<dynamic>('/System/Info/Public'))
                  .statusCode ==
              200,
        // 群晖：查询 Audio Station 服务信息（info.cgi）
        ServerType.synology =>
          (await apiClient.get<dynamic>(
            '/webapi/AudioStation/info.cgi',
            queryParameters: {
              'api': 'SYNO.AudioStation.Info',
              'version': 1,
              'method': 'getinfo',
            },
          ))
                  .statusCode ==
              200,
      };
      if (!mounted || seq != _testConnSeq) return; // 过期或已卸载，丢弃
      setState(() {
        _connectionStatus = ok;
        _isTestingConnection = false;
      });
    } catch (e) {
      AppLogger.warn('连接测试失败', data: {'url': url, 'error': e.toString()});
      if (!mounted || seq != _testConnSeq) return; // 过期或已卸载，丢弃
      setState(() {
        _connectionStatus = false;
        _isTestingConnection = false;
      });
    }
  }

  /// 友好的错误提示
  String _friendlyError(dynamic e) {
    // 群晖两步验证：提示输入验证码并显示 OTP 输入框
    if (e is SynologyOtpRequiredException) {
      return '该账号开启了两步验证，请输入验证码';
    }
    // 群晖认证异常：直接展示可读信息（含错误码）
    if (e is SynologyAuthException) {
      return e.message;
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('refused') ||
        msg.contains('timeout')) {
      return '无法连接到服务器，请检查地址和网络';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return '用户名或密码错误';
    }
    if (msg.contains('404') || msg.contains('not found')) {
      return '服务器地址不正确';
    }
    if (msg.contains('ssl') || msg.contains('certificate')) {
      return 'SSL 证书验证失败';
    }
    return e is String ? e : '登录失败：$e';
  }

  /// 提交登录：按服务器类型走对应认证流程，带防重复提交锁和内联错误提示
  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_formKey.currentState?.validate() != true) return;

    final server = _embyController.text.trim().replaceAll(RegExp(r'/+$'), '');
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final otp = _otpController.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_serverType == ServerType.synology) {
        // 群晖 Audio Station：独立认证（sid 会话）
        await ref.read(synologyAuthProvider.notifier).login(
              serverUrl: server,
              account: username,
              password: password,
              otpCode: otp.isEmpty ? null : otp,
            );
      } else {
        await ref.read(authProvider.notifier).login(server, username, password);
      }
      await _saveServerHistory(server);
      await _saveCredentials(server, username, password);
      // 写入服务器注册表（多服务器管理），rememberMe 时保存密码
      final synoSid =
          _serverType == ServerType.synology ? ref.read(synologyAuthProvider).sid : null;
      final registrySaved = await _saveToRegistry(
        server: server,
        username: username,
        password: _rememberMe ? password : null,
        synoSid: _serverType == ServerType.synology ? synoSid : null,
      );
      if (!registrySaved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('服务器配置保存失败，可在设置 → 服务器管理中手动添加')),
        );
      }
      if (mounted) {
        // 群晖登录成功 → 进入音乐页；Emby/Plex → 首页
        context.go(_serverType == ServerType.synology ? '/music' : '/');
      }
    } catch (e) {
      AppLogger.warn('登录失败',
          data: {'type': _serverType.name, 'server': server, 'error': e.toString()});
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyError(e);
          // 两步验证开启：显示 OTP 输入框
          if (e is SynologyOtpRequiredException) {
            _otpRequired = true;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 登录成功后写入服务器注册表（已存在则更新），并设为激活
  /// 返回 true 表示写入成功，false 表示失败（调用方应提示用户）
  Future<bool> _saveToRegistry({
    required String server,
    required String username,
    String? password,
    String? synoSid,
  }) async {
    try {
      final kind = switch (_serverType) {
        ServerType.emby => ServerKind.emby,
        ServerType.plex => ServerKind.plex,
        ServerType.synology => ServerKind.synology,
      };
      final registry = ref.read(serverRegistryProvider.notifier);
      final host = _hostOf(server);
      ServerProfile? existing;
      for (final s in ref.read(serverRegistryProvider)) {
        if (s.kind == kind && s.username == username && s.url.contains(host)) {
          existing = s;
          break;
        }
      }
      final profile = ServerProfile(
        id: existing?.id ?? 'srv_${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        name: existing?.name ?? _extractHostPortName(server),
        url: existing?.url ?? server,
        internalUrl: existing?.internalUrl,
        externalUrl: existing?.externalUrl,
        username: username,
        networkMode: existing?.networkMode ?? NetworkMode.auto,
        isDefault: existing?.isDefault ?? ref.read(serverRegistryProvider).isEmpty,
        lastUsed: DateTime.now(),
      );
      if (existing != null) {
        await registry.update(profile,
            password: password, synoSid: synoSid);
      } else {
        await registry.add(profile, password: password, synoSid: synoSid);
      }
      // 设为当前激活服务器
      await ref.read(activeServerIdProvider.notifier).setActive(profile.id);
      return true;
    } catch (e) {
      AppLogger.error('写入服务器注册表失败', error: e);
      return false;
    }
  }

  /// 从 URL 提取 host:port 作为默认显示名
  static String _extractHostPortName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }

  /// 提取 host（用于匹配已有服务器）
  static String _hostOf(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  /// 清除内联错误（用户修改输入时调用）
  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 32,
              right: 32,
              top: 48,
              bottom: 48 + bottomInset,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo 图标（居中）
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 应用标题
                  Text(
                    'EmbyTok',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '浏览你的私人媒体库',
                    style:
                        TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // 服务器类型选择（先选类型，再填信息）：
                  // 卡片网格 —— 视频服务（Emby/Plex） / 音乐服务（群晖 Audio Station）
                  _buildServerTypeSelector(scheme),
                  const SizedBox(height: 16),

                  // 服务器地址
                  _buildServerField(scheme),
                  if (_serverHistory.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildServerHistory(scheme),
                  ],
                  const SizedBox(height: 16),

                  // 用户名
                  _buildTextField(
                    scheme: scheme,
                    controller: _usernameController,
                    label: '用户名',
                    icon: Icons.person_outline,
                    focusNode: _usernameFocusNode,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 16),

                  // 密码
                  _buildTextField(
                    scheme: scheme,
                    controller: _passwordController,
                    label: '密码',
                    icon: Icons.lock_outline,
                    focusNode: _passwordFocusNode,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    onChanged: (_) => _clearError(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 群晖两步验证码（开启后显示）
                  if (_serverType == ServerType.synology && _otpRequired) ...[
                    _buildTextField(
                      scheme: scheme,
                      controller: _otpController,
                      label: '验证码（两步验证）',
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      onFieldSubmitted: (_) => _submit(),
                      onChanged: (_) => _clearError(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 记住密码 + HTTP 安全提示
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        activeColor: scheme.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('记住密码'),
                      const Spacer(),
                      if (_isHttpWarning())
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: scheme.error, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'HTTP 不安全',
                              style: TextStyle(
                                color: scheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // 内联错误提示
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: scheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: scheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style:
                                  TextStyle(color: scheme.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 登录按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isLoading || _isSubmitting) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: (isLoading || _isSubmitting)
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    scheme.onPrimary),
                              ),
                            )
                          : const Text('登录'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 判断是否为 HTTP（非 HTTPS）以显示安全提示
  /// 私网段（10/8, 172.16/12, 192.168/16）与回环地址不警告
  bool _isHttpWarning() {
    final url = _embyController.text.trim().toLowerCase();
    if (!url.startsWith('http://')) return false;
    try {
      final host = Uri.parse(url).host;
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return false;
      }
      // 10.0.0.0/8
      if (host.startsWith('10.')) return false;
      // 192.168.0.0/16
      if (host.startsWith('192.168.')) return false;
      // 172.16.0.0/12（172.16.x.x – 172.31.x.x）
      if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host)) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 切换服务器类型：重置连接测试与两步验证状态
  void _onServerTypeChanged(ServerType type) {
    if (type == _serverType) return;
    // 使在途连接测试失效，避免旧类型结果覆盖新类型状态
    _testConnSeq++;
    setState(() {
      _serverType = type;
      _connectionStatus = null;
      _isTestingConnection = false;
      // 切换服务器类型时重置两步验证状态
      _otpRequired = false;
      _otpController.clear();
    });
  }

  /// 服务器类型选择：图标卡片网格（先选类型，再填信息）
  ///
  /// 设计参考：AudioDock / AuthPortal —— 用卡片直观区分视频服务与音乐服务，
  /// 选中态以主题色边框 + 背景 + 勾选角标标识，表单随选择动态适配。
  Widget _buildServerTypeSelector(ColorScheme scheme) {
    // 注意：登录表单在 SingleChildScrollView 内，垂直方向无界，
    // 不能使用 crossAxisAlignment.stretch（需要有限高度），用默认 center
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildServerTypeCard(
            scheme: scheme,
            type: ServerType.emby,
            title: 'Emby 视频',
            subtitle: 'Emby / Plex 视频流',
            icon: Icons.movie_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildServerTypeCard(
            scheme: scheme,
            type: ServerType.synology,
            title: '群晖音乐',
            subtitle: 'Audio Station 音乐库',
            icon: Icons.library_music_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildServerTypeCard({
    required ColorScheme scheme,
    required ServerType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _serverType == type;
    return GestureDetector(
      onTap: () => _onServerTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 30,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            // 选中角标（未选中时占位保持高度一致，避免卡片跳动）
            selected
                ? Icon(Icons.check_circle, size: 16, color: scheme.primary)
                : const SizedBox(
                    height: 16,
                    width: 16,
                    child: Icon(Icons.check_circle,
                        size: 16, color: Colors.transparent),
                  ),
          ],
        ),
      ),
    );
  }

  /// 服务器地址输入框（带连接测试状态指示器）
  Widget _buildServerField(ColorScheme scheme) {
    final isSyno = _serverType == ServerType.synology;
    return TextFormField(
      controller: _embyController,
      focusNode: _serverFocusNode,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.url],
      style: TextStyle(color: scheme.onSurface),
      onChanged: (_) {
        // 服务器地址变化时总是 rebuild：更新 HTTP 警告与连接状态
        _clearError();
        setState(() {});
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surface,
        labelText: isSyno ? '群晖服务器地址' : 'Emby 服务器地址',
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintText: isSyno ? 'http://192.168.1.100:5000' : 'http://192.168.1.1:8096',
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
        prefixIcon: Icon(Icons.dns_outlined, color: scheme.primary),
        suffixIcon: _buildConnectionIndicator(scheme),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _connectionStatus == false
                ? scheme.error
                : _connectionStatus == true
                    ? Colors.green
                    : scheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入服务器地址';
        }
        if (!value.trim().startsWith('http://') &&
            !value.trim().startsWith('https://')) {
          return '地址需以 http:// 或 https:// 开头';
        }
        return null;
      },
      onFieldSubmitted: (_) => _usernameFocusNode.requestFocus(),
    );
  }

  /// 连接状态指示器
  Widget? _buildConnectionIndicator(ColorScheme scheme) {
    if (_isTestingConnection) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
      );
    }
    if (_connectionStatus == true) {
      return Icon(Icons.check_circle, color: Colors.green, size: 22);
    }
    if (_connectionStatus == false) {
      return Icon(Icons.cancel, color: scheme.error, size: 22);
    }
    return null;
  }

  /// 服务器历史记录 — 卡片式列表，含服务器类型图标、友好名称和删除确认
  Widget _buildServerHistory(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '最近使用',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        ...List.generate(_serverHistory.length, (index) {
          final entry = _serverHistory[index];
          final isFirst = index == 0;
          return Padding(
            padding: EdgeInsets.only(
                bottom: index < _serverHistory.length - 1 ? 4 : 0),
            child: Material(
              color: scheme.onSurface.withValues(alpha: isFirst ? 0.06 : 0.03),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _embyController.text = entry.url;
                  // 恢复该服务器上次使用的类型
                  if (entry.serverType != _serverType) {
                    setState(() => _serverType = entry.serverType);
                  }
                  _clearError();
                  _testConnection();
                  _usernameFocusNode.requestFocus();
                },
                onLongPress: () => _showDeleteConfirmDialog(index, scheme),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // 服务器类型图标
                      _buildServerTypeIcon(entry.serverType, scheme),
                      const SizedBox(width: 10),
                      // 服务器信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (entry.url != entry.displayName)
                              Text(
                                entry.url,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 删除按钮
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: Icon(Icons.close,
                              size: 16, color: scheme.onSurfaceVariant),
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              _showDeleteConfirmDialog(index, scheme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 服务器类型图标
  Widget _buildServerTypeIcon(ServerType type, ColorScheme scheme) {
    switch (type) {
      case ServerType.emby:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF52B54B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.dns, size: 18, color: Color(0xFF52B54B)),
        );
      case ServerType.plex:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE5A00D).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_circle_outline,
              size: 18, color: Color(0xFFE5A00D)),
        );
      case ServerType.synology:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2C8EF4).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.library_music_outlined,
              size: 18, color: Color(0xFF2C8EF4)),
        );
    }
  }

  /// 删除确认弹窗
  Future<void> _showDeleteConfirmDialog(int index, ColorScheme scheme) async {
    final entry = _serverHistory[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: const Text('删除服务器'),
        content: Text(
          '确定要删除 "${entry.displayName}" 吗？',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _deleteHistoryEntry(index);
    }
  }

  /// 通用表单项
  Widget _buildTextField({
    required ColorScheme scheme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    TextInputType? keyboardType,
    ValueChanged<String>? onFieldSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      style: TextStyle(color: scheme.onSurface),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surface,
        labelText: label,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintText: hint,
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: scheme.primary),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入$label';
        }
        return null;
      },
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
