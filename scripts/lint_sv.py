#!/usr/bin/env python3
"""Parse both debug-port branches with pyslang, without loading vendor VIP."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCAL_PYSLANG = ROOT / ".tools" / "pyslang"
if LOCAL_PYSLANG.is_dir():
    sys.path.insert(0, str(LOCAL_PYSLANG))

try:
    import pyslang
except ImportError:
    print("pyslang is unavailable; install it or run scripts/check_project.py")
    raise SystemExit(2)


def without_includes(text: str) -> str:
    return re.sub(r'^\s*`include\s+"[^"]+"\s*$', "", text, flags=re.M)


def is_expected_vendor_macro(diagnostic: object) -> bool:
    code = str(diagnostic.code)
    args = [str(arg) for arg in diagnostic.args]
    return code.endswith("UnknownDirective)") and bool(args) and args[0].startswith("`uvm_")


def parse(path: Path, mode: str) -> list[str]:
    source = without_includes(path.read_text(encoding="utf-8"))
    source = f"`define DEBUG_PORT_{mode.upper()} 1\n" + source
    tree = pyslang.syntax.SyntaxTree.fromText(
        source,
        name=f"{path.name}:{mode}",
    )
    problems: list[str] = []
    for diagnostic in tree.diagnostics:
        if is_expected_vendor_macro(diagnostic):
            continue
        problems.append(
            f"{path.relative_to(ROOT)} [{mode}]: {diagnostic.code} {list(diagnostic.args)}"
        )
    return problems


def main() -> int:
    sources = sorted((ROOT / "tb").rglob("*.sv"))
    problems = [
        problem
        for mode in ("jtag", "swd")
        for source in sources
        for problem in parse(source, mode)
    ]
    if problems:
        print("pyslang syntax check FAILED:")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"pyslang syntax check passed: {len(sources)} files x 2 protocol branches")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
