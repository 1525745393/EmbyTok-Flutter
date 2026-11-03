// 从 settings_builders.dart 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== 设置项构建（下半） ====================

extension _SettingsBuilders2 on SettingsView {

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

  Widget _buildSynologyMusicTile(BuildContext context, WidgetRef ref) {
    final synoAuth = ref.watch(synologyAuthProvider);
    return settingsTapTile(
      icon: Icons.library_music_outlined,
      iconColor: accentBlue,
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
      iconColor: lastfmRed,
      title: 'Last.fm 补充',
      subtitle:
          configured ? '已配置：歌手头像/简介优先用 Last.fm' : '配置 API Key，补充歌手图与简介（免费）',
      onTap: () =>
          _showLastFmKeyDialog(context, ref, keyAsync.valueOrNull ?? ''),
      helpText:
          '配置 Last.fm 服务（可选）。\n\n用于获取歌手头像、简介等补充信息，丰富歌手详情页。\n\n· 需要注册 Last.fm API Key\n· 未配置时歌手详情仅显示服务器已有信息',
    );
  }

  // 音乐 - NAS 元数据同步（L3 缓存）
  // batch41-F4：原实现 onChanged 未登录时静默 return（点击无任何反馈）、直接改
  // service 可写字段（不持久化、且 settingsSwitchTile 非响应式——开关点击后弹回）。
  // 已提取为 _NasMetadataSyncTile（本文件底部类）：initState 直读 prefs 恢复开关，
  // 未登录点击弹提示，写 service.setNasSyncEnabled 持久化，写入后本地 setState 刷新。
  Widget _buildNasMetadataSyncTile(BuildContext context, WidgetRef ref) {
    return const _NasMetadataSyncTile();
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
              const SizedBox(height: kSpacingXs),
              const Text(
                '用于补充歌手头像与简介（未配置时自动使用群晖/Wikipedia 数据）',
                style: TextStyle(fontSize: _kFontSizeSmall),
              ),
              const SizedBox(height: kSpacingMd),
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

  // 关于 - 下载源
  // batch41-F5：原 FutureBuilder 在 build 中重建 future（每次 rebuild 闪回 + 重复
  // 读 prefs）——已提取为 _DownloadMirrorTile（本文件底部类），initState 读一次，
  // 选择镜像后重建 future 刷新副标题。
  Widget _buildDownloadMirrorTile(BuildContext context, WidgetRef ref) {
    return const _DownloadMirrorTile();
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
      onTap: () => _handleVersionTap(context),
    );
  }

  void _handleVersionTap(BuildContext context) {
    _versionTapCount++;
    _versionTapResetTimer?.cancel();
    _versionTapResetTimer =
        Timer(const Duration(milliseconds: kTestModeTapResetMs), () {
      _versionTapCount = 0;
    });
    HapticFeedback.lightImpact();

    if (_versionTapCount >= kTestModeTapThreshold) {
      _versionTapCount = 0;
      _versionTapResetTimer?.cancel();
      if (!isAppTestMode) {
        // release/profile 构建：路由未注册，给出明确提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('测试模式仅在 debug 构建中可用')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('进入测试模式')),
      );
      context.push('/test-mode');
    } else {
      final remaining = kTestModeTapThreshold - _versionTapCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '再点 $remaining 次${isAppTestMode ? '' : '（测试模式仅 debug 可用）'}'),
            duration: const Duration(milliseconds: 800)),
      );
    }
  }

  /// 本地媒体库模式的退出按钮（batchF3）：
  /// 与 [local_library_settings_page] 的「退出本地模式」同语义——
  /// 同时清 localModeProvider 与 authProvider 注入态，守卫才放行跳登录页。
  Widget _buildLocalModeExitButton(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(Icons.logout, color: scheme.onError),
          label: Text(
            '退出本地模式',
            style: TextStyle(color: scheme.onError, fontSize: _kFontSizeXLarge),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            ref.read(localModeProvider.notifier).state = false;
            ref.read(authProvider.notifier).reset();
            context.go('/login');
          },
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
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

// ==================== 下载源选择对话框 ====================

class _MirrorPickerDialog extends StatefulWidget {
  const _MirrorPickerDialog({required this.svc, required this.current});
  final UpdateCheckService svc;
  final String? current;

  @override
  State<_MirrorPickerDialog> createState() => _MirrorPickerDialogState();
}

class _MirrorPickerDialogState extends State<_MirrorPickerDialog> {
  final Map<String, int> _results = {};
  bool _testing = true;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  Future<void> _runTest() async {
    final r = await widget.svc.testAllMirrors();
    if (!mounted) return;
    setState(() {
      _results.addAll(r);
      _testing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('选择下载源'),
      content: SizedBox(
        width: double.maxFinite,
        child: _testing
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: kSpacingXl),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在测速原始链接和镜像…'),
                  ],
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  RadioListTile<String?>(
                    value: null,
                    groupValue: widget.current,
                    title: const Text('自动选择（推荐）'),
                    subtitle: const Text('按顺序尝试，失败自动切换'),
                    onChanged: (v) async {
                      await widget.svc.setPreferredMirror(v);
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  // 原始 GitHub 链接（可选）
                  RadioListTile<String?>(
                    value: 'direct',
                    groupValue: widget.current,
                    title: const Row(children: [
                      Icon(Icons.public, size: 18),
                      SizedBox(width: 8),
                      Text('原始链接（GitHub）'),
                    ]),
                    subtitle: Text(_results['direct'] == -1
                        ? '连接失败'
                        : '${_results['direct'] ?? -1}ms'),
                    secondary: _results['direct'] == -1
                        ? Icon(Icons.error_outline,
                            color: scheme.error, size: 18)
                        : const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                    onChanged: (v) async {
                      await widget.svc.setPreferredMirror(v);
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ...widget.svc.allDownloadMirrors.map((m) {
                    final ms = _results[m] ?? -1;
                    final label = ms < 0
                        ? '连接失败'
                        : ms < 300
                            ? '${ms}ms（快）'
                            : '${ms}ms';
                    return RadioListTile<String?>(
                      value: m,
                      groupValue: widget.current,
                      title: Text(_mirrorLabel(m)),
                      subtitle: Text(label),
                      secondary: ms < 0
                          ? Icon(Icons.error_outline,
                              color: scheme.error, size: 18)
                          : ms < 300
                              ? Icon(Icons.check_circle,
                                  color: Colors.green, size: 18)
                              : null,
                      onChanged: (v) async {
                        await widget.svc.setPreferredMirror(v);
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

// ==================== 下载源 库级辅助（batch41-F5） ====================
// 说明：以下 helper 原为 extension _SettingsBuilders2 成员，batch41-F5 新增的
// StatefulWidget（_DownloadMirrorTile）无法调用 extension 成员（非 SettingsView
// 实例），已提升为库顶层函数，供 extension 与 State 类共同调用
// （同库作用域直接可见，避免重复实现）。

/// 镜像显示名映射（_MirrorPickerDialog 原 _label 与此合并，batch41-F5 消重）
String _mirrorLabel(String mirror) {
  if (mirror == 'direct') return '原始链接（GitHub）';
  if (mirror.contains('ghfast.top')) return 'ghfast.top';
  if (mirror.contains('gh-proxy.com')) return 'gh-proxy.com';
  if (mirror.contains('ghproxy.net')) return 'ghproxy.net';
  if (mirror.contains('mirror.ghproxy.com')) return 'mirror.ghproxy.com';
  if (mirror.contains('ghps.cc')) return 'ghps.cc';
  return mirror;
}

/// 打开下载源选择对话框
Future<void> _showMirrorPicker(
  BuildContext context,
  WidgetRef ref,
  UpdateCheckService svc,
  String? current,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _MirrorPickerDialog(svc: svc, current: current),
  );
}


// ==================== NAS 元数据同步开关（batch41-F4） ====================

/// NAS 元数据同步开关（batch41-F4）
///
/// 原实现：未登录点击静默 return（无任何反馈）；直接写 service 可写字段
/// （不持久化，重启即丢）；settingsSwitchTile 非响应式（service 不是
/// ChangeNotifier），点击后 Switch 视觉弹回。修复：
/// 1. initState 直读 SharedPreferences（key `nas_sync_enabled`，与
///    ArtistMetadataService 持久化同一 key，不受 service.init 异步竞态影响）；
/// 2. 未登录点击弹提示「需先登录群晖 Audio Station」；
/// 3. 登录后调 service.setNasSyncEnabled 持久化，本地 setState 刷新开关。
class _NasMetadataSyncTile extends ConsumerStatefulWidget {
  const _NasMetadataSyncTile({super.key});

  @override
  ConsumerState<_NasMetadataSyncTile> createState() =>
      _NasMetadataSyncTileState();
}

class _NasMetadataSyncTileState extends ConsumerState<_NasMetadataSyncTile> {
  static const _key = 'nas_sync_enabled';
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          _enabled = p.getBool(_key) ?? false;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _toggle(bool value) async {
    if (!ref.read(synologyAuthProvider).isLoggedIn) {
      // 未登录：明确提示，不再静默吞掉点击
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NAS 元数据同步需先登录群晖 Audio Station'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    // 持久化：service 内部同步更新字段并写 prefs（key 与本 tile 一致）
    await ref.read(artistMetadataServiceProvider).setNasSyncEnabled(value);
    if (mounted) setState(() => _enabled = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'NAS 元数据同步已开启' : 'NAS 元数据同步已关闭'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return settingsSwitchTile(
      icon: Icons.cloud_sync_outlined,
      iconColor: Colors.teal,
      title: 'NAS 元数据同步',
      subtitle: _enabled ? '已开启：歌手简介/头像同步到群晖，多设备共享' : '开启后同步到 NAS（需先登录群晖）',
      value: _enabled,
      onChanged: _toggle,
      helpText:
          '开启后，自动同步 NAS（群晖）音乐库的元数据（歌手、专辑、曲目信息）。\n\n· 开启 → 音乐库信息保持最新（同步耗时）\n· 关闭 → 仅使用本地缓存（更快但可能滞后）\n\n首次配置后建议开启一次完成全量同步。',
    );
  }
}

// ==================== 下载源 tile（batch41-F5） ====================

/// 下载源 tile（batch41-F5）
///
/// 原实现（settings_builders_extra.dart）在 build 中新建
/// `svc.getPreferredMirror()` future——每次 rebuild 回 pending 再 resolve，
/// 副标题闪回且重复读 prefs。修复：future 在 initState 创建一次；
/// 选择镜像并关闭弹窗后重建 future 刷新当前源显示。
class _DownloadMirrorTile extends ConsumerStatefulWidget {
  const _DownloadMirrorTile({super.key});

  @override
  ConsumerState<_DownloadMirrorTile> createState() =>
      _DownloadMirrorTileState();
}

class _DownloadMirrorTileState extends ConsumerState<_DownloadMirrorTile> {
  late Future<String?> _preferredFuture;

  @override
  void initState() {
    super.initState();
    _preferredFuture =
        ref.read(updateCheckServiceProvider).getPreferredMirror();
  }

  Future<void> _pick(String? current) async {
    final svc = ref.read(updateCheckServiceProvider);
    await _showMirrorPicker(context, ref, svc, current);
    if (mounted) {
      // 选择后重建 future，刷新副标题为最新镜像
      setState(() => _preferredFuture = svc.getPreferredMirror());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _preferredFuture,
      builder: (_, snap) {
        final preferred = snap.data;
        final subtitle =
            preferred == null ? '自动选择（推荐）' : '当前：${_mirrorLabel(preferred)}';
        return settingsTapTile(
          icon: Icons.download_outlined,
          iconColor: Colors.teal,
          title: '下载源',
          subtitle: subtitle,
          onTap: () => _pick(preferred),
          helpText:
              '选择 APK 下载加速镜像。\n\n· 自动模式按顺序尝试，失败自动切换\n· 手动测速后选择最快的镜像\n· 原始链接为 GitHub 官方地址',
        );
      },
    );
  }
}

