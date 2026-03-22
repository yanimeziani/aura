"""Mental Biological Safety audit for AI-generated media copy."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Hype / dark-pattern phrases (match as substrings after lowercasing).
_HYPE_PHRASES: tuple[str, ...] = (
    "get rich quick",
    "secret formula",
    "limited time offer",
    "you're missing out",
    "buy now",
    "revolutionary breakthrough",
    "mind-blowing",
    "act now",
)

# Single tokens matched with word boundaries to cut false positives (e.g. "forewarning").
_HYPE_WORDS: tuple[str, ...] = (
    "guaranteed",
    "urgent",
    "100%",
)

_STRESS_PHRASES: tuple[str, ...] = (
    "left behind",
    "fatal error",
    "don't ignore",
    "critical mistake",
)

_STRESS_WORDS: tuple[str, ...] = (
    "warning",
    "danger",
    "failing",
    "disaster",
)


@dataclass(frozen=True)
class AuditResult:
    ok: bool
    violations: tuple[str, ...]


def _phrase_violations(text_lower: str, phrases: tuple[str, ...], label: str) -> list[str]:
    out: list[str] = []
    for phrase in phrases:
        if phrase in text_lower:
            out.append(f"{label}: {phrase!r}")
    return out


def _word_violations(text_lower: str, words: tuple[str, ...], label: str) -> list[str]:
    out: list[str] = []
    for word in words:
        if re.search(rf"\b{re.escape(word)}\b", text_lower):
            out.append(f"{label}: {word!r}")
    return out


def audit_media_copy(text: str) -> AuditResult:
    """
    Classify copy without printing. Use for programmatic checks and tests.
    """
    text_lower = text.lower().strip()
    if not text_lower:
        return AuditResult(ok=True, violations=())

    violations: list[str] = []
    violations.extend(_phrase_violations(text_lower, _HYPE_PHRASES, "Hype/Dark Pattern"))
    violations.extend(_word_violations(text_lower, _HYPE_WORDS, "Hype/Dark Pattern"))
    violations.extend(_phrase_violations(text_lower, _STRESS_PHRASES, "Anxiety/Stress Inducing"))
    violations.extend(_word_violations(text_lower, _STRESS_WORDS, "Anxiety/Stress Inducing"))

    # De-dupe while preserving order
    seen: set[str] = set()
    unique = tuple(v for v in violations if not (v in seen or seen.add(v)))

    return AuditResult(ok=len(unique) == 0, violations=unique)


def evaluate_media_copy(text: str, *, verbose: bool = True) -> bool:
    """
    Backwards-compatible API: print audit transcript and return pass/fail.
    """
    result = audit_media_copy(text)
    if verbose:
        if result.ok:
            print("✅ [MEZIANI AI AUDIT] Media copy passed. Cognitively safe and compliant.")
        else:
            print("❌ [MEZIANI AI AUDIT] Media copy rejected. Biological Safety Invariant violated.")
            for v in result.violations:
                print(f"   - {v}")
    return result.ok


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Meziani AI Media Audit Filter")
    parser.add_argument("--file", help="Path to the drafted media text file")
    parser.add_argument("--text", help="Direct text input to audit")
    args = parser.parse_args(argv)

    content = ""
    if args.file:
        try:
            content = Path(args.file).read_text(encoding="utf-8")
        except OSError as e:
            print(f"Error reading file: {e}", file=sys.stderr)
            return 1
    elif args.text:
        content = args.text
    else:
        content = sys.stdin.read()

    if not content.strip():
        print("No content provided to audit.", file=sys.stderr)
        return 1

    return 0 if evaluate_media_copy(content) else 1
