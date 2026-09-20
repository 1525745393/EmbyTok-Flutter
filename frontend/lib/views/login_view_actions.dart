// 从 login_view.dart 拆分（part 文件，无行为变化）

part of 'login_view.dart';

// ==================== 登录动作与持久化 ====================

extension _LoginViewActions on _LoginViewState {
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

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _serverHistory.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(kStorageKeyServerHistory, raw);
    } catch (e) {
      AppLogger.error('保存服务器历史失败', error: e);
    }
  }

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

  Future<void> _deleteHistoryEntry(int index) async {
    setState(() => _serverHistory.removeAt(index));
    await _persistHistory();
  }

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
          (await apiClient.get<dynamic>('/System/Info/Public')).statusCode ==
              200,
        // 群晖：查询 Audio Station 服务信息（info.cgi）
        ServerType.synology => (await apiClient.get<dynamic>(
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
      final synoSid = _serverType == ServerType.synology
          ? ref.read(synologyAuthProvider).sid
          : null;
      final registrySaved = await _saveToRegistry(
        server: server,
        username: username,
        password: _rememberMe ? password : null,
        synoSid: _serverType == ServerType.synology ? synoSid : null,
      );
      if (!registrySaved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务器配置保存失败，可在设置 → 服务器管理中手动添加')),
        );
      }
      if (mounted) {
        // 群晖登录成功：音乐模式下首页即音乐库（无返回按钮），视频模式下进 /music
        if (_serverType == ServerType.synology) {
          final mode = ref.read(serviceModeProvider);
          context.go(mode == AppServiceMode.music ? '/' : '/music');
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      AppLogger.warn('登录失败', data: {
        'type': _serverType.name,
        'server': server,
        'error': e.toString()
      });
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

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

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

  void _onServerFocusChanged() {
    if (!_serverFocusNode.hasFocus && _embyController.text.trim().isNotEmpty) {
      _testConnection();
    }
  }
}
