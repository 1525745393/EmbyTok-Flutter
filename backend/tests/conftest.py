# Pytest 配置文件
# 定义测试用 fixture，供所有测试文件共享使用

import pytest
from fastapi.testclient import TestClient

# 注意：实际运行测试时，需要确保 main.py 可被导入
# 如果路径有问题，请在测试文件开头添加：
# import sys
# sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
