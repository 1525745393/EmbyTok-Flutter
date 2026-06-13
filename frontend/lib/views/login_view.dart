// 登录页面：深色 TikTok 风格，粉紫色主题
// 功能：
//   1. 服务器地址输入（自动补全 http:// 和默认端口 8096）
//   2. 提交前服务器可达性验证（GET /System/Info/Public）
//   3. 用户名 + 密码登录
//   4. 友好的中文错误提示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../services/embbytok_service.dart';

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
  bool _passwordVisible = false;
  bool _isVerifying = false; // 正在验证服务器
  bool _isSubmitting = false; // 正在提交登录

  @override
  void dispose() {
    _embyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ——— 服务器地址自动补全 ———
  // 将用户输入的简化地址标准化为完整 URL：
  //   192.168.1.100        → http://192.168.1.100:8096
  //   192.168.1.100:8096   → http://192.168.1.100:8096
  //   http://192.168.1.100 → http://192.168.1.100:8096
  //   https://emby.example.com → 保持不变
  static String normalizeServerUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    // 1. 如果没有协议前缀，添加 http://
    String url = trimmed;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    // 2. 使用 Uri.parse 解析并补全端口
    try {
      final uri = Uri.parse(url);
      final scheme = uri.scheme;
      final host = uri.host;
      final port = uri.hasPort ? uri.port : 8096; // Emby 默认端口
      final path = uri.path.isEmpty ? '' : uri.path;
      return '$scheme://$host:$port$path';
    } catch (_) {
      // 解析失败：原样返回
      return url;
    }
  }

  // ——— 提交登录 ———
  Future<void> _submit() async {
    // 1. 表单字段验证
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 2. 服务器地址标准化
      final rawUrl = _embyController.text.trim();
      final normalizedUrl = normalizeServerUrl(rawUrl);
      if (mounted && normalizedUrl != rawUrl) {
        setState(() {
          _embyController.text = normalizedUrl;
        });
      }

      // 3. 服务器可达性验证（快速 ping）
      setState(() {
        _isVerifying = true;
      });
      try {
        final pingService = EmbytokService();
        await pingService.pingServer(normalizedUrl);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '无法连接到服务器：${e is String ? e : "请检查地址和网络"}',
              ),
              backgroundColor: Colors.orangeAccent,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '仍然登录',
                textColor: Colors.white,
                onPressed: () {
                  // 用户选择忽略验证，继续尝试登录
                  _doLogin(normalizedUrl);
                },
              ),
            ),
          );
        }
        setState(() {
          _isSubmitting = false;
          _isVerifying = false;
        });
        return;
      }
      setState(() {
        _isVerifying = false;
      });

      // 4. 实际登录
      await _doLogin(normalizedUrl);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _isVerifying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is String ? e : '登录失败：$e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ——— 执行实际登录操作 ———
  Future<void> _doLogin(String serverUrl) async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await ref.read(authProvider.notifier).login(
            serverUrl,
            username,
            password,
          );
      if (mounted) {
        // 登录成功，导航到主页
        context.go('/');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = _isSubmitting || authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
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
                  const Text(
                    'EmbyTok',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE91E63),
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '浏览你的私人媒体库',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Emby 服务器地址 + 自动补全提示
                  _buildTextField(
                    controller: _embyController,
                    label: 'Emby 服务器地址',
                    icon: Icons.dns_outlined,
                    hint: '192.168.1.100 或 https://emby.example.com',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 4),
                  // 提示文字：自动补全说明
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '提示：仅输入 IP 地址时将自动补全为 http://IP:8096',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 用户名
                  _buildTextField(
                    controller: _usernameController,
                    label: '用户名',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  // 密码
                  _buildTextField(
                    controller: _passwordController,
                    label: '密码',
                    icon: Icons.lock_outline,
                    obscureText: !_passwordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 登录按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
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
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isVerifying ? '正在连接服务器…' : '正在登录…',
                                ),
                              ],
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

  // 通用表单字段
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[900],
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: const Color(0xFFE91E63)),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE91E63)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入$label';
        }
        return null;
      },
    );
  }
}
