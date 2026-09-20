// 从 login_view.dart 拆分（part 文件，无行为变化）

part of 'login_view.dart';

// ==================== 登录页 UI 构建 ====================

extension _LoginViewBuilders on _LoginViewState {
  Widget _buildServerTypeSelector(ColorScheme scheme) {
    // 注意：登录表单在 SingleChildScrollView 内，垂直方向无界，
    // 不能使用 crossAxisAlignment.stretch（需要有限高度），用默认 center
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildServerTypeCard(
            scheme: scheme,
            type: ServerType.emby,
            title: 'Emby 视频',
            subtitle: 'Emby / Plex 视频流',
            icon: Icons.movie_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildServerTypeCard(
            scheme: scheme,
            type: ServerType.synology,
            title: '群晖音乐',
            subtitle: 'Audio Station 音乐库',
            icon: Icons.library_music_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildServerTypeCard({
    required ColorScheme scheme,
    required ServerType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _serverType == type;
    return GestureDetector(
      onTap: () => _onServerTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 30,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            // 选中角标（未选中时占位保持高度一致，避免卡片跳动）
            selected
                ? Icon(Icons.check_circle, size: 16, color: scheme.primary)
                : const SizedBox(
                    height: 16,
                    width: 16,
                    child: Icon(Icons.check_circle,
                        size: 16, color: Colors.transparent),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerField(ColorScheme scheme) {
    final isSyno = _serverType == ServerType.synology;
    return TextFormField(
      controller: _embyController,
      focusNode: _serverFocusNode,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.url],
      style: TextStyle(color: scheme.onSurface),
      onChanged: (_) {
        // 服务器地址变化时总是 rebuild：更新 HTTP 警告与连接状态
        _clearError();
        setState(() {});
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surface,
        labelText: isSyno ? '群晖服务器地址' : 'Emby 服务器地址',
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintText:
            isSyno ? 'http://192.168.1.100:5000' : 'http://192.168.1.1:8096',
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
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
            padding: EdgeInsets.only(
                bottom: index < _serverHistory.length - 1 ? 4 : 0),
            child: Material(
              color: scheme.onSurface.withValues(alpha: isFirst ? 0.06 : 0.03),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _embyController.text = entry.url;
                  // 恢复该服务器上次使用的类型
                  if (entry.serverType != _serverType) {
                    setState(() => _serverType = entry.serverType);
                  }
                  _clearError();
                  _testConnection();
                  _usernameFocusNode.requestFocus();
                },
                onLongPress: () => _showDeleteConfirmDialog(index, scheme),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          icon: Icon(Icons.close,
                              size: 16, color: scheme.onSurfaceVariant),
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              _showDeleteConfirmDialog(index, scheme),
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

  Widget _buildServerTypeIcon(ServerType type, ColorScheme scheme) {
    switch (type) {
      case ServerType.emby:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF52B54B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.dns, size: 18, color: Color(0xFF52B54B)),
        );
      case ServerType.plex:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE5A00D).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_circle_outline,
              size: 18, color: Color(0xFFE5A00D)),
        );
      case ServerType.synology:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2C8EF4).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.library_music_outlined,
              size: 18, color: Color(0xFF2C8EF4)),
        );
    }
  }

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
    TextInputType? keyboardType,
    ValueChanged<String>? onFieldSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      style: TextStyle(color: scheme.onSurface),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surface,
        labelText: label,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintText: hint,
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
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
