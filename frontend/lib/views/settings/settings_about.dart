part of '../settings_view.dart';

// 从 settings_view.dart 拆分（part 文件，无行为变化）

class _DonatePlaceholder extends StatelessWidget {
  const _DonatePlaceholder({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: _kSpacingMedium),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: _kFontSizeMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _kSpacingXSmall),
          Text(
            hint,
            style: TextStyle(
              color: color.withValues(alpha: 0.6),
              fontSize: _kFontSizeTiny,
            ),
          ),
        ],
      ),
    );
  }
}

// 关于页的功能亮点行
class _AboutFeatureRow extends StatelessWidget {
  const _AboutFeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: _kFontSizeBody,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 自定义中文许可证页面 ====================

/// 自定义中文许可证页面
///
/// 替代 Flutter 框架内置的英文 [showLicensePage]，使用 [LicenseRegistry]
/// 异步收集所有依赖的许可证条目，渲染为中文界面的可展开列表，
/// 支持按包名搜索过滤。
class _LicensePage extends StatefulWidget {
  const _LicensePage({
    required this.applicationName,
    required this.applicationVersion,
    required this.primaryColor,
  });
  final String applicationName;
  final String applicationVersion;
  final Color primaryColor;

  @override
  State<_LicensePage> createState() => _LicensePageState();
}

class _LicensePageState extends State<_LicensePage> {
  // 收集到的所有许可证条目
  List<_LicenseEntryView> _entries = const [];
  bool _isLoading = true;
  String? _error;
  // 搜索状态
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 收集 LicenseRegistry.licenses 流并聚合为列表
  Future<void> _loadLicenses() async {
    try {
      final entries = <_LicenseEntryView>[];
      // LicenseRegistry.licenses 是单订阅流，await for 一次性消费
      await for (final entry in LicenseRegistry.licenses) {
        final packages = entry.packages.toList();
        final body = entry.paragraphs.map((p) => p.text).join('\n');
        if (packages.isEmpty) {
          // 无包名的条目归入"未命名包"
          entries.add(_LicenseEntryView(
            packageName: '(未命名包)',
            body: body,
          ));
        } else {
          // 一个 LicenseEntry 可能覆盖多个包，分别建立条目以便搜索
          for (final pkg in packages) {
            entries.add(_LicenseEntryView(packageName: pkg, body: body));
          }
        }
      }
      // 按包名排序，便于查找
      entries.sort((a, b) =>
          a.packageName.toLowerCase().compareTo(b.packageName.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载许可证失败：$e';
        _isLoading = false;
      });
    }
  }

  // 按搜索关键词过滤包名
  List<_LicenseEntryView> get _filtered {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries
        .where((e) => e.packageName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索包名...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
                style: TextStyle(
                    color: scheme.onSurface, fontSize: _kFontSizeXLarge),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('开源许可证'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消搜索',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索包名',
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  // 主体内容：加载中 / 错误 / 空态 / 列表 四种状态
  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: widget.primaryColor),
            const SizedBox(height: _kSpacingXLarge),
            Text(
              '正在加载许可证...',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeBody),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: scheme.error, fontSize: _kFontSizeMedium),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? '暂无许可证信息' : '没有匹配「$_searchQuery」的包',
          style: TextStyle(
              color: scheme.onSurfaceVariant, fontSize: _kFontSizeMedium),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length + 1, // +1 为顶部说明卡片
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeaderCard(scheme, list.length);
        final entry = list[index - 1];
        return _buildLicenseTile(scheme, entry);
      },
    );
  }

  // 顶部说明卡片：致谢与应用信息
  Widget _buildHeaderCard(ColorScheme scheme, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: widget.primaryColor),
              const SizedBox(width: 6),
              Text(
                '${widget.applicationName} · 版本 ${widget.applicationVersion}',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: _kFontSizeBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: _kSpacingMedium),
          Text(
            '本应用使用了 $count 个开源软件包，谨向以下项目的作者致以诚挚谢意。',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: _kFontSizeSmall,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 单个许可证条目：点击展开查看全文
  Widget _buildLicenseTile(ColorScheme scheme, _LicenseEntryView entry) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(
        entry.packageName,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: _kFontSizeMedium,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '点击查看许可证全文',
        style:
            TextStyle(color: scheme.onSurfaceVariant, fontSize: _kFontSizeTiny),
      ),
      children: [
        SelectableText(
          entry.body.isEmpty ? '（无许可证文本）' : entry.body,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: _kFontSizeSmall,
            height: 1.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// 许可证条目视图模型
class _LicenseEntryView {
  const _LicenseEntryView({required this.packageName, required this.body});
  final String packageName;
  final String body;
}

// ==================== 推荐高级选项折叠组件 ====================

/// 推荐高级选项折叠 tile
///
/// 基础推荐设置始终显示；高级选项（完播率门控、时间衰减、反疲劳、用户评分）
/// 默认折叠，点击"高级选项"后展开。展开状态为局部 state，页面重建后重置为折叠。
