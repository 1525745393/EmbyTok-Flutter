/// 编辑文件源保留 mediaType 回归测试
///
/// 缺陷（全仓 UI 审查 P1-2）：编辑源时 `_save` 只重建连接字段（host/port/
/// share/username/password），`FileSource.copyWith(config:)` 为整体替换而非
/// 浅合并，会把「修改媒体类型」写入的 `config['mediaType']` 静默清空 →
/// 剧集源被当电影平铺展示，刮削/重命名链路走错分支且无提示。
/// 修复：`_save` 以原 config 为底拷贝，再覆盖连接字段。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/file_source.dart';
import 'package:embytok_flutter/providers/file_sources_provider.dart';
import 'package:embytok_flutter/views/local/file_source_edit_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('编辑 SMB 源保存后 mediaType 保留', (tester) async {
    const src = FileSource(
      id: 'smb1',
      type: FileSourceType.smb,
      name: '源1',
      config: {'host': '1.2.3.4', 'mediaType': '剧集'},
    );
    SharedPreferences.setMockInitialValues({
      'file_sources_v1': json.encode([src.toJson()]),
    });
    // 防 flutter_secure_storage MissingPluginException（保存时密码落安全存储）
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    // 直接持有 container，交互后从同一容器读 state（避免 element 查找歧义）
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // 经 push 进入编辑页，保存后 pop 回退合法（避免根路由 pop）
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const FileSourceEditView(existing: src),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 编辑页不 watch fileSourcesProvider（保存时才 ref.read），
    // 若不显式触发构造，保存瞬间 provider 才首次创建、_load 未完成、
    // state 为空 → update 的 map-replace 会整体替换成空列表（丢数据）。
    // 这里先触发构造并等 _load 完成，模拟真实使用中列表页已加载过源的场景。
    container.read(fileSourcesProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 修改名称并保存（保存按钮在 ListView 底部，先滚动到可见再点）
    await tester.enterText(find.byType(TextField).first, '源1-改');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final list = container.read(fileSourcesProvider);
    final updated = list.firstWhere((s) => s.id == 'smb1');
    expect(updated.name, '源1-改');
    expect(updated.config['mediaType'], '剧集',
        reason: '编辑保存不得清空 mediaType（修复前 copyWith 整体替换会丢失）');
    expect(updated.config['host'], '1.2.3.4');
  });
}
