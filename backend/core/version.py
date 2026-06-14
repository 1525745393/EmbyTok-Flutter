# ================================
# 版本号管理
# ================================
# 单一事实来源（Single Source of Truth）：
#   - main.py 中 FastAPI(version=...)
#   - 本文件中的 __version__
# 两者在每次发布时必须保持一致。
# 可使用 scripts/verify-release.sh 自动验证。
# ================================

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import total_ordering
from typing import Optional

# 语义版本号（MAJOR.MINOR.PATCH），与 main.py FastAPI.version 同步更新
__version__: str = "1.2.4"

# 服务显示名，用于 /api/health 等响应中的 meta 信息
APP_NAME: str = "EmbyTok Backend"


# ================================
# 语义版本解析与比较工具
# ================================

_VERSION_RE: re.Pattern = re.compile(
    r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)"
    r"(?:-(?P<prerelease>[A-Za-z0-9.\-]+))?$"
)


@total_ordering
@dataclass(frozen=True)
class SemanticVersion:
    """语义版本对象：支持解析、比较、格式化

    示例：
        v = SemanticVersion.parse("1.2.4")
        v2 = SemanticVersion.parse("1.3.0-beta.1")
        v < v2  # True
    """

    major: int
    minor: int
    patch: int
    prerelease: Optional[str] = None

    @classmethod
    def parse(cls, value: str) -> "SemanticVersion":
        """解析版本字符串，失败时抛出 ValueError"""
        match = _VERSION_RE.match(value.strip())
        if not match:
            raise ValueError(f"Invalid semantic version: {value!r}")
        return cls(
            major=int(match["major"]),
            minor=int(match["minor"]),
            patch=int(match["patch"]),
            prerelease=match["prerelease"],
        )

    @classmethod
    def try_parse(cls, value: str) -> Optional["SemanticVersion"]:
        try:
            return cls.parse(value)
        except ValueError:
            return None

    # ---- 比较实现 ----
    def _compare_key(self) -> tuple:
        # 预发布版本：有 prerelease 视为小于没有 prerelease 的
        # Python bool: False=0, True=1；None 时更大 → 用 (False, ...)
        is_prerelease = self.prerelease is not None
        return (
            self.major,
            self.minor,
            self.patch,
            0 if is_prerelease else 1,
            self.prerelease or "",
        )

    def __lt__(self, other: "SemanticVersion") -> bool:
        return self._compare_key() < other._compare_key()

    def __str__(self) -> str:
        if self.prerelease is None:
            return f"{self.major}.{self.minor}.{self.patch}"
        return f"{self.major}.{self.minor}.{self.patch}-{self.prerelease}"


def is_update_available(current: str, remote: str) -> bool:
    """比较当前版本与远端版本，返回是否需要升级"""
    cur = SemanticVersion.try_parse(current)
    new = SemanticVersion.try_parse(remote)
    if cur is None or new is None:
        return False
    return new > cur


# ---------- 便捷属性 ----------

def current_version() -> SemanticVersion:
    return SemanticVersion.parse(__version__)


def version_info() -> dict:
    """返回结构化版本信息，便于 /api/health 等接口响应使用"""
    return {
        "name": APP_NAME,
        "version": __version__,
        "parsed": current_version().__dict__,
    }
