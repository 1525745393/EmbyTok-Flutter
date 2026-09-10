// 服务器管理页：多服务器统一控制台
//
// - 列出所有已添加服务器（类型 / 名称 / 地址 / 状态 / 默认角标）
// - 点击行：切换为激活服务器（用保存的凭据自动登录）
// - 添加 / 编辑：地址、内外网地址、网络模式、用户名、密码（可选记住）
// - 删除（确认弹窗）、设为默认
//
// 设计参考：Yamby / AudioDock —— 集中管理，列表 + 编辑表单。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/auth_provider.dart';
import '../providers/server_registry_provider.dart';
import '../providers/synology_auth_provider.dart';
import '../utils/logger.dart';

class ServersView extends ConsumerWidget {
  const ServersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final servers = ref.watch(serverRegistryProvider);
    final activeId = ref.watch(activeServerIdProvider);
    final auth = ref.watch(authProvider);
    final synoAuth = ref.watch(synologyAuthProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: const Text('服务器管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加服务器',
            onPressed: () => _showEditSheet(context, ref),
          ),
        ],
      ),
      body: servers.isEmpty
          ? _buildEmpty(scheme)
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                for (final server in servers)
                  _ServerCard(
                    server: server,
                    active: server.id == activeId,
                    isLoggedIn: _isServerLoggedIn(server, auth, synoAuth),
                    onTap: () => _switchServer(context, ref, server),
                    onEdit: () => _showEditSheet(context, ref, server: server),
                    onDelete: () => _confirmDelete(context, ref, server),
                    onSetDefault: () =>
                        ref.read(serverRegistryProvider.notifier).setDefault(server.id),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加服务器'),
      ),
    );
  }

  bool _isServerLoggedIn(
    ServerProfile server,
    AuthState auth,
    SynologyAuthState synoAuth,
  ) {
    return switch (server.kind) {
      ServerKind.emby || ServerKind.plex => auth.isAuthenticated &&
          (auth.embyServerUrl?.contains(_hostOf(server.url)) ?? false),
      ServerKind.synology => synoAuth.isLoggedIn &&
          (synoAuth.serverUrl?.contains(_hostOf(server.url)) ?? false),
    };
  }

  /// 提取 host 用于登录状态匹配（地址可能带端口/协议差异）
  static String _hostOf(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  /// 切换激活服务器：用保存的凭据自动登录
  Future<void> _switchServer(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final registry = ref.read(serverRegistryProvider.notifier);
    final secureStorage = ref.read(secureStorageProvider);
    await registry.touch(server.id);
    await ref.read(activeServerIdProvider.notifier).setActive(server.id);

    try {
      if (server.kind == ServerKind.synology) {
        // 优先用保存的 sid 会话（避免重复输入密码）
        String? sid;
        try {
          sid = await secureStorage.read(key: serverSynoSidKey(server.id));
        } catch (_) {
      // 操作失败不影响主流程，静默处理
    }
        final synoAuth = ref.read(synologyAuthProvider.notifier);
        if (sid != null && sid.isNotEmpty) {
          await synoAuth.restoreSession(
            serverUrl: server.resolveUrl(),
            account: server.username,
            sid: sid,
          );
        } else {
          final password = await _readPassword(secureStorage, server.id);
          if (password == null) {
            messenger.showSnackBar(const SnackBar(
                content: Text('未保存该服务器的密码，请编辑后重试')));
            return;
          }
          await synoAuth.login(
            serverUrl: server.resolveUrl(),
            account: server.username,
            password: password,
          );
          // 保存 sid 供下次免密恢复
          final current = ref.read(synologyAuthProvider);
          if (current.sid != null && current.sid!.isNotEmpty) {
            await registry.update(server, synoSid: current.sid);
          }
        }
      } else {
        final password = await _readPassword(secureStorage, server.id);
        if (password == null) {
          messenger.showSnackBar(const SnackBar(
              content: Text('未保存该服务器的密码，请编辑后重试')));
          return;
        }
        await ref.read(authProvider.notifier).login(
              server.resolveUrl(),
              server.username,
              password,
            );
      }
      if (context.mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('已切换到「${server.name}」')));
      }
    } catch (e, st) {
      AppLogger.error('切换服务器失败', error: e, stackTrace: st);
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('切换失败：$e')));
      }
    }
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_outlined, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            '还没有配置服务器',
            style: TextStyle(fontSize: 16, color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角「添加服务器」，配置 Emby / 群晖音乐等数据源',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 添加 / 编辑服务器表单（底部弹层）
  Future<void> _showEditSheet(
    BuildContext context,
    WidgetRef ref, {
    ServerProfile? server,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = server != null;
    final nameCtrl = TextEditingController(text: server?.name ?? '');
    final urlCtrl = TextEditingController(text: server?.url ?? '');
    final internalCtrl =
        TextEditingController(text: server?.internalUrl ?? '');
    final externalCtrl =
        TextEditingController(text: server?.externalUrl ?? '');
    final userCtrl = TextEditingController(text: server?.username ?? '');
    final passCtrl = TextEditingController();
    var kind = server?.kind ?? ServerKind.emby;
    var networkMode = server?.networkMode ?? NetworkMode.auto;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: scheme.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? '编辑服务器' : '添加服务器',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 类型选择（编辑时不可改类型）
                  if (!isEdit)
                    SegmentedButton<ServerKind>(
                      segments: [
                        for (final k in ServerKind.values)
                          ButtonSegment(
                            value: k,
                            label: Text(k.label),
                            icon: Icon(
                              k == ServerKind.synology
                                  ? Icons.library_music_outlined
                                  : Icons.movie_outlined,
                              size: 15,
                            ),
                          ),
                      ],
                      selected: {kind},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setSheetState(() => kind = s.first),
                    ),
                  if (!isEdit) const SizedBox(height: 14),
                  _field(scheme, nameCtrl, '名称（如：家里的 Emby）', Icons.label_outline),
                  const SizedBox(height: 10),
                  _field(scheme, urlCtrl, '服务器地址（必填）', Icons.dns_outlined),
                  const SizedBox(height: 10),
                  _field(scheme, userCtrl, '用户名', Icons.person_outline),
                  const SizedBox(height: 10),
                  _field(
                    scheme,
                    passCtrl,
                    isEdit ? '密码（留空则不修改）' : '密码（可选，用于快速切换）',
                    Icons.lock_outline,
                    obscure: true,
                  ),
                  const SizedBox(height: 14),
                  // 内外网地址与网络模式（智能切换）
                  Text(
                    '网络模式（智能切换）',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<NetworkMode>(
                    segments: [
                      for (final m in NetworkMode.values)
                        ButtonSegment(
                          value: m,
                          label: Text(m.label),
                          icon: Icon(
                            switch (m) {
                              NetworkMode.auto => Icons.wifi_find,
                              NetworkMode.internal => Icons.home_outlined,
                              NetworkMode.external => Icons.public,
                            },
                            size: 15,
                          ),
                        ),
                    ],
                    selected: {networkMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setSheetState(() => networkMode = s.first),
                  ),
                  const SizedBox(height: 10),
                  _field(scheme, internalCtrl, '内网地址（可选，auto 优先）',
                      Icons.home_outlined),
                  const SizedBox(height: 10),
                  _field(scheme, externalCtrl, '外网地址（可选）', Icons.public),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final url = urlCtrl.text.trim();
                        final name = nameCtrl.text.trim();
                        if (url.isEmpty || name.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                  content: Text('名称与服务器地址为必填项')));
                          return;
                        }
                        final registry =
                            ref.read(serverRegistryProvider.notifier);
                        final password = passCtrl.text;
                        // 保存时规范化地址：trim + 补 http:// 协议（端口由 API 层补默认值）
                        String norm(String? v) {
                          if (v == null || v.trim().isEmpty) return '';
                          final t = v.trim();
                          return (t.startsWith('http://') ||
                                  t.startsWith('https://'))
                              ? t
                              : 'http://$t';
                        }
                        final profile = ServerProfile(
                          id: server?.id ??
                              'srv_${DateTime.now().microsecondsSinceEpoch}',
                          kind: kind,
                          name: name,
                          url: norm(url),
                          internalUrl: norm(internalCtrl.text).isEmpty
                              ? null
                              : norm(internalCtrl.text),
                          externalUrl: norm(externalCtrl.text).isEmpty
                              ? null
                              : norm(externalCtrl.text),
                          username: userCtrl.text.trim(),
                          networkMode: networkMode,
                          isDefault: server?.isDefault ?? false,
                          lastUsed: server?.lastUsed ?? DateTime.now(),
                        );
                        if (isEdit) {
                          await registry.update(
                            profile,
                            password: password.isEmpty ? null : password,
                          );
                        } else {
                          await registry.add(
                            profile,
                            password: password.isEmpty ? null : password,
                          );
                        }
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  isEdit ? '已保存「$name」' : '已添加「$name」')));
                        }
                      },
                      child: Text(isEdit ? '保存' : '添加'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    ColorScheme scheme,
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// 删除确认
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除「${server.name}」吗？\n已保存的密码与登录状态将一并清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(serverRegistryProvider.notifier).remove(server.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已删除「${server.name}」')));
    }
  }

  /// 读取保存的密码
  Future<String?> _readPassword(FlutterSecureStorage storage, String id) async {
    try {
      return await storage.read(key: serverPasswordKey(id));
    } catch (_) {
      return null;
    }
  }
}

/// 服务器卡片
class _ServerCard extends StatelessWidget {
  final ServerProfile server;
  final bool active;
  final bool isLoggedIn;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _ServerCard({
    required this.server,
    required this.active,
    required this.isLoggedIn,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: active ? scheme.primaryContainer.withValues(alpha: 0.4) : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: active ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
          width: active ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (server.kind == ServerKind.synology
                          ? const Color(0xFF2C8EF4)
                          : Colors.deepPurple)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  server.kind == ServerKind.synology
                      ? Icons.library_music_outlined
                      : Icons.movie_outlined,
                  color: server.kind == ServerKind.synology
                      ? const Color(0xFF2C8EF4)
                      : Colors.deepPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            server.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bolt, size: 14, color: scheme.primary),
                        ],
                        if (server.isDefault) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star, size: 14, color: Colors.amber),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${server.kind.label} · ${server.resolveUrl()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          isLoggedIn ? Icons.check_circle : Icons.circle_outlined,
                          size: 12,
                          color: isLoggedIn ? Colors.green : scheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLoggedIn ? '已登录' : '未登录',
                          style: TextStyle(
                            fontSize: 11,
                            color: isLoggedIn ? Colors.green : scheme.outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '网络：${server.networkMode.label}',
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: '编辑',
                onPressed: onEdit,
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: (value) {
                  switch (value) {
                    case 'default':
                      onSetDefault();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'default', child: Text('设为默认')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
