"""Tests for Mental Biological Safety media copy audit."""

from __future__ import annotations

import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent.parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from media.audit import audit_media_copy


def test_clean_copy() -> None:
    r = audit_media_copy("A calm overview of sovereign digital architecture.")
    assert r.ok
    assert r.violations == ()


def test_hype_phrase_detected() -> None:
    r = audit_media_copy("Act now before you miss this offer.")
    assert not r.ok
    assert any("act now" in v.lower() for v in r.violations)


def test_warning_not_inside_forewarning() -> None:
    r = audit_media_copy("We offer forewarning about timelines.")
    assert r.ok


def test_standalone_warning_detected() -> None:
    r = audit_media_copy("Warning: this is not legal advice.")
    assert not r.ok
    assert any("warning" in v.lower() for v in r.violations)


def test_empty_whitespace_passes() -> None:
    r = audit_media_copy("   \n\t  ")
    assert r.ok
