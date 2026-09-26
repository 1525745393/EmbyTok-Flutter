// 从 settings_builders.dart 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== 设置项构建（下半） ====================

extension _SettingsBuilders2 on SettingsView {
  Widget _buildServerRegistryTile(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serverRegistryProvider);
    final active = ref.watch(activeServerProvider);
    return settingsTapTile(
      icon: Icons.dns_outlined,
      iconColor: Colors.blueGrey,
      title: '服务器管理',
      subtitle: servers.isEmpty
          ? '配置 Emby / 群晖等多台服务器并快速切换'
          : '${servers.length} 台服务器 · 当前：${active?.name ?? '未激活'}',
      onTap: () => context.push('/servers'),
      helpText:
          '管理已配置的服务器（Emby / Jellyfin / 群晖 Audio Station 等）。\n\n· 查看已添加的服务器列表与状态\n· 添加、编辑、删除服务器\n· 快速切换当前使用的服务器\n\n切换服务器后，媒体库/登录状态跟随切换。',
    );
  }

  Widget _buildServiceModeSelector(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(serviceModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<AppServiceMode>(
            segments: [
              for (final m in AppServiceMode.values)
                ButtonSegment(
                  value: m,
                  label: Text(m.label),
                  icon: Icon(m.icon, size: 16),
                ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) async {
              final next = selection.first;
              if (next == mode) return;
              await ref.read(serviceModeProvider.notifier).setMode(next);
              if (!context.mounted) return;
              // 切换模式后回到首页，立即展示对应界面
              context.go('/');
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: _kFontSizeBody)),
            ),
          ),
          const SizedBox(height: _kSpacingMedium),
          Text(
            mode == AppServiceMode.music
                ? '首页将显示音乐库界面（群晖 Audio Station）'
                : '首页将显示视频流界面（Emby / Plex）',
            style: TextStyle(
                fontSize: _kFontSizeSmall, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleScopeHint(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Text(
        '以下规则按 推荐 / 关注 / 发现 页面分类设置。'
        '媒体库、标签等数据源修改后实时生效；评分、时长等规则在刷新页面后生效。',
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSharedRuleHint(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Text(
        '评分阈值 / 最短时长 / 包含类型 / 排除已观看 等规则与推荐页共用同一开关，'
        '一个设置同时作用于关注页。',
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildServerGroupLabel(
    BuildContext context,
    WidgetRef ref,
    String label,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: _kFontSizeSmall,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerInfoTile(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return settingsInfoTile(
      icon: Icons.cloud_outlined,
      iconColor: Colors.blue,
      title: '当前服务器',
      subtitle: auth.backendUrl ?? '未连接',
      helpText:
          '当前正在使用的服务器地址。\n\n如需切换或添加服务器，请使用上方「服务器管理」入口。\n\n服务器切换后，媒体库、推荐与收藏内容都会跟随当前服务器变化。',
    );
  }

  Widget _buildSynologyMusicTile(BuildContext context, WidgetRef ref) {
    final synoAuth = ref.watch(synologyAuthProvider);
    return settingsTapTile(
      icon: Icons.library_music_outlined,
      iconColor: const Color(0xFF2C8EF4),
      title: '群晖音乐',
      subtitle: synoAuth.isLoggedIn
          ? (synoAuth.account ?? '已登录')
          : '连接群晖 NAS Audio Station',
      onTap: () => context.push('/music'),
      helpText:
          '配置群晖 Audio Station 音乐服务。\n\n· 填写服务器地址、账号密码\n· 用于音乐服务模式下的音乐库浏览与播放\n\n需要群晖开启 Audio Station 并授予当前用户访问权限。',
    );
  }

  Widget _buildLastFmTile(BuildContext context, WidgetRef ref) {
    final keyAsync = ref.watch(lastfmApiKeyAsyncProvider);
    final configured = (keyAsync.valueOrNull ?? '').isNotEmpty;
    return settingsTapTile(
      icon: Icons.graphic_eq,
      iconColor: const Color(0xFFD51007),
      title: 'Last.fm 补充',
      subtitle:
          configured ? '已配置：歌手头像/简介优先用 Last.fm' : '配置 API Key，补充歌手图与简介（免费）',
      onTap: () =>
          _showLastFmKeyDialog(context, ref, keyAsync.valueOrNull ?? ''),
      helpText:
          '配置 Last.fm 服务（可选）。\n\n用于获取歌手头像、简介等补充信息，丰富歌手详情页。\n\n· 需要注册 Last.fm API Key\n· 未配置时歌手详情仅显示服务器已有信息',
    );
  }

  Widget _buildNasMetadataSyncTile(BuildContext context, WidgetRef ref) {
    final service = ref.read(artistMetadataServiceProvider);
    final isLoggedIn = ref.read(synologyAuthProvider).isLoggedIn;

    return settingsSwitchTile(
      icon: Icons.cloud_sync_outlined,
      iconColor: Colors.teal,
      title: 'NAS 元数据同步',
      subtitle: service.nasSyncEnabled
          ? '已开启：歌手简介/头像同步到群晖，多设备共享'
          : '开启后同步到 NAS（需先登录群晖）',
      value: service.nasSyncEnabled,
      onChanged: (value) {
        if (!isLoggedIn) return;
        service.nasSyncEnabled = value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'NAS 元数据同步已开启' : 'NAS 元数据同步已关闭'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      helpText:
          '开启后，自动同步 NAS（群晖）音乐库的元数据（歌手、专辑、曲目信息）。\n\n· 开启 → 音乐库信息保持最新（同步耗时）\n· 关闭 → 仅使用本地缓存（更快但可能滞后）\n\n首次配置后建议开启一次完成全量同步。',
    );
  }

  void _showLastFmKeyDialog(
      BuildContext context, WidgetRef ref, String currentKey) {
    final controller = TextEditingController(text: currentKey);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Last.fm API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '免费申请：https://www.last.fm/api/account/create',
                style: TextStyle(fontSize: _kFontSizeSmall),
              ),
              const SizedBox(height: _kSpacingXSmall),
              const Text(
                '用于补充歌手头像与简介（未配置时自动使用群晖/Wikipedia 数据）',
                style: TextStyle(fontSize: _kFontSizeSmall),
              ),
              const SizedBox(height: _kSpacingXLarge),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: '如：xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                autocorrect: false,
                enableSuggestions: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final saved = await saveLastFmApiKey(controller.text.trim());
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(saved ? 'Last.fm API Key 已保存' : '保存失败，请重试'),
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.info_outline,
      iconColor: Colors.blueGrey,
      title: '关于 EmbyTok',
      subtitle: '了解更多关于应用的信息',
      onTap: () => _showAboutDialog(context, ref),
      helpText:
          '关于页包含：\n\n· 应用简介与当前版本\n· 开源许可证列表\n· 项目 GitHub 仓库与联系方式\n\n如需反馈问题或查看源码，可在此找到入口。',
    );
  }

  Widget _buildCheckUpdateTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.system_update_outlined,
      iconColor: Colors.green,
      title: '检查更新',
      subtitle: '检查是否有新版本',
      onTap: () => _checkForUpdate(context, ref),
      helpText:
          '检查是否有新版本。\n\n· 自动检测 GitHub Releases 最新版本\n· 发现新版本可一键下载安装包\n\n国内网络下载失败时，可稍后重试或使用代理。',
    );
  }

  Widget _buildDonateTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.volunteer_activism_outlined,
      iconColor: Colors.red,
      title: '打赏支持',
      subtitle: '请作者喝杯咖啡',
      onTap: () => _showDonateDialog(context),
      helpText: '支持开发者：查看捐赠方式。\n\n捐赠是自愿行为，不影响任何功能使用。',
    );
  }

  Widget _buildFeedbackTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.feedback_outlined,
      iconColor: Colors.orange,
      title: '意见反馈',
      subtitle: '通过邮件反馈问题或建议',
      onTap: () async {
        final uri = Uri(
          scheme: 'mailto',
          path: 'support@embytok.app',
          queryParameters: {'subject': 'EmbyTok 意见反馈'},
        );
        try {
          await launchUrl(uri);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('未找到邮件应用')),
            );
          }
        }
      },
      helpText: '提交使用反馈或问题报告。\n\n建议附上：设备型号、App 版本、操作步骤、是否可复现，以及导出日志内容，便于快速定位。',
    );
  }

  Widget _buildVersionTile(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final subtitle = versionAsync.when(
      data: (v) => v,
      loading: () => '加载中…',
      error: (_, __) => '未知',
    );
    return settingsInfoTile(
      icon: Icons.new_releases_outlined,
      iconColor: Colors.blueGrey,
      title: '版本',
      subtitle: subtitle,
      helpText:
          '当前 App 版本与构建号。\n\n版本格式：主版本.次版本.修订号+构建号\n· 修订号 +1 → 小修复\n· 次版本 +1 → 新功能\n\n如发现新版本无法下载，可到「检查更新」重试。\n\n（debug 构建连续点击 5 次可进入测试模式）',
      onTap: () => _handleVersionTap(context),
    );
  }

  void _handleVersionTap(BuildContext context) {
    if (!isAppTestMode) return;
    _versionTapCount++;
    _versionTapResetTimer?.cancel();
    _versionTapResetTimer = Timer(const Duration(milliseconds: kTestModeTapResetMs), () {
      _versionTapCount = 0;
    });
    HapticFeedback.lightImpact();
    if (_versionTapCount >= kTestModeTapThreshold) {
      _versionTapCount = 0;
      _versionTapResetTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('进入测试模式')),
      );
      context.push('/test-mode');
    } else {
      final remaining = kTestModeTapThreshold - _versionTapCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再点 $remaining 次进入测试模式'), duration: const Duration(milliseconds: 800)),
      );
    }
  }

  Widget _buildPerformanceMonitorTile(BuildContext context, WidgetRef ref) {
    final enabled = PerformanceMonitor.instance.enabled;
    return settingsSwitchTile(
      icon: Icons.analytics_outlined,
      iconColor: Colors.purple,
      title: '性能监控面板',
      subtitle: enabled ? '已开启：悬浮显示内存/FPS/重建次数/API 请求' : '已关闭：开发调试用，不影响发布版本',
      value: enabled,
      onChanged: (value) {
        if (value) {
          PerformanceMonitor.instance.enable();
        } else {
          PerformanceMonitor.instance.disable();
        }
        // 提示用户
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '性能监控面板已开启' : '性能监控面板已关闭'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      helpText: '开启后显示实时性能监控（帧率、内存占用等）。\n\n· 调试用，日常可关闭\n· 开启会略微增加系统开销',
    );
  }

  Widget _buildProfileTile(BuildContext context, WidgetRef ref) {
    // 音乐模式显示群晖账户，视频模式显示 Emby 账户
    if (ref.read(serviceModeProvider) == AppServiceMode.music) {
      final syno = ref.watch(synologyAuthProvider);
      return settingsInfoTile(
        icon: Icons.account_circle_outlined,
        iconColor: Colors.blue,
        title: syno.account ?? (syno.isLoggedIn ? '群晖账号' : '未登录'),
        subtitle: syno.serverUrl ?? '未连接群晖 NAS',
        helpText:
            '当前登录的账号信息（音乐模式）。\n\n· 显示群晖 Audio Station 账号与 NAS 地址\n· 信息不符时，可到「服务器管理」重新登录或切换服务器',
      );
    }
    final auth = ref.watch(authProvider);
    final name = auth.user?.name ?? '未登录';
    return settingsInfoTile(
      icon: Icons.account_circle_outlined,
      iconColor: Colors.blue,
      title: name,
      subtitle: auth.backendUrl ?? '未连接服务器',
      helpText:
          '当前登录的账号信息（视频模式）。\n\n· 显示 Emby 账号名与服务器地址\n· 信息不符时，可到「服务器管理」重新登录或切换服务器',
    );
  }

  Widget _buildSelfSignedCertificateTile(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: _loadAllowSelfSignedCertificate(),
      builder: (context, snapshot) {
        final allow = snapshot.data ?? false;
        return settingsSwitchTile(
          icon: Icons.security_outlined,
          iconColor: Colors.orange,
          title: '允许自签名证书',
          subtitle:
              allow ? '已允许：可连接自签名证书的内网服务器（存在安全风险）' : '已禁用：严格校验 SSL 证书（推荐）',
          value: allow,
          onChanged: (value) {
            if (value) {
              // 开启时弹出安全风险提示
              _showSelfSignedCertificateWarning(context, ref);
            } else {
              // 关闭时直接保存
              _setAllowSelfSignedCertificate(context, false);
            }
          },
          helpText:
              '开启后允许连接使用自签名证书的服务器（如内网 NAS、自建 Emby）。\n\n· 开启 → 信任自签名证书，避免 TLS 校验失败\n· 关闭 → 只信任受信任 CA 签发的证书\n\n仅在你信任该服务器时开启，否则存在中间人攻击风险。',
        );
      },
    );
  }

  Future<void> _setAllowSelfSignedCertificate(
      BuildContext context, bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStorageKeyAllowSelfSignedCertificate, allow);
    if (allow) {
      AppLogger.warn('已允许自签名证书，SSL 校验已禁用，存在安全风险');
    } else {
      AppLogger.info('已禁用自签名证书，SSL 校验已启用');
    }
    // 提示用户重启 App 生效
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allow ? '已允许自签名证书，重启 App 后生效' : '已禁用自签名证书，重启 App 后生效'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSelfSignedCertificateWarning(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.error, size: 24),
            const SizedBox(width: 8),
            const Text('安全风险提示'),
          ],
        ),
        content: const Text(
          '允许自签名证书将禁用 SSL 证书校验，可能导致中间人攻击，'
          '使您的账号密码和播放数据面临泄露风险。\n\n'
          '仅建议在受信任的内网环境中使用，且仅连接您自己的服务器。\n\n'
          '确定要开启吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _setAllowSelfSignedCertificate(context, true);
            },
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('确认开启'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(Icons.logout, color: scheme.onError),
          label: Text(
            '退出登录',
            style: TextStyle(color: scheme.onError, fontSize: _kFontSizeXLarge),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showLogoutDialog(context, ref),
        ),
      ),
    );
  }
}
