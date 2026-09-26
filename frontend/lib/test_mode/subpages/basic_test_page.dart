// 基础功能测试：页面跳转、权限、弹窗演示

import 'package:flutter/material.dart';

class BasicTestPage extends StatelessWidget {
  const BasicTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('基础功能测试')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('页面跳转测试'),
            subtitle: const Text('进入二级页并逐级返回'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('二级页')),
                  body: const Center(child: Text('返回上一级验证返回栈')),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.message_outlined),
            title: const Text('Toast 提示'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Toast 测试成功')),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: const Text('确认对话框'),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('确认？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('确定')),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.hourglass_empty),
            title: const Text('空状态展示'),
            subtitle: const Text('验证空列表 UI'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('空状态')),
                  body: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('暂无数据', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
