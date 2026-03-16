#!/usr/bin/env python3
from __future__ import annotations

import runpy
from pathlib import Path


LEGACY_SCRIPT = Path(__file__).with_name("build-aura-docs-bundle.py")


if __name__ == "__main__":
    runpy.run_path(str(LEGACY_SCRIPT), run_name="__main__")
