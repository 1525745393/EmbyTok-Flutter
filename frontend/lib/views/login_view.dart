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
import '../services/api_client.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// 安全存储键名（仅用于凭据，服务器历史仍用 SharedPreferences）
const _kSecureKeyServer = 'embbytok_secure_server';
const _kSecureKeyUsername = 'embbytok_secure_username';
const _kSecureKeyPassword = 'embbytok_secure_password';

/// 服务器类型
enum ServerType {
  emby,
  plex,
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
      lastUsed: json['d'] != null
          ? DateTime.tryParse(json['d'] as String)
          : null,
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
  final _formKey = GlobalKey<FormState>();
  final _serverFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _secureStorage = const FlutterSecureStorage();

  bool _passwordVisible = false;
  bool _rememberMe = false;
  List<_ServerHistoryEntry> _serverHistory = [];

  // 连接测试状态：null=未测试, true=成功, false=失败
  bool? _connectionStatus;
  bool _isTestingConnection = false;

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
      _serverHistory.insert(0, _ServerHistoryEntry(url: url, lastUsed: DateTime.now()));
      // 最多保留 5 条
      if (_serverHistory.length > 5) {
        _serverHistory = _serverHistory.sublist(0, 5);
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
  Future<void> _saveCredentials(String server, String username, String password) async {
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

  /// 测试服务器连接：复用 ApiClient（Dio），替代原始 HttpClient
  Future<void> _testConnection() async {
    final url = _embyController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final apiClient = ApiClient(baseUrl: url);
      final response = await apiClient.get('/System/Info/Public');
      if (mounted) {
        setState(() {
          _connectionStatus = response.statusCode == 200;
          _isTestingConnection = false;
        });
      }
    } catch (e) {
      AppLogger.warn('连接测试失败', data: {'url': url, 'error': e.toString()});
      if (mounted) {
        setState(() {
          _connectionStatus = false;
          _isTestingConnection = false;
        });
      }
    }
  }

  /// 友好的错误提示
  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') || msg.contains('connection') || msg.contains('refused') || msg.contains('timeout')) {
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

  /// 提交登录：带防重复提交锁和内联错误提示
  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_formKey.currentState?.validate() != true) return;

    final emby = _embyController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).login(emby, username, password);
      await _saveServerHistory(emby);
      await _saveCredentials(emby, username, password);
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyError(e);
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
                    style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Emby 服务器地址
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
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
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

                  // 记住密码 + HTTP 安全提示
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
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
                        color: scheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: scheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: scheme.error, fontSize: 13),
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(scheme.onPrimary),
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
  bool _isHttpWarning() {
    final url = _embyController.text.trim().toLowerCase();
    return url.startsWith('http://') && !url.contains('localhost') && !url.contains('127.0.0.1') && !url.contains('192.168.');
  }

  /// 服务器地址输入框（带连接测试状态指示器）
  Widget _buildServerField(ColorScheme scheme) {
    return TextFormField(
      controller: _embyController,
      focusNode: _serverFocusNode,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.url],
      style: TextStyle(color: scheme.onSurface),
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surface,
        labelText: 'Emby 服务器地址',
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintText: 'http://192.168.1.1:8096',
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
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
            padding: EdgeInsets.only(bottom: index < _serverHistory.length - 1 ? 4 : 0),
            child: Material(
              color: scheme.onSurface.withOpacity(isFirst ? 0.06 : 0.03),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _embyController.text = entry.url;
                  _clearError();
                  _testConnection();
                  _usernameFocusNode.requestFocus();
                },
                onLongPress: () => _showDeleteConfirmDialog(index, scheme),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
                          padding: EdgeInsets.zero,
                          onPressed: () => _showDeleteConfirmDialog(index, scheme),
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
            color: const Color(0xFF52B54B).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.dns, size: 18, color: Color(0xFF52B54B)),
        );
      case ServerType.plex:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE5A00D).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_circle_outline, size: 18, color: Color(0xFFE5A00D)),
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
    ValueChanged<String>? onFieldSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      style: TextStyle(color: scheme.onSurface),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surface,
        labelText: label,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintText: hint,
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
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