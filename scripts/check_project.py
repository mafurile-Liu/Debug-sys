#!/usr/bin/env python3
"""Dependency-free structural checks for the local SystemVerilog sources."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SUFFIXES = {".sv", ".svh", ".svi"}
EXTERNAL_INCLUDES = {
    "svt_jtag.uvm.pkg",
    "svt_swd.uvm.pkg",
    "svt_apb.uvm.pkg",
    "svt_axi.uvm.pkg",
    "svt_atb.pkg",
    "uvm_macros.svh",
    "uvm_pkg.sv",
    "svt_apb_if.svi",
}


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', text)


def check_preprocessor(path: Path, text: str, errors: list[str]) -> None:
    stack: list[tuple[str, int]] = []
    for number, line in enumerate(text.splitlines(), 1):
        match = re.match(r"\s*`(ifdef|ifndef|elsif|else|endif)\b", line)
        if not match:
            continue
        directive = match.group(1)
        if directive in {"ifdef", "ifndef"}:
            stack.append((directive, number))
        elif directive in {"elsif", "else"}:
            if not stack:
                errors.append(f"{path}:{number}: `{directive} without open conditional")
        elif not stack:
            errors.append(f"{path}:{number}: `endif without open conditional")
        else:
            stack.pop()
    for directive, number in stack:
        errors.append(f"{path}:{number}: unclosed `{directive}")


def check_pairs(path: Path, text: str, errors: list[str]) -> None:
    clean = strip_comments(text)
    pairs = [
        (r"\bclass\b", r"\bendclass\b", "class"),
        (r"\bmodule\b", r"\bendmodule\b", "module"),
        (r"\bpackage\b", r"\bendpackage\b", "package"),
        (r"\binterface\b", r"\bendinterface\b", "interface"),
        (r"\bfunction\b", r"\bendfunction\b", "function"),
        (r"\btask\b", r"\bendtask\b", "task"),
    ]
    for opening, closing, label in pairs:
        left = len(re.findall(opening, clean))
        right = len(re.findall(closing, clean))
        if left != right:
            errors.append(f"{path}: {label}/end{label} count is {left}/{right}")


def resolve_include(path: Path, include: str) -> bool:
    candidates = [
        path.parent / include,
        ROOT / "tb" / include,
        ROOT / "tb" / "env" / include,
        ROOT / "tb" / "tests" / include,
    ]
    return any(candidate.is_file() for candidate in candidates)


def check_includes(path: Path, text: str, errors: list[str]) -> None:
    for include in re.findall(r"`include\s+\"([^\"]+)\"", strip_comments(text)):
        if include in EXTERNAL_INCLUDES:
            continue
        if not resolve_include(path, include):
            errors.append(f"{path}: unresolved local include {include!r}")


def main() -> int:
    errors: list[str] = []
    sources = sorted(
        path for path in (ROOT / "tb").rglob("*") if path.suffix in SOURCE_SUFFIXES
    )
    if not sources:
        errors.append("no SystemVerilog sources found")

    for path in sources:
        text = path.read_text(encoding="utf-8")
        check_preprocessor(path, text, errors)
        check_pairs(path, text, errors)
        check_includes(path, text, errors)

    top = ROOT / "tb" / "debug_port_top.sv"
    top_text = top.read_text(encoding="utf-8") if top.exists() else ""
    for required in ("DEBUG_PORT_JTAG", "DEBUG_PORT_SWD", "run_test"):
        if required not in top_text:
            errors.append(f"top is missing required selector/hook: {required}")

    if errors:
        print("Project check FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"Project check passed: {len(sources)} SystemVerilog files")
    return 0


if __name__ == "__main__":
    sys.exit(main())

