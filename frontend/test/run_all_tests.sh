#!/bin/bash

# EmbyTok Flutter 测试运行脚本
# 运行所有测试并生成覆盖率报告

set -e

echo "======================================"
echo "EmbyTok Flutter 测试套件"
echo "======================================"

# 切换到项目根目录
cd "$(dirname "$0")/.."

# 检查 Flutter 是否可用
if ! command -v flutter &> /dev/null; then
    echo "错误: Flutter 未安装或不在 PATH 中"
    exit 1
fi

# 获取依赖
echo ""
echo ">>> 获取依赖..."
flutter pub get

# 运行测试并生成覆盖率
echo ""
echo ">>> 运行测试并生成覆盖率报告..."
flutter test --coverage

# 检查覆盖率文件是否生成
if [ -f "coverage/lcov.info" ]; then
    echo ""
    echo "======================================"
    echo "覆盖率报告已生成: coverage/lcov.info"
    echo "======================================"

    # 如果安装了 lcov，可以生成 HTML 报告
    if command -v genhtml &> /dev/null; then
        echo ""
        echo ">>> 生成 HTML 覆盖率报告..."
        genhtml coverage/lcov.info -o coverage/html
        echo ""
        echo "HTML 报告已生成: coverage/html/"
        echo "在浏览器中打开: file://$(pwd)/coverage/html/index.html"
    else
        echo ""
        echo "提示: 安装 lcov 以生成 HTML 报告"
        echo "  - macOS: brew install lcov"
        echo "  - Ubuntu: sudo apt-get install lcov"
        echo "  - 然后运行: genhtml coverage/lcov.info -o coverage/html"
    fi
else
    echo ""
    echo "警告: 覆盖率文件未生成"
fi

# 显示测试摘要
echo ""
echo "======================================"
echo "测试完成!"
echo "======================================"
