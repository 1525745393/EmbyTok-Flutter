// 登录页面：深色 TikTok 风格，粉紫色主题
// 优化：服务器历史、记住密码、HTTPS 提示、连接测试、键盘交互、错误提示

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// 保存的服务器凭据
class _SavedCredentials {
  final String serverUrl;
  final String username;
  final String password;

  const _SavedCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
      };

  factory _SavedCredentials.fromJson(Map<String, dynamic> json) {
    return _SavedCredentials(
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
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

  bool _passwordVisible = false;
  bool _rememberMe = false;
  List<String> _serverHistory = [];
  // 连接测试状态：null=未测试, true=成功, false=失败
  bool? _connectionStatus;
  bool _isTestingConnection = false;

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
    // 显式移除 listener 再 dispose，避免 dispose 过程中残留回调
    _serverFocusNode.removeListener(_onServerFocusChanged);
    _embyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _serverFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// 加载服务器历史和保存的凭据
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载服务器历史
      final history = prefs.getStringList(kStorageKeyServerHistory) ?? [];
      if (mounted) setState(() => _serverHistory = history);

      // 加载保存的凭据
      final saved = prefs.getString(kStorageKeySavedCredentials);
      if (saved != null && saved.isNotEmpty) {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        final creds = _SavedCredentials.fromJson(json);
        _embyController.text = creds.serverUrl;
        _usernameController.text = creds.username;
        _passwordController.text = creds.password;
        if (mounted) setState(() => _rememberMe = true);
      }
    } catch (e) {
      AppLogger.error('加载登录数据失败', error: e);
    }
  }

  /// 保存服务器地址到历史列表（去重，最多 5 个）
  Future<void> _saveServerHistory(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(kStorageKeyServerHistory) ?? [];
      history.remove(url);
      history.insert(0, url);
      if (history.length > 5) history.removeRange(5, history.length);
      await prefs.setStringList(kStorageKeyServerHistory, history);
      if (mounted) setState(() => _serverHistory = history);
    } catch (e) {
      AppLogger.error('保存服务器历史失败', error: e);
    }
  }

  /// 保存或清除凭据
  Future<void> _saveCredentials(String server, String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        final creds = _SavedCredentials(
          serverUrl: server,
          username: username,
          password: password,
        );
        await prefs.setString(kStorageKeySavedCredentials, jsonEncode(creds.toJson()));
      } else {
        await prefs.remove(kStorageKeySavedCredentials);
      }
    } catch (e) {
      AppLogger.error('保存凭据失败', error: e);
    }
  }

  /// 测试服务器连接（GET /System/Info/Public）
  Future<void> _testConnection() async {
    final url = _embyController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse('$url/System/Info/Public');
      final request = await client.getUrl(uri);
      final response = await request.close();
      client.close();
      if (mounted) {
        setState(() {
          _connectionStatus = response.statusCode == 200;
          _isTestingConnection = false;
        });
      }
    } catch (e) {
      // 记录错误详情便于排查，同时更新 UI 状态
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

  // 提交登录请求
  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final emby = _embyController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await ref.read(authProvider.notifier).login(emby, username, password);
      // 登录成功后保存历史和凭据
      await _saveServerHistory(emby);
      await _saveCredentials(emby, username, password);
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo 图标
                  Container(
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
                  const SizedBox(height: 16),
                  // 顶部大标题
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
                  const SizedBox(height: 24),

                  // 登录按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
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
                      child: isLoading
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

  /// 服务器历史记录快选
  Widget _buildServerHistory(ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _serverHistory.map((url) {
        return InputChip(
          label: Text(
            url,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          avatar: Icon(Icons.history, size: 14, color: scheme.onSurfaceVariant),
          backgroundColor: scheme.onSurface.withOpacity(0.05),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onPressed: () {
            _embyController.text = url;
            _testConnection();
            _usernameFocusNode.requestFocus();
          },
          onDeleted: () async {
            setState(() => _serverHistory.remove(url));
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(kStorageKeyServerHistory, _serverHistory);
          },
          deleteIconColor: scheme.onSurfaceVariant,
        );
      }).toList(),
    );
  }

  // 通用表单项
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
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      style: TextStyle(color: scheme.onSurface),
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
