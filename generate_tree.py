#!/usr/bin/env python3
"""
Generate a JSON representation of a directory tree.

Usage:
    python generate_tree.py --root /path/to/project
"""

import json
import argparse
import sys
from pathlib import Path
from typing import List, Dict, Union

# -----------------------------
# 1. 參數解析
# -----------------------------
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a JSON representation of a directory tree."
    )
    parser.add_argument(
        "-r",
        "--root",
        type=str,
        help="Root directory to scan (required if you want to run the script)",
    )
    # 如果沒有任何參數，顯示說明並退出
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    return parser.parse_args()

# -----------------------------
# 2. 目錄遞迴
# -----------------------------
def walk_dir(
    path: Path,
    ignore: set[str] = None,
) -> List[Dict[str, Union[str, List]]]:
    """
    Recursively walk a directory and build a list of dicts.

    Each dict contains:
        - path: full path relative to the root
        - type: 'dir' or 'file'
        - extension: (only for files)
        - children: (only for dirs)
    """
    ignore = ignore or {"__pycache__", ".DS_Store"}
    items = []

    for child in sorted(path.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower())):
        if child.name in ignore:
            continue

        rel_path = child.relative_to(root_path).as_posix()

        if child.is_dir():
            items.append(
                {
                    "path": rel_path,
                    "type": "dir",
                    "children": walk_dir(child, ignore),
                }
            )
        else:
            # 忽略 .pyc 檔案
            if child.suffix == ".pyc":
                continue

            items.append(
                {
                    "path": rel_path,
                    "type": "file",
                    "extension": child.suffix,
                }
            )

    return items

# -----------------------------
# 3. 主程式
# -----------------------------
if __name__ == "__main__":
    args = parse_args()

    # 轉成 Path 物件並確定它是存在的目錄
    root_path = Path(args.root).resolve()
    if not root_path.is_dir():
        raise ValueError(f"'{root_path}' is not a directory or does not exist.")

    # 產生結構
    tree = walk_dir(root_path)

    # 產生輸出檔案路徑
    output_file = root_path / "project_structure.json"

    # 寫入 JSON
    with output_file.open("w", encoding="utf-8") as f:
        json.dump(tree, f, indent=2, ensure_ascii=False)

    # 回顯訊息
    print(f"✅  Directory tree JSON written to: {output_file.resolve()}")