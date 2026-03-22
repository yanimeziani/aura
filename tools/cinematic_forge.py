#!/usr/bin/env python3
"""CLI shim — implementation lives in ``media.forge``."""

from __future__ import annotations

import sys
from pathlib import Path

_tools = str(Path(__file__).resolve().parent)
if _tools not in sys.path:
    sys.path.insert(0, _tools)

from media.forge import main

if __name__ == "__main__":
    raise SystemExit(main())
