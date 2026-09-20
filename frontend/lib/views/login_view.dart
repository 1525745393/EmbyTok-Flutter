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
import '../providers/service_mode_provider.dart';
import '../services/services.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
part 'login_view_builders.dart';
part 'login_view_actions.dart';

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
  _ServerHistoryEntry({
    required this.url,
    this.serverType = ServerType.emby,
    String? displayName,
    DateTime? lastUsed,
  })  : displayName = displayName ?? _extractHostPort(url),
        lastUsed = lastUsed ?? DateTime.now();

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
  final String url;
  final ServerType serverType;
  final String displayName;
  final DateTime lastUsed;

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
  /// 持久化服务器历史到 SharedPreferences
  /// 保存服务器地址到历史列表（去重，最多 5 个）
  /// 删除指定服务器历史条目
  /// 保存或清除凭据（使用 flutter_secure_storage 加密存储）
  /// 测试服务器连接：按服务器类型走不同探测端点
  /// 请求序号机制：快速切换服务器类型或反复失焦时，后发先至的过期结果被丢弃
  /// 友好的错误提示
  /// 提交登录：按服务器类型走对应认证流程，带防重复提交锁和内联错误提示
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
        isDefault:
            existing?.isDefault ?? ref.read(serverRegistryProvider).isEmpty,
        lastUsed: DateTime.now(),
      );
      if (existing != null) {
        await registry.update(profile, password: password, synoSid: synoSid);
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
  /// 切换服务器类型：重置连接测试与两步验证状态
  /// 服务器类型选择：图标卡片网格（先选类型，再填信息）
  ///
  /// 设计参考：AudioDock / AuthPortal —— 用卡片直观区分视频服务与音乐服务，
  /// 选中态以主题色边框 + 背景 + 勾选角标标识，表单随选择动态适配。
  /// 服务器地址输入框（带连接测试状态指示器）
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
      return const Icon(Icons.check_circle, color: Colors.green, size: 22);
    }
    if (_connectionStatus == false) {
      return Icon(Icons.cancel, color: scheme.error, size: 22);
    }
    return null;
  }

  /// 服务器历史记录 — 卡片式列表，含服务器类型图标、友好名称和删除确认
  /// 服务器类型图标
  /// 删除确认弹窗
  /// 通用表单项
}
