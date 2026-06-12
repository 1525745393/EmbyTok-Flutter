// 登录页面：深色 TikTok 风格，粉紫色主题

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';

// 登录页面：ConsumerWidget 直接读取 authProvider 状态
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  // 表单控制器：后端代理地址、Emby 服务器地址、用户名、密码
  final _backendController = TextEditingController(text: 'http://localhost:8000');
  final _embyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _passwordVisible = false;

  @override
  void dispose() {
    _backendController.dispose();
    _embyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 提交登录请求
  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final backend = _backendController.text.trim();
    final emby = _embyController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await ref.read(authProvider.notifier).login(emby, backend, username, password);
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is String ? e : '登录失败：$e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听 authProvider 的 loading 与 error 状态
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

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
                  // 顶部大标题
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

                  // 后端代理地址
                  _buildTextField(
                    controller: _backendController,
                    label: '后端代理地址',
                    icon: Icons.cloud_outlined,
                    hint: 'http://localhost:8000',
                  ),
                  const SizedBox(height: 16),

                  // Emby 服务器地址
                  _buildTextField(
                    controller: _embyController,
                    label: 'Emby 服务器地址',
                    icon: Icons.dns_outlined,
                    hint: 'https://your-emby-server.example.com',
                  ),
                  const SizedBox(height: 16),

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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  // 通用表单项：圆角灰色背景 + 前缀图标 + 下划线文字
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
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
